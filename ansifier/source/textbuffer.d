
import std.stdio;
import std.traits;


version(trace) import diesel.minitrace;

static @trusted toImmutable(T)(T c) {
    return cast(immutable(T))(c);
}
@safe class TextBuffer(CHAR, ATTRS)
{
	static const int WRAPPED = 1;

    import std.typecons;
    struct TextLine {

        struct Item {
            CHAR c;
            ATTRS a;
        };

        this(immutable Item[] items, int flags = 0) immutable {
            data = items;
            this.flags = flags;
        }

        this(Item[] items, int flags = 0) {
            data = items;
            this.flags = flags;
        }

        this(int n,  CHAR c = ' ', ATTRS a = ATTRS.init) {
            data = new Item[n];
            foreach(ref d ; data) {
                d.c = c;
                d.a = a;
            }
        }

        // Resize line, Filling with c/a if needed
        void resize(int w, CHAR c = ' ', ATTRS a = ATTRS.init) {
            auto item = Item(c, a);
            while(data.length < w) {
                data ~= item;
            }
            data.length = w;
        }

        size_t opDollar() const { return data.length; }

        TextLine opSlice(size_t a, size_t b) {
            return TextLine(data[a..b], flags);
        }

        TextLine opSlice() {
            return TextLine(data[], flags);
        }

        @property auto length() const { return data.length; }
        @property void length(size_t l) {
            resize(cast(int)l);
        }

        immutable (CHAR)[] getString() {
            auto s = new CHAR[data.length];
            foreach(i, d ; data)
                s[i] = d.c;
            return toImmutable(s);
        }

        bool opEquals(T)(T other) if(isSomeString!T) {
            return getString() == other;
        }

        bool opEquals(TextLine other) {
            return data == other.data;
        }

        string toString() {
            import std.utf;
            return '\"' ~ toUTF8(getString()) ~ '\"' ~ (flags & WRAPPED ? "w" :"");
        }

        immutable(TextLine) idup() {
            return immutable TextLine(data.idup, flags);
        }

        Item[] data;
		int flags = 0;
        alias data this;

		@property bool wrapped() { return (flags & WRAPPED) != 0; }
		@property void wrapped(bool on) {
			if(on) flags |= WRAPPED;
			else flags &= ~WRAPPED;
		}
    };

    ATTRS attrs;

    int _width = 0;
    int _height = 0;
	void width(int w) { _width = w; }
	int width() inout { return _width; }
	void height(int h) { _height = h; }
	int height() inout { return _height; }

    // Entire buffer. Actually allocated
    protected TextLine[] allLines;
    // View into buffer where text is rendered
    protected TextLine[] screen;
    // Copy of last view sent
    protected TextLine[] lastData;

    // Offset to what is seen
    int scrollOffset = 0;


    /* invariant { */
    /*     assert(data.length == lastData.length); */
    /*     assert(data.length == _height); */
    /*     if(data.length > 0) { */
    /*         assert(data.data[0].length == _width); */
    /*         assert(lastData.data[0].length == _width); */
    /*         assert(data.data[$-1].length == _width); */
    /*         assert(lastData.data[$-1].length == _width); */
    /*     } */
    /* } */

    this(int w, int h)
    {
		allLines = new TextLine[1000];
        screen = allLines[$-h .. $];
        resize(w, h);
    }

    void refresh() {
        lastData[] = TextLine(width, 0, ATTRS.init);
    }

    void resize(int w, int h) {
        width = w;
        height = h;
        debug writeln("RESIZE ", w, "x", h);

        foreach(ref d ; allLines) {
            if(w != d.length)
                d.resize(w);
        }
        lastData.length = h;
        lastData[] = TextLine(w,0);

        screen = allLines[$-h .. $];
        scrollOffset = 0;

    }

    void put(int x, int y, CHAR c) {
        if(x > width || y > height) return;
        screen[y-1][x-1] = TextLine.Item(c, attrs);
    }

