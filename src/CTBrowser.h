#pragma once
#import <Cocoa/Cocoa.h>
#import "chrome/browser/tabs/tab_strip_model.h"
#import "TabStripModelDelegate.h"
#import "BrowserCommands.h"

enum CTWindowOpenDisposition {
  CURRENT_TAB,
  NEW_FOREGROUND_TAB,
  NEW_BACKGROUND_TAB,
};

class TabStripModel;
@class CTBrowserWindowController;

// There is one CTBrowser instance per percieved window.
// A CTBrowser instance has one TabStripModel.

@interface CTBrowser : NSObject <TabStripModelDelegate> {
  TabStripModel *tabStripModel_;
  CTBrowserWindowController *windowController_;
}

// The tab strip model
@property(readonly, nonatomic) TabStripModel* tabStripModel;

// The window controller
@property(readonly, nonatomic) CTBrowserWindowController* windowController;

// The window. Convenience for [windowController window]
@property(readonly, nonatomic) NSWindow* window;

// Create a new browser with a window. (autoreleased)
+(CTBrowser*)browser;
+(CTBrowser*)browserWithWindowFrame:(const NSRect)frame;

// Creates and opens a new window. (retained)
+(CTBrowser*)openEmptyWindow;

// Creates a new window controller. The default implementation will create a
// controller loaded with a nib called "BrowserWindow". If the nib can't be
// found in the main bundle, a fallback nib will be loaded from the framework.
// This is usually enough since all UI which normally is customized is comprised
// within each tab (CTTabContents view).
-(CTBrowserWindowController *)createWindowController;

// Commands
-(void)newWindow;
-(void)closeWindow;
-(CTTabContents*)addTabContents:(CTTabContents*)contents
                      atIndex:(int)index
                 inForeground:(BOOL)foreground;
-(CTTabContents*)addBlankTabAtIndex:(int)index inForeground:(BOOL)foreground;
-(CTTabContents*)addBlankTabInForeground:(BOOL)foreground;
-(CTTabContents*)addBlankTab; // InForeground:YES
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
-(void)executeCommand:(int)cmd; // withDisposition:CURRENT_TAB

// callbacks
-(void)loadingStateDidChange:(CTTabContents*)contents;
-(void)windowDidBeginToClose;

// Convenience helpers (proxy for TabStripModel)
-(int)tabCount;
-(int)selectedTabIndex;
-(CTTabContents*)selectedTabContents;
-(CTTabContents*)tabContentsAtIndex:(int)index;
-(void)selectTabContentsAtIndex:(int)index userGesture:(BOOL)userGesture;
-(void)closeAllTabs;

@end
