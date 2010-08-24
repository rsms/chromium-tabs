#import "WindowController.h"
#include "base/logging.h"

@implementation WindowController

- (id)initWithWindowNibName:(NSString *)windowNibName
			chromiumTabbedBrowser:(NSObject<ChromiumTabbedBrowser>*)browser {
	self = [super initWithWindowNibName:windowNibName];
	browser_ = [browser retain];
	return self;
}

-(void)dealloc {
	[browser_ release];
	[super dealloc];
}

#pragma mark -
#pragma mark TabStripModelDelegate protocol

// Adds what the delegate considers to be a blank tab to the model.
-(TabContents*)addBlankTab:(BOOL)foreground {
	DLOG(INFO) << "WindowController addBlankTab" << foreground;
	return NULL; // TODO
}

-(TabContents*)addBlankTabAt:(int)index foreground:(BOOL)foreground {
	DLOG(INFO) << "WindowController addBlankTabAt" << index << foreground;
	return NULL; // TODO
}

// Returns whether some contents can be duplicated.
-(BOOL)canDuplicateContentsAt:(int)index {
	DLOG(INFO) << "WindowController canDuplicateContentsAt" << index;
	return false;
}

// Duplicates the contents at the provided index and places it into its own
// window.
-(void)duplicateContentsAt:(int)index {
	DLOG(INFO) << "WindowController duplicateContentsAt" << index;
}

// Called when a drag session has completed and the frame that initiated the
// the session should be closed.
-(void)closeFrameAfterDragSession {
	DLOG(INFO) << "WindowController closeFrameAfterDragSession";
}

// Creates an entry in the historical tab database for the specified
// TabContents.
-(void)createHistoricalTab:(TabContents*)contents {
	DLOG(INFO) << "WindowController createHistoricalTab" << contents;
}

// Runs any unload listeners associated with the specified TabContents before
// it is closed. If there are unload listeners that need to be run, this
// function returns true and the TabStripModel will wait before closing the
// TabContents. If it returns false, there are no unload listeners and the
// TabStripModel can close the TabContents immediately.
-(BOOL)runUnloadListenerBeforeClosing:(TabContents*)contents {
	DLOG(INFO) << "WindowController runUnloadListenerBeforeClosing" << contents;
	return false;
}

// Returns true if a tab can be restored.
-(BOOL)canRestoreTab {
	DLOG(INFO) << "WindowController canRestoreTab";
	return false;
}

// Restores the last closed tab if CanRestoreTab would return true.
-(void)restoreTab {
	DLOG(INFO) << "WindowController restoreTab";
}

// Returns whether some contents can be closed.
-(BOOL)canCloseContentsAt:(int)index {
	DLOG(INFO) << "WindowController canCloseContentsAt" << index;
	return true;
}

// Returns true if any of the tabs can be closed.
-(BOOL)canCloseTab {
	DLOG(INFO) << "WindowController canCloseTab";
	return true;
}

@end
