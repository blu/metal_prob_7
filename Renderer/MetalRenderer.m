/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import MetalKit;

#import "MetalRenderer.h"
#import "param.h"

#define USE_BUFFER 0

@implementation MetalRenderer
{
    id<MTLDevice> _device;
    id<MTLComputePipelineState> _fnHelloPSO;
    id<MTLCommandQueue> _commandQueue;

#if USE_BUFFER
    id<MTLBuffer> _buffer;

#endif
}

- (nonnull instancetype)initWithMTLDevice:(nonnull id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        NSError* error = nil;

        _device = device;

        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

#if USE_BUFFER
        id<MTLFunction> fnHello = [defaultLibrary newFunctionWithName:@"hello"];

#else
        id<MTLFunction> fnHello = [defaultLibrary newFunctionWithName:@"holla"];

#endif
        if (fnHello == nil) {
            NSLog(@"error: Failed to find the adder function.");
            return nil;
        }

        _fnHelloPSO = [_device newComputePipelineStateWithFunction:fnHello error:&error];

        if (_fnHelloPSO == nil) {
            NSLog(@"error: Failed to created pipeline state object, error %@.", error);
            return nil;
        }

        const unsigned draw_w = param.image_w;
        const unsigned draw_h = param.image_h;
        const unsigned drawSize = draw_w * draw_h;
        const unsigned threadgroupSizeMax = (unsigned) _fnHelloPSO.maxTotalThreadsPerThreadgroup;

        unsigned threadgroupSize = param.group_w != -1U ? param.group_w * param.group_h : threadgroupSizeMax;
        if (threadgroupSize > drawSize) {
            threadgroupSize = drawSize;
        }

        if (threadgroupSize > threadgroupSizeMax) {
            NSLog(@"error: group size exceeds limit (%u)", threadgroupSizeMax);
            [[NSApplication sharedApplication] terminate:nil];
            return nil;
        }

        unsigned threadgroupWidth = param.group_w != -1U ? param.group_w : (unsigned) _fnHelloPSO.threadExecutionWidth;
        if (threadgroupWidth > draw_w) {
            threadgroupWidth = draw_w;
        }

        param.group_w = threadgroupWidth;
        param.group_h = threadgroupSize / threadgroupWidth;

        if (draw_w % param.group_w || draw_h % param.group_h) {
            NSLog(@"error: grid size not a multiple of group size (%u, %u)", param.group_w, param.group_h);
            [[NSApplication sharedApplication] terminate:nil];
            return nil;
        }

        NSLog(@"grid size (%u, %u)", param.group_w, param.group_h);

        _commandQueue = [_device newCommandQueue];

#if USE_BUFFER
        const NSUInteger bufferLen = drawSize * sizeof(uint8_t);

        _buffer = [_device newBufferWithLength:bufferLen options:MTLResourceStorageModeShared];

#endif
    }

    return self;
}

// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
    static uint32_t frame;

    @autoreleasepool {
        const size_t draw_w = param.image_w;
        const size_t draw_h = param.image_h;
        const size_t group_w = param.group_w;
        const size_t group_h = param.group_h;

        id<CAMetalDrawable> drawable = view.currentDrawable;
        id<MTLTexture> texture = drawable.texture;

        // execute compute kernel
        {
            id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

            id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];

            [computeEncoder setComputePipelineState:_fnHelloPSO];
#if USE_BUFFER
            [computeEncoder setBuffer:_buffer
                               offset:0
                              atIndex:0];

            [computeEncoder setBytes:&frame
                              length:sizeof(frame)
                             atIndex:1];
#else
            [computeEncoder setTexture:texture
                               atIndex:0];

            [computeEncoder setBytes:&frame
                              length:sizeof(frame)
                             atIndex:0];
#endif
            MTLSize gridSize = MTLSizeMake(draw_w / group_w, draw_h / group_h, 1);
            MTLSize groupSize = MTLSizeMake(group_w, group_h, 1);

            [computeEncoder dispatchThreadgroups:gridSize
                           threadsPerThreadgroup:groupSize];

            [computeEncoder endEncoding];

#if USE_BUFFER
            [commandBuffer commit];

            // force-sync to kernel completion as buffer content will be accessed next
            [commandBuffer waitUntilCompleted];
#else
            [commandBuffer presentDrawable:drawable];
            [commandBuffer commit];
#endif
        }
#if USE_BUFFER
        const uint8_t *const buffer = _buffer.contents;
        [texture replaceRegion:MTLRegionMake2D(0, 0, draw_w, draw_h)
                   mipmapLevel:0
                     withBytes:buffer
                   bytesPerRow:draw_w * sizeof(*buffer)];

        // present drawable
        {
            id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

            [commandBuffer presentDrawable:drawable];
            [commandBuffer commit];
        }
#endif
    }

    frame++;
}

// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    assert(size.width == param.image_w);
    assert(size.height == param.image_h);
}

- (void) dealloc
{
}

@end
