module diesel.broadcom;

enum DISPMANX_FLAGS_ALPHA_T {
	/* Bottom 2 bits sets the alpha mode */
	DISPMANX_FLAGS_ALPHA_FROM_SOURCE = 0,
	DISPMANX_FLAGS_ALPHA_FIXED_ALL_PIXELS = 1,
	DISPMANX_FLAGS_ALPHA_FIXED_NON_ZERO = 2,
	DISPMANX_FLAGS_ALPHA_FIXED_EXCEED_0X07 = 3,

	DISPMANX_FLAGS_ALPHA_PREMULT = 1 << 16,
	DISPMANX_FLAGS_ALPHA_MIX = 1 << 17
}

const int DISPMANX_PROTECTION_MAX = 0x0f;
const int DISPMANX_PROTECTION_NONE = 0;
const int DISPMANX_PROTECTION_HDCP = 11;   // Derived from the WM DRM levels, 101-300


alias DISPMANX_ELEMENT_HANDLE_T = uint;
alias DISPMANX_DISPLAY_HANDLE_T = uint;
alias DISPMANX_UPDATE_HANDLE_T = uint;
alias DISPMANX_PROTECTION_T = uint;
alias DISPMANX_RESOURCE_HANDLE_T = uint;

struct VC_RECT_T {
	int x;
	int y;
	int width;
	int height;
}

struct VC_DISPMANX_ALPHA_T {
	DISPMANX_FLAGS_ALPHA_T flags;
	uint opacity;
	DISPMANX_RESOURCE_HANDLE_T mask;
}   /* for use with vmcs_host */

enum DISPMANX_FLAGS_CLAMP_T {
	DISPMANX_FLAGS_CLAMP_NONE = 0,
	DISPMANX_FLAGS_CLAMP_LUMA_TRANSPARENT = 1,
	DISPMANX_FLAGS_CLAMP_TRANSPARENT = 2,
	DISPMANX_FLAGS_CLAMP_REPLACE = 3
};

enum DISPMANX_TRANSFORM_T {
	/* Bottom 2 bits sets the orientation */
	DISPMANX_NO_ROTATE = 0,
	DISPMANX_ROTATE_90 = 1,
	DISPMANX_ROTATE_180 = 2,
	DISPMANX_ROTATE_270 = 3,

	DISPMANX_FLIP_HRIZ = 1 << 16,
	DISPMANX_FLIP_VERT = 1 << 17,

	/* invert left/right images */
	DISPMANX_STEREOSCOPIC_INVERT =  1 << 19,
	/* extra flags for controlling 3d duplication behaviour */
	DISPMANX_STEREOSCOPIC_NONE   =  0 << 20,
	DISPMANX_STEREOSCOPIC_MONO   =  1 << 20,
	DISPMANX_STEREOSCOPIC_SBS    =  2 << 20,
	DISPMANX_STEREOSCOPIC_TB     =  3 << 20,
	DISPMANX_STEREOSCOPIC_MASK   = 15 << 20,

	/* extra flags for controlling snapshot behaviour */
	DISPMANX_SNAPSHOT_NO_YUV = 1 << 24,
	DISPMANX_SNAPSHOT_NO_RGB = 1 << 25,
	DISPMANX_SNAPSHOT_FILL = 1 << 26,
	DISPMANX_SNAPSHOT_SWAP_RED_BLUE = 1 << 27,
	DISPMANX_SNAPSHOT_PACK = 1 << 28
};

enum DISPMANX_FLAGS_KEYMASK_T {
	DISPMANX_FLAGS_KEYMASK_OVERRIDE = 1,
	DISPMANX_FLAGS_KEYMASK_SMOOTH = 1 << 1,
	DISPMANX_FLAGS_KEYMASK_CR_INV = 1 << 2,
	DISPMANX_FLAGS_KEYMASK_CB_INV = 1 << 3,
	DISPMANX_FLAGS_KEYMASK_YY_INV = 1 << 4
};

union DISPMANX_CLAMP_KEYS_T {
	struct yuv {
		ubyte yy_upper;
		ubyte yy_lower;
		ubyte cr_upper;
		ubyte cr_lower;
		ubyte cb_upper;
		ubyte cb_lower;
	};
	struct rgb {
		ubyte red_upper;
		ubyte red_lower;
		ubyte blue_upper;
		ubyte blue_lower;
		ubyte green_upper;
		ubyte green_lower;
	};
};


struct DISPMANX_CLAMP_T {
	DISPMANX_FLAGS_CLAMP_T mode;
	DISPMANX_FLAGS_KEYMASK_T key_mask;
	DISPMANX_CLAMP_KEYS_T key_value;
	uint replace_value;
};


struct EGL_DISPMANX_WINDOW_T {
	DISPMANX_ELEMENT_HANDLE_T element;
	int width;   /* This is necessary because dispmanx elements are not queriable. */
	int height;
};


extern(C) void bcm_host_init();
extern(C) int graphics_get_display_size(ushort display_number, uint* width, uint* height);
extern(C) DISPMANX_DISPLAY_HANDLE_T vc_dispmanx_display_open(uint device);
extern(C) DISPMANX_UPDATE_HANDLE_T vc_dispmanx_update_start(int priority);
extern(C) DISPMANX_ELEMENT_HANDLE_T vc_dispmanx_element_add(DISPMANX_UPDATE_HANDLE_T update,
		DISPMANX_DISPLAY_HANDLE_T display,
		int layer, const VC_RECT_T *dest_rect, DISPMANX_RESOURCE_HANDLE_T src,
		const VC_RECT_T *src_rect, DISPMANX_PROTECTION_T protection,
		VC_DISPMANX_ALPHA_T *alpha,
		DISPMANX_CLAMP_T *clamp, DISPMANX_TRANSFORM_T transform );
extern(C) int vc_dispmanx_update_submit_sync(DISPMANX_UPDATE_HANDLE_T update);

