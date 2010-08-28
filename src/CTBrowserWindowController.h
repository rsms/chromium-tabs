#import <Cocoa/Cocoa.h>
#import "CTBrowser.h"
#import "CTTabStripModelDelegate.h"
#import "CTTabWindowController.h"

@class CTTabStripController;
@class CTToolbarController;
class CTTabStripModelObserverBridge;

@interface CTBrowserWindowController : CTTabWindowController {
  CTBrowser* browser_;
  CTTabStripController *tabStripController_;
  CTTabStripModelObserverBridge *tabStripObserver_;
  CTToolbarController *toolbarController_;
 @private
  BOOL initializing_; // true if the instance is initializing
}

@property(readonly, nonatomic) CTTabStripController *tabStripController;
@property(readonly, nonatomic) CTToolbarController *toolbarController;
@property(readonly, nonatomic) CTBrowser *browser;

- (id)initWithWindowNibPath:(NSString *)windowNibPath
                    browser:(CTBrowser*)browser;

// Gets the pattern phase for the window.
- (NSPoint)themePatternPhase;

// Returns fullscreen state.
- (BOOL)isFullscreen;

// Called to check whether or not this window has a toolbar. By default returns
// true if toolbarController_ is not nil.
- (BOOL)hasToolbar;

// Updates the toolbar with the states of the specified |contents|.
// If |shouldRestore| is true, we're switching (back?) to this tab and should
// restore any previous state (such as user editing a text field) as well.
- (void)updateToolbarWithContents:(CTTabContents*)tab
               shouldRestoreState:(BOOL)shouldRestore;

// Brings this controller's window to the front.
- (void)activate;

// Make the (currently-selected) tab contents the first responder, if possible.
- (void)focusTabContents;

// Lays out the tab content area in the given frame. If the height changes,
// sends a message to the renderer to resize.
- (void)layoutTabContentArea:(NSRect)frame;

@end
