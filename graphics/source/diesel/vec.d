
module diesel.vec;
import std.traits;

struct vec(int N, T = float) {

    alias length = N;

    union {
        T[N] data;
        struct {
            T x;
            static if(N > 1) { T y; }
            static if(N > 2) { T z; }
            static if(N > 3) { T w; }
        }
        struct {
            T r;
            static if(N > 1) { T g; }
            static if(N > 2) { T b; }
            static if(N > 3) { T a; }
        }
    }
    alias data this;

    static if(N > 2) {
        uint col() const {
            uint rc = (cast(int)(data[0] * 255) << 16) |
                (cast(int)(data[1] * 255) << 8) |
                (cast(int)(data[2] * 255));
            static if(N > 3)
                rc |= (cast(int)(data[3] * 255) << 24);
            return rc;
        }
    }

    static if(N > 2) {
        this(uint col) {
            data[0] = cast(T)(((col>>16)&0xff) / 255.0f);
            data[1] = cast(T)(((col>>8)&0xff) / 255.0f);
            data[2] = cast(T)((col&0xff) / 256.0f);
            static if(N > 3)
                data[3] = cast(T)(((col>>24)&0xff) / 255.0f);
        }
    }

    this(T[N] d) {
        data[] = d[];
    }

    this(X)(X[N] d) if(!is(X == T)) {
        foreach(i, ref v ; data)
            v = cast(T)d[i];
    }

    this(ARGS ...)(ARGS args) {
        foreach(i,a ; args)
            data[i] = cast(T)a;
    }

    static if(N == 4) {
        import std.typecons;
        Tuple!(T, T, T, T) tup() { return tuple(data[0], data[1], data[2], data[3]); }
    }

    T dot(const vec other) const {
        T rc = 0;
        foreach(i, v ; data)
            rc += (v * other[i]);
        return rc;
    }

    vec opBinary(string op)(const T[N] rhs) const {
        vec result;
        result.data[] = mixin(`data[]` ~ op ~ `rhs[]`);
        return result;
    }

    vec opBinary(string op)(const T rhs) const {
        vec result;
        result.data[] = mixin(`data[]` ~ op ~ `rhs`);
        return result;
    }

    vec opBinary(string op)(const vec!(N,T) rhs) const {
        vec result;
        result.data[] = mixin(`data[]` ~ op ~ `rhs.data[]`);
        return result;
    }

    VEC opCast(VEC)() const {
        VEC rc;
        foreach(i,v ; data)
            rc[i] = cast(typeof(rc[0]))v;
        return rc;
    }

    //"abcdefghijklmnopqrstuvwxyz";
    static immutable enum int[26] indexOf = [3,2,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,3,0,1,2];

    auto opDispatch(string what)() const {
        import std.stdio : writeln;
        auto v = vec!(what.length, T)();
        int i = 0;
        foreach(w ; what) {
            if(w == 'O' || w == '0' || w == 'o')
                v[i++] = cast(T)0;
            else
                v[i++] = data[indexOf[w - 'a']];
        }
        return v;
    }

    void opAssign(T[N] d) {
        data[] = d[];
    }

    void opOpAssign(string op)(T[N] d) {
        foreach(int i, ref a ; data)
            mixin(`a ` ~ op ~ `= d[i];`);
    }

    string toString() {
        import std.string : format;
        string s = "[ ";
        static if(isFloatingPoint!T)
            foreach(d ; data) s ~= format("%.3f ", d);
        else
            foreach(d ; data) s ~= format("%d  ", d);
        return s ~ "]";
    }

};



alias vec2u = vec!(2, uint);
alias vec2i = vec!(2, int);
alias vec2f = vec!(2, float);

alias cvec2u = immutable vec!(2, uint);
alias cvec2i = immutable vec!(2, int);
alias cvec2f = immutable vec!(2, float);

alias vec3u = vec!(3, uint);
alias vec3i = vec!(3, int);
alias vec3f = vec!(3, float);

