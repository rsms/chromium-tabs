#import "AppDelegate.h"
#import "MyBrowser.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // Create a new browser & window when we start
  CTBrowserWindowController* windowController =
      [[CTBrowserWindowController alloc] initWithBrowser:[MyBrowser browser]];
  [windowController.browser addBlankTabInForeground:YES];
  [windowController showWindow:self];
  // Because window controller are owned by the app, we need to release our
  // reference.
  //[windowController autorelease];
}

// When there are no windows in our application, this class (AppDelegate) will
// become the first responder. We forward the command to the browser class.
- (void)commandDispatch:(id)sender {
  NSLog(@"commandDispatch %d", (int)[sender tag]);
  [MyBrowser executeCommand:[sender tag]];
}

@end
