struct cli_param {
    unsigned image_w;       // frame width
    unsigned image_h;       // frame height
    unsigned image_hz;      // frame rate target Hz
    unsigned frames;        // frames to run
    unsigned group_w;       // workgroup width
    unsigned group_h;       // workgroup height
};

extern struct cli_param param;
