module diesel.gl.window;

import diesel.gl.core;

import std.exception;
import std.conv : to;
import std.stdio;
import std.string : startsWith, toz = toStringz;


version(raspberry) import diesel.linux.input_event_codes;
// Mixin to translate all Linux KEY_ symbols into DK_ symbols
string generateKeys()
{
    string entries = "";

    foreach(m; __traits(allMembers, diesel.linux.input_event_codes)) {
        static if(m.startsWith("KEY_")) {
            enum v = __traits(getMember, diesel.linux.input_event_codes, m);
            enum line = ("static const int DK" ~ m[3..$] ~ " = " ~ to!string(v + 0x0080_0000) ~ ";\n");
            entries ~= line;
        }
    }
    return entries;
}

class Window
{
    int width;
    int height;
    ulong frameCounter = 0;
    bool fullScreen = false;
    int factor = 1;

    int getScale() { return factor; }

	void delegate(int, int) resize_cb;

	void onResize(void delegate(int,int) cb) {
		resize_cb = cb;
	}

    import diesel.keycodes;

    version(raspberry) {

        import diesel.broadcom;
        import derelict.gles.egl;
        import std.concurrency;
		import diesel.linux.keyboard;

		// Pull in Linux KEY_* symbols and translate them to DK_* symbols
        mixin(generateKeys());

        EGLConfig eglConfig;
        EGLContext eglContext;
        EGLDisplay eglDisplay;
        EGLSurface eglSurface;
        EGL_DISPMANX_WINDOW_T nativeWindow;

        void initEGL()
        {
            EGLint numConfigs;
            EGLConfig config;
            EGLConfig[32] configList;

            eglDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);

            EGLint m0;
            EGLint m1;

            eglInitialize(eglDisplay, &m0, &m1);

            eglGetConfigs(eglDisplay, configList.ptr, 32, &numConfigs);

            for(int i=0; i<numConfigs; i++) {
                EGLint conf, stype, caveat, sbuffers;
                eglGetConfigAttrib(eglDisplay, configList[i], EGL_CONFORMANT, &conf);
                eglGetConfigAttrib(eglDisplay, configList[i], EGL_SURFACE_TYPE, &stype);
                eglGetConfigAttrib(eglDisplay, configList[i], EGL_CONFIG_CAVEAT, &caveat);
                eglGetConfigAttrib(eglDisplay, configList[i], EGL_SAMPLE_BUFFERS, &sbuffers);

                // Pick a ES 2 context that preferably has some AA
                if((conf & EGL_OPENGL_ES2_BIT) && (stype & EGL_WINDOW_BIT)) {
                    config = configList[i];
                    if(sbuffers > 0) {
                        break;
                    }
                }
            }

            if(config == null)
                throw new gl_exception("Could not find compatible config");

            EGLint[] attribs = [
                EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL_NONE, EGL_NONE
            ];

            eglContext = eglCreateContext(eglDisplay, config, null, attribs.ptr);
            if(eglContext == EGL_NO_CONTEXT)
                throw new gl_exception("Cound not create GL context");

            eglSurface = eglCreateWindowSurface(eglDisplay, config, cast(Display*)&nativeWindow, null);
            if(eglSurface == EGL_NO_SURFACE)
                throw new gl_exception("Cound not create GL surface");

            if(eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext) == EGL_FALSE)
                throw new gl_exception("Cound not set context");

