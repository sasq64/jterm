/* Converted to D from input-event-codes.h by htod */
module diesel.linux.input_event_codes;
/*
 * Input event codes
 *
 *    *** IMPORTANT ***
 * This file is not only included from C-code but also from devicetree source
 * files. As such this file MUST only contain comments and defines.
 *
 * Copyright (c) 1999-2002 Vojtech Pavlik
 * Copyright (c) 2015 Hans de Goede <hdegoede@redhat.com>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 as published by
 * the Free Software Foundation.
 */

/*
 * Device properties and quirks
 */

const INPUT_PROP_POINTER = 0x00;
const INPUT_PROP_DIRECT = 0x01;
const INPUT_PROP_BUTTONPAD = 0x02;
const INPUT_PROP_SEMI_MT = 0x03;
const INPUT_PROP_TOPBUTTONPAD = 0x04;
const INPUT_PROP_POINTING_STICK = 0x05;

const INPUT_PROP_ACCELEROMETER = 0x06;
const INPUT_PROP_MAX = 0x1f;

/*
 * Event types
 */

const EV_SYN = 0x00;
const EV_KEY = 0x01;
const EV_REL = 0x02;
const EV_ABS = 0x03;
const EV_MSC = 0x04;
const EV_SW = 0x05;
const EV_LED = 0x11;
const EV_SND = 0x12;
const EV_REP = 0x14;
const EV_FF = 0x15;
const EV_PWR = 0x16;
const EV_FF_STATUS = 0x17;
const EV_MAX = 0x1f;

/*
 * Synchronization events.
 */

const SYN_REPORT = 0;
const SYN_CONFIG = 1;
const SYN_MT_REPORT = 2;
const SYN_DROPPED = 3;
const SYN_MAX = 0xf;

/*
 * Keys and buttons
 *
 * Most of the keys/buttons are modeled after USB HUT 1.12
 * (see http://www.usb.org/developers/hidpage).
 * Abbreviations in the comments:
 * AC - Application Control
 * AL - Application Launch Button
 * SC - System Control
 */

const KEY_RESERVED = 0;
const KEY_ESC = 1;
const KEY_1 = 2;
const KEY_2 = 3;
const KEY_3 = 4;
const KEY_4 = 5;
const KEY_5 = 6;
const KEY_6 = 7;
const KEY_7 = 8;
const KEY_8 = 9;
const KEY_9 = 10;
const KEY_0 = 11;
const KEY_MINUS = 12;
const KEY_EQUAL = 13;
const KEY_BACKSPACE = 14;
const KEY_TAB = 15;
const KEY_Q = 16;
const KEY_W = 17;
const KEY_E = 18;
const KEY_R = 19;
const KEY_T = 20;
const KEY_Y = 21;
const KEY_U = 22;
const KEY_I = 23;
const KEY_O = 24;
const KEY_P = 25;
const KEY_LEFTBRACE = 26;
const KEY_RIGHTBRACE = 27;
const KEY_ENTER = 28;
const KEY_LEFTCTRL = 29;
const KEY_A = 30;
const KEY_S = 31;
const KEY_D = 32;
const KEY_F = 33;
const KEY_G = 34;
const KEY_H = 35;
const KEY_J = 36;
const KEY_K = 37;
const KEY_L = 38;
const KEY_SEMICOLON = 39;
const KEY_APOSTROPHE = 40;
const KEY_GRAVE = 41;
const KEY_LEFTSHIFT = 42;
const KEY_BACKSLASH = 43;
const KEY_Z = 44;
const KEY_X = 45;
const KEY_C = 46;
const KEY_V = 47;
const KEY_B = 48;
const KEY_N = 49;
const KEY_M = 50;
const KEY_COMMA = 51;
const KEY_DOT = 52;
const KEY_SLASH = 53;
const KEY_RIGHTSHIFT = 54;
const KEY_KPASTERISK = 55;
const KEY_LEFTALT = 56;
const KEY_SPACE = 57;
const KEY_CAPSLOCK = 58;
const KEY_F1 = 59;
const KEY_F2 = 60;
const KEY_F3 = 61;
const KEY_F4 = 62;
const KEY_F5 = 63;
const KEY_F6 = 64;
const KEY_F7 = 65;
const KEY_F8 = 66;
const KEY_F9 = 67;
const KEY_F10 = 68;
const KEY_NUMLOCK = 69;
const KEY_SCROLLLOCK = 70;
const KEY_KP7 = 71;
const KEY_KP8 = 72;
const KEY_KP9 = 73;
const KEY_KPMINUS = 74;
const KEY_KP4 = 75;
const KEY_KP5 = 76;
const KEY_KP6 = 77;
const KEY_KPPLUS = 78;
const KEY_KP1 = 79;
const KEY_KP2 = 80;
const KEY_KP3 = 81;
const KEY_KP0 = 82;

