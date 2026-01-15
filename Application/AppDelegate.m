#import "AppDelegate.h"
#import "MetalRenderer.h"
#import "param.h"

@interface AppDelegate ()
{
	NSWindowController *_controller;
	MetalRenderer *_renderer;
}
@end

@implementation AppDelegate

- (instancetype) init
{
	self = [super init];

	if (self) {
		NSScreen *screen = [NSScreen mainScreen];
		const size_t retina = screen.backingScaleFactor == 2.f ? 1 : 0;
		const NSRect rect = NSMakeRect(0, 0, param.image_w >> retina, param.image_h >> retina);
		MTKView *view = [[MTKView alloc] initWithFrame:rect device:MTLCreateSystemDefaultDevice()];

		// Keep drawing at a const (vsync) rate, if possible
		view.enableSetNeedsDisplay = NO;
		view.preferredFramesPerSecond = param.image_hz;

		// Ensure any MTLTexture to be used by the view's drawables is not 'framebufferOnly'
		// in case we output to buffers, and set view texel format as expected by future writes
#if USE_DST_BUFFER
		view.framebufferOnly = NO;

#endif
		view.colorPixelFormat = MTLPixelFormatR8Unorm;

		_renderer = [[MetalRenderer alloc] initWithMTLDevice:view.device];

		// Largely unnecessary, still confirm the view size with the renderer
		[_renderer mtkView:view drawableSizeWillChange:view.drawableSize];
		view.delegate = _renderer;

		NSWindow *window = [[NSWindow alloc] initWithContentRect:rect
													   styleMask:NSWindowStyleMaskBorderless
														 backing:NSBackingStoreBuffered
														   defer:NO
														  screen:screen];
		window.title = NSProcessInfo.processInfo.processName;
		window.contentView = view;
		_controller = [[NSWindowController alloc] initWithWindow:window];
	}

	return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[NSApp activateIgnoringOtherApps:YES];
	[_controller.window makeKeyAndOrderFront:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	_renderer = nil;
}

@end
