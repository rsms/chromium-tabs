#import "AppDelegate.h"
#import "Browser.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Create a browser and show the window
	Browser *browser = [Browser browser];
	[browser appendNewEmptyTab];
	[browser.windowController showWindow:self];
}


@end
