import std.conv;
import std.stdio;
import std.typecons;
import std.experimental.logger;

import wrap : wrap, unwrap;
import textbuffer;

version(trace) import diesel.minitrace;

import cutops : shift;

struct Attrs {
    ushort flags = 0;
    uint fg = 0xffffff00;
    uint bg = 0xff000000;
}

@safe struct Change
{
    this(wstring text, int x, int y, uint fg, uint bg, uint flags) {
        this.text = text;
        this.x = cast(ushort)x;
        this.y = cast(ushort)y;
        this.fg = fg;
        this.bg = bg;
        this.flags = cast(ushort)flags;
    }

    this(wstring text, int x, int y, Attrs a) {
        this.text = text;
        this.x = cast(ushort)x;
        this.y = cast(ushort)y;
        this.fg = a.fg;
        this.bg = a.bg;
        this.flags = cast(ushort)a.flags;
    }

    wstring text;
    ushort x;
    ushort y;
    uint fg;
    uint bg;
    ushort flags;
}

alias CHAR = wchar;

// We extend the generic TextBuffer for our ANSI needs; attributes have for- and background colors,
// we add a cursor postion and various operations on the buffer etc
@safe class TextScreen : TextBuffer!(CHAR, Attrs)
{
    static const enum {
        BOLD = 1,
        ITALIC = 2,
        UNDERLINE = 4,
        BLINK = 8,
        REVERSE = 16,
        UNDERLINED = 32,
        INVISIBLE = 64,
        FAINT = 128,
        CROSSED_OUT = 256,

        CURSOR_POS = 0x1000,
    };

    int x = 0;
    int y = 0;

    int[2] cursor() { return [x,y]; }

    int scrollTop = 1;
    int scrollBottom = 0;;
    bool cursorOn = true;

    int scrollBackTop = 0;

    private TextLine[] altData;
    private TextLine[] realData;
    public bool usingAlt = false;

    immutable (TextLine)[] scrollBack;

    invariant {
        /* assert(x <= width+1); */
        /* assert(y <= height); */
        /* assert(scrollTop >= 1); */
        /* assert(scrollBottom <= height); */

        /* //assert(realData == null || altData == null); */

    }

    //public auto getCursor() { return tuple(x, y); }

    bool didChange = false;

    @property bool changed() {
        bool rc = didChange;
        didChange = false;
        return rc;
    }

    this(int w, int h, uint bg = 0x00000000, uint fg = 0xffffffff)
    {
        super(w,h);

        altData = new TextLine[h];
        foreach(ref d; altData)
            d = TextLine(width, ' ', attrs);

        x = y = 1;
        attrs.fg = fg;
        attrs.bg = bg;
        scrollBottom = height;
        scrollTop = 1;
        didChange = true;
    }

    override void resize(int w, int h) {

        //writefln("RESIZE %dx%d", w, h);

        didChange = true;

        if(!usingAlt) {

            auto len = allLines.length;
            auto lines = allLines;

            // Mark cursor location
            if(x > 0 && y > 0 && x <= width && y <= height) {
                screen[y-1][x-1].c = 0x1b;
            }

            // Join any wrapped lines
            lines = unwrap!((auto ref t) => t.wrapped)(lines);
            // Strip trailing spaces
            foreach(ref d ; lines) {
                auto l = d.length;
                while(l > 0 && (d[l-1].c == ' ')) l--;
                d = d[0 .. l];
            }

            // Locate cursor and delete text after it
            bool found = false;
            foreach(yy, ref line ; lines) {
                foreach(xx, cell ; line) {
                    if(cell.c == 0x1b) {
                        //writefln("Cursor line %d cut at %d", yy, xx);
                        //writeln(line[0 .. xx].toString());
                        line = line[0 .. xx+1];
                        found = true;
                        break;
                    }
                }
                if(found) {
                    lines = lines [0 .. yy+1];
                    //writefln("Last line: %02x", lines[$-1][0].c);
                    break;
                }
            }

            // Wrap lines to the new width
            lines = wrap!((auto ref a, bool w) => a.wrapped = w)(lines, w, TextLine.Item(' ', attrs));

            // Add or remove lines to get back to same number of lines
            while(lines.length > len)
                lines = lines[1 .. $];

            auto empty = TextLine(w, ' ', attrs);
            while(lines.length < len)
                lines = empty ~ lines;

            foreach(i, l ; lines)
                if(l != empty) {
                    //writeln("First non empty line at ", i);
                    scrollBackTop = cast(int)(len - i);
                    break;
                }

            allLines = lines;
            screen = allLines[$ - h .. $];
            //screen.set(allLines, h, allLines.length - h);

            // Locate cursor again to set position
            foreach(int yy, ref line ; screen) {
                foreach(int xx, ref cell ; line) {
                    if(cell.c == 0x1b) {
                       // writefln("Cursor at %d, %d", xx, yy);
                        cell.c = ' ';
                        x = xx + 1;
                        y = yy + 1;
                        break;
                    }
                }
            }

        } else {
            // In ALT buffer mode, just resize
            altData.length = h;
            screen = altData;
            //screen.set(altData);
            foreach(ref d ; screen) {
                d.resize(w, ' ', attrs);
            }
        }

        lastData.length = h;
        lastData[] = TextLine(w, 0);

        width = w;
        height = h;

        if(x >= w) x = w;
        if(y >= h) y = h;
        scrollBottom = height;
        scrollTop = 1;
    }

