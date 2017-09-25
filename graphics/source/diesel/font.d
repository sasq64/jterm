module diesel.font;

import std.stdio;
import std.string : toz = toStringz;
import std.conv;

import fontconfig.fontconfig;
import derelict.freetype.ft;

// Fontconfig helpers

T PatternGet(T)(FcPattern *p, const char *object, int n) {
    T t;
    FcResult result;
    static if(is(T == string)) {
        FcChar8* str = null;
        result = FcPatternGetString(p, object, n, &str);
        t = to!string(str);
    } else static if(is(T == int))
        result = FcPatternGetInteger(p, object, n, &t);
    else static if(is(T == double))
        result = FcPatternGetDouble(p, object, n, &t);

    if(result != FcResult.FcResultMatch)
        throw new Exception("Bad format:");

    return t;
}

class ft_exception : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

auto check(alias FN, string FILE = __FILE__, int LINE = __LINE__, ARGS ...)(ARGS args) {
    import std.format : format;
    scope(exit) {
        FT_Error e = FN(args);
        if(e != 0) throw new ft_exception(format("%s() : FT Error 0x%x",
            __traits(identifier, FN), e), FILE, LINE);
    }
    return FN(args);
}

class Font
{
    FontSet font;
    int pixelSize;
    union {
        struct {
            int width;
            int height;
        }
        int[2] size;
    }


    void renderChar(T)(dchar c, T[] target, int stride, int width = 0, int height = 0)
    {
        font.renderChar(pixelSize, c, target, stride, width, height);
    }


    this() {}

    this(string name, float scale = 1.0, bool mono = false)
    {
        font = new FontSet(name, scale, mono);
        this.pixelSize = font.size;
        this.size = font.getActualSize();
    }

    this(const ubyte* ptr, size_t length, int size = -1, bool mono = false)
    {
        font = new FontSet(ptr, length, size, mono);
        this.pixelSize = font.size;
        this.size = font.getActualSize();
    }

    void setSize(int psz)
    {
        pixelSize = psz;
        size = font.getActualSize(psz);
    }

    Font dup()
    {
        auto f = new Font();
        f.font = font;
        f.size = size;
        f.pixelSize = pixelSize;
        return f;
    }

    alias font this;
}


class FontSet
{

    FT_Library flib;
    FT_Face[] face;
    FT_Face currentFace;
    int size; // Original size
    bool mono;

    // FT_Size for each pixelSize
    FT_Size[int][4] sizeList;

    this() {}

    FcPattern* fontPattern;

    // Create face list from fontconfig spec
    void fromConfig(string fontSpec, float scale = 1.0f)
    {
        auto config = FcInitLoadConfigAndFonts();
        fontPattern = FcNameParse(cast(const FcChar8*)toz(fontSpec));
        FcPatternAddInteger(fontPattern, FC_SPACING, FC_MONO);
        FcPatternPrint(fontPattern);

        FcDefaultSubstitute(fontPattern);
        FcPatternPrint(fontPattern);
		int primary = -1;
		int secondary = -1;

        FcResult result;
        auto fset = FcFontSort(config, fontPattern, FcFalse, null, &result);
        int curf = 0;
        for (curf = 0; curf < fset.nfont; ++curf) {
		    auto curp = fset.fonts[curf];
            int spacing = 0;
            try {
                spacing = PatternGet!int(curp, FC_SPACING, 0);
            } catch(Exception e) {}
            if(spacing != 100)
                continue;
			if(primary == -1)
				primary = curf;
            auto fontName = PatternGet!string(curp, FC_FILE, 0);
            auto name = to!string(fontName);
            writeln(name);
            FcCharSet* charset;
            result = FcPatternGetCharSet(curp, FC_CHARSET, 0, &charset);
		    if (result != FcResult.FcResultMatch)
			    continue;
		    if (FcCharSetHasChar(charset, 0x2663) && FcCharSetHasChar(charset, 0x276f)) {
				secondary = curf;
				break;
			}
        }

        face = new FT_Face[2];
        auto rpat = FcFontRenderPrepare(config, fontPattern, fset.fonts[primary]);
        FcPatternPrint(rpat);
        auto fontName = PatternGet!string(rpat, FC_FILE, 0);
        check!FT_New_Face(flib, toz(fontName), 0, &face[0]);
        this.size = cast(int)(PatternGet!double(rpat, FC_SIZE, 0) * scale);

        rpat = FcFontRenderPrepare(config, fontPattern, fset.fonts[secondary]);
        FcPatternPrint(rpat);
        fontName = PatternGet!string(rpat, FC_FILE, 0);
        check!FT_New_Face(flib, toz(fontName), 0, &face[1]);
    }


