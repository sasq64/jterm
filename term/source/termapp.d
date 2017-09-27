import std.stdio;
import std.string;
import std.file;
import std.conv;

import diesel.gl;
import diesel.vec;

import layout;
import luainterpreter;
import terminal;
import termops;

import diesel.keycodes;

version(trace) import diesel.minitrace;

class TermApp
{
    TermOps ops;
    Program progNormal;

    Font font;
    Window win;
    string cmd;
    string[] args;

    Texture background;

    LuaInterpreter lua;

    int border = 0;

    uint[] defaultPalette;

    alias NODE = Node!Terminal;

    const static int minSplitSize = 40;

    NODE root;
    NODE currentNode = null;
    NODE lastNode = null;

    int zoom = 1;

    bool justSwitched = false;
    vec3f bgColor;

    @property Terminal currentTerm() {
        return currentNode ? currentNode.payload : null;
    }

    @property void currentTerm(Terminal t) {
        if(t) {
            Terminal.activeTerminal = t;
            currentNode = root.find(t);
        } else
            currentNode = null;
    }

    Split!Terminal currentSplit;
    int[2] startSplit;

    float rotation = 0.0;

    const string vs_normal = q{  // Vertex shader
        attribute vec2 in_pos;
        attribute vec2 in_uv;
        uniform mat4 in_mat;
        varying vec2 uv;
        void main(void) {
            gl_Position = in_mat * vec4(in_pos, 0, 1);
            uv = in_uv;
        }
    };

    void setupProgram()
    {
        version(trace) auto x = ScopedTrace();
        setShader(q{
            gl_FragColor = texture2D(tex, uv) * (active / 4.0 + 0.75);
        });

        auto fs_scanline = q{  // Fragment shader
            uniform sampler2D tex;
            varying vec2 uv;
            uniform int frameCounter;
            void main(void) {
                float my = mod(gl_FragCoord.y, 2.0);
                float mx = mod(gl_FragCoord.x + 1.0, 2.0);
                float mz = mod(gl_FragCoord.x + gl_FragCoord.y, 2.0);
                vec4 c = texture2D(tex, uv);
                gl_FragColor = vec4(c.x * mx, c.y * my, c.z * mz, c.a);
            }
        };
        //progScanlines = Program(vs, fs_scanline);
    }

    // Set the pixel shader for rendering the terminal areas.
    // 'shader' goes inside main() and must write to gl_FragColor
    // Available variables/uniforms:
    // uv - The UV coordinate
    // tex - The texture sampler
    // active = 1 or 0
    // frameCounter - Uniform that increases each frame
    // Default: "gl_FragColor = texture2D(tex, uv);"
    void setShader(string shader)
    {
        auto prefix = q{
            uniform sampler2D tex;
            varying vec2 uv;
            uniform int frameCounter;
            uniform float active;
        };
        auto p = Program(vs_normal,
            prefix ~ "void main(void) {\n" ~ shader ~ "\n}\n"
        );
        progNormal = p;
    }

    void initLua()
    {
        import std.base64;
        import imageformats;
        try {
            lua = new LuaInterpreter();
        } catch(Exception e) {
            lua = null;
            writeln("**Warning: Could not initialize LUA. Make sure you have "
                    ~ "liblua 5.3 or later installed.");
            version(OSX) writeln("Perhaps `brew install lua@5.3` ?");
            return;
        }

        foreach(m; __traits(allMembers, diesel.keycodes)) {
            static if(m.startsWith("DK_")) {
                enum v = __traits(getMember, diesel.keycodes, m);
                lua.set(m, v);
            }
        }

        lua.expose(ops);
    }

    this(Window win, string cmd, string[] args)
    {
        this.ops = new TermOps(this);
        this.win = win;
        this.args = args;
        this.cmd = cmd;
        setupProgram();
        initLua;

        auto mod = DKM_ALT;
        version(raspberry) mod = DKM_CMD;
        version(OSX) mod = DKM_CMD;
        version(Windows) mod = DKM_CMD;

        ops.bind(mod | 'p', &ops.setFontSize, () {
                auto s = currentTerm.font.requestedSize / win.getScale();
                return s + (s<24 ? 1 : 0);
        });
        ops.bind(mod | 'o', &ops.setFontSize, () {
                auto s = currentTerm.font.requestedSize / win.getScale();
                return s - (s>10 ? 1 : 0);
        });
        //ops.bind(mod | 'p', &ops.setFontSize, [10,11,12,13,14,15,16,18,20,24,30]);
        ops.bind(mod | DK_RIGHT, &ops.goRight);
        ops.bind(mod | DK_LEFT, &ops.goLeft);
        ops.bind(mod | DK_UP, &ops.goUp);
        ops.bind(mod | DK_DOWN, &ops.goDown);

        ops.bind(mod | '=', &ops.equalizeAll);
        ops.bind(mod | '[', &ops.shrink, 1);
        ops.bind(mod | ']', &ops.grow, 1);

        ops.bind(mod | 's', &ops.verticalSplit);
        ops.bind(mod | 'a', &ops.horizontalSplit);
        ops.bind(mod | 'w', &ops.closeCurrent);
        ops.bind(mod | 'z', &ops.toggleZoom);
        ops.bind(mod | 'x', &ops.setTermScale, () {
            int z = currentTerm.zoom + 1;
            if(z > 4) z = 1;
            return z;
        });
        ops.bind(mod | 'b', &ops.takeScreenshot);
        ops.bind(mod | 'v', &ops.paste);

        if(lua && lua.valid) {
            try {
                auto luaCode = readText("startup.lua");
                lua.load(luaCode, "startup.lua");
            } catch (FileException fe) {
                writeln("**Warning: No `startup.lua` found.");
            } catch (Exception e) {
                writeln("**LUA Error: " ~ e.msg);
            }
        }
    }

