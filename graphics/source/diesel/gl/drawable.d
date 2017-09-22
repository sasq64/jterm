module diesel.gl.drawable;

import std.exception;

import diesel.vec;
import diesel.gl.core;
import diesel.gl.buffer;
import diesel.gl.program;

struct Globals
{
    @property static ref T[string] values(T)() {
        static T[string] values;
        return values;
    }

    static void set(T)(string name, T value) {
        values!(T)[name] = value;
    }

    static T get(T)(string name) {
        if(name in values!(T))
            return values!(T)[name];
        else
            return T.init;
    }
};

struct Rectangle {
    import std.math;
    static Buffer!vec2f buf;

    static void draw(Program prog)
    {
        if(!buf) {
            vec2f[] data = [ vec2f(-1, 1), vec2f(0, 0), vec2f(1, 1), vec2f(1, 0), vec2f(-1, -1), vec2f(0, 1), vec2f(1, -1), vec2f(1, 1) ];
            for(int i=0; i<data.length; i+=2)
                data[i] = data[i] * 0.5f;
            buf = Buffer!vec2f(data, GL_ARRAY_BUFFER);
        }
        buf.bind();

        auto uvpos = prog.getAttribLocation("in_uv");
        if(uvpos >= 0)
            prog.vertexAttribPointer(uvpos, 2, GL_FLOAT, GL_FALSE, 16, 8);

        auto vecpos = prog.getAttribLocation("in_pos");
        if(vecpos >= 0)
            prog.vertexAttribPointer(vecpos, 2, GL_FLOAT, GL_FALSE, 16, 0);
        check!glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
}

static void draw(SHAPE, int N)(float[N][N] matrix, Program prog = Program.basic2d)
{
    enforce(.viewPort[0] >= 0);
    prog.use();
    prog.setUniform("in_mat", matrix);
    auto color = Globals.get!uint("drawColor");
    prog.setUniform("drawColor", vec4f(color));
    SHAPE.draw(prog);
}

static void draw(SHAPE, int N)(SHAPE shape, float[N][N] matrix, Program prog = Program.basic2d)
{
    enforce(.viewPort[0] >= 0);
    prog.use();
    prog.setUniform("in_mat", matrix);
    prog.setUniform("drawColor", vec4f(1.0, 0.2, 0.2, 1.0));
    shape.draw(prog);
}

void renderRectangle(int[2] pos, int[2] size, Program prog = Program.basic2d)
{
    vec3f screenScale = vec3f(2.0, 2.0, 1.0) / vec3f(.viewPort[0], .viewPort[1], 1.0);

    float[3] npos = [
                -viewPort[0]*0.5 + cast(float)pos[0] + size[0]*0.5,
                viewPort[1]*0.5 - cast(float)pos[1] - size[1]*0.5,
                0];
    float[3] nsize = [size[0], -size[1], 1];
    auto m = mat4f(1.0);
    draw!Rectangle(
            make_scale(nsize) *
            make_translate(npos) *
           // make_rotate!3(rotation) *
            make_scale([2.0 / .viewPort[0], 2.0 / .viewPort[1], 1.0]) // Screen scale always last
            ,prog);
};

