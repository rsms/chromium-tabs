#import "AppDelegate.h"
#import <ChromiumTabs/ChromiumTabs.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  DLOG("applicationDidFinishLaunching %@", notification);
  // Configure context menu
  //NSMenu *mainMenu = [NSApp mainMenu];
  //[mainMenu itemWithTag:#import "BrowserCommands.h"];
  //commandDispatch

  // Create a browser and show the window
  [CTBrowser openEmptyWindow];
}

- (void)commandDispatch:(id)sender {
  assert(sender);
  switch ([sender tag]) {
    // Window management commands
    case IDC_NEW_WINDOW:
    case IDC_NEW_TAB:     [CTBrowser openEmptyWindow]; break;
    case IDC_EXIT:       [NSApp terminate:self]; break;
  }
}


@end
