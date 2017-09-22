import std.array;
import std.string;
import std.stdio;
import std.file;
import std.conv;
import std.concurrency;
version(trace) import diesel.minitrace;

import ansiparser;
import textscreen;

@safe class ansi_exception : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

static const wchar[] decGraphics = [
    0x00A0, 0x25C6, 0x2592, 0x2409, 0x240C, 0x240D, 0x240A, 0x00B0, 0x00B1,
    0x2424, 0x240B, 0x2518, 0x2510, 0x250C, 0x2514, 0x253C, 0x23BA, 0x23BB,
    0x2500, 0x23BC, 0x23BD, 0x251C, 0x2524, 0x2534, 0x252C, 0x2502, 0x2264,
    0x2265, 0x03C0, 0x2260, 0x00A3, 0x00B7
];

enum {
    DEC_CKM = 1, // Application Cursor Keys
    DEC_SCNM = 5,
    DEC_AWM = 7, // Wraparound mode
    DEC_TCEM = 25, // Cursor
    DEC_ALTBUF_ALT = 47,

    DEC_ALTBUF = 1047,
    DEC_SAVE_CURSOR = 1048,
    DEC_ALT_AND_CURSOR = 1049,

    DEC_X10_MOUSE               = 9,
    DEC_VT200_MOUSE             = 1000,
    DEC_VT200_HIGHLIGHT_MOUSE   = 1001,
    DEC_BTN_EVENT_MOUSE         = 1002,
    DEC_ANY_EVENT_MOUSE         = 1003,
    DEC_FOCUS_EVENT_MOUSE       = 1004,
    DEC_EXT_MODE_MOUSE          = 1005,
    DEC_SGR_EXT_MODE_MOUSE      = 1006,
    DEC_URXVT_EXT_MODE_MOUSE    = 1015,
    DEC_ALTERNATE_SCROLL        = 1007,
};

@safe class AnsiScreenParser(FILE)
{
    struct Args {
        this(int[] a) { args = a; }
        int[] args;
        char x;
        bool empty() { return args.length == 0; }
        int opCall(int index, int def = 1) { return args.length > index ? args[index] : def; }
        alias args this;
    };

    alias CsiFn = @safe void delegate(Args);
    alias EscFn = @safe void delegate(char);

    AnsiParser parser;
    CsiFn[char] csiFunctions;
    EscFn[char] escFunctions;
    bool[int] decMode;
    bool[int] savedMode;
    TextScreen screen;
    bool appKeypad = false;

    int[2] savedCursor;

    public enum {
        DECCKM = 1, // Application Cursor Keys
        DECSCNM = 5,
        DECAWM = 7, // Wraparound mode
        DECTCEM = 25, // Cursor
    };

    alias SACallback = void delegate(string);
    SACallback oscCallback;

    FILE inFile;

    uint defaultFg = 0xff0000;
    uint defaultBg = 0x000000;

    uint bg;
    uint fg;
    ushort flags = 0;

    enum {
        CHARSET_NORMAL,
        DEC_LINE_DRAWING,
    };

    uint[4] characterSet = [ CHARSET_NORMAL, CHARSET_NORMAL, CHARSET_NORMAL, CHARSET_NORMAL ];
    bool shifting = false;

    private void unhandled(T...)(string x, T args)
    {
        writeln("UNHANDLED ", x, ": ", args);
    }

    uint[256] palette;

    private void setAttrs(Args attrs)
    {
        static const uint[] flagList = [
            0,
            TextScreen.BOLD,
            TextScreen.FAINT,
            TextScreen.ITALIC,
            TextScreen.UNDERLINED,
            TextScreen.BLINK,
            0,
            TextScreen.REVERSE,
            TextScreen.INVISIBLE,
            TextScreen.CROSSED_OUT
        ];
        if(attrs.empty) {
            flags = 0;
            fg = defaultFg;
            bg = defaultBg;
        } else
        for(int i=0; i<attrs.length; i++) {
            auto a = attrs[i];
            if(a == 0) {
                flags = 0;
                fg = defaultFg;
                bg = defaultBg;
            } else if((a == 38 || a == 48)) {
                i++;
                if(i >= attrs.length) break;
                uint col = 0xff00_0000;
                if(attrs[i] == 2) {
                    col |= attrs[i+1]<<16 | attrs[i+2]<<8 | attrs[i+3];
                    i += 3;
                } else if(attrs[i] == 5)
                    col |= palette[attrs[++i]];
                if(a == 38)
                    fg = col;
                else
                    bg = col;
            } else if(a >= 40 && a <= 49)
                bg = a == 49 ? defaultBg : palette[a - 40];
            else if(a >= 30 && a <= 39)
                fg = a == 39 ? defaultFg : palette[a - 30];
            else if(a >= 90 && a <= 97)
                fg = palette[a - 90 + 8];
            else if(a >= 100 && a <= 107)
                bg = palette[a - 100 + 8];
            else if(a < 10)
                flags |= flagList[a];
            else if(a >= 21 && a <= 29)
                flags &= ~flagList[a - 20];
            else
                unhandled("Attribute", a);
        }
        screen.setColor(fg, bg, flags);
    }

