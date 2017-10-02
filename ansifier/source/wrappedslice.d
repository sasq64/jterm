
import std.stdio;

struct WrappedSlice(T) {
    sizediff_t offset = 0;
    size_t length;
    sizediff_t index = 0;
    private T[] backing;

    // Create a view of length 'length' from offset 'offs' into the given slice
    this(T[] b, sizediff_t length = -1, sizediff_t off = 0) {
        set(b, length, off);
    }

    void set(T[] b, sizediff_t length = -1, sizediff_t offs = 0) {
        if(length < 0) length = b.length;
        this.backing = b;
        this.length = length;
        this.offset = offs;
    }

    ref T at(size_t i) {
        return backing[(offset+i) % backing.length];
    }


    bool empty() const @property
    {
        return index == length;
    }

    void popFront()
    {
        index++;
    }

    T front() @property
    {
        writeln(&backing[0]);
        return at(index);
    }

    T[] flatten() {
        T[] t = new T[length];
        for(int i=0; i<length; i++)
            t[i] = at(i);
        return t;
    }

    WrappedSlice!T opBinary(string S : "~")(WrappedSlice!T other) {
        return WrappedSlice!T(flatten ~ other.flatten);
    }

    // Move the offset
    void opOpAssign(string T : "+")(size_t o) {
        offset += o;
    }

    // this[] = other[]
    void opIndexAssign(WrappedSlice!T other) {
        for(int i=0; i<this.length; i++)
            at(i) = other[i];
    }

    void opIndexAssign(T t, ulong i) {
        at(i) = t;
    }

    ref T opIndex(int i) {
        return at(i);
    }

    WrappedSlice!T opSlice(size_t a, size_t b) {
        return WrappedSlice(backing, b - a, a + offset);
    }

    size_t opDollar() { return length; }

    WrappedSlice!T opSlice() {
        return WrappedSlice(backing, length, offset);
    }

    string toString() {
        import std.conv : to;
        return to!string(flatten);
    }

}

auto wrapped_slice(T)(T[] b, size_t l = -1, size_t o = 0) {
    return WrappedSlice!T(b, l, o);
}

unittest {
    import std.range;
    import std.array;

    auto backing = array(iota(0,1000));
    auto bs = wrapped_slice(backing, 10);

    bs[] = bs[5 .. 10] ~ bs[0 .. 5];
    assert(bs[0] == 5);
    assert(bs[5] == 0);
    assert(backing[0] == 5);

    bs += 995;

    writeln(bs);
    bs[] = bs[7 .. 10] ~ bs[0..7];
    writeln(bs);
    assert(backing[0] == 997);

}

unittest {
    import std.range;
    import std.array;

    auto backing = array(iota(0,1000));
    assert(backing.length == 1000);
    auto bs = wrapped_slice(backing, 10);
    assert(bs.length == 10);
    assert(bs[3] == 3);
    bs += 995;
    assert(bs[0] == 995);
    assert(bs[9] == 4);


    auto bs2 = wrapped_slice(backing, 2000, 999);
    assert(bs2[0] == 999);
    assert(bs2[1] == 0);
    assert(bs2[1002] == 1);

    auto bs3 = wrapped_slice(backing, 10, -5);
    writeln(bs[0]);
    assert(bs[0] == 995);



}
