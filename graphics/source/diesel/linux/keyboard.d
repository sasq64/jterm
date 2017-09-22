module diesel.linux.keyboard;

version(raspberry) {

import core.sys.posix.sys.ioctl;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.posix.sys.time;
import core.sys.posix.sys.ioctl;

import std.string : toz = toStringz;
import diesel.linux.input_event_codes;
import std.stdio;

static auto _IOC(int dir, int type, int nr, int size)
{
	return (((dir)  << _IOC_DIRSHIFT) |
			((type) << _IOC_TYPESHIFT) |
			((nr)   << _IOC_NRSHIFT) |
			((size) << _IOC_SIZESHIFT));
}


int EVIOCGBIT(int ev, int len) {
	return _IOC(_IOC_READ, 'E', 0x20 + (ev), len);
}

struct input_event {
	timeval time;
	ushort type;
	ushort code;
	int value;
}

static const int EVIOCGRAB = _IOW!int('E', 0x90);

class LinuxKeyboard
{
	ubyte[512] pressed_keys;
	uint[] key_events;
	int[] fdv;

	bool haveKeys() { return key_events.length > 0; }

	uint nextKey() {
		if(key_events.length == 0)
			return 0;

		uint code = key_events[0];
		key_events = key_events[1..$];
		return code;
	}

	bool isPressed(int key) {
		if(key < 512)
			return pressed_keys[key] != 0;
		return false;
	}

	static bool test_bit(ubyte[] v, int n) {
		return (v[n/8] & (1<<(n%8))) != 0;
	}



	this()
	{
		import std.file;

		ubyte[(EV_MAX+7)/8] evbit;
		ubyte[(KEY_MAX+7)/8] keybit;

		writeln("Init keyboard");

		// Find all input devices generating keys we are interested in
		foreach(f ; dirEntries("/dev/input", SpanMode.breadth)) {
			if(!f.isDir) {
				writeln("Checking ", f.name);
				int fd = .open(toz(f.name), O_RDONLY, 0);
				if(fd >= 0) {
					ioctl(fd, EVIOCGBIT(0, evbit.length), evbit.ptr);
					if(test_bit(evbit, EV_KEY)) {
						ioctl(fd, EVIOCGBIT(EV_KEY, keybit.length), keybit.ptr);
						if(test_bit(keybit, KEY_LEFT) || test_bit(keybit, BTN_LEFT)) {
							writeln("Has input");
							ioctl(fd, EVIOCGRAB, 1);
							fdv ~= fd;
							continue;
						}
					}
					.close(fd);
				}
			}
		}
	}

	void pollKeyboard(uint usec)
	{
		int maxfd = -1;
		fd_set readset;
		timeval tv;
		ubyte[256] buf;

		FD_ZERO(&readset);
		foreach(fd ; fdv) {
			FD_SET(fd, &readset);
			if(fd > maxfd)
				maxfd = fd;
		}
		tv.tv_sec = usec / 1000_000;
		tv.tv_usec = usec % 1000_000;
		if(select(maxfd+1, &readset, null, null, &tv) <= 0)
			return;
		foreach(fd ; fdv) {
			if(FD_ISSET(fd, &readset)) {
				auto rc = .read(fd, buf.ptr, input_event.sizeof * 4);
				auto ptr = cast(input_event*)buf.ptr;
				while(rc >= input_event.sizeof) {
					if(ptr.type == EV_KEY) {
						//writeln("Got key ", ptr.code);
						if(ptr.value) {
							key_events ~= ptr.code;
						}
						if(ptr.code < 512)
							pressed_keys[ptr.code] = cast(ubyte)ptr.value;
					}
					ptr++;
					rc -= input_event.sizeof;
				}
			}
		}
	}
}

}
