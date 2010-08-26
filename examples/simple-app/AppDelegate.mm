#import "AppDelegate.h"
#import "MyBrowser.h"

#import <ChromiumTabs/ChromiumTabs.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // Create a new browser & window when we start
  [MyBrowser openEmptyWindow];
}

// When there are no windows in our application, this class (AppDelegate) will
// become the first responder. We receive and parse relevant user commands.
- (void)commandDispatch:(id)sender {
  // TODO: provide a shorthand [CTBrowser commandDispatch:sender]
  switch ([sender tag]) {
    case CTBrowserCommandNewWindow:
    case CTBrowserCommandNewTab:    [MyBrowser openEmptyWindow]; break;
    case CTBrowserCommandExit:      [NSApp terminate:self]; break;
  }
}

@end
