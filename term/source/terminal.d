
import std.stdio;
import std.concurrency;
import std.exception;
import std.string : toz = toStringz;

import std.conv : to;
import core.time : Duration, dur;

import std.experimental.logger;
import diesel.gl.font;
import diesel.gl.core : scaleColor;
import diesel.gl.window;
import diesel.gl.program;
import diesel.gl.drawable;
version(trace) import diesel.minitrace;

import terminalsession;
import textscreen;
import launch : launch, PtyFile, getDead;
import console;

import diesel.keycodes;

@safe struct PackedChange
{
    this(wstring t, int x, int y, Attrs a)
    {
        text = t;
        data = [ cast(ushort)x, cast(ushort)y, a.fg, a.bg, a.flags ];
    }

    wstring text;
    immutable(uint)[] data;
}

class Terminal
{
    TermState state;
    Font font;
    Window win;
    int zoom = 1;

    int cols;
    int rows;
    // Pixel size
    int width;
    int height;

    //int cursorShape = 0;
    //int cursorX = -1;
    //int cursorY = -1;
    Console console;
    bool hasQuit = false;
    PtyFile tty;
    int id;
    Program prg;
    static Terminal activeTerminal;
    bool thisActive = false;

    static Terminal[] terminals;
    //static Terminal get(int n) { return terminals[n]; }
    //static ulong length() { return terminals.length; }

    bool marking = false;

    int scrollPos = 0;

    int[2] currentMouse;
    int[2] lastPos;
    int border = 0;
    int resizedWhen = 0;
    int frameCounter = 0;


    version(threaded)
    {
        struct SYNC {}
        struct RESIZE {}
        struct QUIT {}

        class BaseCall {
            void call(TerminalSession) immutable {
            }
        }

        class Call(string FN, ARGS...) : BaseCall {

            this(ARGS args) {
                this.args = args;
            }

            ARGS args;
            override void call(TerminalSession session) immutable {
                mixin(FN ~ `(args);`);
            }
        }

        auto makeCall(string FN, ARGS...)(ARGS args) {
            return cast(immutable)(new Call!(FN, ARGS)(args));
        }
        struct OSCData {
            int cmd;
            string text;
        }

        Tid sessionThread;
    } else {
        TerminalSession session;
    }

    void renderChange(const Change c)
    {
        version(trace) auto _st = ScopedTrace();
        uint fg = c.fg;
        uint bg = c.bg;

        if(c.flags & TextScreen.REVERSE) {
            auto x = fg;
            fg = bg;
            bg = x;
        }

        if(c.flags & TextScreen.BOLD) {
            if(c.flags & TextScreen.REVERSE)
                bg = scaleColor(bg, 1.5, 0x50);
            else
                fg = scaleColor(fg, 1.5, 0x50);
        }
        if(c.flags & TextScreen.CURSOR_POS)
            bg = 0xfff08000;
        console.write(c.text, [c.x - 1, c.y - 1], fg, bg);
    }

    void setFont(Font font)
    {
        this.font = font;
        console.font = font;
    }

    void sessionCall(string FN, ARGS...)(ARGS args) {
        version(threaded) {
            send(sessionThread, cast(immutable)(new Call!(FN, ARGS)(args)));
        } else {
            mixin(FN ~ `(args);`);
        }
    }

    void resize(int w = -1, int h = -1)
    {
        if(w != width || h != height)
            resizedWhen = frameCounter;
        if(w >= 0) width = w;
        if(h >= 0) height = h;

        int cw = width/zoom;
        int ch = height/zoom;

        int cols = (cw - border*2) / font.size.x;
        int rows = (ch - border*2) / font.size.y;

        if(cols < 1) cols = 1;
        if(rows < 1) rows = 1;
        if(cols != this.cols || rows != this.rows) {
            this.cols = cols;
            this.rows = rows;
            sessionCall!`session.resize`(cols, rows);
            console.resize(cols, rows);
        }
    }

