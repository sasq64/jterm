

import std.stdio;
import std.concurrency;
import std.exception;
import std.string : toz = toStringz;

import std.conv;
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

    // Current selection
    int selStart = -1;
    int selEnd = -1;
    int selPos = -1;

    vec3f bg;
    @property void bgColor(uint color) {
        bg = vec3f(color);
        updateTexture();
    };
    @property vec3f bgColor() {
        return bg;
    }

    void clearSelection()
    {
        begin();
        foreach(int i, ref c ; buffer) {
            if(c.marked) {
                int[2] pos = [ i % cols , i / cols];
                auto s = to!wstring(c.c);
                //writefln("Restore %d '%x' %x %x", i, c.c, c.fg, c.bg);
                write(s, pos, c.fg, c.bg, false);
                c.marked = false;
            }
        }
        end();
    }

    void startSelection(int[2] pos)
    {
        selPos = selStart = selEnd = pos[0] + pos[1] * cols;
        updateSelection();
        writeln("START ", selStart);
    }

    void extendSelection(int[2] pos)
    {
        auto i = pos[0] + pos[1] * cols;
            if(i <= selPos) {
                selStart = i;
                selEnd = selPos;
            } else if (i > selPos) {
                selEnd = i;
                selStart = selPos;
            }
            updateSelection();
    }

    private void updateSelection()
    {
        begin();
        foreach(int i , ref c ; buffer) {
            bool marked = (i >= selStart && i <= selEnd);
            if(c.marked != marked) {
                int[2] pos = [ i % cols , i / cols];
                auto s = to!wstring(c.c);
                write(s, pos,
                        marked ? 0xff00_0000 : c.fg,
                        marked ? 0xffff_ffff : c.bg,
                false);
                c.marked = marked;
            }
        }
        end();
    }

    string getSelection()
    {
        import std.algorithm.iteration;
        import std.utf;
        import std.algorithm.mutation : stripRight;
        import std.array : join, array;

        int sx = selStart % cols;
        int sy = selStart / cols;
        int ex = selEnd % cols;
        int ey = selEnd / cols;
        string[] lines;
        foreach(y ; sy .. ey+1) {
            int x0 = y == sy ? sx : 0;
            int x1 = y == ey ? ex+1 : cols;
            auto s = toUTF8(array(buffer[x0 + y * cols .. x1 + y * cols].map!(c => c.c)().stripRight(' ')));
            writeln(s);
            lines ~= s;
        }

        return lines.join("\n");

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

    void write(wstring text, int[2] p, uint fg, uint bg, bool save = true)
    {
        import std.array;

        if(p[1] >= rows) return;
        auto x = p[0] + p[1] * cols;
        auto ex = (p[1]+1) * cols;

        if(save) {
            foreach(c ; text) {
                if(x >= ex) break;
                buffer[x++] = Cell(c, fg, bg);
            }
        }

        auto fw = font.size.x;
        auto fh = font.size.y;
        auto w = screenTexture.width;
        auto h = screenTexture.height;
        vec2f pos = [p[0]*fw - w*0.5, -(p[1]*fh + fh - h*0.5)];
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
