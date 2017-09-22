module diesel.font;

import std.stdio;
import std.string : toz = toStringz;
import std.conv;

import fontconfig.fontconfig;


T PatternGet(T)(FcPattern *p, const char *object, int n) {
    T t;
    FcResult result;
    static if(is(T == string)) {
        FcChar8* str = null;
        result = FcPatternGetString(p, object, n, &str);
        t = to!string(str);
    } else static if(is(T == int))
        result = FcPatternGetInt(p, object, n, &t);
    else static if(is(T == double))
        result = FcPatternGetDouble(p, object, n, &t);

    if(result != FcResult.FcResultMatch)
        throw new Exception("Bad format:");

    return t;
}

class Font
{
    import derelict.freetype.ft;

    FT_Library flib;
    FT_Face face;
    FT_Size ftSize;

    int width;
    int height;
    int size;
    bool mono;

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

    Font dup() {
        Font f = new Font;
        f.flib = flib;
        f.mono = mono;
        f.face = face;
        f.ftSize = ftSize;
        check!FT_New_Size(f.face, &f.ftSize);
        f.setSize(size);
        //writeln("DUP SIZE ", size);
        return f;
    }


    void setSize(int size)
    {
        this.size = size;
        //writeln("SET SIZE ", size);
        check!FT_Activate_Size(ftSize);
        check!FT_Set_Pixel_Sizes(face, size, 0);
        if(FT_Load_Char(face, 'X', FT_LOAD_NO_BITMAP) != 0)
            return;
        auto m = face.size.metrics;
        auto m2 = face.glyph.metrics;
        //writefln("%d %d %d", m2.horiAdvance, m2.width, m.max_advance);
        width = cast(int)(m2.horiAdvance >> 6);
        height = cast(int)(m.height >> 6);
    }

    this() {}

    FcPattern* fontPattern;

    void fromConfig(string fontSpec)
    {
        auto fpattern = toz(fontSpec);

        //if(!FcInit())
        //  throw new Exception("Can't init font config library");
        auto config = FcInitLoadConfigAndFonts();
        //writeln(config);
        //make pattern from font name
        //auto pat = FcNameParse(cast(const FcChar8*)"Hack");
        fontPattern = FcNameParse(cast(const FcChar8*)fpattern);
        //FcPatternPrint(fontPattern);
        FcConfigSubstitute(config, fontPattern, FcMatchKind.FcMatchPattern);
        //FcPatternPrint(fontPattern);
        //FcPatternAddString(fontPattern, FC_STYLE, "Bold");
        FcPatternAddInteger(fontPattern, FC_SPACING, FC_MONO);
        FcDefaultSubstitute(fontPattern);
        //FcPatternPrint(fontPattern);
        FcResult result;



        fontPattern = FcFontMatch(config, fontPattern, &result);
    }

    this(string name, float scale = 1.0, bool mono = false)
    {
        fromConfig(name);
        auto fontName = PatternGet!string(fontPattern, FC_FILE, 0);
        this.size = cast(int)(PatternGet!double(fontPattern, FC_SIZE, 0) * scale);
        this.mono = mono;
        writeln(fontName, ",", this,size);
        DerelictFT.load();
        check!FT_Init_FreeType(&flib);
        check!FT_New_Face(flib, toz(fontName), 0, &face);
        check!FT_New_Size(face, &ftSize);
        setSize(this.size);
    }

    this(const ubyte* ptr, size_t length, int size = -1, bool mono = false)
    {
        this.mono = mono;
        this.size = size;
        DerelictFT.load();
        check!FT_Init_FreeType(&flib);
        check!FT_New_Memory_Face(flib, ptr, length, 0, &face);
        check!FT_New_Size(face, &ftSize);
        setSize(size);
    }

    void renderChar(T)(dchar c, T[] target, int stride, int width = 0, int height = 0)
    {
        check!FT_Activate_Size(ftSize);
        if(FT_Load_Char(face, c, FT_LOAD_RENDER | (mono ? FT_LOAD_MONOCHROME : 0)) != 0)
            return;
        auto b = face.glyph.bitmap;

        auto delta = face.size.metrics.ascender / 64;

        auto xoffs = face.glyph.bitmap_left ;
        auto yoffs = delta - face.glyph.bitmap_top;

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

    /* private void check(FT_Error e, string file = __FILE__, uint line = __LINE__) { */
    /*     if(e) throw new Exception("FT", file, line); */
    /* } */
}