const KEY_KPDOT = 83;
const KEY_ZENKAKUHANKAKU = 85;
const KEY_102ND = 86;
const KEY_F11 = 87;
const KEY_F12 = 88;
const KEY_RO = 89;
const KEY_KATAKANA = 90;
const KEY_HIRAGANA = 91;
const KEY_HENKAN = 92;
const KEY_KATAKANAHIRAGANA = 93;
const KEY_MUHENKAN = 94;
const KEY_KPJPCOMMA = 95;
const KEY_KPENTER = 96;
const KEY_RIGHTCTRL = 97;
const KEY_KPSLASH = 98;
const KEY_SYSRQ = 99;
const KEY_RIGHTALT = 100;
const KEY_LINEFEED = 101;
const KEY_HOME = 102;
const KEY_UP = 103;
const KEY_PAGEUP = 104;
const KEY_LEFT = 105;
const KEY_RIGHT = 106;
const KEY_END = 107;
const KEY_DOWN = 108;
const KEY_PAGEDOWN = 109;
const KEY_INSERT = 110;
const KEY_DELETE = 111;
const KEY_MACRO = 112;
const KEY_MUTE = 113;
const KEY_VOLUMEDOWN = 114;
const KEY_VOLUMEUP = 115;
const KEY_POWER = 116;
const KEY_KPEQUAL = 117;
const KEY_KPPLUSMINUS = 118;
const KEY_PAUSE = 119;

const KEY_SCALE = 120;
const KEY_KPCOMMA = 121;
const KEY_HANGEUL = 122;
alias KEY_HANGEUL KEY_HANGUEL;
const KEY_HANJA = 123;
const KEY_YEN = 124;
const KEY_LEFTMETA = 125;
const KEY_RIGHTMETA = 126;

const KEY_COMPOSE = 127;
const KEY_STOP = 128;
const KEY_AGAIN = 129;
const KEY_PROPS = 130;
const KEY_UNDO = 131;
const KEY_FRONT = 132;
const KEY_COPY = 133;
const KEY_OPEN = 134;
const KEY_PASTE = 135;
const KEY_FIND = 136;
const KEY_CUT = 137;
const KEY_HELP = 138;
const KEY_MENU = 139;
const KEY_CALC = 140;
const KEY_SETUP = 141;
const KEY_SLEEP = 142;
const KEY_WAKEUP = 143;
const KEY_FILE = 144;
const KEY_SENDFILE = 145;
const KEY_DELETEFILE = 146;
const KEY_XFER = 147;
const KEY_PROG1 = 148;
const KEY_PROG2 = 149;
const KEY_WWW = 150;
const KEY_MSDOS = 151;
const KEY_COFFEE = 152;
alias KEY_COFFEE KEY_SCREENLOCK;
const KEY_ROTATE_DISPLAY = 153;
alias KEY_ROTATE_DISPLAY KEY_DIRECTION;
const KEY_CYCLEWINDOWS = 154;
const KEY_MAIL = 155;
const KEY_BOOKMARKS = 156;
const KEY_COMPUTER = 157;
const KEY_BACK = 158;
const KEY_FORWARD = 159;
const KEY_CLOSECD = 160;
const KEY_EJECTCD = 161;
const KEY_EJECTCLOSECD = 162;
const KEY_NEXTSONG = 163;
const KEY_PLAYPAUSE = 164;
const KEY_PREVIOUSSONG = 165;
const KEY_STOPCD = 166;
const KEY_RECORD = 167;
const KEY_REWIND = 168;
const KEY_PHONE = 169;
const KEY_ISO = 170;
const KEY_CONFIG = 171;
const KEY_HOMEPAGE = 172;
const KEY_REFRESH = 173;
const KEY_EXIT = 174;
const KEY_MOVE = 175;
const KEY_EDIT = 176;
const KEY_SCROLLUP = 177;
const KEY_SCROLLDOWN = 178;
const KEY_KPLEFTPAREN = 179;
const KEY_KPRIGHTPAREN = 180;
const KEY_NEW = 181;

