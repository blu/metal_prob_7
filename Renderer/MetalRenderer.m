/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

@import MetalKit;

#import "MetalRenderer.h"
#import "param.h"

#define USE_BUFFER 0

enum { n_buffering = 3 };

@implementation MetalRenderer
{
	id<MTLDevice> _device;
	id<MTLComputePipelineState> _fnHelloPSO;
	id<MTLCommandQueue> _commandQueue;

	id<MTLBuffer> _src_buffer[n_buffering][buffer_designation_count];

#if USE_BUFFER
	id<MTLBuffer> _dst_buffer[n_buffering];

#endif
}

struct content_init_arg cont_init_arg;

- (nonnull instancetype)initWithMTLDevice:(nonnull id<MTLDevice>)device
{
	self = [super init];
	if (self) {
		NSError* error = nil;

		_device = device;

		id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
		id<MTLFunction> fnHello = [defaultLibrary newFunctionWithName:@"monokernel"];

		if (fnHello == nil) {
			NSLog(@"error: Failed to find kernel function.");
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

		NSLog(@"grid size (%u, %u), group size (%u, %u)", param.image_w, param.image_h, param.group_w, param.group_h);

		_commandQueue = [_device newCommandQueue];

		if (content_init(&cont_init_arg)) {
			[[NSApplication sharedApplication] terminate:nil];
		}

		for (size_t bi = 0; bi < n_buffering; bi++) {
			for (size_t di = 0; di < buffer_designation_count; di++) {
				_src_buffer[bi][di] = [_device newBufferWithLength:cont_init_arg.buffer_size[di]
														   options:MTLResourceStorageModeShared];
			}
		}

#if USE_BUFFER
		const NSUInteger bufferLen = drawSize * sizeof(uint8_t);

		for (size_t bi = 0; bi < n_buffering; bi++) {
			_dst_buffer[bi] = [_device newBufferWithLength:bufferLen
												   options:MTLResourceStorageModeShared];
		}

#endif
	}

	return self;
}

// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
	static uint32_t frame_idx;
	const uint32_t frame = frame_idx++;

	@autoreleasepool {

		struct content_frame_arg frame_arg;
		frame_arg.buffer[buffer_octet] = _src_buffer[frame % n_buffering][buffer_octet].contents;
		frame_arg.buffer[buffer_leaf]  = _src_buffer[frame % n_buffering][buffer_leaf].contents;
		frame_arg.buffer[buffer_voxel] = _src_buffer[frame % n_buffering][buffer_voxel].contents;
		frame_arg.buffer[buffer_carb]  = _src_buffer[frame % n_buffering][buffer_carb].contents;

		if (content_frame(frame_arg))  {
			[[NSApplication sharedApplication] terminate:nil];
		}

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

			uint32_t b_idx = 0;
			uint32_t t_idx = 0;

			for (size_t di = 0; di < buffer_designation_count; di++) {
				[computeEncoder setBuffer:_src_buffer[frame % n_buffering][di]
								   offset:0
								  atIndex:b_idx++];
			}

#if USE_BUFFER
			[computeEncoder setBuffer:_dst_buffer[frame % n_buffering]
							   offset:0
							  atIndex:b_idx++];

#else
			[computeEncoder setTexture:texture
							   atIndex:t_idx++];

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
		const uint8_t *const buffer = _dst_buffer[frame % n_buffering].contents;
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
}

// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
	assert(size.width == param.image_w);
	assert(size.height == param.image_h);
}

- (void) dealloc
{
	content_deinit();
}

@end
