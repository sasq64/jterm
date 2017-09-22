# Code Overview

## _TermApp_

The main application.
Handles all the split panes using a _layout_ system.
Owns the `Window`. Reads keys and renders `Terminal`s inside split panes.

## _Terminal_

The top level terminal class. Has a `Console` for rendering and a `TerminalSession` for
running the shell.

## _Console_

Holds a font and a rendertarget, and renders text. Also renders cursor and current selection.


## _TerminalSession_

Normally runs in a separate thread. Reads stdout from the shell and sends it to the `AnsiScreenParser`.
Receives key and mouse data from the Terminal and sends it to stdin.
Gets all changes from `TextScreen` and sends them back to the `Terminal`


## _AnsiScreenParser_

Parses all incoming bytes according to VT102, Xterm etc protocols. Writes all modifications to a `TextScreen`.


## _TextScreen_

Holds a 2D array of characters with attributes, and has methods for manipulating that text.
Compares to a secondary buffer to generate a list of changes that can be used for rendering.


## _Window_

The system specific window class that sets up the GL context and provides keyboard and mouse events.