    FT_Size getSize(int pixelSize, int index)
    {
        if(!(pixelSize in sizeList[index])) {
            FT_Size fts;
            check!FT_New_Size(face[index], &fts);
            check!FT_Activate_Size(fts);
            check!FT_Set_Pixel_Sizes(face[index], pixelSize, 0);
            sizeList[index][pixelSize] = fts;
        }
        check!FT_Activate_Size(sizeList[index][pixelSize]);
        return sizeList[index][pixelSize];
    }

    int[2] getActualSize(int pixelSize = -1)
    {
        if(pixelSize == -1) pixelSize = size;

        auto fs = getSize(pixelSize, 0);
        if(FT_Load_Char(face[0], 'X', FT_LOAD_NO_BITMAP) != 0)
            return [-1, -1];
        auto m = face[0].size.metrics;
        auto m2 = face[0].glyph.metrics;
        return [cast(int)(m2.horiAdvance >> 6), cast(int)(m.height >> 6)];
    }


    this(string name, float scale = 1.0, bool mono = false)
    {
        this.mono = mono;
        DerelictFT.load();
        check!FT_Init_FreeType(&flib);
        fromConfig(name, scale);
    }

    this(const ubyte* ptr, size_t length, int size = -1, bool mono = false)
    {
        this.mono = mono;
        this.size = size;
        DerelictFT.load();
        check!FT_Init_FreeType(&flib);
        check!FT_New_Memory_Face(flib, ptr, length, 0, &face[0]);
    }

    void renderChar(T)(int pixelSize, dchar c, T[] target, int stride, int width = 0, int height = 0)
    {
        int index = -1;
        foreach(int i, f ; face) {
            if(FT_Get_Char_Index(f, c) != 0) {
                index = i;
                break;
            }
        }

        if(index == -1)
            return;
        currentFace = face[index];

        auto fts = getSize(pixelSize, index);
        check!FT_Activate_Size(fts);
        renderChar(c, target, stride, width, height);
    }

    void renderChar(T)(dchar c, T[] target, int stride, int width = 0, int height = 0)
    {
        if(FT_Load_Char(currentFace, c, FT_LOAD_RENDER | (mono ? FT_LOAD_MONOCHROME : 0)) != 0) {
            writefln("Char %x not found in font", c);
            return;
        }
        auto b = currentFace.glyph.bitmap;

        auto delta = currentFace.size.metrics.ascender / 64;

        auto xoffs = currentFace.glyph.bitmap_left ;
        auto yoffs = delta - currentFace.glyph.bitmap_top;

        //writefln("%d x %d (%d,%d)", b.width, b.rows, face.glyph.bitmap_left, face.glyph.bitmap_top);
        ubyte* data = b.buffer;
        for(int y=0; y<b.rows; y++) {
            for(int x=0; x<b.width; x++) {
                int pitch = b.pitch;
                ubyte *row = &data[pitch * y];
                ubyte alpha = mono ? ((row[x>>3] & (128 >> (x & 7))) ? 0xff : 0) :
                                      data[x + y * b.pitch];
                if(x+xoffs < 0 || y+yoffs < 0)
                    continue;
                if(width > 0 && x + xoffs > width)
                    continue;
                if(height > 0 && y + yoffs > height)
                    continue;
                auto offset = (x+xoffs) + (y+yoffs)*stride;
                // TODO: Make sure this does not crash
                static if(is(T == ubyte))
                    target[offset] = alpha;
                else
                    target[offset] = alpha << 24 | alpha << 16 | alpha << 8 | alpha;
            }
        }
    }
}
