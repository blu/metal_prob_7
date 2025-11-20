/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Application entry point for macOS.
*/

#import <Cocoa/Cocoa.h>
#import "AAPLAppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application activateIgnoringOtherApps: YES];

        // provide app menu with one item: quit
        NSMenuItem *item = [[NSMenuItem alloc] init];
        [item setSubmenu: [[NSMenu alloc] init]];
        [item.submenu addItem: [[NSMenuItem alloc] initWithTitle: [@"Quit " stringByAppendingString: NSProcessInfo.processInfo.processName] action:@selector(terminate:) keyEquivalent:@"q"]];
        [application setMainMenu: [[NSMenu alloc] init]];
        [application.mainMenu addItem: item];

        AAPLAppDelegate *appDelegate = [[AAPLAppDelegate alloc] init];
        [application setDelegate: appDelegate];
        [application run];
    }

    return EXIT_SUCCESS;
}
