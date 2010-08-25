#pragma once

@class Browser;
#import "TabContents.h"

enum {
	TAB_MOVE_ACTION = 1,
	TAB_TEAROFF_ACTION = 2
};

@protocol TabStripModelDelegate
// Adds what the delegate considers to be a blank tab to the model.
-(TabContents*)addBlankTab:(BOOL)foreground;
-(TabContents*)addBlankTabAt:(int)index foreground:(BOOL)foreground;

// Asks for a new TabStripModel to be created and the given tab contents to
// be added to it. Its size and position are reflected in |window_bounds|.
// If |dock_info|'s type is other than NONE, the newly created window should
// be docked as identified by |dock_info|. Returns the Browser object
// representing the newly created window and tab strip. This does not
// show the window, it's up to the caller to do so.
-(Browser*)createNewStripWithContents:(TabContents*)contents
												 windowBounds:(const NSRect)windowBounds
														 maximize:(BOOL)maximize;

// Creates a new Browser object and window containing the specified
// |contents|, and continues a drag operation that began within the source
// window's tab strip. |window_bounds| are the bounds of the source window in
// screen coordinates, used to place the new window, and |tab_bounds| are the
// bounds of the dragged Tab view in the source window, in screen coordinates,
// used to place the new Tab in the new window.
-(void)continueDraggingDetachedTab:(TabContents*)contents
											windowBounds:(const NSRect)windowBounds
											   tabBounds:(const NSRect)tabBounds;

// Returns whether some contents can be duplicated.
-(BOOL)canDuplicateContentsAt:(int)index;

// Duplicates the contents at the provided index and places it into its own
// window.
-(void)duplicateContentsAt:(int)index;

// Called when a drag session has completed and the frame that initiated the
// the session should be closed.
-(void)closeFrameAfterDragSession;

// Creates an entry in the historical tab database for the specified
// TabContents.
-(void)createHistoricalTab:(TabContents*)contents;

// Runs any unload listeners associated with the specified TabContents before
// it is closed. If there are unload listeners that need to be run, this
// function returns true and the TabStripModel will wait before closing the
// TabContents. If it returns false, there are no unload listeners and the
// TabStripModel can close the TabContents immediately.
-(BOOL)runUnloadListenerBeforeClosing:(TabContents*)contents;

// Returns true if a tab can be restored.
-(BOOL)canRestoreTab;

// Restores the last closed tab if CanRestoreTab would return true.
-(void)restoreTab;

// Returns whether some contents can be closed.
-(BOOL)canCloseContentsAt:(int)index;

// Returns true if any of the tabs can be closed.
-(BOOL)canCloseTab;

@end  // @protocol TabStripModelDelegate
