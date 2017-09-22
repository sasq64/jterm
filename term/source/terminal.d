
import std.stdio;
import std.concurrency;
import std.exception;
import std.string : toz = toStringz;

import core.time : Duration, dur;

import std.experimental.logger;
import diesel.gl.font;
import diesel.gl.core : scaleColor;
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
    int zoom = 1;

    int cols;
    int rows;
    // Pixel size
    int width;
    int height;

    int cursorShape = 0;
    int cursorX = -1;
    int cursorY = -1;
    Console console;
    bool hasQuit = false;
    PtyFile tty;
    int id;
    Program prg;
    static Terminal activeTerminal;
    bool thisActive = false;

    static Terminal[] terminals;
    static Terminal get(int n) { return terminals[n]; }
    static ulong length() { return terminals.length; }


    int scrollPos = 0;

    version(threaded)
    {
        struct SYNC {}
        struct RESIZE {}
        struct QUIT {}

        struct Focus { bool yes; }

        struct ReportMouse {
            int[2] pos;
        }

        struct Resize {
            int c;
            int r;
        }

        struct SetPalette {
            immutable (uint)[] palette;
        }

        struct SetScroll {
            int y;
        }

        struct KeyCode {
            uint key;
        }

        struct OSCData {
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
        console.write(c.text, [c.x,c.y], fg, bg);
    }

    void setFont(Font font)
    {
        this.font = font;
        console.font = font;
    }

    int border = 0;

    void resize(int w = -1, int h = -1)
    {
        if(w >= 0) width = w;
        if(h >= 0) height = h;

        int cw = width;//  / zoo;
        int ch = height;// zoom;

        cw /= zoom;
        ch /= zoom;

        // We need this much extra space
        auto b = border*2/zoom;

        // Actual extra space
        int bx = (cw % font.size.x);
        int by = (ch % font.size.y);

        // Shrink allocated space for console as needed
        if(bx < b) cw -= (b - bx);
        if(by < b) ch -= (b - by);


        int cols = cw / font.size.x;
        int rows = ch / font.size.y;

        if(cols < 1) cols = 1;
        if(rows < 1) rows = 1;
        if(cols != this.cols || rows != this.rows) {
            this.cols = cols;
            this.rows = rows;
            version(threaded) {
                send(sessionThread, Resize(cols, rows));
            } else {
                session.resize(cols, rows);
            }
        }
        console.resize(cw, ch);
    }

    void reportMouse(int[2] pos)
    {
        if(state.mouseReport) {
            pos[0] = pos[0] / (font.size.x * zoom) + 1;
            pos[1] = pos[1] / (font.size.y * zoom) + 1;
            version(threaded) send(sessionThread, ReportMouse(pos));
        } else {
        }
    }

    void render(int[2] xy)
    {
        console.screenTexture.bind();
        int[2] sz = console.screenTexture.size[] * zoom;
        prg.setUniform("active", activeTerminal == this ? 1.0 : 0.0);
        int[2] xyb = xy[] + [ (width - console.width * zoom) / 2, (height - console.height * zoom) / 2];
        renderRectangle(xyb, sz, prg);
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
                    writeln("Got new state ", state.mouseReport);
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
        version(threaded) {
            if(activeTerminal == this && !thisActive) {
                thisActive = true;
                send(sessionThread, Focus(true));
            } else if(activeTerminal != this && thisActive) {
                thisActive = false;
                send(sessionThread, Focus(false));
            }
            send(sessionThread, SYNC.init);
        } else {
            session.update();
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
                    send(sessionThread, SetScroll(scrollPos));
            }
        }
        version(threaded) send(sessionThread, KeyCode(key));
        else session.putKey(key);

    }

    /* void setPalette(immutable uint[] colors) { */
    /*     send(sessionThread, colors); */
    /* } */

    void setPalette(uint[] colors) {
        send(sessionThread, SetPalette(colors.idup));
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
        string[] oscData;
        session.onOSC((string s) @safe {
            import std.algorithm.iteration : splitter;
            import std.array;
            writeln("OSC: ", s);
            auto args = array(splitter(s, ";"));
            if(args.length > 1) {
                if(args[0] == "543") {
                    oscData ~= args[1];
                }
            }
        });
        try {
            bool focus = false;
            bool synced = false;
            while(!quit) {
                if(synced) {
                    int rc = session.update();
                    if(rc == 1)
                        send(parentTid, id, session.state);
                    foreach(o ; oscData) {
                        send(parentTid, id, OSCData(o));
                    }
                    oscData.length = 0;
                }

                // Commands received from main thread
                receiveTimeout(dur!"msecs"(focus ? 2 : 10),
                    (Resize a) {
                        session.resize(a.c, a.r);
                    },
                    (Focus f) { focus = f.yes; },
                    (ReportMouse a) {
                        session.reportMouse(a.pos);
                    },
                    (SetPalette a) {
                        writeln("PAL");
                        session.setPalette(a.palette);
                    },
                    (SYNC _) {
                            if(!synced)
                            writeln("SYNCED");
                            synced = true;
                            auto changes = session.getChanges!PackedChange();
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
                    (SetScroll s) {
                        session.setScroll(s.y);
                    },
                    (KeyCode a) {
                        session.putKey(a.key);
                    }
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


    this(Font font, int w, int h, int zoom, string cmd, string[] args = [])
    {
        this.font = font;
        this.zoom = zoom;
        cols = w / font.size.x / zoom;
        rows = h / font.size.y / zoom;
        width = w;
        height = h;

        console = new Console(font, w / zoom, h / zoom);
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
