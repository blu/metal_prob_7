/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import MetalKit;

#import "AAPLRenderer.h"
#include <mach/mach_time.h>

// Main class performing the rendering
@implementation AAPLRenderer
{
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;

    MTLClearColor _clearColor;
}

static mach_timebase_info_data_t tb;

static uint64_t timer_ns(void) {
    const uint64_t t = mach_absolute_time();
    return t * tb.numer / tb.denom;
}

- (nonnull instancetype)initWithMTLDevice:(nonnull id<MTLDevice>)device
{
    self = [super init];
    if(self) {
        _device = device;
        _commandQueue = [_device newCommandQueue];

        _clearColor = MTLClearColorMake(0.0, 0.5, 1.0, 1.0);

        mach_timebase_info(&tb);
    }

    return self;
}

static void swap(double *a, double *b)
{
    double t = *a;
    *a = *b;
    *b = t;
}

static uint64_t t_last;
static uint8_t cnt;

// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    // The render pass descriptor references the texture into which Metal should draw
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor == nil)
    {
        return;
    }

    view.clearColor = _clearColor;
    swap(&_clearColor.blue, &_clearColor.red);

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // Create a render pass and immediately end encoding, causing the drawable to be cleared
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    [commandEncoder endEncoding];
    
    // Get the drawable that will be presented at the end of the frame
    id<MTLDrawable> drawable = view.currentDrawable;

    // Request that the drawable texture be presented by the windowing system once drawing is done
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];

    const uint64_t now = timer_ns();
    const uint64_t then = t_last;
    t_last = now;

    if (cnt++ == 0 && then) {
        const double period = (now - then) * 1e-9;
        NSLog(@">>> %f", period);
    }
}

// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
}

@end