    void reportMouse(int[2] pos)
    {
        pos[0] = pos[0] - (width - console.width * zoom) /2;
        pos[1] = pos[1] - (height - console.height * zoom) /2;
        pos[] = pos[] / (font.size[] * zoom);
        if(pos[0] <= 0) pos[0] = 0;
        if(pos[1] <= 0) pos[1] = 0;
        if(pos[0] >= cols) pos[0] = cols-1;
        if(pos[1] >= rows) pos[1] = rows-1;
        currentMouse = pos;
        pos[0] = pos[0] + 1;
        pos[1] = pos[1] + 1;
        if(state.mouseReport) {
            if(lastPos != pos && pos[0] > 0 && pos[1] > 0)
                sessionCall!`session.reportMouse`(pos);
            lastPos = pos;
        } else {
            if(marking) {
                console.extendSelection(currentMouse);
            }
        }
    }

    void render(int[2] xy)
    {
        console.screenTexture.bind();
        int[2] sz = console.screenTexture.size[] * zoom;
        prg.setUniform("active", activeTerminal == this ? 1.0 : 0.0);
        int[2] xyb;
        if(frameCounter > resizedWhen + 8)
            // Center the console inside the area
            xyb = xy[] + [ (width - console.width * zoom) / 2,
                           (height - console.height * zoom) / 2];
        else
            // Avoid centering during resize since it looks jerky
            xyb = xy[] + [border * zoom, border * zoom];
        renderRectangle(xyb, sz, prg);

        frameCounter++;
    }

    static void updateAll()
    {
        auto pid = getDead();
        if(pid != -1) {
            writeln("DIED ", pid);
            foreach(i, t ; terminals) {
                if(t.tty.pid == pid) {
                    t.quit();
                }
            }
        }

        version(threaded) {
            // Commands sent back to main thread
            while(receiveTimeout(dur!"usecs"(1),
                (int id, QUIT _) {
                    writeln("Quitting terminal ", id);
                    terminals[id].quit();
                },
                (int id, TermState state) {
                    terminals[id].state = state;
                    terminals[id].scrollPos = state.scrollPos;
                },
                (int id, immutable(Change)[] changes) {
                    terminals[id].console.begin();
                    foreach(c ; changes) terminals[id].renderChange(c);
                    terminals[id].console.end();
                },
                (int id, immutable(PackedChange)[] changes) {
                    terminals[id].console.begin();
                    foreach(pc ; changes) {
                        auto c = Change(pc.text, pc.data[0], pc.data[1],
                                pc.data[2], pc.data[3], pc.data[4]);
                        terminals[id].renderChange(c);
                    }
                    terminals[id].console.end();
                },
                (int id, OSCData osc) {
                    if(osc.cmd == 1)
                        writeln("Started ", osc.text);
                    else if(osc.cmd == 543)
                        writeln("COMMAND " ~ osc.text);
                }
                //,(Variant v) { writeln("ERROR ", v.type); }
            )) {}
        }

        foreach(ref t ; terminals)
            t.update();
    }

    void update()
    {
        if(activeTerminal == this && !thisActive) {
            thisActive = true;
            sessionCall!`session.focus`(true);
        } else if(activeTerminal != this && thisActive) {
            thisActive = false;
            sessionCall!`session.focus`(false);
        }

        version(threaded) {
            send(sessionThread, SYNC.init);
        } else {
            session.update();
            state = session.state;
            scrollPos = state.scrollPos;
            console.begin();
            auto changes = session.getChanges!Change();
            foreach(c ; changes) renderChange(c);
            console.end();
        }
    }

