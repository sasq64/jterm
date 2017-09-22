module diesel.gl.program;

import diesel.gl.core;

import std.string : toz = toStringz;
import std.typecons : RefCounted;
import std.conv : to;
import std.traits;

struct Program
{
    struct ProgRef
    {
        GLuint programId = UNSET;
        GLuint vertexId = UNSET;
        GLuint fragmentId = UNSET;

        this(GLint programId, GLint vertexId, GLint fragmentId) {
            this.programId = programId;
            this.vertexId = vertexId;
            this.fragmentId = fragmentId;
        }

        ~this() {
            if(programId != UNSET) check!glDeleteProgram(programId);
            if(vertexId != UNSET) check!glDeleteShader(vertexId);
            if(fragmentId != UNSET) check!glDeleteShader(fragmentId);
        }
    }
    RefCounted!ProgRef progRef;

    GLuint[string] uniforms;
    GLint[string] attributes;

    this(string vertexSource, string fragmentSource)
    {
        auto vertexShader = loadShader(GL_VERTEX_SHADER, vertexSource);
        auto fragmentShader = loadShader(GL_FRAGMENT_SHADER, fragmentSource);
        auto program = createProgram(vertexShader, fragmentShader);
        progRef = ProgRef(program, vertexShader, fragmentShader);
    }

    void use() {
        check!glUseProgram(progRef.programId);
    }

    GLuint getUniformLocation(string name) {
        GLuint u;
        if(name in uniforms)
            u = uniforms[name];
        else {
            //writeln(name, " ",progRef.programId);
            u = check!glGetUniformLocation(progRef.programId, toz(name));
            uniforms[name] = u;
        }
        return u;
    }

    private static string typeString(T)() {
        string rc = "";
        static if(isFloatingPoint!T) rc = "f";
        else static if(isUnsigned!T) rc = "ui";
        else static if(isIntegral!T) rc = "i";
        return rc;
    }
/*
    void setUniform(T, int N)(GLuint h, T[N][] args) if(isScalarType!T) {
        auto fn = mixin(`glUniform` ~ to!string(N) ~ typeString!T ~ "v");
        fn(h, cast(GLint)args.length, cast(T*)args.ptr);
    }

    void setUniform(T)(GLuint h, T[] args) if(isScalarType!T) {
        auto fn = mixin(`glUniform1` ~ typeString!T ~ "v");
        fn(h, args.length, args.ptr);
    }
*/
    void setUniform(int N)(GLuint h, float[N] args) {
        use();
        mixin(`glUniform` ~ to!string(N) ~ "fv")(h, 1, args.ptr);
    }

    // All scalar versions
    void setUniform(ARGS...)(GLuint h, ARGS args)  {
        use();
        auto fn = mixin(`glUniform` ~ to!string(args.length) ~ typeString!(typeof(args[0])));
        fn(h, args);
    }

    void setUniform(int N, int M)(GLuint h, float[N][M] mat) {
        use();
        auto fn = mixin(`glUniformMatrix` ~ to!string(N) ~ `fv`);
        fn(h, 1, false, mat[0].ptr);
    }

    void setUniform(ARGS...)(string name, ARGS args)  {
        auto h = getUniformLocation(name);
        setUniform(h, args);
    }

    GLint getAttribLocation(string name) {
        GLint a;
        if(name in attributes) {
            a = attributes[name];
        } else {
            a = check!glGetAttribLocation(progRef.programId, toz(name));
            attributes[name] = a;
        }
        return a;
    }

    void vertexAttribPointer(GLint h, GLint size, GLenum type,
            GLboolean normalized, GLsizei stride, GLuint offset)
    {
        check!glVertexAttribPointer(h, size, type, normalized, stride, cast(void*)offset);
        check!glEnableVertexAttribArray(h);
    }

    void vertexAttribPointer(string name, GLint size, GLenum type,
            GLboolean normalized, GLsizei stride, GLuint offset)
    {
        GLint h = getAttribLocation(name);
        vertexAttribPointer(h, size, type, normalized, stride, offset);
    }

    bool opCast(T)() if(is(T == bool)) {
        return progRef.programId != UNSET;
    }

    static private Program flat2dProg;
    @property static Program flat2d() {
        if(!flat2dProg) {
            flat2dProg = Program(flat2dShaders[0], flat2dShaders[1]);
        }
        return flat2dProg;
    }

    static private Program basic2dProg;
    @property static Program basic2d() {
        if(!basic2dProg) {
            basic2dProg = Program(basic2dShaders[0], basic2dShaders[1]);
        }
        return basic2dProg;
    }

    static string[2] flat2dShaders = [
    q{  // Vertex shader
        attribute vec2 in_pos;
        uniform mat4 in_mat;
        void main(void) {
            gl_Position = in_mat * vec4(in_pos, 0, 1);
        }
    },
    q{  // Fragment shader
        uniform vec4 drawColor;
        void main(void) {
            gl_FragColor = drawColor;
        }
    }];

    static string[2] basic2dShaders = [
    q{  // Vertex shader
        attribute vec2 in_pos;
        attribute vec2 in_uv;
        uniform mat4 in_mat;
        varying vec2 out_uv;
        void main() {
            gl_Position = in_mat * vec4(in_pos, 0, 1);
            out_uv = in_uv;
        }
    },
    q{  // Fragment shader
        uniform sampler2D in_tex;
        varying vec2 out_uv;
        void main() {
            vec4 c = texture2D(in_tex, out_uv);
            gl_FragColor = c;//vec4(c.xyz, 1.0);
        }
    }];

}

