
import launch : launch, PtyFile, signal_winsize;
import dec : Dec;
import ansiscreenparser;
import textscreen;
import std.string : format;
import std.conv : to;
import std.utf;
import std.stdio;

import diesel.keycodes;

struct TermState {
    bool mouseReport = false;
    int scrollPos = 0;
    int scrollTop = 0;
};

@safe class TerminalSession
{
    public TermState state;
    private TextScreen screen;
    private AnsiScreenParser!PtyFile parser;
    private PtyFile tty;

    private int[2] currentMouse;
    private bool leftMouseDown = false;
    private bool screenChanged = true;
    private bool dead = false;

	struct Cb {
		int offset;
		void delegate(int, uint) @safe cb;
		alias cb this;
	}

    private Cb[int] keyCallbacks;
    private Cb defaultCb;

    this(int cols, int rows, PtyFile tty)
    {
        this.tty = tty;
        screen = new TextScreen(cols, rows);
        parser = new AnsiScreenParser!PtyFile(tty, screen);
        setupKeys();
    }

    void onOSC(void delegate(string) @safe cb)
    {
        parser.onOSC(cb);
    }

    void kill()
    {
        tty.kill();
    }

    immutable(CHANGE[]) getChanges(CHANGE)()
    {
        if(!screenChanged) return [];
        screenChanged = false;
        return screen.getChanges!CHANGE();
    }

    int update()
    {
        int changed = 0;
		if(dead) return -1;
        int rc = parser.update(10);
		dead = (rc < 0);
        if(screen.changed) screenChanged = true;
        bool ma = parser.getMode(Dec.BTN_EVENT_MOUSE) || parser.getMode(Dec.VT200_MOUSE);
        if(ma != state.mouseReport) {
            state.mouseReport = ma;
            changed = 1;
        }
        if(screen.scrollBackTop != state.scrollTop) {
            state.scrollTop = screen.scrollBackTop;
            changed = 1;
        }
        if(screen.scrollOffset != state.scrollPos) {
            state.scrollPos = screen.scrollOffset;
            changed = 1;
        }
        return changed;
    }

    void resize(int w, int h)
    {
        update();
        //parser.clear();
        screen.resize(w, h);
        signal_winsize(tty, cast(ushort)w, cast(ushort)h);
    }

    void putKey(uint code)
    {
        auto mods = code & 0xff_000000;
        code &= 0x00_ffffff;
        if(code in keyCallbacks) {
            auto cb = keyCallbacks[code];
            cb(cb.offset, mods);
        } else if(defaultCb)
            defaultCb(code, mods);
    }

    void reportMouse(int[2] pos)
    {
        if(currentMouse != pos) {
            currentMouse = pos;
            if(parser.getMode(Dec.BTN_EVENT_MOUSE)) {
                int m = leftMouseDown ? 0 : 3;
                wchar mc = (m == 0 ? 'M' : 'm');
                //tty.write("\x1b[<" ~ to!string(m+32) ~ ";" ~to!string(currentMouse[0]) ~ ";" ~ to!string(currentMouse[1]) ~ (m == 0 ? "M" : "m"));
                tty.write(format("\x1b[<%d;%(%d;%)%c", m+32, currentMouse, mc));
            }
        }
    }

    void setScroll(int y)
    {
        if(!screen.usingAlt) {
            screen.scrollOffset = y;
            screenChanged = true;
        }
    }

    void setPalette(const uint[] pal) {
        parser.setPalette(pal);
        //screen.refresh();
        screenChanged = true;
        //signal_winsize(tty, cast(short)screen.width, cast(short)screen.height);
    }

    private void onKeyDefault(void delegate(int, uint) @safe cb)
    {
        defaultCb = cb;
    }

    private void onKey(int code, void delegate() @safe cb, int offs = 0)
    {
        keyCallbacks[code] = Cb(offs, (int, uint){ cb(); });
    }

    private void onKey(int code, void delegate(int) @safe cb, int offs = 0)
    {
        keyCallbacks[code] = Cb(offs, (int k, uint) { cb(k); });
    }

    private void onKey(int code, void delegate(int, uint) @safe cb, int offs = 0)
    {
        keyCallbacks[code] = Cb(offs, cb);
    }

    private void onKey(ARGS...)(int[] codes, void delegate(ARGS) @safe cb)
    {
        foreach(int i, code ; codes)
			onKey(code, cb, i);
    }

