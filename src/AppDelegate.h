#import <Cocoa/Cocoa.h>
#import "ChromiumTabbedBrowser.h"
#import "chrome/browser/tabs/tab_strip_model.h"

@class WindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate,
														       ChromiumTabbedBrowser> {
	TabStripModel *tab_strip_model_;
}

- (WindowController *)spawnNewWindow;

@end