const KEY_REDO = 182;
const KEY_F13 = 183;
const KEY_F14 = 184;
const KEY_F15 = 185;
const KEY_F16 = 186;
const KEY_F17 = 187;
const KEY_F18 = 188;
const KEY_F19 = 189;
const KEY_F20 = 190;
const KEY_F21 = 191;
const KEY_F22 = 192;
const KEY_F23 = 193;

const KEY_F24 = 194;
const KEY_PLAYCD = 200;
const KEY_PAUSECD = 201;
const KEY_PROG3 = 202;
const KEY_PROG4 = 203;
const KEY_DASHBOARD = 204;
const KEY_SUSPEND = 205;
const KEY_CLOSE = 206;
const KEY_PLAY = 207;
const KEY_FASTFORWARD = 208;
const KEY_BASSBOOST = 209;
const KEY_PRINT = 210;
const KEY_HP = 211;
const KEY_CAMERA = 212;
const KEY_SOUND = 213;
const KEY_QUESTION = 214;
const KEY_EMAIL = 215;
const KEY_CHAT = 216;
const KEY_SEARCH = 217;
const KEY_CONNECT = 218;
const KEY_FINANCE = 219;
const KEY_SPORT = 220;
const KEY_SHOP = 221;
const KEY_ALTERASE = 222;
const KEY_CANCEL = 223;
const KEY_BRIGHTNESSDOWN = 224;
const KEY_BRIGHTNESSUP = 225;

const KEY_MEDIA = 226;
/* Cycle between available video
					   outputs (Monitor/LCD/TV-out/etc) */
const KEY_SWITCHVIDEOMODE = 227;
const KEY_KBDILLUMTOGGLE = 228;
const KEY_KBDILLUMDOWN = 229;

const KEY_KBDILLUMUP = 230;
const KEY_SEND = 231;
const KEY_REPLY = 232;
const KEY_FORWARDMAIL = 233;
const KEY_SAVE = 234;

const KEY_DOCUMENTS = 235;

const KEY_BATTERY = 236;
const KEY_BLUETOOTH = 237;
const KEY_WLAN = 238;

const KEY_UWB = 239;

const KEY_UNKNOWN = 240;
const KEY_VIDEO_NEXT = 241;
const KEY_VIDEO_PREV = 242;
/* Set Auto Brightness: manual
const KEY_BRIGHTNESS_CYCLE = 243;
					  brightness control is off,
					  rely on ambient */
const KEY_BRIGHTNESS_AUTO = 244;
alias KEY_BRIGHTNESS_AUTO KEY_BRIGHTNESS_ZERO;

const KEY_DISPLAY_OFF = 245;
const KEY_WWAN = 246;
alias KEY_WWAN KEY_WIMAX;

const KEY_RFKILL = 247;

const KEY_MICMUTE = 248;
/* Code 255 is reserved for special needs of AT keyboard driver */

