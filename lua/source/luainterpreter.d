
import std.stdio;
import std.conv;
import std.traits;
import std.exception;

import derelict.lua.lua;

import std.string : toz = toStringz;

class lua_exception : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

/// Tagging attribute for expose() function
enum script;

class LuaInterpreter
{
    class FunctionCaller {
        public abstract int call();
    }

    class FunctionCallerImpl(R, ARGS...) : FunctionCaller {

        this(lua_State* L, R delegate(ARGS) fn) {
            this.L = L;
            this.fn = fn;
        }

        public override int call() {
            ARGS args;
            foreach(int i,A ; ARGS) {
                args[i] = getArg!A(L, i+1);
            }
            static if(is(R == void)) {
                fn(args);
                return 0;
            } else {
                pushArg(L, fn(args));
                return 1;
            }
        }

        lua_State* L;
        R delegate(ARGS) fn;
    }

    static void pushArg(T)(lua_State* L, T arg) if(isSomeString!T) {
        lua_pushstring(L, toz(arg));
    }

    static void pushArg(T)(lua_State* L, T arg) if(isBoolean!T) {
        lua_pushboolean(L, cast(bool)arg);
    }

    static void pushArg(T)(lua_State* L, T arg) if(isNumeric!T) {
        lua_pushnumber(L, cast(double)arg);
    }

    void pushArg(FN : R delegate(ARGS), R, ARGS...)(lua_State* L, FN fn) {
        // Save in list instead of passing directly to avoid it being GC:ed
        functions ~= new FunctionCallerImpl!(R,ARGS)(L, fn);
        lua_pushlightuserdata(L, cast(void*)(functions.length));
        lua_pushcclosure(L, &proxy_func, 1);
    }

    static T getArg(T)(lua_State* L, int index = -1) if(isNumeric!T) {
        return cast(T)lua_tonumber(L, index);
    }

    static auto getArg(T)(lua_State* L, int index = -1) if(isSomeString!T) {
        return to!T(lua_tostring(L, index));
    }

    static auto getArg(FN : R delegate(ARGS), R, ARGS...)(lua_State* L, int index = -1) {
        int r = luaL_ref(L, LUA_REGISTRYINDEX);
        return delegate(ARGS args) {
            lua_rawgeti(L, LUA_REGISTRYINDEX, r);
            foreach(a ; args) pushArg(L, a);
            static if(is(R == void)) {
                lua_call(L, args.length, 0);
                return;
            } else {
                lua_call(L, args.length, 1);
                return getArg!R(L, -1);
            }
        };
    }

    static T getArg(T : A[N], A, int N)(lua_State* L, int index = -1) {
        T result;
        lua_pushnil(L);
        int i = 0;
        while(i <= N && lua_next(L, index)) {
            result[i++] = getArg!A(L);
            lua_pop(L, 1);
        }
        return result;
    }

    static T getArg(T : A[], A)(lua_State* L, int index = -1) if(isDynamicArray!T && !isSomeString!T) {
        T result;
        lua_pushnil(L);
        while(lua_next(L, index)) {
            result ~= getArg!A(L);
            lua_pop(L, 1);
        }
        return result;
    }

    static T getArg(T)(lua_State* L, int index) if(isAggregateType!T) {
        return to!T(null);
    }



    static const luaL_Reg[] printlib = [
        { "print", &l_my_print },
        { null, null }
    ];

    static extern(C) int l_my_print(lua_State* L) nothrow {

        try {
            auto li = cast(LuaInterpreter*)lua_touserdata(L, lua_upvalueindex(1));
            int nargs = lua_gettop(L);
            for (int i=1; i <= nargs; ++i) {
                const char *s = lua_tostring(L, i);
                if(s)
                    writeln(to!string(s));
            }
        } catch(Throwable t) { }
        return 0;
    }

    extern(C) static int proxy_func(lua_State* L) nothrow {
        try {
            auto index = cast(uint)(lua_touserdata(L, lua_upvalueindex(1)));
            return functions[index-1].call();
        } catch (Throwable t) {
            try { writeln(t); } catch(Throwable t0) {}
            puts("THROW");
        }
        return 0;
    }

