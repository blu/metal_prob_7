/*
See the LICENSE.txt file for this sample’s licensing information.

*/

#import <Cocoa/Cocoa.h>

struct cli_param {
    unsigned image_w;       // frame width
    unsigned image_h;       // frame height
    unsigned image_hz;      // frame rate target Hz
    unsigned frames;        // frames to run
};

@interface AppDelegate : NSObject <NSApplicationDelegate>

@end