alias cvec3u = immutable vec!(3, uint);
alias cvec3i = immutable vec!(3, int);
alias cvec3f = immutable vec!(3, float);

alias vec4u = vec!(4, uint);
alias vec4i = vec!(4, int);
alias vec4f = vec!(4, float);

alias cvec4u = immutable vec!(4, uint);
alias cvec4i = immutable vec!(4, int);
alias cvec4f = immutable vec!(4, float);

unittest {
    import std.stdio;

    vec2f v0 = [13.2f, 4.8f];
    auto v1 = cast(vec2i)v0;
    assert(v1.x == 13);
    assert(v1.y == 4);

    assert(v1.yx == [4, 13]);
    assert(v1.Oy == [0, 4]);
    assert(v1.xO == [13, 0]);

    assert(v1 + v1 == [26, 8]);

    vec2i v2 = [2, 3];
    vec2i v3 = [3, 4];
    v3 += v2;
    assert(v3 == [5, 7]);

    vec3f c = [0.5f, 0.5f, 1.0f];
    assert(c.col == 0x7f7fff);

}


struct mat(int N, T = float)
{
    this(float f) {
        foreach(ref v ; elements)
            v = 0.0;
        for(int i=0; i<N; i++)
            elements[i][i] = f;
    }

    vec!(N,T) opBinary(string op)(const vec!(N, T) other) const {
        vec!(N,T) r = 0;
        for(int j=0; j<N; j++)
            for(int i=0; i<N; i++)
                r[i] += columns[j][i] * other[j];
        return r;
    }

	mat opBinary(string op)(const mat other) const {
		mat r;
		auto t = other.transpose();
		for(int i=0; i<N; i++)
			for(int j=0; j<N; j++)
				r[i][j] = columns[i].dot(t[j]);
		return r;
	}

    mat transpose() const {
        mat r;
		for(int i=0; i<N; i++)
			for(int j=0; j<N; j++)
				r[i,j] = columns[j][i];
        return r;
    }

    union {
        float[N][N] elements;
        vec!(N, T)[N] columns;
    }

    alias elements this;

    ref vec!(N,T) opIndex(size_t x) {
        return columns[x];
    }

    ref T opIndex(size_t x, size_t y) {
        return columns[x][y];
    }

}

alias mat2f = mat!(2,float);
alias mat3f = mat!(3,float);
alias mat4f = mat!(4,float);

auto make_scale(ARGS...)(ARGS args) {
    enum N = args.length;
	auto matrix = mat!(N+1,float)(1.0);
    foreach(i, a ; args)
        matrix[i,i] = a;
	return matrix;
}

auto make_scale(int N)(float[N] v) {
	auto matrix = mat!(N+1,float)(1.0);
    foreach(i, a ; v)
        matrix[i][i] = a;
	return matrix;
}

auto make_translate(ARGS...)(ARGS args) {
    enum N = args.length;
	auto matrix = mat!(N+1,float)(1.0);
    foreach(i, a ; args)
        matrix[N][i] = a;
	return matrix;
}

auto make_translate(int N)(float[N] v) {
	auto matrix = mat!(N+1,float)(1.0);
    foreach(i, a ; v)
        matrix[N][i] = a;
	return matrix;
}
import std.math;
auto make_rotate(int N)(float r) {

	auto m = mat!(N+1,float)(1.0);
    m[0][0] = cos(r);
    m[1][0] = sin(r);
    m[0][1] = -sin(r);
    m[1][1] = cos(r);
    return m;
}

unittest {
    import std.stdio;
    auto m = mat4f(2.0);

    auto m0 = m.transpose();

    assert(m0[1][1] == m[1,1]);
    assert(m0[2][2] == 2.0f);

    auto m2 = make_scale(2.0f, 2.0f);
    auto m3 = make_translate(5.0, 5.0);
    auto mm = m3 * m2;

    pragma(msg, typeof(mm));

    writeln(mm);
    auto v = mm * vec3f(3.0f,3.0f,1.0f);
    writeln(v);



}