const BTN_MISC = 0x100;
const BTN_0 = 0x100;
const BTN_1 = 0x101;
const BTN_2 = 0x102;
const BTN_3 = 0x103;
const BTN_4 = 0x104;
const BTN_5 = 0x105;
const BTN_6 = 0x106;
const BTN_7 = 0x107;
const BTN_8 = 0x108;

const BTN_9 = 0x109;
const BTN_MOUSE = 0x110;
const BTN_LEFT = 0x110;
const BTN_RIGHT = 0x111;
const BTN_MIDDLE = 0x112;
const BTN_SIDE = 0x113;
const BTN_EXTRA = 0x114;
const BTN_FORWARD = 0x115;
const BTN_BACK = 0x116;

const BTN_TASK = 0x117;
const BTN_JOYSTICK = 0x120;
const BTN_TRIGGER = 0x120;
const BTN_THUMB = 0x121;
const BTN_THUMB2 = 0x122;
const BTN_TOP = 0x123;
const BTN_TOP2 = 0x124;
const BTN_PINKIE = 0x125;
const BTN_BASE = 0x126;
const BTN_BASE2 = 0x127;
const BTN_BASE3 = 0x128;
const BTN_BASE4 = 0x129;
const BTN_BASE5 = 0x12a;
const BTN_BASE6 = 0x12b;

const BTN_DEAD = 0x12f;
const BTN_GAMEPAD = 0x130;
const BTN_SOUTH = 0x130;
alias BTN_SOUTH BTN_A;
const BTN_EAST = 0x131;
alias BTN_EAST BTN_B;
const BTN_C = 0x132;
const BTN_NORTH = 0x133;
alias BTN_NORTH BTN_X;
const BTN_WEST = 0x134;
alias BTN_WEST BTN_Y;
const BTN_Z = 0x135;
const BTN_TL = 0x136;
const BTN_TR = 0x137;
const BTN_TL2 = 0x138;
const BTN_TR2 = 0x139;
const BTN_SELECT = 0x13a;
const BTN_START = 0x13b;
const BTN_MODE = 0x13c;
const BTN_THUMBL = 0x13d;

const BTN_THUMBR = 0x13e;
const BTN_DIGI = 0x140;
const BTN_TOOL_PEN = 0x140;
const BTN_TOOL_RUBBER = 0x141;
const BTN_TOOL_BRUSH = 0x142;
const BTN_TOOL_PENCIL = 0x143;
const BTN_TOOL_AIRBRUSH = 0x144;
const BTN_TOOL_FINGER = 0x145;
const BTN_TOOL_MOUSE = 0x146;
const BTN_TOOL_LENS = 0x147;
const BTN_TOOL_QUINTTAP = 0x148;
const BTN_TOUCH = 0x14a;
const BTN_STYLUS = 0x14b;
const BTN_STYLUS2 = 0x14c;
const BTN_TOOL_DOUBLETAP = 0x14d;
const BTN_TOOL_TRIPLETAP = 0x14e;

const BTN_TOOL_QUADTAP = 0x14f;
const BTN_WHEEL = 0x150;
const BTN_GEAR_DOWN = 0x150;

