#pragma once
#import <Cocoa/Cocoa.h>

@class CTTabStripModel;
@class CTBrowser;

extern NSString *const CTTabContentsDidCloseNotification;

//
// Visibility states:
//
// - isVisible:  if the tab is visible (on screen). You may implement the
//               callbacks in order to enable/disable "background" tasks like
//               animations.
//               Callbacks:
//               - tabDidBecomeVisible
//               - tabDidResignVisible
//
// - isActive:   if the tab is the active tab in its window. Note that a tab
//               can be active withouth being visible (i.e. the window is
//               minimized or the app is hidden). If your tabs contain
//               user-interactive components, you should save and restore focus
//               by sublcassing the callbacks.
//               Callbacks:
//               - tabDidBecomeActive
//               - tabDidResignActive
//
// - isKey:      if the tab has the users focus. Only one tab in the application
//               can be key at a given time. (Note that the OS will automatically
//               restore any focus to user-interactive components.)
//               Callbacks:
//               - tabDidBecomeKey
//               - tabDidResignKey
//

@interface CTTabContents : NSDocument {
	BOOL isApp_;
	BOOL isLoading_;
	BOOL isWaitingForResponse_;
	BOOL isCrashed_;
	BOOL isVisible_;
	BOOL isActive_;
	BOOL isTeared_; // YES while being "teared" (dragged between windows)
	BOOL isPinned_;
	BOOL isBlocked_;
	id delegate_;
	unsigned int closedByUserGesture_; // TabStripModel::CloseTypes
	NSView *view_; // the actual content
	NSString *title_; // title of this tab
	NSImage *icon_; // tab icon (nil means no or default icon)
	CTBrowser *browser_;
	CTTabContents* parentOpener_; // the tab which opened this tab (unless nil)
}

@property(assign, nonatomic) BOOL isApp;
@property(assign, nonatomic) BOOL isLoading;
@property(assign, nonatomic) BOOL isCrashed;
@property(assign, nonatomic) BOOL isWaitingForResponse;
@property(assign, nonatomic, setter = setVisible:) BOOL isVisible;
@property(assign, nonatomic, setter = setActive:) BOOL isActive;
@property(assign, nonatomic, setter = setTeared:) BOOL isTeared;
@property(retain, nonatomic) id delegate;
@property(assign, nonatomic) unsigned int closedByUserGesture;
@property(retain, nonatomic) IBOutlet NSView *view;
@property(retain, nonatomic) NSString *title;
@property(retain, nonatomic) NSImage *icon;
@property(retain, nonatomic) CTBrowser *browser;
@property(strong, nonatomic) CTTabContents* parentOpener;

// If this returns YES, special icons like throbbers and "crashed" is
// displayed, even if |icon| is nil. By default this returns YES.
@property(readonly, nonatomic) BOOL hasIcon;

// Initialize a new CTTabContents object.
// The default implementation does nothing with |baseContents| but subclasses
// can use |baseContents| (the active CTTabContents, if any) to perform
// customized initialization.
-(id)initWithBaseTabContents:(CTTabContents*)baseContents;

// Called when the tab should be destroyed (involves some finalization).
//-(void)destroy:(CTTabStripModel *)sender;

#pragma mark Action

// Selects the tab in it's window and brings the window to front
- (void)makeKeyAndOrderFront:(id)sender;

// Give first-responder status to view_ if isVisible
- (BOOL)becomeFirstResponder;


#pragma mark -
#pragma mark Callbacks

// Called when this tab may be closing (unless CTBrowser respond no to
// canCloseTab).
-(void)closingOfTabDidStart:(CTTabStripModel *)model;

// The following three callbacks are meant to be implemented by subclasses:
// Called when this tab was inserted into a browser
- (void)tabDidInsertIntoBrowser:(CTBrowser*)browser
                        atIndex:(NSInteger)index
                   inForeground:(BOOL)foreground;
// Called when this tab replaced another tab
- (void)tabReplaced:(CTTabContents*)oldContents
          inBrowser:(CTBrowser*)browser
            atIndex:(NSInteger)index;
// Called when this tab is about to close
- (void)tabWillCloseInBrowser:(CTBrowser*)browser atIndex:(NSInteger)index;
// Called when this tab was removed from a browser
- (void)tabDidDetachFromBrowser:(CTBrowser*)browser atIndex:(NSInteger)index;

// The following callbacks called when the tab's visible state changes. If you
// override, be sure and invoke super's implementation. See "Visibility states"
// in the header of this file for details.

// Called when this tab become visible on screen. This is a good place to resume
// animations.
-(void)tabDidBecomeVisible;

// Called when this tab is no longer visible on screen. This is a good place to
// pause animations.
-(void)tabDidResignVisible;

// Called when this tab is about to become the active tab. Followed by a call
// to |tabDidBecomeActive|
-(void)tabWillBecomeActive;

// Called when this tab is about to resign as the active tab. Followed by a
// call to |tabDidResignActive|
-(void)tabWillResignActive;

// Called when this tab became the active tab in its window. This does
// neccessarily not mean it's visible (app might be hidden or window might be
// minimized). The default implementation makes our view the first responder, if
// visible.
-(void)tabDidBecomeActive;

// Called when another tab in our window "stole" the selection.
-(void)tabDidResignActive;

// Called when this tab is about to being "teared" (when dragging a tab from one
// window to another).
-(void)tabWillBecomeTeared;

// Called when this tab is teared and is about to "land" into a window.
-(void)tabWillResignTeared;

// Called when this tab was teared and just landed in a window. The default
// implementation makes our view the first responder, restoring focus.
-(void)tabDidResignTeared;

// Called when the frame has changed, which isn't too often.
// There are at least two cases when it's called:
// - When the tab's view is first inserted into the view hiearchy
// - When a torn off tab is moves into a window with other dimensions than the
//   initial window.
-(void)viewFrameDidChange:(NSRect)newFrame;

@end

@protocol TabContentsDelegate
-(BOOL)canReloadContents:(CTTabContents*)contents;
-(BOOL)reload; // should set contents->isLoading_ = YES
@end

