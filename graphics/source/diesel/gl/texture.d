module diesel.gl.texture;

import diesel.gl.core;

import std.string : toz = toStringz;
import std.typecons : RefCounted;

enum Filter { Nearest, Bilinear };
struct Texture
{
    union {
        struct {
            int width;
            int height;
        }
        int[2] size;
    }

    float[2] sizef() { return [ cast(float)width, cast(float)height ]; }

    int targetFormat;

    struct TexRef {
        GLuint id = UNSET;
        ~this() { if(id != UNSET) check!glDeleteTextures(1, &id); }
    }
    RefCounted!TexRef texRef;

    struct FBRef {
        GLuint id = UNSET;
        ~this() { if(id != UNSET) check!glDeleteFramebuffers(1, &id); }
    }
    RefCounted!FBRef fbRef;

    void clear() {
        bind();
        glClear(GL_COLOR_BUFFER_BIT);
    }

    const static enum uint[5] translate = [0, GL_ALPHA, 0, GL_RGB, GL_RGBA];
    import std.stdio;

    bool opCast(T)() if(is(T == bool)) {
        return texRef.id != UNSET;
    }

    this(T)(int w, int h, T* data, int targetFormat = GL_RGBA, int sourceFormat = -1) {
        this.width = w;
        this.height = h;
        this.targetFormat = targetFormat;
        if(sourceFormat == -1) sourceFormat = translate[T.sizeof];

        check!glGenTextures(1, &texRef.id);
        check!glBindTexture(GL_TEXTURE_2D, texRef.id);
        check!glTexImage2D(GL_TEXTURE_2D, 0, targetFormat, w, h, 0, sourceFormat,
                GL_UNSIGNED_BYTE, data);
        check!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        check!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        check!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        check!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        /* check!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT); */
        /* check!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT); */
    }


    @property void filter(Filter f) {
        check!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, f == Filter.Nearest ? GL_NEAREST : GL_LINEAR);
        check!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, f == Filter.Nearest ? GL_NEAREST : GL_LINEAR);
    }

    this(int w, int h, int targetFormat = GL_RGBA) {
        this(w, h, cast(uint*)null, targetFormat);

        check!glGenFramebuffers(1, &fbRef.id);
        check!glBindFramebuffer(GL_FRAMEBUFFER, fbRef.id);
        check!glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texRef.id, 0);
    }


    this(BITMAP)(BITMAP bm, int targetFormat = GL_RGBA) {
        this(bm.width, bm.height, bm.pixels.ptr, targetFormat);
    }
/*
    void update(void *data) {
        bind();
        check!glTexImage2D(GL_TEXTURE_2D, 0, targetFormat, width, height, 0, GL_RGBA,
                GL_UNSIGNED_BYTE, data);
    }
*/
    void update(BITMAP)(BITMAP bm) {
        bind();
        int sourceFormat = translate[bm.pixels.ptr[0].sizeof];
        assert(width == bm.width);
        assert(height == bm.height);
        check!glTexImage2D(GL_TEXTURE_2D, 0, targetFormat, bm.width, bm.height, 0, sourceFormat,
                GL_UNSIGNED_BYTE, bm.pixels.ptr);
    }

    void bind() {
        check!glBindTexture(GL_TEXTURE_2D, texRef.id);
    }

    void setTarget() {
        check!glBindFramebuffer(GL_FRAMEBUFFER, fbRef.id);
	    setViewPort([width,height]);
    }

    uint[] getPixels()
    {
        auto data = new uint[width * height];
        bind();
        // TODO: Need _actual_ size of texture
        glReadPixels(0, 0, width, height, targetFormat, GL_UNSIGNED_BYTE, data.ptr);
        return data;
    }
}

