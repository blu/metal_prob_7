/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import MetalKit;

#import "AAPLRenderer.h"

extern void content_init(size_t view_w, size_t view_h);
extern void content_deinit(void);
extern void content_render(void *texture);

// Main class performing the rendering
@implementation AAPLRenderer
{
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
}

void back_to_caller(void *texture, void *bytes, size_t perRow, size_t width, size_t height)
{
    [(__bridge id<MTLTexture>)texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
                                        mipmapLevel:0
                                          withBytes:bytes
                                        bytesPerRow:perRow];
}

- (nonnull instancetype)initWithMTLDevice:(nonnull id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    @autoreleasepool {
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

        // Get the drawable that will be presented at the end of the frame
        id<CAMetalDrawable> drawable = view.currentDrawable;

        // Get the drawable's texture to render content into
        id<MTLTexture> texture = drawable.texture;
        content_render((__bridge void *)texture);

        // Request that the drawable texture be presented by the windowing system once drawing is done
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
}

// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    const size_t draw_w = size.width;
    const size_t draw_h = size.height;

    content_init(draw_w, draw_h);
}

- (void) dealloc
{
    content_deinit();
}

@end