    void reorg()
    {
        if(!root) return;
        //root.layout();
        root.forEach((NODE n) {
            auto terminal = n.payload;
            if(terminal) {
                terminal.resize(n.w, n.h);
            }
        });
    }

    void closeTerm(NODE node)
    {
        if(node) {
            root.print;
            node.print;

            node.payload.quit();
            node.payload = null;

            NODE newNode = null;
            root.forEach((NODE n) {
                if(newNode) return;
                if(n.payload && n.payload != lastNode && n.payload != node.payload)
                    newNode = n;

            });

            node.remove();
            if(root.childCount == 0)
                win.quit();
            else {
                reorg();
            }
            if(lastNode && lastNode.payload) {
                currentTerm = lastNode.payload;
                lastNode = null;
            } else if(newNode && newNode.payload)
                setTerm(newNode);
            else
                currentTerm = null;
        }
    }

    void newTerm(NODE node)
    {
        node.payload = new Terminal(font.dup(), node.w, node.h, zoom, cmd, args);
        node.payload.prg = progNormal;
        node.payload.border = border;
        node.payload.start();
        if(defaultPalette.length > 0)
            node.payload.setPalette(defaultPalette);
        reorg();
    }

    void setFont(NODE node, Font font)
    {
        node.payload.setFont(font);
        node.payload.resize(node.w, node.h);
    }

    void setTerm(NODE n)
    {
        if(n && n.payload) {
            lastNode = root.find(currentTerm);
            currentTerm = n.payload;
        }
    }


    void handleKey(uint key, int[2] pos)
    {
        bool handled = false;
        if(currentTerm)
            handled = ops.handle(key);

        if(key & DKM_CMD) {
            int code = (key & 0xff_ff_ff);
            int no = code - 0x31;
            if(no >= 0 && no < Terminal.length)
                currentTerm = Terminal.get(no);
            else if(code == 'b') {

            }
            else if(code == 'q')
                win.quit();
            if(code == 'r')
                rotation += 0.1;
        } else
            if(key == DK_LEFT_MOUSE_DOWN) {
                auto split = root.findSplit(pos, 12);
                auto newNode = root.find(pos);
                if(split) {
                    currentSplit = split;
                    startSplit = pos;
                } else if(currentNode != newNode && newNode && newNode.payload) {
                    currentTerm = newNode.payload;
                    justSwitched = true;
                } else if(currentTerm)
                    currentTerm.putKey(key);
            } else if (key == DK_LEFT_MOUSE_UP) {
                   if(currentSplit) {
                    currentSplit.move(pos[0], pos[1], minSplitSize);
                    reorg();
                    currentSplit.parent = null;
                } else if(!justSwitched)
                    currentTerm.putKey(key);
                justSwitched = false;
            } else if(!handled && key != 0 && currentTerm) {
                currentTerm.putKey(key);
            }
    }

    void run()
    {
        if(font is null) {
            auto x = import("unscii-16.ttf");
            font = new Font(cast(const ubyte*)x.ptr, x.length, 16, [8, 16], true);
            zoom *= win.getScale();
        }

        root = new NODE(win.width, win.height);
        root.add();

        root.forEach((NODE n) {
            newTerm(n);
        });

        win.onResize((int width, int height) {
            root.resize(0, 0, width, height);
            reorg();
        });

        currentTerm = root.firstPayload(); //child[0].payload;

        win.runLoop({
            version(trace) auto _st = ScopedTrace("terminal.d", "loop");

            glDisable(GL_BLEND);

            currentTerm.updateAll();

            auto pos = win.getMouse();
            if(currentNode) {
                // TODO: Only report on buttons or move to new cell
                // TODO: Floating point mode
                int[2] cpos = [pos[0] - currentNode.x, pos[1] - currentNode.y];
                if(currentTerm)
                    currentTerm.reportMouse(cpos);
            }

            if(currentSplit) {
                //if(win.frameCounter % 4 == 0) {
                if(pos != startSplit) {
                    currentSplit.move(pos[0], pos[1], minSplitSize);
                    startSplit = pos;
                    reorg();
                }
                //}
            }

            uint key = win.getKey();
            while(key) {
                handleKey(key, pos);
                key = win.getKey();
            }

            if(currentTerm && currentTerm.haveSelection()) {
                win.putClipboard(currentTerm.popSelection());
            }

            win.setTarget();

            if(background) {
                background.bind();
                renderRectangle([0,0], [win.width, win.height], Program.basic2d);
            } else {

                glClearColor(bgColor.r, bgColor.g, bgColor.b, 1.0);
                glClear(GL_COLOR_BUFFER_BIT);
            }

            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            glEnable(GL_SCISSOR_TEST);
            glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_FALSE);
            root.forEach((NODE n) {
                auto term = n.payload;
                if(!term)
                    return;
                if(term.hasQuit) {
                    closeTerm(root.find(term));
                    return;
                }

                glScissor(n.x, .viewPort[1] - n.h - n.y, n.w, n.h);
                term.render([n.x, n.y]);

                // Render split lines

                Globals.set("drawColor", 0xFF_C0_C0_FF);

                if(n.y + n.h + 2 < (root.y + root.h)) {
                    renderRectangle([n.x, n.y + n.h - 2], [n.w, 2],
                        Program.flat2d);
                }

                if(n.x + n.w + 2 < (root.x + root.w)) {
                    renderRectangle([n.x + n.w - 2, n.y], [2, n.h],
                        Program.flat2d);
                }


            });
            glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
            glDisable(GL_SCISSOR_TEST);
        });
        Terminal.quitAll();
    }

}

