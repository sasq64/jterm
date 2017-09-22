import core.sys.posix.termios;
import std.stdio;

extern(C) void cfmakeraw(termios *termios_p);

void setRaw(File f)
{
    termios  ostate;
    termios  nstate;

    tcgetattr(f.fileno, &nstate);
    cfmakeraw(&nstate);
    tcsetattr(f.fileno, TCSADRAIN, &nstate);

    //

//    tcsetattr(f.fileno, TCSADRAIN, &ostate);
    // return to original mode
}
void setNonBlocking(File f)
{
    import core.sys.posix.fcntl;
    int fd = f.fileno;
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

import std.ascii;
import std.array;

import std.algorithm : map;

void main(string[] args)
{
    import std.conv;
    char[128] c;
    //gets(c.ptr);
    //writeln(to!string(c));


    setRaw(stdin);
    setNonBlocking(stdin);
    //setvbuf(pipes.stdin.getFP(), null, _IONBF, 0U);

    ubyte[10] buf;

    string value = "";
    while(true) {
        auto rc = fread(buf.ptr, 1, buf.length, stdin.getFP());
        if(rc > 0) {
            ubyte[] r = buf[0 .. rc];
            if(isDigit(r[0]))
                value = value ~ r[0];
            else if(r[0] == 'z')
                write("\x1b>");
            else if(r[0] == 'Z')
                write("\x1b=");
            else if(r[0] == 'x' || r[0] == 'X')
                break;
            else if(r[0] == 'h' || r[0] == 'l') {
                //writeln(value, " ", cast(char)r[0]);
                writefln("\x1b[?%s%c%s %s\r", value, cast(char)r[0], value, r[0] == 'h' ? "SET" : "CLEARED");
                value = "";
            } else {
                auto s = cast(string)array(buf[0 .. rc].map!(c => c == 0x1b ? '!' : (c >= 0x20 && c <= 0x7f ? c : '_')));
                write("'", s, "' ", r, x"0a 0d");
            }
        }
    }

}