    static FunctionCaller[] functions;

    bool valid = false;

    this()
    {
        version(linux) DerelictLua.load("liblua5.3.so.0");
        version(OSX) DerelictLua.load("liblua.5.3.dylib");
        L = luaL_newstate();
        luaL_openlibs(L);
        lua_getglobal(L, "_G");
        lua_pushlightuserdata(L, cast(void*)this);
        luaL_setfuncs(L, printlib.ptr, 1);
        lua_pop(L, 1);
        valid = true;
    }

    ~this() {
        if(L)
            lua_close(L);
    }

    /// Execute lua code
    bool load(string code, string name = "LUA") {
        if(luaL_loadbuffer(L, toz(code), code.length, toz(name)) == LUA_OK) {
            int rc = lua_pcall(L, 0, 0, 0);
            if(rc != LUA_OK) {
                const char *s = lua_tostring(L, -1);
                lua_pop(L, 1);
                throw new lua_exception(to!string(s));
            }
        } else {
            const char *s = lua_tostring(L, -1);
            lua_pop(L, 1);
            throw new lua_exception(to!string(s));
        }
        return true;
    }

    /// Call a LUA function
    T call(T, ARGS ...)(string name, ARGS args) {
        lua_getglobal(L, toz(name));
        foreach(arg ; args) {
            pushArg(L, arg);
        }
        static if(is(T == void)) {
            lua_call(L, args.length, 0);
        } else {
            lua_call(L, args.length, 1);
            return getArg!T(L, -1);
        }
    }

    /// Set a LUA global to value
    void set(T)(string name, T value) {
        pushArg(L, value);
        lua_setglobal(L, toz(name));
    }

    struct LuaRef {
        string name;
        LuaInterpreter lua;
        void opAssign(T)(T value) {
            lua.pushArg(lua.L, value);
            lua_setglobal(lua.L, toz(name));
        }

        T get(T)() {
            lua_getglobal(lua.L, toz(name));
            return lua.getArg!T(lua.L, -1);
        }

        T opCast(T)() { return get!T; }

    }

    /// Access a global value
    LuaRef opIndex(string name) {
        return LuaRef(name, this);
    }

    /// Register all member functions tagged with '@script'
    void expose(T)(T obj) {
        foreach(N ; __traits(allMembers, T)) {
            static if(hasUDA!(__traits(getMember, obj, N), script)) {
               set(N, &__traits(getMember, obj, N));
            }
        }
    }

    lua_State* L;
}

version(unittest) {
    class Test {
        @script float hey(string x) {
            return 14.0;
        }
        @script float you(int p, string x) {
            return p*2;
        }

        private int delegate(int) cb;

        @script void callme(int delegate(int) cb) {
            writeln("callme with ", cb);
            this.cb = cb;
        }

    }
}

unittest {

    auto lua = new LuaInterpreter;

    auto t = new Test();

    lua["testFunc"] = (string s, int i, float f) {
        writeln(s, " ", i, " ", t);
        return 5;
    };

    lua.expose(t);

    string luaCode = r"
    function test( a, b)

        print(x)
        print 'In test'
        x = testFunc('hello', 2, 3)

        callme(function(a)
            print 'In function'
            print(a)
            return a * 10
        end)

        -- print(a)
        return x * 2 + a + b + hey() + you(4, 'ok');
    end
    ";
    writeln(luaCode);

    lua.load(luaCode, "test");

    lua["x"] = 5;

    auto a = lua["x"].get!int;

    stdout.flush();
    auto res = lua.call!float("test", 4, 2);
    writeln(res);
    assert(res == 38);

    auto test = lua["test"].get!(int delegate(int, int));
    res = test(9, 3);
    writeln(res);

    assert(res == 44);
    auto res2 = t.cb(9);
    writeln(res2);
    assert(res2 == 90);

}