const BTN_GEAR_UP = 0x151;
const KEY_OK = 0x160;
const KEY_SELECT = 0x161;
const KEY_GOTO = 0x162;
const KEY_CLEAR = 0x163;
const KEY_POWER2 = 0x164;
const KEY_OPTION = 0x165;
const KEY_INFO = 0x166;
const KEY_TIME = 0x167;
const KEY_VENDOR = 0x168;
const KEY_ARCHIVE = 0x169;
const KEY_PROGRAM = 0x16a;
const KEY_CHANNEL = 0x16b;
const KEY_FAVORITES = 0x16c;
const KEY_EPG = 0x16d;
const KEY_PVR = 0x16e;
const KEY_MHP = 0x16f;
const KEY_LANGUAGE = 0x170;
const KEY_TITLE = 0x171;
const KEY_SUBTITLE = 0x172;
const KEY_ANGLE = 0x173;
const KEY_ZOOM = 0x174;
const KEY_MODE = 0x175;
const KEY_KEYBOARD = 0x176;
const KEY_SCREEN = 0x177;
const KEY_PC = 0x178;
const KEY_TV = 0x179;
const KEY_TV2 = 0x17a;
const KEY_VCR = 0x17b;
const KEY_VCR2 = 0x17c;
const KEY_SAT = 0x17d;
const KEY_SAT2 = 0x17e;
const KEY_CD = 0x17f;
const KEY_TAPE = 0x180;
const KEY_RADIO = 0x181;
const KEY_TUNER = 0x182;
const KEY_PLAYER = 0x183;
const KEY_TEXT = 0x184;
const KEY_DVD = 0x185;
const KEY_AUX = 0x186;
const KEY_MP3 = 0x187;
const KEY_AUDIO = 0x188;
const KEY_VIDEO = 0x189;
const KEY_DIRECTORY = 0x18a;
const KEY_LIST = 0x18b;
const KEY_MEMO = 0x18c;
const KEY_CALENDAR = 0x18d;
const KEY_RED = 0x18e;
const KEY_GREEN = 0x18f;
const KEY_YELLOW = 0x190;
const KEY_BLUE = 0x191;
const KEY_CHANNELUP = 0x192;
const KEY_CHANNELDOWN = 0x193;
const KEY_FIRST = 0x194;
const KEY_LAST = 0x195;
const KEY_AB = 0x196;
const KEY_NEXT = 0x197;
const KEY_RESTART = 0x198;
const KEY_SLOW = 0x199;
const KEY_SHUFFLE = 0x19a;
const KEY_BREAK = 0x19b;
const KEY_PREVIOUS = 0x19c;
const KEY_DIGITS = 0x19d;
const KEY_TEEN = 0x19e;
const KEY_TWEN = 0x19f;
const KEY_VIDEOPHONE = 0x1a0;
const KEY_GAMES = 0x1a1;
const KEY_ZOOMIN = 0x1a2;
const KEY_ZOOMOUT = 0x1a3;
const KEY_ZOOMRESET = 0x1a4;
const KEY_WORDPROCESSOR = 0x1a5;
const KEY_EDITOR = 0x1a6;
const KEY_SPREADSHEET = 0x1a7;
const KEY_GRAPHICSEDITOR = 0x1a8;
const KEY_PRESENTATION = 0x1a9;
const KEY_DATABASE = 0x1aa;
const KEY_NEWS = 0x1ab;
const KEY_VOICEMAIL = 0x1ac;
const KEY_ADDRESSBOOK = 0x1ad;
const KEY_MESSENGER = 0x1ae;
const KEY_DISPLAYTOGGLE = 0x1af;
alias KEY_DISPLAYTOGGLE KEY_BRIGHTNESS_TOGGLE;
const KEY_SPELLCHECK = 0x1b0;

const KEY_LOGOFF = 0x1b1;
const KEY_DOLLAR = 0x1b2;

const KEY_EURO = 0x1b3;
const KEY_FRAMEBACK = 0x1b4;
const KEY_FRAMEFORWARD = 0x1b5;
const KEY_CONTEXT_MENU = 0x1b6;
const KEY_MEDIA_REPEAT = 0x1b7;
const KEY_10CHANNELSUP = 0x1b8;
const KEY_10CHANNELSDOWN = 0x1b9;

const KEY_IMAGES = 0x1ba;
const KEY_DEL_EOL = 0x1c0;
const KEY_DEL_EOS = 0x1c1;
const KEY_INS_LINE = 0x1c2;

