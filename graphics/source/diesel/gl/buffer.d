module diesel.gl.buffer;

import diesel.gl.core;
import std.typecons : RefCounted;

import std.stdio;

struct Buffer(T = float)
{
    struct BufRef {
        GLuint id = UNSET;
        ~this() { if(id != UNSET) glDeleteBuffers(1, &id); }
    }
    RefCounted!BufRef bufRef;
    GLuint bufType;

    this(S)(S* data, size_t length, GLuint bt = GL_ARRAY_BUFFER, GLuint usage = GL_STATIC_DRAW) {
        this.bufType = bt;
        check!glGenBuffers(1, &bufRef.id);
        check!glBindBuffer(bufType, bufRef.id);
        check!glBufferData(bufType, length * S.sizeof, cast(T*)data, usage);
    }

    this(T[] data, GLuint bt = GL_ARRAY_BUFFER, GLuint usage = GL_STATIC_DRAW) {
        this.bufType = bt;
        check!glGenBuffers(1, &bufRef.id);
        check!glBindBuffer(bufType, bufRef.id);
        check!glBufferData(bufType, data.length * T.sizeof, data.ptr, usage);
    }

    this(size_t size, GLuint bt = GL_ARRAY_BUFFER, GLuint usage = GL_STATIC_DRAW) {
        this.bufType = bt;
        check!glGenBuffers(1, &bufRef.id);
        check!glBindBuffer(bufType, bufRef.id);
        check!glBufferData(bufType, size * T.sizeof, null, usage);
    }

    void bind() {
        check!glBindBuffer(bufType, bufRef.id);
    }

    void upload(size_t offset, T[] data, size_t length = 0)
    {
        if(length == 0)
            length = data.length;
        check!glBindBuffer(bufType, bufRef.id);
        check!glBufferSubData(bufType, offset * T.sizeof, length * T.sizeof, data.ptr);
    }

    void upload(S)(size_t offset, S* data, size_t length)
    {
        check!glBindBuffer(bufType, bufRef.id);
        check!glBufferSubData(bufType, offset * S.sizeof, length * S.sizeof, cast(T*)data);
    }

    bool opCast(T)() if(is(T == bool)) {
        return bufRef.id != UNSET;
    }

/*
    void vertexAttribPointer(GLuint h, GLuint offset = 0, GLsizei stride = 0)
    {
        uint n = T.sizeof;
        check!glVertexAttribPointer(h, T.length, GL_FLOAT, GL_FALSE, stride * n, cast(void*)(offset * n));
        check!glEnableVertexAttribArray(h);
    }
*/
}

