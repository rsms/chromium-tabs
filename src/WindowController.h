#import <Cocoa/Cocoa.h>
#import "ChromiumTabbedBrowser.h"
#import "TabStripModelDelegate.h"
#import "chrome/browser/cocoa/tab_window_controller.h"

@interface WindowController : TabWindowController <TabStripModelDelegate> {
	NSObject<ChromiumTabbedBrowser>* browser_;
}
- (id)initWithWindowNibName:(NSString *)windowNibName
			chromiumTabbedBrowser:(NSObject<ChromiumTabbedBrowser>*)browser;

@end