const KEY_DEL_LINE = 0x1c3;
const KEY_FN = 0x1d0;
const KEY_FN_ESC = 0x1d1;
const KEY_FN_F1 = 0x1d2;
const KEY_FN_F2 = 0x1d3;
const KEY_FN_F3 = 0x1d4;
const KEY_FN_F4 = 0x1d5;
const KEY_FN_F5 = 0x1d6;
const KEY_FN_F6 = 0x1d7;
const KEY_FN_F7 = 0x1d8;
const KEY_FN_F8 = 0x1d9;
const KEY_FN_F9 = 0x1da;
const KEY_FN_F10 = 0x1db;
const KEY_FN_F11 = 0x1dc;
const KEY_FN_F12 = 0x1dd;
const KEY_FN_1 = 0x1de;
const KEY_FN_2 = 0x1df;
const KEY_FN_D = 0x1e0;
const KEY_FN_E = 0x1e1;
const KEY_FN_F = 0x1e2;
const KEY_FN_S = 0x1e3;

const KEY_FN_B = 0x1e4;
const KEY_BRL_DOT1 = 0x1f1;
const KEY_BRL_DOT2 = 0x1f2;
const KEY_BRL_DOT3 = 0x1f3;
const KEY_BRL_DOT4 = 0x1f4;
const KEY_BRL_DOT5 = 0x1f5;
const KEY_BRL_DOT6 = 0x1f6;
const KEY_BRL_DOT7 = 0x1f7;
const KEY_BRL_DOT8 = 0x1f8;
const KEY_BRL_DOT9 = 0x1f9;

const KEY_BRL_DOT10 = 0x1fa;
const KEY_NUMERIC_0 = 0x200;
const KEY_NUMERIC_1 = 0x201;
const KEY_NUMERIC_2 = 0x202;
const KEY_NUMERIC_3 = 0x203;
const KEY_NUMERIC_4 = 0x204;
const KEY_NUMERIC_5 = 0x205;
const KEY_NUMERIC_6 = 0x206;
const KEY_NUMERIC_7 = 0x207;
const KEY_NUMERIC_8 = 0x208;
const KEY_NUMERIC_9 = 0x209;
const KEY_NUMERIC_STAR = 0x20a;
const KEY_NUMERIC_POUND = 0x20b;
const KEY_NUMERIC_A = 0x20c;
const KEY_NUMERIC_B = 0x20d;
const KEY_NUMERIC_C = 0x20e;

const KEY_NUMERIC_D = 0x20f;
const KEY_CAMERA_FOCUS = 0x210;

const KEY_WPS_BUTTON = 0x211;
const KEY_TOUCHPAD_TOGGLE = 0x212;
const KEY_TOUCHPAD_ON = 0x213;

const KEY_TOUCHPAD_OFF = 0x214;
const KEY_CAMERA_ZOOMIN = 0x215;
const KEY_CAMERA_ZOOMOUT = 0x216;
const KEY_CAMERA_UP = 0x217;
const KEY_CAMERA_DOWN = 0x218;
const KEY_CAMERA_LEFT = 0x219;

const KEY_CAMERA_RIGHT = 0x21a;
const KEY_ATTENDANT_ON = 0x21b;
const KEY_ATTENDANT_OFF = 0x21c;
const KEY_ATTENDANT_TOGGLE = 0x21d;

const KEY_LIGHTS_TOGGLE = 0x21e;
const BTN_DPAD_UP = 0x220;
const BTN_DPAD_DOWN = 0x221;
const BTN_DPAD_LEFT = 0x222;

const BTN_DPAD_RIGHT = 0x223;

const KEY_ALS_TOGGLE = 0x230;
const KEY_BUTTONCONFIG = 0x240;
const KEY_TASKMANAGER = 0x241;
const KEY_JOURNAL = 0x242;
const KEY_CONTROLPANEL = 0x243;
const KEY_APPSELECT = 0x244;
const KEY_SCREENSAVER = 0x245;

const KEY_VOICECOMMAND = 0x246;
const KEY_BRIGHTNESS_MIN = 0x250;

const KEY_BRIGHTNESS_MAX = 0x251;
const KEY_KBDINPUTASSIST_PREV = 0x260;
const KEY_KBDINPUTASSIST_NEXT = 0x261;
const KEY_KBDINPUTASSIST_PREVGROUP = 0x262;
const KEY_KBDINPUTASSIST_NEXTGROUP = 0x263;
const KEY_KBDINPUTASSIST_ACCEPT = 0x264;