    this(FILE inFile, TextScreen ts = null)
    {
        import xtermpalette;

        for(int i=0; i<256; i++)
            palette[i] = xpal[i] | (i == 0 ? 0 : 0xff000000);
        defaultFg = palette[7];
        defaultBg = palette[0];

        this.screen = ts;
        this.inFile = inFile;
        parser = new AnsiParser();

        decMode[DECAWM] = true;

        escFunctions = [
            '#' : (char c) {
                writeln("RESET");
                screen.clear(-1,-1,-1,'E');
                screen.gotoXY(1,1);
            },
            '(' : (char c) {
                if(c == '0')
                    characterSet[0] = DEC_LINE_DRAWING;
                else if(c == 'B')
                    characterSet[0] = CHARSET_NORMAL;
            },
            ')' : (char c) {
                if(c == '0')
                    characterSet[1] = DEC_LINE_DRAWING;
                else if(c == 'B')
                    characterSet[1] = CHARSET_NORMAL;
            },
            '=' : (char c) { appKeypad = true; },
            '>' : (char c) { appKeypad = false; },
            '7' : (char c) { savedCursor = screen.cursor; },
            '8' : (char c) { screen.gotoXY(savedCursor[0], savedCursor[1]); },
            'D' : (char c) {
                    if(screen.y == screen.scrollBottom)
                        screen.scroll(1);
                    else
                        screen.setDY(1);
            },
            'M': (char c) {
                    if(screen.y == 1)
                        screen.scroll(-1);
                    else
                        screen.setDY(-1);
            },
            'E': (char c) {
                    if(screen.y == screen.scrollBottom)
                        screen.scroll(1);
                    else
                        screen.gotoXY(1, screen.y + 1);
            }
        ];

        csiFunctions = [
            '@' : (Args a) { screen.insert(screen.x, a(0,1), ' '); },
            'A' : (Args a) { screen.setDY(-a(0,1)); },
            'B' : (Args a) { screen.setDY(a(0,1)); },
            'C' : (Args a) { screen.setDX(a(0,1)); },
            'D' : (Args a) { screen.setDX(-a(0,1)); },

            // TODO: Should these scroll
            'E' : (Args a) { screen.gotoXY(1, screen.y + a(0,1)); },
            'F' : (Args a) { screen.gotoXY(1, screen.y - a(0,1)); },
            'G' : (Args a) { screen.gotoXY(a(0,1), screen.y); },

            'H' : (Args a) { screen.gotoXY(a(1,1), a(0,1)); },
            'J' : (Args a) {
                int j = a(0,0);
                if(j == 2) screen.clear();
                else if(j == 0) {
                    screen.clear(screen.x, screen.y);
                    for(int i=screen.y+1; i <= screen.height; i++)
                        screen.clearLine(i);
                } else if(j == 1) {
                    for(int i=1; i < screen.y; i++)
                        screen.clearLine(i);
                    screen.clear(0, screen.y, screen.x);
                }
            },
            'K' : (Args a) {
                int j = a(0,0);
                int sx = j == 0 ? screen.x : 1;
                int ex = j == 1 ? screen.x : screen.width;
                screen.clear(sx, screen.y, ex - sx);
            },
            'L' : (Args a) { screen.insertLines(screen.y, a(0,1)); },
            'M' : (Args a) { screen.delLines(screen.y, a(0,1)); },
            'P' : (Args a) { screen.del(screen.x, a(0,1)); },
            'S' : (Args a) { screen.scroll(a(0,1)); },
            'T' : (Args a) { screen.scroll(-a(0,1)); },
            'c' : (Args a) {
                if(a.x == '>')
                    inFile.write("\x1b[>0;1;1c");
                else
                    inFile.write("\x1b[?0;1;1c");
            },
            'f' : (Args a) { screen.gotoXY(a(1,1), a(0,1)); },
            'm' : &setAttrs,
            /* 'h' : (Args a) { */
            /*     // TODO: 4 = insert mode */
            /* }, */
            /* 'l' : (Args a) { */
            /*     // TODO : 4 = replace mode */
            /* }, */
            'n' : (Args a) {
                if(a[0] == 5)
                    inFile.write("\x1b[0n");
                else if(a[0] == 6)
                    inFile.write(format("\x1b[%d;%dR", screen.y, screen.x));
            },
            'r' : (Args a) { screen.setScrollRegion(a(0,1), a(1, screen.height)); },
            'd' : (Args a) { screen.gotoXY(screen.x, a(0,1)); },
            'X' : (Args a) { screen.clear(screen.x, -1, a[0]); },
            'p' : (Args a) {
                if(a.x == '!') {
                    screen.setScrollRegion();
                    screen.setColor(defaultFg, defaultBg, 0);
                    screen.showCursor(true);
                    decMode[DECAWM] = false;
                    characterSet = [CHARSET_NORMAL, CHARSET_NORMAL, CHARSET_NORMAL, CHARSET_NORMAL];
                    screen.gotoXY(1,1);
                    shifting = false;
                }
            }

        ];
    }