    void putKey(const uint key)
    {
        if(!state.mouseReport) {
            if(state.scrollTop > rows) {
                auto sp = scrollPos;
                if(key == DK_WHEEL_UP)
                    scrollPos += 10;
                else if(key == DK_WHEEL_DOWN)
                    scrollPos -= 10;
                if(scrollPos < 0) scrollPos = 0;
                if(scrollPos > state.scrollTop - rows)
                    scrollPos = state.scrollTop - rows;
                if(sp != scrollPos)
                    sessionCall!`session.setScroll`(scrollPos);
            }
            if(key == DK_LEFT_MOUSE_DOWN) {
                marking = true;
                console.clearSelection();
                console.startSelection(currentMouse);
            } else if(key == DK_LEFT_MOUSE_UP) {
                if(marking) {
                    marking = false;
                    auto selection = console.getSelection();
                    win.putClipboard(selection);
                    console.clearSelection();
                }
            }

            if((key & KEYCODE) == 0) {
                if(scrollPos != 0) {
                    scrollPos = 0;
                    sessionCall!`session.setScroll`(scrollPos);
                }
            }

        }
        sessionCall!`session.putKey`(key);

    }

    void setPalette(immutable uint[] colors) {
        sessionCall!`session.setPalette`(colors);
        console.bgColor = colors[0];
    }

    void setPalette(uint[] colors) {
        sessionCall!`session.setPalette`(colors.idup);
        console.bgColor = colors[0];
    }

    static void quitAll()
    {
        foreach(t ; terminals)
            t.quit();
    }


version(threaded) {
    void quit()
    {
        if(!hasQuit) {
            send(sessionThread, QUIT.init);
            receiveTimeout(dur!"seconds"(1),
                (LinkTerminated l) { writeln("Child terminated"); }
            );
        }
        hasQuit = true;
    }

    static void sessionFn(Tid parentTid, int id, int cols, int rows, PtyFile tty)
    {
        auto session = new TerminalSession(cols, rows, tty);
        bool quit = false;
        bool deadSent = false;
        int count = 0;
        OSCData[] oscData;
        session.onOSC((string s) @safe {
            import std.algorithm.iteration : splitter;
            import std.array;
            writeln("OSC: ", s);
            auto args = array(splitter(s, ";"));
            if(args.length > 1) {
                oscData ~= OSCData(to!int(args[0]), args[1]);
            }
        });
        try {
            bool synced = false;
            while(!quit) {
                if(synced) {
                    int rc = session.update();
                    if(rc == 1)
                        send(parentTid, id, session.state);
                    foreach(o ; oscData) {
                        send(parentTid, id, o);
                    }
                    oscData.length = 0;
                }

                // Commands received from main thread
                receiveTimeout(dur!"msecs"(session.focus ? 2 : 10),
                    (immutable (BaseCall) c) {
                        c.call(session);
                    },
                    (SYNC _) {
                            if(!synced)
                                writeln("SYNCED");
                            synced = true;
                            auto changes = session.getChanges!Change();
                            if(changes.length > 0)
                                send(parentTid, id, changes);
                    },
                    (QUIT _) {
                        writeln("QUIT FROM PARENT");
                        quit = true;
                        if(!deadSent) {
                            writeln("KILL PID");
                            session.kill();
                        }
                    },
                );
            }
        } catch (Throwable e) {
                writeln("## Exception in session thread:");
                writeln(e);
        }
    }

} else {
    void quit()
    {
        session.kill();
    }
}


    this(Font font, int w, int h, Window win, int zoom, int border, string cmd, string[] args = [])
    {
        this.win = win;
        this.font = font;
        this.zoom = zoom;
        this.border = border;

        cols = (w / zoom - border*2) / font.size.x;
        rows = (h / zoom - border*2) / font.size.y;
        width = w;
        height = h;

        console = new Console(font, cols, rows);
        terminals ~= this;
        id = cast(int)terminals.length - 1;
        synchronized {
            tty = launch([cmd] ~ args, cols, rows);
        }
    }

    static void startAll()
    {
        foreach(ref t ; terminals)
            t.start();
    }

    void start()
    {
        writeln("START");
        version(threaded) {
            sessionThread = spawnLinked(&sessionFn, thisTid, id, cols, rows, tty);
        } else {
            session = new TerminalSession(cols, rows, tty);
        }
        resize();
    }

}
