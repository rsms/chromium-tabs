#import <Cocoa/Cocoa.h>
#import "chrome/browser/tabs/tab_strip_model.h"
#import "TabStripModelDelegate.h"
#import "WindowOpenDisposition.h"
#import "BrowserCommands.h"

class TabStripModel;
@class BrowserWindowController;

// There is one Browser instance per percieved window.
// A Browser instance has one TabStripModel.

@interface Browser : NSObject <TabStripModelDelegate> {
	TabStripModel *tabStripModel_;
	BrowserWindowController *windowController_;
}

// The tab strip model
@property(readonly, nonatomic) TabStripModel* tabStripModel;

// The window controller
@property(readonly, nonatomic) BrowserWindowController* windowController;

// The window. Convenience for [windowController window]
@property(readonly, nonatomic) NSWindow* window;

// Create a new browser with a window. (autoreleased)
+(Browser*)browser;
+(Browser*)browserWithWindowFrame:(const NSRect)frame;

// Creates and opens a new window. (retained)
+(Browser*)openEmptyWindow;

// Commands
-(void)newWindow;
-(void)closeWindow;
-(TabContents*)addTabContents:(TabContents*)contents
											atIndex:(int)index
								 inForeground:(BOOL)foreground;
-(TabContents*)addBlankTabAtIndex:(int)index inForeground:(BOOL)foreground;
-(TabContents*)addBlankTabInForeground:(BOOL)foreground;
-(TabContents*)addBlankTab; // InForeground:YES
-(void)closeTab;
-(void)selectNextTab;
-(void)selectPreviousTab;

-(void)executeCommand:(int)cmd
			withDisposition:(WindowOpenDisposition)disposition;
-(void)executeCommand:(int)cmd; // withDisposition:CURRENT_TAB

// callbacks
-(void)loadingStateDidChange:(TabContents*)contents;
-(void)windowDidBeginToClose;

// Convenience helpers (proxy for TabStripModel)
-(int)tabCount;
-(int)selectedTabIndex;
-(TabContents*)selectedTabContents;
-(TabContents*)tabContentsAtIndex:(int)index;
-(void)selectTabContentsAtIndex:(int)index userGesture:(BOOL)userGesture;
-(void)closeAllTabs;

@end