    void setColor(uint fg, uint bg, ushort flags) {
        attrs.fg = fg;
        attrs.bg = bg;
        attrs.flags = flags;
    }

    void refreshBg()
    {
        foreach(ref l ; allLines) {
            foreach(ref c ; l) {
                if((c.a.bg & 0xffffff) == 0)
                    c.a.bg = attrs.bg;
            }
        }
        refresh();
    }

    void setDY(int dy, bool doScroll = false) {
        didChange = true;
        y += dy;
        if(y < scrollTop) y = scrollTop;
        if(y > scrollBottom) {
            int sy = y - scrollBottom;
            y = scrollBottom;
            if(doScroll) {
                scroll(sy);
            }
        }
    }

    void setDX(int dx, bool doWrap = false) {
        didChange = true;
        x += dx;
        if(x < 1) x = 1;
        if(x > width)  {
            if(doWrap) {
                x = 1;
                setDY(1, true);
            } else
                x = width;
        }
    }

    void gotoXY(int x, int y)
    {
        if(x > width || y > height || x < 1 || y < 1) {
            writeln("GOTOXY OUTSIDE: ", x, " ", y);
            return;
        }
        didChange = true;
        this.x = x;
        this.y = y;
    }

    // Clear l chars in line from (x,y)
    void clear(int x = -1, int y = -1, int l = -1, wchar c = ' ') {
        didChange = true;
        if(x == -1 && y == -1 && l == -1) {
            foreach(ref d ; screen)
                d = makeEmpty(c);
        }
        if(x == -1) x = this.x;
        if(y == -1) y = this.y;
        if(l == -1)
            l = width - x;
        while(x <= width && l >= 0) {
            put(x++, y, c);
            l--;
        }
    }

    private TextLine makeEmpty(wchar c = ' ') {
        return TextLine(width, c, attrs);
    }

    void clearLine(int y) {
        didChange = true;
        tracef("clearLine %d", y);
        screen[y-1] = makeEmpty();
    }

    void insertLines(int y, int count) {
        didChange = true;
        tracef("insertLines %d+%d", y, count);
        shift(screen[y - 1 .. scrollBottom], -count, makeEmpty());

    }

    void delLines(int y, int count) {
        didChange = true;
        shift(screen[y - 1 .. scrollBottom], count, makeEmpty());
        tracef("delLines %d+%d", y, count);
    }

    void del(int x, int count) {
        didChange = true;
        tracef("del %d+%d", x, count);
        shift(screen[y-1][x-1 .. $], count, TextLine.Item(' ', attrs));
    }

    void insert(int x, int count, CHAR what = ' ') {
        didChange = true;
        tracef("insert %d+%d", x, count);
        shift(screen[y-1][x-1 .. $], -count, TextLine.Item(what, attrs));
    }

    void setScrollRegion(int top = 1, int bottom = -1)
    {
        if(bottom <= 0) bottom = height;
        tracef("setScrollRegion [%d %d]", top, bottom);
        scrollTop = top;
        scrollBottom = bottom;
    }

    void scroll(int dy)
    {
        didChange = true;
        //debug writefln("scroll %d in %d .. %d", dy, scrollTop, height);
        if(!usingAlt) {
            // TODO: Use scrollTop
            scrollBackTop += dy;
            if(scrollBackTop >= allLines.length)
                scrollBackTop = cast(int)allLines.length - 1;
            shift(allLines[0 .. $ - (height - scrollBottom)], dy, makeEmpty());
        } else
            shift(altData[scrollTop -1 .. scrollBottom], dy, makeEmpty());
    }

    void write(T)(const T[] text, bool wrap)
    {
        screen[y-1].wrapped = false;
        if(x == 1 && y > 1)
            screen[y-2].wrapped = false;
        didChange = true;
        foreach(c ; text) {
            if(x > width) {
                if(wrap) {
                    x = 1;
                    screen[y-1].wrapped = true;
                    setDY(1, true);
                } else
                    x--;
            }
            put(x, y, cast(wchar)c);
            x += 1;
        }
    }

    void showCursor(bool show) {
        didChange = true;
        cursorOn = show;
    }

    Attrs realAttrs;

    void altBuffer(bool on)
    {
        didChange = true;
        writeln("ALT ", on);
        if(on && !usingAlt) {
            realAttrs = attrs;
            usingAlt = true;
            altData.length = height;
            foreach(ref d ; altData)
                d = makeEmpty();
            screen = altData;
            scrollOffset = 0;
        } else if(!on && usingAlt) {
            attrs = realAttrs;
            usingAlt = false;
            scrollOffset = 0;
            if(allLines[0].length != width) {
                resize(width, height);
            }
            screen = allLines[$-height .. $];
        }
    }

    @trusted toImmutable(T)(T c) {
        return cast(immutable(T))(c);
    }

    immutable(CHANGE)[] getChanges(CHANGE)()
    {
        version(trace) auto _st = ScopedTrace();

        bool showCursor = (cursorOn && x > 0 && y > 0 && x <= width && y <= height);
        if(showCursor) screen[y-1][x-1].a.flags |= CURSOR_POS;
        auto textChanges = super.getChanges!CHANGE();
        if(showCursor) screen[y-1][x-1].a.flags &= ~CURSOR_POS;

        // NOTE: We have no other references to `textChanges` at this point so
        // it is safe to cast to immutable -- and it saves us a bunch of copying
        return toImmutable(textChanges);
    }

}

