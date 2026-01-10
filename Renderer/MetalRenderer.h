@import MetalKit;

@interface MetalRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMTLDevice:(nonnull id<MTLDevice>)device;
- (void) dealloc;

@end
