

T toArray(T, S)(S s) if(is(T == char**))
{
    import core.stdc.stdlib;
    char** argv = cast(char**) malloc((char*).sizeof * (s.length + 1));
    foreach(i, arg; s) {
        argv[i] = cast(char*) malloc(arg.length + 1);
        argv[i][0 .. arg.length] = arg[];
        argv[i][arg.length] = 0;
    }

    argv[s.length] = null;

    return argv;
}

static int[64] deadChildren;
static uint deadCount = 0;
static uint deadFound = 0;

int getDead() {
    import core.atomic : atomicFence;
    atomicFence(); // Overkill ?
    if(deadCount > deadFound) {
        deadFound++;
        return deadChildren[(deadFound-1) % deadChildren.length];
    }
    return -1;
}

import core.sys.posix.termios;
import core.sys.posix.sys.ioctl;
import core.sys.posix.signal;
import core.sys.posix.unistd;

import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.stdlib;
import std.stdio;

version(Posix) {


extern(C) pid_t forkpty(int *amaster, char *name, termios *termp, winsize *winp);

struct winsize
{
  ushort ws_row;    /* rows, in characters */
  ushort ws_col;    /* columns, in characters */
  ushort ws_xpixel; /* horizontal size, pixels */
  ushort ws_ypixel; /* vertical size, pixels */
};

const int PENDIN =  0x20000000;
const int ECHOCTL = 0x00000040;
const int ECHOKE =  0x00000001;
const int OXTABS =  0x00000004;
const int IUTF8 =   0x00004000;

const int SIGWINCH = 28;


@trusted struct PtyFile
{
    this(int fd, int pid)
    {
        this.fd = fd;
        this.pid = pid;
    }

    void kill()
    {
        writeln("KILLING ", pid);
        //.kill(pid, SIGTERM);
        .kill(pid, SIGKILL);
    }

    PtyFile blocking(bool on)
    {
        import core.sys.posix.fcntl;
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, (!on) ? flags | O_NONBLOCK : flags & ~O_NONBLOCK);
        return this;
    }

    PtyFile nonBlocking()
    {
        return blocking(false);
    }

    import core.stdc.errno;

    void write(T)(T[] data) {
        long rc = -1;
        //while(rc <= 0)
        rc = core.sys.posix.unistd.write(fd, data.ptr, data.length);
        // TODO: Block instead
        assert(rc == data.length);
    }

    ssize_t read(T)(T[] data) {
        ssize_t rc = core.sys.posix.unistd.read(fd, &data[0], data.length);
        return rc;
    }

    int fd = 0;
    int pid = 0;
}

@trusted void signal_winsize(PtyFile f, ushort cols, ushort rows)
{
    winsize ws = winsize(rows, cols, 512, 640);
    ioctl(f.fd, TIOCSWINSZ, &ws );
    //kill(f.pid, SIGWINCH );
}

PtyFile launch(string[] args, int cols, int rows)
{
    winsize ws = winsize(cast(ushort)rows, cast(ushort)cols, 512, 640);
    termios tp;
    int master;

    extern(C) nothrow static @nogc
    void childdead(int id) {
        auto pid = wait(null);
        try {
            deadChildren[deadCount % deadChildren.length] = pid;
            deadCount++;
        } catch(Throwable t) {}
    }

    signal(SIGCHLD, &childdead);

    tcgetattr(0, &tp);

    /* tp.c_lflag |= (ECHO | ECHOK | ECHOE); */
    /* tp.c_lflag |= (ICANON | ISIG | IEXTEN | ECHO); */
    /* tp.c_lflag |= (ECHOKE | ECHOCTL | PENDIN); */

    tp.c_iflag |= IUTF8;

    // Turn off XON/XOFF, allowing use of CTRL-S/CTRL-Q
    tp.c_iflag &= ~IXON;

    // Don't translate tabs to spaces
    /* tp.c_oflag &= ~OXTABS; */

    // 8 bits per byte
    tp.c_cflag |= CS8;
    // No parity bits
    tp.c_cflag &= ~PARENB;

    // How long to wait when reading
    /* tp.c_cc[VTIME] = 5; */
    /* tp.c_cc[VMIN] = 1; */

    int rc = forkpty(&master, null, &tp, &ws);

    if(rc == 0) {
        // In child process
            import core.stdc.stdlib;
            setenv("TERM", "xterm-256color", 1);
            //setenv("LANG", "en_US.UTF-8", 1);
            auto argv = toArray!(char**)(args);
            core.sys.posix.unistd.execv(argv[0], argv);
            assert(false);
    } else if(rc < 0)
        writeln("LAUNCH FAILED");
    else writeln("Launched as ", master, "/", rc);

    auto f = PtyFile(master, rc);
    f.nonBlocking();
    return f;

}

} // version(linux)

version(Windows) {

alias ssize_t = int;

@trusted struct PtyFile
{
    this(int fd, int pid)
    {
        this.fd = fd;
        this.pid = pid;
    }

    void kill()
    {
    }

    PtyFile blocking(bool on)
    {
        return this;
    }

    PtyFile nonBlocking()
    {
        return blocking(false);
    }

    void write(T)(T[] data) {
    }

    ssize_t read(T)(T[] data) {
        ssize_t rc = 0;
        return rc;
    }

    int fd = 0;
    int pid = 0;
}

@trusted void signal_winsize(PtyFile f, ushort cols, ushort rows)
{
    // TODO send WINSIZE signals
}

PtyFile launch(string[] args, int cols, int rows)
{
    //TODO Launch executable and read/write stdin/out (forkpty on posix)
    return PtyFile(0, 0);
}

}