    private void setupKeys()
    {
        // Generate partial ansi code from modifiers
        static string mods2code(uint m)
        {
            const static auto lookup = [0, 2, 5, 6, 3, 4, 7, 8];
            string mods = "";
            // Rely on DKM_ enum order
            m = lookup[(m>>24)&7];
            if(m != 0)
                mods = format(";%d", m);
            return mods;
        }

        onKey([DK_LEFT_MOUSE_UP, DK_RIGHT_MOUSE_UP, DK_MIDDLE_MOUSE_UP,
                DK_LEFT_MOUSE_DOWN, DK_WHEEL_UP,  DK_WHEEL_DOWN], (int k) {
            //leftMouseDown = k == 3;
            if(parser.getMode(Dec.BTN_EVENT_MOUSE) || parser.getMode(Dec.VT200_MOUSE)) {
                if(parser.getMode(Dec.SGR_EXT_MODE_MOUSE)) {
                    static int[6] tx = [ 0, 2, 1, 0, 64, 65 ];
                    wchar mc = (k > 2 ? 'M' : 'm');
                    tty.write(format("\x1b[<%d;%d;%d%c", tx[k], currentMouse[0], currentMouse[1], mc));
                    //tty.write("\x1b[<0;" ~to!string(currentMouse[0]) ~ ";" ~ to!string(currentMouse[1]) ~ (k == 0 ? "M" : "m"));
                } else {
                    wchar mc = (k == 0 ? ' ' + 0 : ' ' + 3);
                    tty.write(format("\x1b[M%c%c%c", mc, cast(char)(' ' + currentMouse[0]), cast(char)(' ' + currentMouse[1])));
                }
            }
        });

		onKey([DK_ESC, DK_ENTER, DK_BACKSPACE, DK_TAB], (int k) {
				char[] x = [0x1b,13,8,9];
				tty.write(format("%c", x[k]));
		});

        onKey([DK_UP, DK_DOWN, DK_RIGHT, DK_LEFT], (int k, uint m){
            const string letters = "ABCD";
            bool am = parser.getMode(Dec.CKM);
            string mods = mods2code(m);
            if(mods != "") {
                mods = "1" ~ mods;
                am = false;
            }
            if(am)
                tty.write("\x1b\x4f" ~ letters[k]);
            else
                tty.write("\x1b[" ~ mods ~ letters[k]);
        });

        onKey([DK_F1, DK_F2, DK_F3, DK_F4], (int k, uint m) {
            const string letters = "PQRS";
            tty.write("\x1b\x4f" ~ mods2code(m) ~ letters[k]);
        });

        onKey([DK_F5, DK_F6, DK_F7, DK_F8, DK_F9,
                DK_F10, DK_F11, DK_F12], (int k, uint m) {
            int[] codes = [15,17,18,19,20,21,23,24,25,26,28,29];
            tty.write("\x1b[" ~ to!string(codes[k]) ~ mods2code(m) ~ "~");
        });

        onKey(DK_HOME, (int, uint m) {
            bool am = parser.getMode(Dec.CKM);
            string mods = mods2code(m);
            if(mods != "") {
                mods = "1" ~ mods;
                am = false;
            }
            if(am)
                tty.write("\x1b\x4fH");
            else
                tty.write("\x1b[" ~ mods ~ "H");
        });

        onKey(DK_END, (int, uint m) {
            bool am = parser.getMode(Dec.CKM);
            string mods = mods2code(m);
            if(mods != "") {
                mods = "1" ~ mods;
                am = false;
            }
            if(am)
                tty.write("\x1b\x4fF");
            else
                tty.write("\x1b[" ~ mods ~ "F");
        });

        onKey(DK_PAGEUP, { tty.write("\x1b[5~"); });
        onKey(DK_PAGEDOWN, { tty.write("\x1b[6~"); });
        onKeyDefault((int c, uint mods) {
            if(mods & DKM_CTRL) {
                if(c >= 'a' && c <= 'z')
                    c = c + 1 - 'a';
                else if(c >= '[' && c <= '_')
                    c = c + 27 - '[';
                else if(c == '?')
                    c = 127;
                else if(c == ' ')
                    c = 0;
            } else if(c == DK_DELETE)
                c = 127;
            if(c <= 0xffff) {
                wstring s = [cast(wchar)c];
                string x = std.utf.toUTF8(s);
                tty.write(x);
            }
        });
    }

};

