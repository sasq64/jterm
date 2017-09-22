

import std.stdio;
import std.concurrency;
import std.exception;
import std.string : toz = toStringz;

import core.time : Duration, dur;

import diesel.vec;
import diesel.gl;
version(trace) import diesel.minitrace;


class Console
{
    int cols;
    int rows;

    struct Cell {
        wchar c;
        uint fg;
        uint bg;
        bool marked;
    }

    Cell[] buffer;

    int width;
    int height;
    Texture screenTexture;
    Font font;
    bool resized = false;

    int markStart;
    int markEnd;

    vec3f bg;
    @property void bgColor(uint color) {
        bg = vec3f(color);
        updateTexture();
    };
    @property vec3f bgColor() {
        return bg;
    }

    void setFont(Font font)
    {
        this.font = font;
    }

    void updateTexture() {
        screenTexture = Texture(width, height);
        screenTexture.setTarget();
        glClearColor(bgColor.r, bgColor.g, bgColor.b, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);

        buffer = new Cell[cols * rows];
    }

    void begin() {
        if(resized) {
            updateTexture();
            resized = false;
        }
        screenTexture.setTarget();
        font.startTexts();
    }

    void end()
    {
        font.endTexts();
    }

    void write(wstring text, int[2] p, uint fg, uint bg)
    {
        import std.array;

        if(p[1] > rows) return;
        auto x = (p[0]-1) + (p[1]-1) * cols;
        auto ex = p[1] * cols;

        //writefln("%d %d %d %d", x, ex, cols, rows);
        foreach(c ; text) {
            if(x >= ex) break;
            buffer[x++] = Cell(c, fg, bg);
        }

        auto fw = font.size.x;
        auto fh = font.size.y;
        auto w = screenTexture.width;
        auto h = screenTexture.height;
        vec2f pos = [p[0]*fw - fw - w*0.5, -(p[1]*fh - h*0.5)];
        font.renderText(text, pos, fg, bg);
    }

    void resize(int w, int h)
    {
        int c = w / font.size.x;
        int r = h / font.size.y;
        width = c * font.size.x;
        height = r * font.size.y;
        if(c != cols || r != rows) {
            cols = c;
            rows = r;
            resized = true;
        }
    }

    this(Font font, int w, int h)
    {
        this.font = font;
        this.cols = w / font.size.x;
        this.rows = h / font.size.y;
        resize(w,h);
        updateTexture();
    }

}
