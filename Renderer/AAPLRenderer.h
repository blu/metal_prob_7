/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Header for a platform independent renderer class, which performs Metal setup and per frame rendering.
*/

#define IMAGE_RES_X 2048
#define IMAGE_RES_Y 1024

@import MetalKit;

@interface AAPLRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMTLDevice:(nonnull id<MTLDevice>)device;

@end
