module diesel.minitrace;

public import std.typecons : scoped;

import std.string : toz = toStringz;

extern(C) void mtr_init(const char *json_file);

// Shuts down minitrace cleanly, flushing the trace buffer.
extern(C) void mtr_shutdown();

// Lets you enable and disable Minitrace at runtime.
// May cause strange discontinuities in the output.
// Minitrace is enabled on startup by default.
extern(C) void mtr_start();
extern(C) void mtr_stop();

// Flushes the collected data to disk, clearing the buffer for new data.
extern(C) void mtr_flush();

// Returns the current time in seconds. Used internally by Minitrace. No caching.
extern(C) double mtr_time_s();

// Registers a handler that will flush the trace on Ctrl+C.
// Works on Linux and MacOSX, and in Win32 console applications.
extern(C) void mtr_register_sigint_handler();


// Commented-out types will be supported in the future.
enum mtr_arg_type {
	MTR_ARG_TYPE_NONE = 0,
	MTR_ARG_TYPE_INT = 1,	// I
	// MTR_ARG_TYPE_FLOAT = 2,  // TODO
	// MTR_ARG_TYPE_DOUBLE = 3,  // TODO
	MTR_ARG_TYPE_STRING_CONST = 8,	// C
	MTR_ARG_TYPE_STRING_COPY = 9,
	// MTR_ARG_TYPE_JSON_COPY = 10,
}

// Only use the macros to call these.
extern(C) void internal_mtr_raw_event(const char *category, const char *name, char ph, void *id);
extern(C) void internal_mtr_raw_event_arg(const char *category, const char *name, char ph,
		void *id, mtr_arg_type arg_type, const char *arg_name, void *arg_value);

// c - category. Can be filtered by in trace viewer (or at least that's the intention).
//     A good use is to pass __FILE__, there are macros further below that will do it for you.
// n - name. Pass __FUNCTION__ in most cases, unless you are marking up parts of one.

// Scopes. In C++, use MTR_SCOPE. In C, always match them within the same scope.
//#define MTR_BEGIN(c, n) internal_mtr_raw_event(c, n, 'B', 0)
//#define MTR_END(c, n) internal_mtr_raw_event(c, n, 'E', 0)
//#define MTR_SCOPE(c, n) MTRScopedTrace ____mtr_scope(c, n)
//#define MTR_SCOPE_LIMIT(c, n, l) MTRScopedTraceLimit ____mtr_scope(c, n, l)

@trusted struct ScopedTrace
{
    import core.stdc.string;
	static ScopedTrace opCall(string c = __FILE__, string n = __FUNCTION__) {
        ScopedTrace s;

        const char *cp = strdup(toz(c));
        const char *sp = strdup(toz(n));

		internal_mtr_raw_event(cp, sp, 'B', null);
        return s;
    }

	~this() {
		internal_mtr_raw_event(cp, sp, 'E', null);
	}

	const char *cp;
	const char *sp;
}

mixin template MTR_SCOPE()
{
	import std.typecons : scoped;
	auto x = scoped!ScopedTrace(__FILE__, __FUNCTION__);
}

void MTR_BEGIN(string c = __FILE__, string n = __FUNCTION__)()
{
	internal_mtr_raw_event(toz(c), toz(n), 'B', null);
}

void  MTR_END(string c = __FILE__, string n = __FUNCTION__)()
{
	internal_mtr_raw_event(toz(c), toz(n), 'E', null);
}

void MTR_META_PROCESS_NAME(const char *n) {
	internal_mtr_raw_event_arg("", "process_name", 'M', null, mtr_arg_type.MTR_ARG_TYPE_STRING_COPY, "name", cast(void *)(n));
}

void MTR_META_THREAD_NAME(const char *n) {
	internal_mtr_raw_event_arg("", "thread_name", 'M', null, mtr_arg_type.MTR_ARG_TYPE_STRING_COPY, "name", cast(void *)(n));
}
