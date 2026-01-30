#ifndef param_H__
#define param_H__

#include <stdint.h>

struct cli_param {
	uint32_t image_w;       // frame width
	uint32_t image_h;       // frame height
	uint32_t image_hz;      // frame rate target Hz
	uint32_t frames;        // frames to run
	uint32_t frame_msk;     // frame_id mask
	uint32_t group_w;       // workgroup width
	uint32_t group_h;       // workgroup height
};

enum buffer_designations {
	buffer_octet, // tree node: interior (octet)
	buffer_leaf,  // tree node: leaf
	buffer_voxel, // tree payload (voxel)
	buffer_carb,  // Camera and Root BBox

	buffer_designation_count,
};

struct content_init_arg {
	uint32_t buffer_size[buffer_designation_count];
};

struct content_frame_arg {
	void *buffer[buffer_designation_count];
};

#ifdef __cplusplus
extern "C" {
#endif

extern struct cli_param param; // updated by parseCLI

int parseCLI(int, const char **);
int content_init(struct content_init_arg *);
int content_deinit(void);
int content_frame(struct content_frame_arg, uint32_t);

#ifdef __cplusplus
}
#endif

#endif // param_H__
