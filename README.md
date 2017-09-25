# Jterm

A Terminal Emulator written in D, using OpenGL ES 2.0 as a rendering back end.

Works on Linux, OSX, Raspberry PI

## Building

Make sure you have _LDC_ (The LLVM D Compiler), _Dub_ (The D build tool),
_libfontconfig_, _liblua_ and the _SDL2_ library installed. Then just `make`.

OSX :`brew install ldc dub sdl2 lua@5.3 fontconfig`
Linux : `sudo apt install ldc dub libsdl2-2.0.0`

Then to start:

```
cd term
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
* Meta-O = Decreas font size
* Meta-V = Paste
* Meta-Right/Left/Up/Down = Switch split

* Mouse Wheel = Scroll
* Left mouse = Select and auto copy

