import std.stdio;
int main()
{

    for(dchar d = 0xe080 ; d < 0xf000; d++)
        std.stdio.write(d);

    return 0;
}
