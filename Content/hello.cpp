//
//  hello.cpp
//  MetalKitAndRenderingSetup-macOS
//
//  Created by Martin Krastev on 19.11.25.
//  Copyright © 2025 Apple. All rights reserved.
//

#include <cstdint>
#include <cstdlib>
#include <cstdio>

#include <mach/mach_time.h>

#define IMAGE_RES_X 2048
#define IMAGE_RES_Y 1024

static uint8_t image0[IMAGE_RES_Y][IMAGE_RES_X];
static uint8_t image1[IMAGE_RES_Y][IMAGE_RES_X];
static struct {
    size_t width;
    size_t height;
} imageDim;

static mach_timebase_info_data_t tb;

static uint64_t timer_ns(void)
{
    const uint64_t t = mach_absolute_time();
    return t * tb.numer / tb.denom;
}

extern "C" void content_init(size_t view_w, size_t view_h)
{
    for (size_t i = 0; i < sizeof(image0) / sizeof(image0[0]); ++i)
        for (size_t j = 0; j < sizeof(image0[0]) / sizeof(image0[0][0]); ++j) {
            image0[i][j] = (i & 64) ^ (j & 64);
            image1[i][j] = (i & 64) ^ (j & 64) ^ 64;
        }

    imageDim.width = view_w;
    imageDim.height = view_h;

    mach_timebase_info(&tb);

    fputs("frame_init\n", stderr);
}

extern "C" void content_deinit(void)
{
    fputs("frame_deinit\n", stderr);
}

extern "C" void back_to_caller(void *texture, void *withBytes, size_t perRow, size_t width, size_t height);

extern "C" void content_render(void *texture)
{
    static uint64_t time_last;
    const uint64_t now = timer_ns();
    const uint64_t then = time_last;
    time_last = now;

    static uint8_t cnt;

    if (++cnt == 0) {
        const double period = (now - then) * 1e-9;
        fprintf(stderr, ">>> %f\n", period);
    }

    back_to_caller(texture, (cnt & 1) ? image0 : image1, sizeof(image0[0]), imageDim.width, imageDim.height);
}
