module cutops;

import std.traits;

// Insert array `it` into array `t` at position `offs`. Target array
// does not change size, items pushed outside original array are lost.
T[] ins(T)(T[] t, int offs, T[] it)
{
    t[] = t[0 .. offs] ~ it ~ t[offs .. $ - it.length];
    return t;
}

// Delete `count` elements at offset `offs` in array `t`. Target array
// does not change size, items coming in from the right are set to T.init.
T[] del(T)(ref T[] t, int offs, int count, T fill = T.init)
{
    t[0 .. $ - count] = t[0 .. offs] ~ t[offs+count .. $];
    foreach(i ; t.length - count .. t.length) t[i] = fill;
    return t;
}

import std.range.primitives;

// Rotate the contents of `t` `count` steps to the left.
R rot(R, T = ElementType!R)(R t, int count)
{
    // TODO: Slow, creates temporary array and the copies it
    if(count > 0)
        t[] = t[count .. $] ~ t[0 .. count];
    else
        t[] = t[$ + count .. $] ~ t[0 .. $+count];
    return t;
}


// Shift contents of `t` `count` steps to the left. Lost items
// are filled with `fill`.
R shift(R, T = ElementType!R)(R t, int count, T fill)
{
    rot(t, count);

    // TODO: Use scalar assignment
    static if(hasIndirections!T)
    {
        if(count > 0)
            foreach(i ; t.length - count .. t.length) t[i] = fill.dup;
        else
            foreach(i ; 0 .. -count) t[i] = fill.dup;
    } else {
        if(count > 0)
            foreach(i ; t.length - count .. t.length) t[i] = fill;
        else
            foreach(i ; 0 .. -count) t[i] = fill;
    }
    return t;
}


unittest {
    import std.stdio;

    auto x = [1,2,3,4,5,6,7];

    del(x, 2, 3);
    writeln(x);
    assert(x == [ 1, 2, 6, 7, 0, 0, 0]);

    ins(x, 4, [4, 5, 4]);

    assert(x == [1,2,6,7,4,5,4]);

    rot(x, 2);
    assert(x == [6,7,4,5,4,1,2]);

    rot(x, -5);
    writeln(x);
    assert(x == [4,5,4,1,2,6,7]);

    rot(x[1 .. 3], 1);

    assert(x == [4,4,5,1,2,6,7]);

    shift(x, 4, 0);
    assert(x == [2,6,7,0,0,0,0]);

    ins(x[3 .. 6], 1, [99,88]);

    writeln(x);

    char[] txt = "abcdefg".dup;
    shift(txt[0 .. x.length], -5, '.');
    writeln(txt);


}


unittest {
    import std.conv;
    import std.stdio;

    char[][24] screen;

    for(int i=0; i<24; i++) {
        screen[i] = "aaaaaaaaaaaaaaaaaaaaaaaaa".dup;
        foreach(j ; 0 .. screen[i].length)
            screen[i][j] = cast(char)('a' + j);
        screen[i][0] = to!string(i/10)[0];
        screen[i][1] = to!string(i%10)[0];
    }

    shift(screen[0 .. $], 1, "        ".dup);
    screen[$-1][0 .. 5] = "GGHGG".dup;
    shift(screen[0 .. $], 1, "..........".dup);
    screen[$-1][0 .. 5] = "ZZDDF".dup;
    shift(screen[0 .. $], 1, [' ']);
    writeln(screen);

}

