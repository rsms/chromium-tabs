#import "AppDelegate.h"
#import "WindowController.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Setup tab strip
	tab_strip_model_ = new TabStripModel(self);

	// Create a new window
	WindowController *wc = [self spawnNewWindow];
	[wc showWindow:self];
}

- (WindowController *)spawnNewWindow {
	WindowController *wc =
			[[WindowController alloc] initWithWindowNibName:@"BrowserWindow" 
																chromiumTabbedBrowser:self];
	// Can be accessed through [NSApp windows]
	return wc;
}

-(TabStripModel*)tabStripModel {
	return tab_strip_model_;
}

@end