const KEY_KBDINPUTASSIST_CANCEL = 0x265;
const BTN_TRIGGER_HAPPY = 0x2c0;
const BTN_TRIGGER_HAPPY1 = 0x2c0;
const BTN_TRIGGER_HAPPY2 = 0x2c1;
const BTN_TRIGGER_HAPPY3 = 0x2c2;
const BTN_TRIGGER_HAPPY4 = 0x2c3;
const BTN_TRIGGER_HAPPY5 = 0x2c4;
const BTN_TRIGGER_HAPPY6 = 0x2c5;
const BTN_TRIGGER_HAPPY7 = 0x2c6;
const BTN_TRIGGER_HAPPY8 = 0x2c7;
const BTN_TRIGGER_HAPPY9 = 0x2c8;
const BTN_TRIGGER_HAPPY10 = 0x2c9;
const BTN_TRIGGER_HAPPY11 = 0x2ca;
const BTN_TRIGGER_HAPPY12 = 0x2cb;
const BTN_TRIGGER_HAPPY13 = 0x2cc;
const BTN_TRIGGER_HAPPY14 = 0x2cd;
const BTN_TRIGGER_HAPPY15 = 0x2ce;
const BTN_TRIGGER_HAPPY16 = 0x2cf;
const BTN_TRIGGER_HAPPY17 = 0x2d0;
const BTN_TRIGGER_HAPPY18 = 0x2d1;
const BTN_TRIGGER_HAPPY19 = 0x2d2;
const BTN_TRIGGER_HAPPY20 = 0x2d3;
const BTN_TRIGGER_HAPPY21 = 0x2d4;
const BTN_TRIGGER_HAPPY22 = 0x2d5;
const BTN_TRIGGER_HAPPY23 = 0x2d6;
const BTN_TRIGGER_HAPPY24 = 0x2d7;
const BTN_TRIGGER_HAPPY25 = 0x2d8;
const BTN_TRIGGER_HAPPY26 = 0x2d9;
const BTN_TRIGGER_HAPPY27 = 0x2da;
const BTN_TRIGGER_HAPPY28 = 0x2db;
const BTN_TRIGGER_HAPPY29 = 0x2dc;
const BTN_TRIGGER_HAPPY30 = 0x2dd;
const BTN_TRIGGER_HAPPY31 = 0x2de;
const BTN_TRIGGER_HAPPY32 = 0x2df;
const BTN_TRIGGER_HAPPY33 = 0x2e0;
const BTN_TRIGGER_HAPPY34 = 0x2e1;
const BTN_TRIGGER_HAPPY35 = 0x2e2;
const BTN_TRIGGER_HAPPY36 = 0x2e3;
const BTN_TRIGGER_HAPPY37 = 0x2e4;
const BTN_TRIGGER_HAPPY38 = 0x2e5;
const BTN_TRIGGER_HAPPY39 = 0x2e6;

const BTN_TRIGGER_HAPPY40 = 0x2e7;
/* We avoid low common keys in module aliases so they don't get huge. */
alias KEY_MUTE KEY_MIN_INTERESTING;
const KEY_MAX = 0x2ff;

/*
 * Relative axes
 */

const REL_X = 0x00;
const REL_Y = 0x01;
const REL_Z = 0x02;
const REL_RX = 0x03;
const REL_RY = 0x04;
const REL_RZ = 0x05;
const REL_HWHEEL = 0x06;
const REL_DIAL = 0x07;
const REL_WHEEL = 0x08;
const REL_MISC = 0x09;
const REL_MAX = 0x0f;

/*
 * Absolute axes
 */

