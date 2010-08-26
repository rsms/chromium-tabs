#import <Cocoa/Cocoa.h>
#import "CTBrowser.h"
#import "TabStripModelDelegate.h"
#import "tab_window_controller.h"

@class TabStripController;
class TabStripModelObserverBridge;

@interface CTBrowserWindowController : TabWindowController {
  CTBrowser* browser_;
  TabStripController *tabStripController_;
  TabStripModelObserverBridge *tabStripObserver_;
 @private
  BOOL initializing_; // true if the instance is initializing
}

@property(readonly, nonatomic) TabStripController *tabStripController;
@property(readonly, nonatomic) CTBrowser *browser;

- (id)initWithWindowNibPath:(NSString *)windowNibPath
                    browser:(CTBrowser*)browser;

// Make the (currently-selected) tab contents the first responder, if possible.
- (void)focusTabContents;

// Returns fullscreen state.
- (BOOL)isFullscreen;

// Lays out the tab content area in the given frame. If the height changes,
// sends a message to the renderer to resize.
- (void)layoutTabContentArea:(NSRect)frame;

@end