    public bool getMode(int m) {
        if(m in decMode)
            return decMode[m];
        return false;
    }

    private bool handleDec(char cmd, int[] args)
    {
        //writeln("DECMODE ", cmd, " ", args);
        switch(cmd) {
        case 'h':
            foreach(a ; args) {
                decMode[a] = true;
                switch(a) {
                case DEC_CKM:
                case DEC_BTN_EVENT_MOUSE:
                case DEC_SGR_EXT_MODE_MOUSE:
                case DEC_X10_MOUSE:
                    break;

                case DECTCEM:
                    screen.showCursor(true);
                    break;
                //case DECSCNM:
                    // TODO: Global inverse
                    //break;
                case DEC_SAVE_CURSOR:
                    savedCursor[0] = screen.x;
                    savedCursor[1] = screen.y;
                    break;
                case DEC_ALT_AND_CURSOR:
                    savedCursor[0] = screen.x;
                    savedCursor[1] = screen.y;
                    goto case DEC_ALTBUF;
                case DEC_ALTBUF:
                case DEC_ALTBUF_ALT:
                    screen.altBuffer(true);
                    break;
                default :
                    return false;
                }
            }
            break;
        case 'l':
            foreach(a ; args) {
                decMode[a] = false;
                switch(a) {
                case DECTCEM:
                    screen.showCursor(false);
                    break;
                case DECSCNM:
                    break;
                case DEC_SAVE_CURSOR:
                    screen.gotoXY(savedCursor[0], savedCursor[1]);
                    break;
                case DEC_ALT_AND_CURSOR:
                    screen.gotoXY(savedCursor[0], savedCursor[1]);
                    goto case DEC_ALTBUF;
                case DEC_ALTBUF:
                case DEC_ALTBUF_ALT:
                    flags = 0;
                    fg = defaultFg;
                    bg = defaultBg;
                    screen.setColor(fg, bg, flags);
                    screen.altBuffer(false);
                    break;
                default :
                    return false;
                }
            }
            break;
        case 's':
            savedMode = decMode.dup;
            break;
        case 'r':
            decMode = savedMode.dup;
            break;
        default:
            return false;
        }
        return true;
        // TODO m , n Reporting

    }

    private void putString(string utf8) {
        put(cast(immutable ubyte[])utf8);
    }

