#import "AppDelegate.h"
#import "MyBrowser.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // Create a new browser & window when we start
	MyBrowser* browser = (MyBrowser *)[MyBrowser browser];
	browser.windowController = [[CTBrowserWindowController alloc] initWithBrowser:browser];
	[browser addBlankTabInForeground:YES];
	[browser.windowController showWindow:self];
}

// When there are no windows in our application, this class (AppDelegate) will
// become the first responder. We forward the command to the browser class.
- (void)commandDispatch:(id)sender {
	NSLog(@"commandDispatch %d", (int)[sender tag]);
	[MyBrowser executeCommand:[sender tag]];
}

@end
