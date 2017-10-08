
import std.stdio;
import std.range.primitives;

struct WrappedSlice(T) {
    sizediff_t offset = 0;
    size_t length;
    sizediff_t index = 0;
    bool wraps;
    T[] backing;

    invariant {
       // assert(backing.length == 0 || backing.length == 100);
    }


    bool opEquals(WrappedSlice!T other) {
        return (other.offset == offset && other.length == length &&
                &other.backing[0] == &backing[0] && backing.length == other.backing.length);
    }

    // Create a view of length 'length' from offset 'offs' into the given slice
    this(T[] b, sizediff_t length = -1, sizediff_t off = 0) {
        set(b, length, off);
    }

    void set(T[] b, sizediff_t length = -1, sizediff_t offs = 0) {
        if(length < 0) length = b.length;
        this.backing = b;
        this.length = length;
        this.offset = offs;
        wraps = offset + length > backing.length;
    }

    ref T at(size_t i) {
        assert(i >= 0 && i < length);
        return backing[(offset+i) % backing.length];
    }

    T[] flatten() {
        if(!wraps)
            return backing[offset .. offset + length];
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
        wraps = (offset % backing.length) + length > backing.length;
    }

    // this[] = other[]
    void opIndexAssign(WrappedSlice!T other) {
        assert(length == other.length);
        if(!wraps && !other.wraps) {
            backing[] = other.backing[];
            offset = other.offset;
            length = other.length;
        } else {
        for(int i=0; i<this.length; i++)
            at(i) = other[i];
        }
    }

    void opAssign(WrappedSlice!T other) {
        set(other.backing, other.length, other.offset);
    }

    void opIndexAssign(T t, ulong i) {
        at(i) = t;
    }

    ref T opIndex(size_t i) {
        return at(i);
    }

    WrappedSlice!T opSlice(size_t a, size_t b) {
        assert(a >= 0 && b >= a && b <= length);
        return WrappedSlice(backing, b - a, a + offset);
    }

    size_t opDollar() { return length; }

    View opSlice() {
        return View(this);
    }

    string toString() {
        import std.conv : to;
        return to!string(flatten);
    }

    //alias flatten this;

    // Range interface
    struct View {
        private WrappedSlice ws;
        private size_t index = 0;

        bool empty() const @property { return index == ws.length; }
        void popFront() { index++; }
        ref T front() @property { return ws.at(index); }
    }

}

auto wrapped_slice(T)(T[] b, size_t l = -1, size_t o = 0) {
    return WrappedSlice!T(b, l, o);
}

auto sort(T)(T[] t) {
    import std.algorithm.sorting;
    return std.algorithm.sorting.sort(t);
}

unittest {
    import std.range;
    import std.array;

    auto backing = array(iota(0,1000));
    auto bs = wrapped_slice(backing, 10);

    bs[] = bs[5 .. 10] ~ bs[0 .. 5];
    writeln(bs);
    assert(bs[0] == 5);
    assert(bs[5] == 0);
    assert(backing[0] == 5);

    assert(backing[4] == 9);

    bs += 995;

    bs[1] = bs[$-1];
    writeln(bs);
    assert(backing[996] == 9);

    writeln(bs);
    bs[] = bs[7 .. 10] ~ bs[0..7];
    writeln(bs);
    assert(backing[0] == 997);

    bs[4 .. 7] = [100,101,102];
    assert(backing[0] == 101);

    auto bs2 = sort(bs);

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