    private void put(const ubyte[] t)
    {
        import std.uni;
        version(trace) auto _st = ScopedTrace();
        import std.utf;
        if(t.length > 0)
            parser.put(t);
        foreach (seq; parser) {
            //debug writeln(seq);
            if(seq.isText) {
                size_t index = 0;
                dchar[] ws;
                while(index < seq.text.length) {
                    dchar c;
                    try {
                        c = std.utf.decode(seq.text, index);
                    } catch(UTFException e) {
                        c = '?';
                        index++;
                    }

                    if(characterSet[0] == DEC_LINE_DRAWING)
                        c = decGraphics[c - 0x5f];

                    // TODO: Get the G0/G1/Char set logic right
                    if(shifting && c <= 0x7f && c >= 0x20)
                        c += 0x80;
                    if(shifting && characterSet[1] == DEC_LINE_DRAWING && c>= (0x5f+0x80))
                        c = decGraphics[c - 0x80 - 0x5f];
                    if(c >= 0x300 && c <= 0x365) {
                        // TODO: Deal with split in between composed chars
                        if(ws.length > 0)
                            ws[$-1] = compose(ws[$-1], c);
                    }
                    else
                        ws ~= c;
                }
                screen.write(ws, getMode(DECAWM));
            } else if(seq.type == AnsiParser.OSC) {
                if(oscCallback) {
                    oscCallback(seq.text);
                }
            } else if(seq.type == AnsiParser.DCS) {
                if(seq.text[0 .. 1] == "$q") {
                    inFile.write("\x900$r" ~ seq.text[2 .. $] ~ "\x07");
                }
            }
            else {
                try {
                    putAnsi(seq);
                } catch (Exception e) {
                    writefln(format("CRASH [%(%02x, %)]", t));
                    throw e;
                }
            }
        }
    }

    void flush() {
        parser.flush();
        put([]);
    }


    void onOSC(SACallback cb) {
        oscCallback = cb;
    }

    private void putAnsi(AnsiParser.Code code)
    {
        version(trace) auto _st = ScopedTrace();
        bool handled = false;
        auto t = code.tail;

        if(code.type == AnsiParser.CC) {
            handled = true;
            switch(t[0]) {
            case 7:
                // TODO: Bell
                break;
            case 9:
                screen.gotoXY(((screen.x+7) & 0xfff8) + 1, screen.y);
                break;
            case 8:
                screen.setDX(-1);
                break;
            case 12:
            case 11:
            case 10:
                screen.setDY(1, true);
                break;
            case 13:
                screen.gotoXY(1,screen.y);
                break;
            case 14:
                writeln("SHIFT");
                shifting = true;
                break;
            case 15:
                //characterSet = CHARSET_NORMAL;
                shifting = false;
                break;
            default :
                handled = false;
                break;
            }
        } else if(code.type == AnsiParser.ESC) {

            auto cmd = code.tail[0];
            auto arg = code.tail.length > 1 ? cast(char)code.tail[1] : cast(char)0;

            if(cmd in escFunctions) {
                escFunctions[cmd](arg);
                handled = true;
            }

        } else if(code.type == AnsiParser.CSI) {
            char cmd = 0;
            if(t.length > 0) cmd = t[$-1];
            char x = 0;
            if(t.length > 1) x = t[0];
            handled = false;
            if(x == '?') {
                handled = handleDec(cmd, code.params);

            } else if(cmd in csiFunctions) {
                auto args = Args(code.params);
                args.x = x;
                csiFunctions[cmd](args);
                handled = true;
            }
        }
        try {
            if(!handled)
                unhandled("", code);
        } catch(Exception e) { }

    }

    // Main worker. Call regularly to populate TextScreen
    int update(int count = 100)
    {
        import core.stdc.errno;

        version(trace) auto _st = ScopedTrace();
        ubyte[128*1024] b;
        int bytes = 0;
        auto rc = inFile.read(b);
        if(rc < 0 && errno != EAGAIN)
			return -1;
        int wraps = 0;
        int scrolls = 0;
        while (rc > 0) {
            bytes += rc;
            count--;
            ubyte[] r = b[0 .. rc];
            //writefln("[%(%02x %)]", r);
            put(r);
            if(count == 0)
                break;
            rc = inFile.read(b);
			if(rc < 0 && errno != EAGAIN)
				return -1;
        }
        if(rc <= 0 && parser.inProgress()) {
            flush();
            bytes++;
        }
        return bytes;
    }

    public void setPalette(const uint[] pal) {
        palette[0..pal.length] = pal;
        defaultFg = palette[7];
        defaultBg = palette[0];
        screen.setColor(defaultFg, defaultBg, 0);
        screen.refreshBg();
    }

};

