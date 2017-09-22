module diesel.gl.font;

import diesel.gl.core;

import diesel.gl.texture;
import diesel.gl.buffer;
import diesel.gl.program;
import diesel.vec;
import std.stdio;
version(trace) import diesel.minitrace;
import std.conv : to;

class Font
{
    import std.typecons : Tuple;
    import diesel.font : TTFFont = Font;

    struct TextObject
    {
        uint offset;
        int size;
        uint fg;
        uint bg;
        float[2] pos;
    }

    alias Vert = vec2f;
    alias UV = vec2f;

    alias UV4 = UV[4];
    UV4[uint] indexMap;

    vec2u size = [10,20];
    vec2u nextPos;

    TTFFont font;

    alias PIXEL = ubyte;

    Bitmap!PIXEL bitmap;
    Texture texture;
    Buffer!float[1] buffer;
    static Buffer!ushort indexBuffer;

    // An 8x8 font on a 4k monitor be around 500 chars long;
    static const int maxLen = 1600;
    int currentBuf = 0;
    bool textureDirty = false;

    static const bool doOneUpload = true;
    UV[128*1024*4] uvBuffer;
    uint ulOffs;


    static const bool doDeferred = true;
    TextObject[][2] texts;

    // Dumb cache
    UV size_x0;
    UV size_0y;
    UV size_xy;

    Program textProg;

    auto vertexShader =
    q{
        attribute vec2 in_pos;
        attribute vec2 in_uv;
		uniform vec2 font_size;
        uniform vec2 screen_scale;
        uniform vec2 xypos;
        uniform vec2 tex_scale;
        varying vec2 out_uv;
        void main() {
            gl_Position = vec4((in_pos + xypos) * screen_scale, 0, 1);
            out_uv = in_uv * tex_scale;
        }
    };

    auto pixelShader =
    q{
        uniform sampler2D in_tex;
        varying vec2 out_uv;
        uniform vec4 fgColor;
        uniform vec4 bgColor;
        void main() {
            float a = texture2D(in_tex, out_uv).a;
           // if(bgColor == vec4(0,0,0,0))
           //     gl_FragColor = vec4(fgColor.rgb, a);
           // else
                gl_FragColor = vec4(fgColor.rgb * a +
                    bgColor.rgb * (1.0 - a), 1.0);
        }
    };

    this(const ubyte* ptr, size_t length, int size = -1,
        int[2] pixsize = [-1,-1], bool mono = false)
    {
        this(new TTFFont(ptr, length, size, mono), pixsize);
    }

    this(string name, float scale = 1.0, int[2] pixsize = [-1,-1],
        bool mono = false)
    {
        this(new TTFFont(name, scale, mono), pixsize);
    }

    this(TTFFont font, int[2] pixsize = [-1,-1])
    {
        this.font = font;
        bitmap = Bitmap!PIXEL(1024,1024);
        if(!indexBuffer)
            setupIndexBuffer();
        size = [font.width, font.height];
        if(pixsize[0] != -1)
            size[0] = pixsize[0];
        if(pixsize[1] != -1)
            size[1] = pixsize[1];
        init();
    }


    Font dup()
    {
        auto f = font.dup;
        return new Font(f, [size[0], size[1]]);
    }

    void init()
    {
        indexMap.clear();
        bitmap.clear();
        nextPos = [0,0];

        auto sz = cast(vec2f)size;
        static if(is(UV == float)) {
            size_xy = pack!UV(sz.xy);
            size_x0 = pack!UV(sz.x0);
            size_0y = pack!UV(sz.Oy);
        } else {
            size_xy = sz.xy;
            size_x0 = sz.x0;
            size_0y = sz.Oy;
        }

        for(wchar c = 0x20; c <= 0x7e; c++)
            cacheLetter(c);
        texture = Texture(bitmap, GL_ALPHA);
        textProg = Program(vertexShader, pixelShader);
        setup();
        textProg.use();
        vec2f ts = vec2f(1,1) / vec2f(bitmap.width, bitmap.height);
        textProg.setUniform("tex_scale", ts);
    }

    void setSize(int size)
    {
        font.setSize(size);
        this.size = [ font.width, font.height ];
        init();
    }

    bool cacheLetter(dchar c)
    {
        if(c in indexMap)
            return false;
        font.renderChar(c, bitmap.pixels[nextPos.x+nextPos.y*bitmap.width..$],
            bitmap.width, size.x, size.y);

        auto t = cast(vec2f)nextPos;
        indexMap[c] = [t, t + size_x0, t + size_0y, t + size_xy];

        nextPos.x += (size.x + 1);
        if(nextPos.x + size.x > bitmap.width) {
            nextPos.x = 0;
            nextPos.y += (size.y + 1);
        }

        return true;
    }


    private static ushort U(int l) { return cast(ushort)l; }