const ABS_X = 0x00;
const ABS_Y = 0x01;
const ABS_Z = 0x02;
const ABS_RX = 0x03;
const ABS_RY = 0x04;
const ABS_RZ = 0x05;
const ABS_THROTTLE = 0x06;
const ABS_RUDDER = 0x07;
const ABS_WHEEL = 0x08;
const ABS_GAS = 0x09;
const ABS_BRAKE = 0x0a;
const ABS_HAT0X = 0x10;
const ABS_HAT0Y = 0x11;
const ABS_HAT1X = 0x12;
const ABS_HAT1Y = 0x13;
const ABS_HAT2X = 0x14;
const ABS_HAT2Y = 0x15;
const ABS_HAT3X = 0x16;
const ABS_HAT3Y = 0x17;
const ABS_PRESSURE = 0x18;
const ABS_DISTANCE = 0x19;
const ABS_TILT_X = 0x1a;
const ABS_TILT_Y = 0x1b;

const ABS_TOOL_WIDTH = 0x1c;

const ABS_VOLUME = 0x20;

const ABS_MISC = 0x28;
const ABS_MT_SLOT = 0x2f;
const ABS_MT_TOUCH_MAJOR = 0x30;
const ABS_MT_TOUCH_MINOR = 0x31;
const ABS_MT_WIDTH_MAJOR = 0x32;
const ABS_MT_WIDTH_MINOR = 0x33;
const ABS_MT_ORIENTATION = 0x34;
const ABS_MT_POSITION_X = 0x35;
const ABS_MT_POSITION_Y = 0x36;
const ABS_MT_TOOL_TYPE = 0x37;
const ABS_MT_BLOB_ID = 0x38;
const ABS_MT_TRACKING_ID = 0x39;
const ABS_MT_PRESSURE = 0x3a;
const ABS_MT_DISTANCE = 0x3b;
const ABS_MT_TOOL_X = 0x3c;

const ABS_MT_TOOL_Y = 0x3d;

const ABS_MAX = 0x3f;

/*
 * Switch events
 */

const SW_LID = 0x00;
const SW_TABLET_MODE = 0x01;
/* rfkill master switch, type "any"
const SW_HEADPHONE_INSERT = 0x02;
					 set = radio enabled */
const SW_RFKILL_ALL = 0x03;
alias SW_RFKILL_ALL SW_RADIO;
const SW_MICROPHONE_INSERT = 0x04;
const SW_DOCK = 0x05;
const SW_LINEOUT_INSERT = 0x06;
const SW_JACK_PHYSICAL_INSERT = 0x07;
const SW_VIDEOOUT_INSERT = 0x08;
const SW_CAMERA_LENS_COVER = 0x09;
const SW_KEYPAD_SLIDE = 0x0a;
const SW_FRONT_PROXIMITY = 0x0b;
const SW_ROTATE_LOCK = 0x0c;
const SW_LINEIN_INSERT = 0x0d;
const SW_MUTE_DEVICE = 0x0e;
const SW_MAX = 0x0f;

/*
 * Misc events
 */

const MSC_SERIAL = 0x00;
const MSC_PULSELED = 0x01;
const MSC_GESTURE = 0x02;
const MSC_RAW = 0x03;
const MSC_SCAN = 0x04;
const MSC_TIMESTAMP = 0x05;
const MSC_MAX = 0x07;

/*
 * LEDs
 */

const LED_NUML = 0x00;
const LED_CAPSL = 0x01;
const LED_SCROLLL = 0x02;
const LED_COMPOSE = 0x03;
const LED_KANA = 0x04;
const LED_SLEEP = 0x05;
const LED_SUSPEND = 0x06;
const LED_MUTE = 0x07;
const LED_MISC = 0x08;
const LED_MAIL = 0x09;
const LED_CHARGING = 0x0a;
const LED_MAX = 0x0f;

/*
 * Autorepeat values
 */

const REP_DELAY = 0x00;
const REP_PERIOD = 0x01;
const REP_MAX = 0x01;

/*
 * Sounds
 */

const SND_CLICK = 0x00;
const SND_BELL = 0x01;
const SND_TONE = 0x02;
const SND_MAX = 0x07;

