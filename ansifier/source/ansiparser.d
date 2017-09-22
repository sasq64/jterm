
version(trace) import diesel.minitrace;

import std.stdio;

@safe class AnsiParser {

    // State machine states
    enum { TEXT, ESC, ESC2, CSI, CSI2, DCS, DCS2, OSC, OSC2, OSC_END, CC };

    private int state = TEXT;

    struct Code {
        int type;
        ubyte[] tail;
        string text; // type = TEXT or OSC
        int[] params; // type = CSI or DCS

        bool isText() { return type == TEXT; }

        this(int t, int[] params, ubyte[] tail = null)
        {
            type = t;
            this.params = params;
            this.tail = tail;
        }

        this(int t, string text, ubyte[] tail = null)
        {
            type = t;
            this.text = text;
            this.tail = tail;
        }

        this(int t, ubyte[] tail = null) {
            this.type = t;
            this.tail = tail;
        }

        @trusted string toString() {
            import std.format;
            import std.conv;
            if(type == TEXT)
                return '"' ~ text ~ '"';
            else if(type == ESC)
                return "ESC " ~ cast(string)(tail);
            else if(type == CC)
                return format("%02x", tail[0]);
            else if(type == CSI)
                return "CSI " ~ cast(string)(tail) ~ " " ~ to!string(params);
            else if(type == DCS)
                return "DCS " ~ '"' ~ text ~ '"';
            else if(type == OSC)
                return "OSC " ~ '"' ~ text ~ '"';
            else return format("%02x %s", type, tail);
        }

    };

    Code[] codes;

    private int param = 0;
    private bool haveParam = false;
    private int[] params;
    private ubyte[] buf;
    private string text;

    public bool empty() { return codes.length == 0; }
    public void popFront() { codes = codes[1 .. $]; }
    public Code front() { return codes[0]; }

    void flush() {
        if(state == TEXT && text.length > 0) {
            codes ~= Code(TEXT, text);
            text = "";
        }
    }

    bool inProgress() {
        return text.length > 0;
    }

    bool checkStringEnd = false;

    /// Put bytes from text/ansi stream into parser
    public void put(const ubyte[] data)
    {
        version(trace) auto _st = ScopedTrace();

        foreach (i, d; data) {
            int prevState = state;
            if(checkStringEnd) {
                if(d != '\\') {
                    state = ESC;
                    buf = [];
                    text = "";
                    params = [];
                    haveParam = false;
                    checkStringEnd = false;
                }
            }
            if(d == 0x1b) state = ESC;
            // TODO: Handle these if we are NOT in an UTF-8 sequence
            /* else if(d == 0x90) state = DCS; */
            /* else if(d == 0x9d) state = OSC; */
            /* else if(d == 0x9b) state = CSI; */
            if(prevState != state) {
                if(prevState == TEXT && text.length > 0) {
                    codes ~= Code(TEXT, text);
                    text = "";
                }
                if(state == ESC) {
                    if(prevState == OSC || prevState == DCS) {
                        state = prevState;
                        checkStringEnd = true;
                    } else {
                        buf = [];
                        text = "";
                        params = [];
                        haveParam = false;
                    }
                }
                continue;
            }
            if(state == TEXT) {
                if(d < 0x20) {
                    if(text.length > 0) {
                        codes ~= Code(TEXT, text);
                        text = "";
                    }
                    codes ~= Code(CC, [d]);
                }
                else {
                    text ~= d;
                }
            } else if(state == ESC) {
                if(d == 0x50) state = DCS;
                else if (d == 0x5d) state = OSC;
                else if (d == 0x5b) state = CSI;
                else if(d >=20 && d <= 0x2f) {
                    buf ~= d;
                    state = ESC2;
                } else if(d >= 0x30 && d < 0x7f) {
                    codes ~= Code(ESC, [d]);
                    state = TEXT;
                }
            } else if(state == ESC2) {
                if(d >=20 && d <= 0x2f) {
                    buf ~= d;
                } else {
                    buf ~= d;
                    codes ~= Code(ESC, buf);
                    buf = [];
                    state = TEXT;
                }
            } else if(state == CSI) {
                if(d >= 0x3c && d <= 0x3f) {
                    buf ~= d;
                } else
                if(d >= 0x20 && d <= 0x2f) {
                    if(haveParam) params ~= param;
                    haveParam = false;
                    buf ~= d;
                    state = CSI2;
                } else if(d >= '0' && d <= '9') {
                    if(!haveParam) param = 0;
                    haveParam = true;
                    param = param*10 + (d - '0');
                } else if(d == ';') {
                    if(haveParam)
                        params ~= param;
                    haveParam = false;
                } else if(d >= 0x40) {
                    buf ~= d;
                    if(haveParam) params ~= param;
                    haveParam = false;
                    codes ~= Code(CSI, params, buf);
                    buf = [];
                    params = [];
                    state = TEXT;
                }
            } else if(state == CSI2) {
                if(d >=20 && d <= 0x2f) {
                    buf ~= d;
                } else {
                    codes ~= Code(CSI, params, buf);
                    params = [];
                    haveParam = false;
                    buf = [];
                    state = TEXT;
                }
            } else if(state == OSC) {
                if(d == 0x9c || d == 0x07 || checkStringEnd) {
                    codes ~= Code(OSC, text);
                    text = "";
                    state = TEXT;
                } else if(d >= 0x20) {
                    text ~= d;
                }
            } else if(state == DCS) {
                if(d == 0x9c || d == 0x07 || checkStringEnd) {
                    codes ~= Code(DCS, text);
                    text = "";
                    state = TEXT;
                } else if(d >= 0x20) {
                    text ~= d;
                }
            }
            checkStringEnd = false;
        }
    }
}


unittest {
    import std.stdio;

    auto parser = new AnsiParser();
    parser.put(cast(ubyte[])("\x1b[1;2;3;99;1111;4;1232;555x\x1b[110m\x1b[poo"));
    parser.put(cast(ubyte[])("HEY " ~ x"1B" ~ "[3;"));
    parser.put(cast(ubyte[])("m" ~ "YOU\n" ~ x"1b"));
    parser.put(cast(ubyte[])("[2;2hMAN\x9dLong OSC string!\x9csome\x1bAsmiple\x1bXesc codes"));
    parser.put(cast(ubyte[])("\x1b[?19lXXX\x1b)0pooidi\x1b(9asdsa"));

    foreach(c ; parser.codes) {
        writeln(c);
    }
}


///
unittest {
    import std.stdio;
    import std.array;
    auto parser = new OldAnsiParser();
    parser.put(cast(ubyte[])("HEY " ~ x"1B" ~ "[3"));
    parser.put(cast(ubyte[])("m" ~ "YOU" ~ x"1b"));
    parser.put(cast(ubyte[])("[2;2hMAN"));

    auto seq = array(parser);
    foreach(i, s ; seq)
        writeln(i, " ", s);

    assert(seq.length == 4);
    assert(seq[0].text == "HEY ");
    assert(!seq[1].isText);
    parser.flush();
    seq = array(parser);
    assert(seq.length == 1);
}

