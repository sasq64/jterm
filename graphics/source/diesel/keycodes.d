module diesel.keycodes;

// "Portable" representation of key presses as a single uint
// Format is (BITS) mmmmmmmm_xCcccccc_cccccccc_cccccccc where
// The top byte is for modifiers and bit 23 is for special keys.
// If the x bit is not set, the lower 23 bits is conisdered a Unicode character.
// Bit 22 is set for key Releases, which are often not needed, and particularly not
// for unicode so you still get 23 bits Unicode if you need.

static const uint KEYCODE = 0x0080_0000;
static const uint RELEASED = 0x0040_0000;

enum {
    DKM_SHIFT = 1<<24,
    DKM_CTRL = 2<<24,
    DKM_ALT = 4<<24,
    DKM_CMD = 8<<24, // Win or Command
}

enum {
    DK_LEFT_MOUSE_DOWN = KEYCODE | 0x10001,
    DK_RIGHT_MOUSE_DOWN = KEYCODE | 0x10002,
    DK_MIDDLE_MOUSE_DOWN = KEYCODE | 0x10003,
    DK_WHEEL_UP = KEYCODE | 0x10004,
    DK_WHEEL_DOWN = KEYCODE | 0x10005,

    // Aliases
    DK_LEFT_MOUSE_UP = DK_LEFT_MOUSE_DOWN | RELEASED,
    DK_RIGHT_MOUSE_UP = DK_RIGHT_MOUSE_DOWN | RELEASED,
    DK_MIDDLE_MOUSE_UP = DK_MIDDLE_MOUSE_DOWN | RELEASED,
}

version(raspberry) {
    import diesel.linux.input_event_codes;
    import std.algorithm.searching : startsWith;
    import std.conv : to ;

    // Mixin to translate all Linux KEY_ symbols into DK_ symbols
    string generateKeys()
    {
        string entries = "";

        foreach(m; __traits(allMembers, diesel.linux.input_event_codes)) {
            static if(m.startsWith("KEY_")) {
                enum v = __traits(getMember, diesel.linux.input_event_codes, m);
                enum line = ("static const int DK" ~ m[3..$] ~ " = " ~ to!string(v + KEYCODE) ~ ";\n");
                entries ~= line;
            }
        }
        return entries;
    }

    // Pull in Linux KEY_* symbols and translate them to DK_* symbols
    mixin(generateKeys());
} else {
    import derelict.sdl2.sdl;
    enum {
        DK_ENTER = 0xd,
        DK_BACKSPACE = 0x8,
        DK_TAB = 0x9,
        DK_ESC = SDLK_ESCAPE,

        DK_DELETE = SDL_SCANCODE_DELETE | KEYCODE,

        DK_RIGHT = SDL_SCANCODE_RIGHT | KEYCODE,
        DK_LEFT,
        DK_DOWN,
        DK_UP,

        DK_PAGEUP = SDL_SCANCODE_PAGEUP | KEYCODE,
        DK_PAGEDOWN = SDL_SCANCODE_PAGEDOWN | KEYCODE,

        DK_HOME = SDL_SCANCODE_HOME | KEYCODE,
        DK_END = SDL_SCANCODE_END | KEYCODE,

        DK_F1 = SDL_SCANCODE_F1 | KEYCODE,
        DK_F2,
        DK_F3,
        DK_F4,
        DK_F5,
        DK_F6,
        DK_F7,
        DK_F8,
        DK_F9,
        DK_F10,
        DK_F11,
        DK_F12,
        DK_F13,
        DK_F14,
        DK_F15
    }
}

