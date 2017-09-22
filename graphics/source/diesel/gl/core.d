module diesel.gl.core;

version(raspberry) {
    public import derelict.gles.gles2;
} else {
    public import derelict.opengl;
}

import std.traits;
import std.stdio;
import std.conv : to;
import std.exception;
import std.string : toz = toStringz;

class shader_exception : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

class gl_exception : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

version(glcheck)
{
    auto check(alias FN, string FILE = __FILE__, int LINE = __LINE__, ARGS ...)(ARGS args) {
        import std.format : format;
        scope(exit) {
            auto e = glGetError();
            if(e != GL_NO_ERROR) throw new gl_exception(format("%s() : GL Error 0x%x",
                __traits(identifier, FN), e), FILE, LINE);
        }
        return FN(args);
    }
}
else
{
    auto check(alias FN, ARGS ...)(ARGS args) { return FN(args); }
} // version(glcheck)

const GLuint UNSET = 0xffffffff;

struct Bitmap(T) {
    this(uint w, uint h) {
        pixels = new T[w * h];
        width = w;
        height = h;
    }

    void eachPixel(void delegate(int x, int y, ref T) cb) {
        for(auto y=0; y<height; y++)
            for(auto x=0; x<width; x++)
                cb(x, y, pixels[x + width * y]);
    }
    void clear()
    {
        foreach(ref p ; pixels)
            p = 0;
    }

    uint width;
    uint height;
    T[] pixels;

    alias pixels this;
};

uint scaleColor(uint col, float factor, uint add)
{
    uint r = cast(uint)(((col>>16)&0xff) * factor) + add;
    uint g = cast(uint)(((col>>8)&0xff) * factor) + add;
    uint b = cast(uint)((col&0xff) * factor) + add;
    uint a = col & 0xff00_0000;
    if(r > 0xff) r = 0xff;
    if(g > 0xff) g = 0xff;
    if(b > 0xff) b = 0xff;
    return a | (r<<16) | (g<<8) | b;
}

GLuint loadShader(GLenum shaderType, string source) {
    GLuint shader = check!glCreateShader(shaderType);
    if(shader) {
        const GLchar *p = source.ptr;
        check!glShaderSource(shader, 1, &p, null);
        check!glCompileShader(shader);
        GLint compiled = 0;
        check!glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
        GLint infoLen = 0;
        string msg;
        check!glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
        if(infoLen > 1) {
            write("SOURCE:\n", source);
            char[] log = new char[](infoLen);
            check!glGetShaderInfoLog(shader, infoLen, null, log.ptr);
            msg = to!string(log);
            writeln("glCompileShader():", msg, ":");
        }
        if(!compiled) {
            throw new shader_exception(msg);
        }
    } else
        throw new shader_exception("Failed to create shader");

    return shader;
}

GLuint createProgram(GLuint vertexShader, GLuint fragmentShader) {

    GLuint program = check!glCreateProgram();
    if(program) {
        check!glAttachShader(program, vertexShader);
        check!glAttachShader(program, fragmentShader);
        check!glLinkProgram(program);
        GLint linkStatus = GL_FALSE;
        GLint bufLength = 0;
        string msg;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &bufLength);
        if(bufLength > 1) {
            char[] buf = new char[](bufLength);
            glGetProgramInfoLog(program, bufLength, null, buf.ptr);
            msg = to!string(buf);
            writeln("glLinkProgram():", msg);
        }
        glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
        if(linkStatus != GL_TRUE) {
            glDeleteProgram(program);
            throw new shader_exception(msg);
        }
    } else
        throw new shader_exception("Could not create program");
    return program;
}

int[2] viewPort = [-1,-1];
void setViewPort(int[2] vp) {
    viewPort[] = vp;
    glViewport(0, 0, vp[0], vp[1]);
}


extern(C) void debCallback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length,
        const (GLchar)* message, void* userParam) nothrow {
    try { writeln(to!string(message));
    } catch (Throwable t) {}
}

unittest {
    import derelict.sdl2.sdl;
    import diesel.gl;

    DerelictGL3.load();
    auto win = new Window(320, 240);
    DerelictGL3.reload();
    if(glDebugMessageCallback)
        glDebugMessageCallback(&debCallback, cast(const (void)*)null);

    auto prog = Program(
    q{
            attribute vec2 in_pos;
            attribute vec2 in_uv;
            varying vec2 out_uv;
            void main(void) {
                gl_Position = vec4(in_pos, 0, 1);
                out_uv = in_uv;
            }
    }, q{
            #ifdef GL_ES
                precision mediump float;
            #endif
            uniform sampler2D in_tex;
            varying vec2 out_uv;
            void main(void) {
                vec4 c = texture2D(in_tex, out_uv);
                gl_FragColor = vec4(1.0, 1.0, 0.0, 1.0);
            }
    });

    //prog.setUniform("hello", 4.0f, 1.2f);
    //prog.setUniform("hello", [ [ 3.0f, 2.0f, 1.0f ], [ 5.0f, 6.1f, 7.2f ] ]);
    // alloc, upload(GLuint*)
    float[] data =
        [ -1, 1, 0, 0,
        1, 1, 1, 0,
        -1, -1, 0, 1,
        1, -1, 1, 1, ];
    auto buf = Buffer!float(data);
    buf.bind(); // bind

    auto tex = Texture();

    //win.runLoop({

    SDL_Event e;

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        prog.use();

        prog.vertexAttribPointer("in_pos", 2, GL_FLOAT, GL_FALSE, 16, 0);
        prog.vertexAttribPointer("in_uv", 2, GL_FLOAT, GL_FALSE, 16, 8);

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    //});

    //texture.bind();
    //vertices.draw();
}