    void put(int x, int y, const(CHAR[]) text) {
        foreach(CHAR c ; text) {
            if(x > width) return;
            put(x++, y, c);
        }
    }

    TextLine.Item charAt(int x, int y)  {
        return screen[y-1][x-1];
    }

/*
   How to build the string:
   * Find first character where _Attrs_ OR _Char_ have changed
   * Save ATTRS as a
   * Store characters until;
        Current AND last character are the same
    AND Current AND last character attributes are the same
    OR  Current ATTRS != a
*/

    //

    CHANGE[] getChanges(CHANGE)()
    {
        version(trace) auto _st = ScopedTrace();

        int sy = 0;

        CHANGE[] textChanges;

        TextLine[] view = screen;
        if(scrollOffset != 0)
            view = allLines[$ - height - scrollOffset .. $ - scrollOffset];

        foreach(y ; sy .. sy + height) {
            auto x = 0;
            while(true) {
                // Skip over characters that has not changed
                while(x < width && view[y][x] == lastData[y][x]) x++;

                if(x == width)
                    break;

                // Record start of changed text
                auto a = view[y][x].a;
                auto start = x++;


                // Iterate over changes, building the string
                while(x < width && view[y][x] != lastData[y][x] && view[y][x].a == a) {
                    x++;
                }

                auto dl = view[y][start .. x].getString();
                textChanges ~= CHANGE(dl, start+1, y+1, a);
            }
            lastData[y] = view[y].dup;
        }

        return textChanges;
    }

}


unittest {

    auto text = new TextBuffer!(dchar, uint)(10, 9);

    writeln(text.screen.length);
    writeln(text.screen[0].length);

    text.resize(8,5);

    writeln(text.screen);

    writeln(text.screen.length);
    writeln(text.screen[0].length);

    auto lines = text.join(text.screen);

    assert(lines.length == 5);

    lines = text.wrap(lines);

    writeln(lines);
    assert(lines.length == 5);

     text = new TextBuffer!(dchar, uint)(8, 5);

    // To avoid invariant
    text.lastData = text.screen.dup;

    text.put(1, 1, "12345678");
    text.put(1, 2, "abcd");
    text.put(1, 3, "XYXYXYXYX");
    text.screen[0].flags = text.WRAPPED;
    writeln(text.screen);
    assert(text.screen[0] == "12345678"d);
    lines = text.join(text.screen);
    writeln(lines);
    assert(lines.length == 4);
    assert(lines[0].length == 12);

    text.resize(10,4);


    lines = text.wrap(lines);
    writeln(lines);

    assert(lines.length == 4);
    assert(lines[0].length == 10);
    assert(lines[3].length == 10);

    auto lines2 = text.join(lines);
    writeln(lines2);
    lines2 = text.wrap(lines2, 5);
    writeln(lines2);


    lines2 = text.join(lines2);
    writeln(lines2);
    lines2 = text.wrap(lines2, 9);
    writeln(lines2);


    lines2 = text.join(lines2);
    writeln(lines2);
    lines2 = text.wrap(lines2, 5);
    writeln(lines2);
    //lines = text.wrap(lines, 5);
    //writeln(lines);

}

unittest {

    struct Change {
        dstring text;
        int x;
        int y;
        uint attrs;
    }

    auto text = new TextBuffer!(dchar, uint)(80, 25);

    auto c = text.getChanges!Change();
    writeln(c);
    assert(c.length == 0);

    text.attrs = 1;
    text.put(10, 10, "Hello");
    text.put(15, 10, " people");
    //writeln(text.screen);
    //writeln(text.screen[9].screen);
    c = text.getChanges!Change();
    writeln(c);
    assert(c.length == 1 && c[0].text == "Hello people");

    text.put(15, 10, " peop");
    text.attrs = 2;
    text.put(10, 10, "Hel");
    c = text.getChanges!Change();
    writeln(c);
    assert(c.length == 1 && c[0].text == "Hel");

}


