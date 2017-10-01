
import std.stdio;
import std.range.primitives;

/// Takes a range of arrays and returns an array of arrays
/// Splits long arrays and tags them as wrapped
D wrap(alias FN, D, T = ElementType!D, E = ElementType!T)(D data, int w, E fill = E.init)
{
    T[] newData;
    foreach(i ; 0 .. data.length) {
        auto d = data[i];
        int start = 0;
        while(d.length - start > w) {
            newData ~= d[start .. start + w];
            FN(newData[$-1], true);
            start += w;
        }
        auto nd = d[start .. $];
        pragma(msg, typeof(nd));
        auto l = w - nd.length;
        nd.length = w;
        foreach(ref ndi ; nd[$-l .. $])
            ndi = fill;
        FN(nd, false);
        newData ~= nd;
    }
    return newData;
}

D unwrap(alias FN, D)(D data)
{
    alias T = ElementType!D;
    T[] newData;
    int i = 0;
    while(i < data.length) {
        auto d = data[i++];
        auto wrapped = FN(d);
        while(i < data.length-1 && wrapped) {
            wrapped = FN(data[i]);
            d = d ~ data[i++];
        }
        newData ~= d;
    }
    return newData;
}

unittest {

    import std.range;
    import std.array;
    import std.algorithm.mutation;

    void w0(int[] x, bool w) {
        if(w)
            x[0] |= 0x8000;
        else
            x[0] &= 0x7fff;
    }

    bool w1(int[] x) {
        return (x[0] & 0x8000) != 0;
    }

    auto test = [array(iota(0,20)), array(iota(20,30)), array(iota(30,45))];
    writeln(test);

    auto rc = wrap!(w0)(test, 15);
    foreach(ref r ; rc) {
        if(r.length < 15)
            r = r ~ array(repeat(99, 15 - rc.length));
    }
    writeln(rc);

    auto rc2 = unwrap!((int[] a) => a[0] & 0x8000)(rc);

    foreach(ref r ; rc2) {
        //w0(r, false);
        r = r.stripRight(int.init);
    }


    writeln(rc2);
    assert(rc2 == test);

}