            eglConfig = config;
        }

        void broadcom_init()
        {
            DISPMANX_ELEMENT_HANDLE_T dispman_element;
            DISPMANX_DISPLAY_HANDLE_T dispman_display;
            DISPMANX_UPDATE_HANDLE_T dispman_update;
            VC_RECT_T dst_rect;
            VC_RECT_T src_rect;

            uint display_width;
            uint display_height;

            bcm_host_init();

            if(graphics_get_display_size(0 /* LCD */, &display_width, &display_height) < 0)
                throw new gl_exception("Cound not get display size");

            dst_rect.x = 0;
            dst_rect.y = 0;
            dst_rect.width = display_width;
            dst_rect.height = display_height;

            ushort dwa = 0;
            ushort dha = 0;

            // Scale 50% on hires screens
            /* if(display_width > 1280) { */
            /*     display_width /= 2; */
            /*     display_height /= 2; */
            /*     dwa = cast(ushort)display_width; */
            /*     dha = cast(ushort)display_height; */
            /* } */
            width = display_width;
            height = display_height;

            src_rect.x = 0;
            src_rect.y = 0;
            src_rect.width = display_width << 16 | dwa;
            src_rect.height = display_height << 16 | dha;

            dispman_display = vc_dispmanx_display_open(0 /* LCD */);
            dispman_update = vc_dispmanx_update_start(0);

            dispman_element = vc_dispmanx_element_add(dispman_update,
                    dispman_display, 0, &dst_rect, 0, &src_rect,
                    DISPMANX_PROTECTION_NONE, null, null, DISPMANX_TRANSFORM_T.DISPMANX_NO_ROTATE);

            nativeWindow.element = dispman_element;
            nativeWindow.width = display_width;
            nativeWindow.height = display_height;
            vc_dispmanx_update_submit_sync(dispman_update);
        }

        void runLoop(void delegate() looper) {
            while(!doQuit) {
                //kbd.pollKeyboard(1);
                frameCounter++;
                looper();
                eglSwapBuffers(eglDisplay, eglSurface);
            }
        }

        void swap() {
            eglSwapBuffers(eglDisplay, eglSurface);
        }
        Tid keyTid;

        import core.time : Duration, dur;

        LinuxKeyboard kbd;
		struct KeyCode {
			uint key;
			alias key this;
		}

        uint getKey()
        {
            uint key = 0;
            //if(kbd.haveKeys())
            //	key = kbd.nextKey();
            receiveTimeout(dur!"usecs"(1),
                (KeyCode x) { key = x; }
            );

            return key;
        }


        shared static bool quitKeyboard = false;

        void exit()
        {
            if(!quitKeyboard) {
                quitKeyboard = true;
                writeln("Waiting for keyboard");
                receiveTimeout(dur!"seconds"(1),
                    (LinkTerminated l) { writeln("Keyboard terminated"); }
                );
            }
        }

		static const string toa = "\000\0001234567890-=\x08\x09qwertyuiop[]\x0d\000asdfghjkl;'\000\000\\zxcvbnm,./\000\000\000 ";
		static const string toa_up = "\000\000!@#$%^&*()_+\000\000QWERTYUIOP{}\000\000ASDFGHJKL:\"\000\000|ZXCVBNM<>?\000\000\000 ";

		static uint to_ascii(int code, bool shift) {
			uint a;
			if(code < toa.length) {
				a = shift ? toa_up[code] : toa[code];
			}
			return a;
		}

        void init()
        {
            import derelict.util.loader;
            (cast(SharedLibLoader)DerelictGLES2).load();
            DerelictEGL.load();

            //kbd = new LinuxKeyboard();
            keyTid = spawnLinked((Tid parentTid) {
                auto lk = new LinuxKeyboard();
                while(!quitKeyboard) {
                    lk.pollKeyboard(100_000);
					if(!lk.haveKeys())
						continue;
					bool shift = lk.isPressed( KEY_LEFTSHIFT ) || lk.isPressed( KEY_RIGHTSHIFT );
					bool ctrl = lk.isPressed( KEY_LEFTCTRL ) || lk.isPressed( KEY_RIGHTCTRL );
					bool alt = lk.isPressed( KEY_LEFTALT ) || lk.isPressed( KEY_RIGHTALT );
					bool meta = lk.isPressed( KEY_LEFTMETA ) || lk.isPressed( KEY_RIGHTMETA );
                    while(lk.haveKeys()) {
							auto code = lk.nextKey();
							uint a = to_ascii(code, shift);
							if(a == 0) {
								a = code + KEYCODE;
								if(shift) a |= DKM_SHIFT;
								if(ctrl) a |= DKM_CTRL;
								if(alt) a |= DKM_ALT;
								if(meta) a |= DKM_CMD;
								writefln("CODE %x", a);
							} else {
								if(ctrl) a |= DKM_CTRL;
								if(meta) a |= DKM_CMD;
							}

                        send(parentTid, KeyCode(a));
                    }
                }
            }, thisTid);

            broadcom_init();
            initEGL();
        }

        int[2] getMouse() {
            return [-1,-1];
        }


    } else {

        import derelict.sdl2.sdl;
        SDL_Window* window;
        SDL_Renderer* renderer;

        uint[] keys;

        int[2] currentMouse;
        bool haveMouse = false;

        uint sdlToDkm(uint x) {
            uint rc = 0;
            if(x & KMOD_SHIFT) rc |= DKM_SHIFT;
            if(x & KMOD_ALT) rc |= DKM_ALT;
            if(x & KMOD_CTRL) rc |= DKM_CTRL;
            if(x & KMOD_GUI) rc |= DKM_CMD;
            return rc;
        }

        int[2] getMouse() {
            if(haveMouse)
                return currentMouse;
            SDL_GetMouseState(currentMouse.ptr, currentMouse.ptr+1);
            currentMouse[] *= factor;
            haveMouse = true;
            return currentMouse;
        }

        bool spaceMod = false;
        bool spacePressed = false;
        bool spaceUsed = false;
        bool keyDown = false;

        void runLoop(void delegate() looper) {
            import std.utf;
            import std.algorithm.searching : find;
            SDL_Event e;
            static int[] mbuttons = [SDL_BUTTON_LEFT, SDL_BUTTON_RIGHT, SDL_BUTTON_MIDDLE,
                                     SDL_BUTTON_X1, SDL_BUTTON_X2];
            while(!doQuit) {
                haveMouse = false;
                frameCounter++;

                uint savedKey = 0;
				uint lastSym = 0;
                while(SDL_PollEvent(&e) != 0) {
                    uint s = 0;
                    auto sym = e.key.keysym.sym;
                    auto mod = e.key.keysym.mod;
					if(e.type == SDL_KEYDOWN) {
						// Deal with Ubuntu stupidities
						if(sym == SDLK_LGUI && (mod & KMOD_LGUI))
							continue;
						if(sym == SDLK_LALT && (mod & KMOD_LALT))
							continue;
						if(sym == lastSym)
							continue;
					}
                    /* if(e.type == SDL_KEYUP || e.type == SDL_KEYDOWN || e.type == SDL_TEXTINPUT) { */
                    /*     if(e.type == SDL_TEXTINPUT) { */
                    /*         auto txt = to!string(cast(const char *)e.text.text); */
                    /*         writefln("#TEXT '%s'", txt); */
                    /*     } else */
                    /*         writefln("#KEY %s %x(%x)", e.type == SDL_KEYUP ? "up" : "down", sym, mod); */
                    /* } */
                    if(e.type == SDL_MOUSEWHEEL) {
                        if(e.wheel.y > 0)
                            s = DK_WHEEL_UP;
                        if(e.wheel.y < 0)
                            s = DK_WHEEL_DOWN;
                    } else
                    if(e.type == SDL_MOUSEBUTTONDOWN) {
                        auto f = find(mbuttons, cast(int)e.button.button);
                        s = DK_LEFT_MOUSE_DOWN + cast(uint)(5 - f.length);
                        currentMouse[0] = e.button.x * factor;
                        currentMouse[1] = e.button.y * factor;
                        haveMouse = true;
                    } else if(e.type == SDL_MOUSEBUTTONUP) {
                        auto f = find(mbuttons, cast(int)e.button.button);
                        s = DK_LEFT_MOUSE_UP + cast(uint)(5 - f.length);
                        currentMouse[0] = e.button.x * factor;
                        currentMouse[1] = e.button.y * factor;
                        haveMouse = true;
                    } else if(e.type == SDL_WINDOWEVENT) {
                        if(e.window.event == SDL_WINDOWEVENT_SIZE_CHANGED) {
                            SDL_GetRendererOutputSize(renderer, &width, &height);
                            factor = width / e.window.data1;
                            resize_cb(width, height);
                        }
                    } else if(e.type == SDL_KEYUP) {
                        if(savedKey != 0) {
                            keys ~= savedKey;
                            savedKey = 0;
                        }
                        keyDown = false;
                    } else if(e.type == SDL_KEYDOWN) {
						lastSym = sym;
                        if(savedKey != 0) {
                            keys ~= savedKey;
                            savedKey = 0;
                        }
                        keyDown = true;
                        if(sym >= 0x10000)
                            savedKey = e.key.keysym.scancode | KEYCODE;
                        else
                            savedKey = sym;
                        savedKey |= sdlToDkm(mod);
                    } else if(e.type == SDL_TEXTINPUT) {
                        auto txt = to!string(cast(const char *)e.text.text);
                        size_t index = 0;
                        s = std.utf.decode(txt, index);
                        if((savedKey & 0xffffff) == s)
                            s = savedKey;
                        savedKey = 0;
                    } else if(e.type == SDL_QUIT)
                        doQuit = true;

                    if(s != 0) {
                        if(s == (DKM_CMD | cast(uint)'v')) { // OSX Cmd-v paste hack
                            auto ct = to!string(SDL_GetClipboardText());
                            foreach(dchar c ; ct)
                                keys ~= c;
                        } else {
                            keys ~= s;
                        }
                    }
                }
                if(savedKey != 0) {
                    keys ~= savedKey;
                    savedKey = 0;
                }
                looper();
                SDL_GL_SwapWindow(window);
            }
        }

        void swap() {
            SDL_GL_SwapWindow(window);
        }

        uint getKey() {
            uint rc = 0;
            if(keys.length > 0) {
                rc = keys[0];
                keys = keys[1 .. $];
            }
            return rc;
        }

        void exit()
        {
        }

        void init()
        {
            DerelictSDL2.load();
            DerelictGL3.load();

            SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
            SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
            SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
            enforce(SDL_Init(SDL_INIT_VIDEO) >= 0,
                    "Failed to initialize SDL: " ~ to!string(SDL_GetError()));
            int flags = SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE ;
            flags |= SDL_WINDOW_ALLOW_HIGHDPI;
            if(fullScreen) {
                flags |= SDL_WINDOW_FULLSCREEN;
                if(width == 0)
                    flags |= SDL_WINDOW_FULLSCREEN_DESKTOP;
            } else {
                if(width == 0) {
                    width = 800;
                    height = 480;
                }
            }
            window = SDL_CreateWindow("Jterm", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, width, height, cast(SDL_WindowFlags)flags);
            renderer = SDL_CreateRenderer(window, -1, cast(SDL_RendererFlags)0);

            enforce(SDL_GL_CreateContext(window) != null);

            SDL_GetRendererOutputSize(renderer, &width, &height);

            int w, h;
            SDL_GetWindowSize(window, &w, &h);
            factor = width / w;

            //width *= 2;
            //height *= 2;

            SDL_GL_SetSwapInterval(1);
            DerelictGL3.reload();
        }

    }
    // Common code

    this(int w, int h, bool fs = false)
    {
        fullScreen = fs;
        init();
        setViewPort([width,height]);
    }

    ~this()
    {
        exit();
    }

    void setTarget() {
        check!glBindFramebuffer(GL_FRAMEBUFFER, 0);
        setViewPort([width,height]);
    }
    bool doQuit = false;

    void quit() {
        doQuit = true;
    }
}
