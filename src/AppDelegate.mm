#import "AppDelegate.h"
#import "Browser.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Configure context menu
	//NSMenu *mainMenu = [NSApp mainMenu];
	//[mainMenu itemWithTag:#import "BrowserCommands.h"];
	//commandDispatch

	// Create a browser and show the window
	[Browser openEmptyWindow];
}


@end
