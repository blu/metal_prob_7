#ifndef param_H__
#define param_H__

struct cli_param {
	unsigned image_w;       // frame width
	unsigned image_h;       // frame height
	unsigned image_hz;      // frame rate target Hz
	unsigned frames;        // frames to run
	unsigned frame_msk;     // frame_id mask
	unsigned group_w;       // workgroup width
	unsigned group_h;       // workgroup height
};

enum buffer_designations {
	buffer_octet, // tree node: interior (octet)
	buffer_leaf,  // tree node: leaf
	buffer_voxel, // tree payload (voxel)
	buffer_carb,  // Camera and Root BBox

	buffer_designation_count,
};

struct content_init_arg {
	unsigned buffer_size[buffer_designation_count];
};

struct content_frame_arg {
	void *buffer[buffer_designation_count];
};

#ifdef __cplusplus
extern "C" {
#endif

extern struct cli_param param;

int parseCLI(int, const char **, struct cli_param *);
int content_init(struct content_init_arg *);
int content_deinit(void);
int content_frame(struct content_frame_arg);

#ifdef __cplusplus
}
#endif

#endif // param_H__
