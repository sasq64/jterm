import std.stdio;
import std.string;

import std.typecons : scoped;
import std.getopt;

import core.stdc.stdlib : getenv;
import std.conv : to;
import diesel.gl;

import termapp;

version(trace) import diesel.minitrace;

string which(string cmd, string path = null)
{
    import std.c.stdlib : getenv;
    import std.conv : to;
    import std.path : buildPath;
    import std.file : exists;
    import std.algorithm.iteration : splitter;

    if(cmd.indexOf('/') >= 0)
        return cmd;

    if(!path)
        path = to!string(getenv("PATH"));

    foreach(d ; splitter(path, ":"))
    {
        auto p = buildPath(d, cmd);
        if(exists(p))
            return p;
    }
    return null;
}

unittest {
    import std.string : indexOf;
    assert(which("ls").indexOf("bin") > 0);
    assert(which("j@jklDd##!") == null);
}

void main(string[] args)
{
    string cmd = "";
    bool bench = false;
    bool fullscreen = false;
    int zoom = 1;
    bool split = false;
    string fontSpec = "";

    auto opts = getopt(args,
            "cmd", &cmd,
            "fullscreen|f", &fullscreen,
            "benchmark|b", &bench,
            "zoom|x", &zoom,
            "font", &fontSpec
    );

    if(opts.helpWanted) {
        writeln("JTerm © Jonas Minnberg 2017");
        return;
    }

    string[] xargs = [];
    foreach(a ; args[1..$]) {
        if(a[0] != '-') {
            if(cmd == "")
                cmd = a;
            else
                xargs ~= a;
        }
    }

    if(cmd == "") {
        const char* shell = getenv("SHELL");
        if(shell)
            cmd = to!string(shell);
    }

    version(trace) {
        mtr_init("trace.json");
        MTR_META_PROCESS_NAME("term");
        MTR_META_THREAD_NAME("main thread");
    }

    cmd = which(cmd);

    if(cmd == "") {
        return;
    }

    Window win;
    try {
        win = new Window(fullscreen ? 0 : 1280, fullscreen ? 0 : 1024, fullscreen);
    } catch(derelict.util.exception.SharedLibLoadException e) {
        writeln("**Error: You need libSDL2 to run jterm");
        version(OSX) writeln("Perhaps you should do `brew install sdl2` ?");
		version(linux) writeln("Perhaps you should do `sudo apt install libsdl2-2.0-0` ?");
        return;
    }

    glClearColor(0.0,1.0,0.0,1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    win.swap();
    glClear(GL_COLOR_BUFFER_BIT);
    win.swap();

    auto app = new TermApp(win, cmd, xargs);

    Globals.set("drawColor", 0xFF_F0_80_00);

    if(fontSpec != "") {
        app.font = new Font(fontSpec, cast(float)win.getScale());
    }

    app.run();

	win.exit();

    version(trace) {
        mtr_flush();
        mtr_shutdown();
    }

}

