#import <Cocoa/Cocoa.h>
#import "chrome/browser/tabs/tab_strip_model.h"
#import "TabStripModelDelegate.h"
#import "WindowOpenDisposition.h"

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

// Create a new browser with a window. The Browser instance will be added to the
// internal |browsers| NSSet, so you don't have to manage your own reference.
+(Browser*)browser;

// A set of all live browser instances
+(NSSet*)browsers;

-(TabContents*)appendNewEmptyTab;

-(void)loadingStateDidChange:(TabContents*)contents;

-(void)executeCommand:(int)cmd
			withDisposition:(WindowOpenDisposition)disposition;
-(void)executeCommand:(int)cmd; // withDisposition:CURRENT_TAB

// TabStripModel convenience helpers
-(int)tabCount;
-(int)selectedTabIndex;
-(TabContents*)selectedTabContents;
-(TabContents*)tabContentsAtIndex:(int)index;
-(void)selectTabContentsAtIndex:(int)index userGesture:(BOOL)userGesture;
-(void)closeAllTabs;

@end
