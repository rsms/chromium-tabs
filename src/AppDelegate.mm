#import "AppDelegate.h"
#import "Browser.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  DLOG("applicationDidFinishLaunching %@", notification);
	// Configure context menu
	//NSMenu *mainMenu = [NSApp mainMenu];
	//[mainMenu itemWithTag:#import "BrowserCommands.h"];
	//commandDispatch

	// Create a browser and show the window
	[Browser openEmptyWindow];
}

- (void)commandDispatch:(id)sender {
	assert(sender);
  switch ([sender tag]) {
		// Window management commands
    case IDC_NEW_WINDOW:
    case IDC_NEW_TAB:		 [Browser openEmptyWindow]; break;
    case IDC_EXIT:       [NSApp terminate:self]; break;
	}
}


@end
