
import std.stdio;
import std.conv;
import std.traits;
import std.exception;

import derelict.lua.lua;

import std.string : toz = toStringz;

class lua_exception : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

class LuaInterpreter
{
    static const luaL_Reg[] printlib = [
        { "print", &l_my_print },
        { null, null }
    ];

    static extern(C) int l_my_print(lua_State* L) nothrow {

        try {
        writeln("in my_print ", L);
        auto li = cast(LuaInterpreter*)lua_touserdata(L, lua_upvalueindex(1));
        int nargs = lua_gettop(L);
        writeln(li, " ", nargs);
        for (int i=1; i <= nargs; ++i) {
            const char *s = lua_tostring(L, i);
            writeln(s);
            if(s) {
            //    if(li.outputFunction)
              //      li.outputFunction(s);
            //else
                    writeln(to!string(s));
            }
        }
        if(li.outputFunction)
            li.outputFunction("\n");
        } catch(Throwable t) {
        }
        return 0;
    }

    void function(const char *s) outputFunction;

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

    bool load(string code, string name) {
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

    static void pushArg(T)(lua_State* L, T arg) if(isSomeString!T) {
        lua_pushstring(L, toz(arg));
    }

    static void pushArg(T)(lua_State* L, T arg) if(isBoolean!T) {
        lua_pushboolean(L, cast(bool)arg);
    }

    static void pushArg(T)(lua_State* L, T arg) if(isNumeric!T) {
        lua_pushnumber(L, cast(double)arg);
    }



    static T getArg(T)(lua_State* L, int index) if(isNumeric!T) {
        return cast(T)lua_tonumber(L, index);
    }

    static T getArg(T)(lua_State* L, int index) if(isSomeString!T) {
        return to!T(lua_tostring(L, index));
    }

    static T getArg(T)(lua_State* L, int index) if(isStaticArray!(T)) {
        T result;
        enum N = T.length;
        lua_pushnil(L);
        int i = 0;
        while(i <= N && lua_next(L, index)) {
            result[i++] = getArg!(typeof(result[0]))(L, -1);
            lua_pop(L, 1);
        }
        return result;
    }

    static T getArg(T)(lua_State* L, int index) if(isDynamicArray!T && !isSomeString!T) {
        T result;
        lua_pushnil(L);
        while(lua_next(L, index)) {
            result ~= getArg!(typeof(result[0]))(L, -1);
            lua_pop(L, 1);
        }
        return result;
    }

    static T getArg(T)(lua_State* L, int index) if(isAggregateType!T) {
        return to!T(null);
    }


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

    class FunctionCaller {
        public int call() { puts("NOT HERE!"); return 0; }
    };

    class FunctionCallerImpl(R, ARGS...) : FunctionCaller {

        this(lua_State* L, R delegate(ARGS) fn) {
            this.L = L;
            this.fn = fn;
        }

        public override int call() {
            puts("in call");
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
    };

    extern(C) static int proxy_func(lua_State* L) nothrow {
        try {
            auto index = cast(uint)(lua_touserdata(L, lua_upvalueindex(1)));
            auto fc = functions[index-1];
            return fc.call();
        } catch (Throwable t) {
            try { writeln(t); } catch(Throwable t0) {}
            puts("THROW");
        }
        return 0;
    }

    void set(T)(string name, T value) {
        pushArg(L, value);
        lua_setglobal(L, toz(name));
    }

    static FunctionCaller[] functions;

    void registerFunction(R, ARGS...)(string name, R delegate(ARGS) fn) {
        auto fc = new FunctionCallerImpl!(R,ARGS)(L, fn);
        functions ~= fc;
        //writeln("REG ",&fc, " ", ARGS.length);
        lua_pushlightuserdata(L, cast(void*)(functions.length));
        lua_pushcclosure(L, &proxy_func, 1);
        lua_setglobal(L, toz(name));
    }

    void expose(T)(T obj) {
        enum internal = [ "factory", "this", "Monitor" ];
        import std.algorithm : canFind;
        import std.algorithm.searching : startsWith;
        foreach(N ; __traits(allMembers, T)) {
            static if(!(canFind(internal, N)) &&
                    !N.startsWith("__") &&
                    !N.startsWith("op") &&
                    !N.startsWith("to") &&
                    isSomeFunction!(__traits(getMember, obj, N)) &&
                    __traits(getProtection, __traits(getMember, obj, N)) == "public"
                    ) {
                pragma(msg, N);
                registerFunction(N, &__traits(getMember, obj, N));
            }
        }
    }

    lua_State* L;
}

unittest {

    auto lua = new LuaInterpreter;

    class Test {
        float hey(string x) {
            return 14.0;
        }
        float you(int p, string x) {
            return p*2;
        }
    }

    auto t = new Test();

    lua.registerFunction("testFunc", (string s, int i, float f) {
        writeln(s, " ", i, " ", f);
        return 5;
    });

    lua.expose(t);
    //lua.registerFunction("hey", &t.hey);

	string luaCode = r"
	function test( a, b)
		x = testFunc('hello', 2, 3)
        -- print(a)
		return x * 2 + a + b + hey() + you(4, 'ok');
	end
    ";
    writeln(luaCode);

	lua.load(luaCode, "test");
	auto res = lua.call!float("test", 4, 2);
    writeln(res);

}

