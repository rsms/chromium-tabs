#pragma once
#import <Cocoa/Cocoa.h>
#import "CTTabStripModel.h"
#import "CTTabStripModelDelegate.h"
#import "CTBrowserCommand.h"

enum CTWindowOpenDisposition {
  CTWindowOpenDispositionCurrentTab,
  CTWindowOpenDispositionNewForegroundTab,
  CTWindowOpenDispositionNewBackgroundTab,
};

class CTTabStripModel;
@class CTBrowserWindowController;
@class CTTabContentsController;
@class CTToolbarController;

// There is one CTBrowser instance per percieved window.
// A CTBrowser instance has one TabStripModel.

@interface CTBrowser : NSObject <CTTabStripModelDelegate> {
  CTTabStripModel *tabStripModel_;
  CTBrowserWindowController *windowController_;
}

// The tab strip model
@property(readonly, nonatomic) CTTabStripModel* tabStripModel;

// The window controller
@property(readonly, nonatomic) CTBrowserWindowController* windowController;

// The window. Convenience for [windowController window]
@property(readonly, nonatomic) NSWindow* window;

// Create a new browser with a window. (autoreleased)
+(CTBrowser*)browser;
+(CTBrowser*)browserWithWindowFrame:(const NSRect)frame;

// Returns the current "main" browser instance, or nil if none. "main" means the
// browser's window(Controller) is the main window. Useful when there's a need
// to e.g. add contents to the "best browser from the users perspective".
+ (CTBrowser*)mainBrowser;

// Creates and opens a new window. (retained)
+(CTBrowser*)openEmptyWindow;

// Create a new window controller. The default implementation will create a
// controller loaded with a nib called "BrowserWindow". If the nib can't be
// found in the main bundle, a fallback nib will be loaded from the framework.
// This is usually enough since all UI which normally is customized is comprised
// within each tab (CTTabContents view).
-(CTBrowserWindowController *)createWindowController;

// This should normally _not_ be overridden
-(void)createWindowControllerInstance;

// Create a new toolbar controller. The default implementation will create a
// controller loaded with a nib called "Toolbar". If the nib can't be found in
// the main bundle, a fallback nib will be loaded from the framework.
// Returning nil means there is no toolbar.
-(CTToolbarController *)createToolbarController;

// Create a new tab contents controller. Override this to provide a custom
// CTTabContentsController subclass.
-(CTTabContentsController*)createTabContentsControllerWithContents:
    (CTTabContents*)contents;

// Create a new default/blank CTTabContents.
// |baseContents| represents the CTTabContents which is currently in the
// foreground. It might be nil.
// Subclasses could override this to provide a custom CTTabContents type.
-(CTTabContents*)createBlankTabBasedOn:(CTTabContents*)baseContents;

// Add blank tab
-(CTTabContents*)addBlankTabAtIndex:(int)index inForeground:(BOOL)foreground;
-(CTTabContents*)addBlankTabInForeground:(BOOL)foreground;
-(CTTabContents*)addBlankTab; // inForeground:YES

// Add tab with contents
-(CTTabContents*)addTabContents:(CTTabContents*)contents
                      atIndex:(int)index
                 inForeground:(BOOL)foreground;
-(CTTabContents*)addTabContents:(CTTabContents*)contents; // inForeground:YES

// Commands
-(void)newWindow;
-(void)closeWindow;
-(void)closeTab;
-(void)selectNextTab;
-(void)selectPreviousTab;
-(void)moveTabNext;
-(void)moveTabPrevious;
-(void)selectTabAtIndex:(int)index;
-(void)selectLastTab;
-(void)duplicateTab;

-(void)executeCommand:(int)cmd
      withDisposition:(CTWindowOpenDisposition)disposition;
-(void)executeCommand:(int)cmd;

// Execute a command which does not need to have a valid browser. This can be
// used in application delegates or other non-chromium-tabs windows which are
// first responders. Like this:
//
// - (void)commandDispatch:(id)sender {
//   [MyBrowser executeCommand:[sender tag]];
// }
//
+(void)executeCommand:(int)cmd;

// callbacks
-(void)loadingStateDidChange:(CTTabContents*)contents;
-(void)windowDidBeginToClose;
-(void)windowDidBecomeMain:(NSNotification*)notification;
-(void)windowDidResignMain:(NSNotification*)notification;

// Convenience helpers (proxy for TabStripModel)
-(int)tabCount;
-(int)selectedTabIndex;
-(CTTabContents*)selectedTabContents;
-(CTTabContents*)tabContentsAtIndex:(int)index;
-(void)selectTabContentsAtIndex:(int)index userGesture:(BOOL)userGesture;
-(void)closeAllTabs;

@end
