# Jterm

A Terminal Emulator written in D, using OpenGL ES 2.0 as a rendering back end.

Works on Linux, OSX, Raspberry PI

[![YOUTUBE LINK](http://img.youtube.com/vi/UYLuln2GpEo/0.jpg)](http://www.youtube.com/watch?v=UYLuln2GpEo)

## Building

Make sure you have _LDC_ (The LLVM D Compiler), _Dub_ (The D build tool),
_fontconfig_, _liblua_ and the _SDL2_ library installed.

OSX :`brew install ldc dub sdl2 lua@5.3 fontconfig`
Linux : `sudo apt install ldc dub libsdl2-2.0.0 fontconfig`

Then:

```
cd term
make
cp misc/startup.lua .
./jterm
```

## Command Line Options

* `--font=<fontspec>`
* `--fullscreen`

## Key Bindings

* Meta-S = Split vertically
* Meta-A = Split horizontally
* Meta-W = Close split
* Meta-Z = Toggle zoom
* Meta-P = Increase font size
* Meta-O = Decrease font size
* Meta-V = Paste
* Meta-Right/Left/Up/Down = Switch split

* Mouse Wheel = Scroll
* Left mouse = Select and auto copy

