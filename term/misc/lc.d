void main(string[] args)
{
    import std.string : join;
    import std.stdio : write;
    write("\x1b]543;" ~ join(args[1..$], " ") ~ "\x07");
}
