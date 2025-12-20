/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Application entry point for macOS.
*/

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

const char arg_prefix[]                   = "-";
const char arg_screen[]                   = "screen";
const char arg_frames[]                   = "frames";

static bool
validate_fullscreen(
    const char *const string,
    unsigned *screen_w,
    unsigned *screen_h,
    unsigned *screen_hz)
{
    if (0 == string)
        return false;

    unsigned x, y, hz;

    if (3 != sscanf(string, "%u %u %u", &x, &y, &hz))
        return false;

    if (!x || !y || !hz)
        return false;

    *screen_w = x;
    *screen_h = y;
    *screen_hz = hz;

    return true;
}

static int parseCLI(
    int argc,
    const char **argv,
    struct cli_param *param)
{
    const size_t prefix_len = strlen(arg_prefix);
    bool success = true;

    for (int i = 1; i < argc && success; ++i) {
        if (strncmp(argv[i], arg_prefix, prefix_len)) {
            success = false;
            continue;
        }

        if (!strcmp(argv[i] + prefix_len, arg_screen)) {
            if (++i == argc || !validate_fullscreen(argv[i], &param->image_w, &param->image_h, &param->image_hz))
                success = false;

            continue;
        }

        if (!strcmp(argv[i] + prefix_len, arg_frames)) {
            if (++i == argc || 1 != sscanf(argv[i], "%u", &param->frames))
                success = false;

            continue;
        }

        success = false;
    }

    if (!success) {
        fprintf(stderr, "usage: %s [<option> ...]\n"
            "options (multiple args to an option must constitute a single string, eg. -foo \"a b c\"):\n"
            "\t%s%s <width> <height> <Hz>\t: set framebuffer of specified geometry and refresh\n"
            "\t%s%s <unsigned_integer>\t: set number of frames to run; default is max unsigned int\n",
            argv[0], arg_prefix, arg_screen, arg_prefix, arg_frames);

        return 1;
    }

    return 0;
}

struct cli_param param;

int main(int argc, const char * argv[])
{
    param.image_w = 2560;
    param.image_h = 1440;
    param.image_hz = 60;
    param.frames = -1U;

    if (parseCLI(argc, argv, &param)) {
        return -1;
    }

    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application activateIgnoringOtherApps: YES];

        // provide app menu with one item: quit
        NSMenuItem *item = [[NSMenuItem alloc] init];
        [item setSubmenu: [[NSMenu alloc] init]];
        [item.submenu addItem: [[NSMenuItem alloc] initWithTitle: [@"Quit " stringByAppendingString: NSProcessInfo.processInfo.processName] action:@selector(terminate:) keyEquivalent:@"q"]];
        [application setMainMenu: [[NSMenu alloc] init]];
        [application.mainMenu addItem: item];

        AppDelegate *appDelegate = [[AppDelegate alloc] init];
        [application setDelegate: appDelegate];
        [application run];
    }

    return EXIT_SUCCESS;
}