    void setup()
    {
        version(trace) auto _st = ScopedTrace();

        int i = 0;
        vec2f pos = [0,0];
        auto sz = cast(vec2f)size;

        vec2f[maxLen*4] verts;

        // Quad vertices
        foreach(_ ; 0 .. maxLen) {
            verts[i++] = pos + sz.Oy;
            verts[i++] = pos + sz.xy;
            verts[i++] = pos;
            verts[i++] = pos + sz.xO;
            pos += sz.xO;
        }

        foreach(ref b ; buffer) {
            b = Buffer!float(4*256*1024, GL_ARRAY_BUFFER, GL_DYNAMIC_DRAW);
            b.upload(0, cast(float*)verts.ptr, maxLen*4);
        }
        //verts.ptr, verts.length, GL_ARRAY_BUFFER, GL_STREAM_DRAW);
    }

    static void setupIndexBuffer()
    {
        ushort[maxLen * 6] indexes;
        int i = 0;
        ushort n = 0;
        // Indices
        foreach(_ ; 0 .. maxLen) {
            indexes[i .. i+6] = [U(n), U(n+1), U(n+2), U(n+1), U(n+3), U(n+2)];
            i += 6;
            n += 4;
        }
        indexBuffer = Buffer!ushort(indexes, GL_ELEMENT_ARRAY_BUFFER);

    }

    uint currentOffset = maxLen * 4;


    void buildBuffer(wstring text, uint offs)
    {
        version(trace) auto _st = ScopedTrace();
        int i = 0;
        // Quad UVs
		if(text.length >= maxLen) {
            // TODO: Better handling
			import std.stdio;
			writeln("TEXT ", text, " too long!");
			return;
		}
        if(doOneUpload) {
            foreach(c ; text) {
                auto t = indexMap[c];
                //uvBuffer[ulOffs .. ulOffs + 4] = indexMap[c];
                //ulOffs += 4;
                uvBuffer[ulOffs++] = t[0];
                uvBuffer[ulOffs++] = t[1];
                uvBuffer[ulOffs++] = t[2];
                uvBuffer[ulOffs++] = t[3];
            }
        } else {
            UV[maxLen * 4] temp;
            foreach(c ; text) {
                temp[i .. i + 4] = indexMap[c];
                i+= 4;
            }
            {
                version(trace) auto _st2 = ScopedTrace(__FILE__, "uploadBuffer");
                buffer[currentBuf].upload(offs, cast(float*)temp.ptr,
                    text.length * 4 * UV.sizeof / float.sizeof);
            }
        }

    }

    void startTexts()
    {
        currentOffset = maxLen * 4 * Vert.sizeof / float.sizeof;
        texture.bind();
        textProg.use();
        buffer[currentBuf].bind();
        indexBuffer.bind();
        auto screenSize = diesel.gl.core.viewPort;
        vec2f ss = vec2f(2,2) / cast(vec2f)screenSize;
        textProg.setUniform("screen_scale", ss);
        textProg.setUniform("font_size", cast(vec2f)size);
        texts[currentBuf].length = 0;
        ulOffs = 0;
    }

    void endTexts()
    {
        if(doOneUpload)
        {
            version(trace) auto _st2 = ScopedTrace(__FILE__, "uploadBuffer");
            buffer[currentBuf].upload(maxLen * 4 * Vert.sizeof / float.sizeof,
                cast(float*)uvBuffer.ptr, ulOffs * UV.sizeof / float.sizeof);
            if(buffer.length > 1)
                currentBuf ^= 1;
        }
        if(doDeferred) {
            updateTexture();
            texture.bind();
            textProg.use();
            buffer[currentBuf].bind();
            indexBuffer.bind();
            textProg.vertexAttribPointer("in_pos", Vert.sizeof / float.sizeof,
                GL_FLOAT, GL_FALSE, 0, 0);
            foreach(t ; texts[currentBuf])
                renderText(t);
        }
    }

    void updateTexture()
    {
        if(textureDirty) {
            texture.update(bitmap);
            textureDirty = false;
        }
    }
    // Generate a Vertex Buffer containing screen space coordinates
    TextObject makeText(wstring text, float[2] pos, uint fg, uint bg)
    {
        version(trace) auto _st = ScopedTrace();
        foreach(c ; text)
            textureDirty |= cacheLetter(c);
        buildBuffer(text, currentOffset);

        TextObject o;
        o.pos = pos;
        o.fg = fg;
        o.bg = bg;
        o.offset = currentOffset;
        o.size = cast(int)text.length;
        currentOffset += (text.length*4*UV.sizeof/float.sizeof);
        return o;
    }

    void renderText(TextObject obj)
    {
        version(trace) auto _st = ScopedTrace();

        textProg.setUniform("xypos", obj.pos);
        textProg.setUniform("fgColor", vec4f(obj.fg));
        textProg.setUniform("bgColor", vec4f(obj.bg));

        textProg.vertexAttribPointer("in_uv", UV.sizeof / float.sizeof,
            GL_FLOAT, GL_FALSE, 0, cast(uint)(obj.offset * 4));
        glDrawElements(GL_TRIANGLES, 6*obj.size, GL_UNSIGNED_SHORT, cast(void*)0);
    }

    void renderText(wstring text, float[2] pos, uint fg, uint bg)
    {
        if(doDeferred)
            texts[currentBuf] ~= makeText(text, pos, fg, bg);
        else {
            auto tobj = makeText(text, pos, fg, bg);
            updateTexture();
            renderText(tobj);
        }
    }


}

