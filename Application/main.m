#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "param.h"

int main(int argc, const char * argv[])
{
	param.image_w = 2560;
	param.image_h = 1440;
	param.image_hz = 60;
	param.frames = -1U;
	param.frame_msk = -1U;
	param.group_w = -1U;
	param.group_h = -1U;

	// read render setup from CLI
	const int result_cli = parseCLI(argc, argv);

	if (0 != result_cli)
		return result_cli;

	@autoreleasepool {
		NSApplication *application = [NSApplication sharedApplication];
		[application setActivationPolicy:NSApplicationActivationPolicyRegular];

		// provide app menu with one item: quit
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setSubmenu: [[NSMenu alloc] init]];
		[item.submenu addItem: [[NSMenuItem alloc] initWithTitle:[@"Quit " stringByAppendingString: NSProcessInfo.processInfo.processName]
														  action:@selector(terminate:)
												   keyEquivalent:@"q"]];
		[application setMainMenu: [[NSMenu alloc] init]];
		[application.mainMenu addItem: item];

		AppDelegate *appDelegate = [[AppDelegate alloc] init];
		[application setDelegate: appDelegate];
		[application run];
	}

	return EXIT_SUCCESS;
}
