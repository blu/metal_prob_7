/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import MetalKit;

#import "MetalRenderer.h"

@implementation MetalRenderer
{
    id<MTLDevice> _device;
    id<MTLComputePipelineState> _fnHelloPSO;
    id<MTLCommandQueue> _commandQueue;

    id<MTLBuffer> _buffer;

    struct {
        NSUInteger w;
        NSUInteger h;
    } _draw;
    struct {
        NSUInteger w;
        NSUInteger h;
    } _group;
}

- (nonnull instancetype)initWithMTLDevice:(nonnull id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        NSError* error = nil;

        _device = device;

        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
        id<MTLFunction> fnHello = [defaultLibrary newFunctionWithName:@"hello"];

        if (fnHello == nil) {
            NSLog(@"error: Failed to find the adder function.");
            return nil;
        }

        _fnHelloPSO = [_device newComputePipelineStateWithFunction:fnHello error:&error];

        if (_fnHelloPSO == nil) {
            NSLog(@"error: Failed to created pipeline state object, error %@.", error);
            return nil;
        }

        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    @autoreleasepool {
        const size_t draw_w = _draw.w;
        const size_t draw_h = _draw.h;
        const size_t group_w = _group.w;
        const size_t group_h = _group.h;

        // execute compute kernel
        {
            id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

            id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];

            [computeEncoder setComputePipelineState:_fnHelloPSO];
            [computeEncoder setBuffer:_buffer
                               offset:0
                              atIndex:0];

            MTLSize gridSize = MTLSizeMake(draw_w / group_w, draw_h / group_h, 1);
            MTLSize groupSize = MTLSizeMake(group_w, group_h, 1);

            [computeEncoder dispatchThreadgroups:gridSize
                           threadsPerThreadgroup:groupSize];

            [computeEncoder endEncoding];
            [commandBuffer commit];

            // force-sync to kernel completion as buffer content will be accessed next
            [commandBuffer waitUntilCompleted];
        }
        // present drawable
        {
            id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

            id<CAMetalDrawable> drawable = view.currentDrawable;
            id<MTLTexture> texture = drawable.texture;

            const uint8_t *const buffer = _buffer.contents;
            [texture replaceRegion:MTLRegionMake2D(0, 0, draw_w, draw_h)
                       mipmapLevel:0
                         withBytes:buffer
                       bytesPerRow:draw_w * sizeof(*buffer)];

            [commandBuffer presentDrawable:drawable];
            [commandBuffer commit];
        }
    }
}

// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    const size_t draw_w = _draw.w = size.width;
    const size_t draw_h = _draw.h = size.height;
    const size_t gridArea = draw_w * draw_h;
    const NSUInteger bufferLen = gridArea * sizeof(uint8_t);

    _buffer = [_device newBufferWithLength:bufferLen options:MTLResourceStorageModeShared];

    NSUInteger threadgroupSize = _fnHelloPSO.maxTotalThreadsPerThreadgroup;
    if (threadgroupSize > gridArea) {
        threadgroupSize = gridArea;
    }
    NSUInteger execSize = _fnHelloPSO.threadExecutionWidth;
    if (execSize > draw_w) {
        execSize = draw_w;
    }
    _group.w = execSize;
    _group.h = threadgroupSize / execSize;
}

- (void) dealloc
{
}

@end
