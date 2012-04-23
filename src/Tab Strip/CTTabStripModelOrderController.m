//
//  CTTabStripModelOrderController.m
//  chromium-tabs
//
// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.
//

#import "CTTabStripModelOrderController.h"
#import "CTTabContents.h"

@interface CTTabStripModelOrderController (PrivateMethods)
// Returns a valid index to be active after the tab at |removingIndex| is
// closed. If |index| is after |removingIndex|, |index| is adjusted to 
// reflect the fact that |removingIndex| is going away.
- (int)getValidIndex:(int)index
		 afterRemove:(int)removingIndex;
@end

@implementation CTTabStripModelOrderController {
	CTTabStripModel *tabStripModel_;
	
	InsertionPolicy insertionPolicy_;
}
@synthesize insertionPolicy = insertionPolicy_;

- (id)initWithTabStripModel:(CTTabStripModel *)tabStripModel {
    self = [super init];
    if (self) {
		tabStripModel_ = tabStripModel;
		insertionPolicy_ = INSERT_AFTER;
    }
    
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (int)determineInsertionIndexWithContents:(CTTabContents *)newContents
								transition:(CTPageTransition)transition
							  inForeground:(BOOL)foreground {
	int tab_count = [tabStripModel_ count];
	if (!tab_count)
		return 0;
	
	// NOTE: TabStripModel enforces that all non-mini-tabs occur after mini-tabs,
	// so we don't have to check here too.
	if (transition == CTPageTransitionLink &&
		[tabStripModel_ activeIndex] != -1) {
		int delta = (insertionPolicy_ == INSERT_AFTER) ? 1 : 0;
		if (foreground) {
			// If the page was opened in the foreground by a link click in another
			// tab, insert it adjacent to the tab that opened that link.
			return [tabStripModel_ activeIndex] + delta;
		}
		
		// Otherwise insert adjacent to opener...
		return [tabStripModel_ activeIndex] + delta;
	}
	// In other cases, such as Ctrl+T, open at the end of the strip.
	return [self determineInsertionIndexForAppending];	
}

- (int)determineInsertionIndexForAppending {
	return (insertionPolicy_ == INSERT_AFTER) ?
		[tabStripModel_ count] : 0;
}

- (int)determineNewSelectedIndexAfterClose:(int)removedIndex {
	int tab_count = [tabStripModel_ count];
	assert(removedIndex >= 0 && removedIndex < tab_count);
	
	// if the closing tab has a valid parentOpener tab, return its index
	CTTabContents* parentOpener =
	[tabStripModel_ tabContentsAtIndex:removedIndex].parentOpener;
	if (parentOpener) {
		int index = [tabStripModel_ indexOfTabContents:parentOpener];
		if (index != kNoTab)
			return [self getValidIndex:index
						   afterRemove:removedIndex];
	}
	
	// No opener set, fall through to the default handler...
	int activeIndex = [tabStripModel_ activeIndex];
	if (activeIndex >= (tab_count - 1))
		return activeIndex - 1;
	return activeIndex;
	
	// Chromium legacy code keept for documentation purposes
	/*NavigationController* parent_opener =
	 tabStripModel_->GetOpenerOfTabContentsAt(removing_index);
	 // First see if the index being removed has any "child" tabs. If it does, we
	 // want to select the first in that child group, not the next tab in the same
	 // group of the removed tab.
	 NavigationController* removed_controller =
	 &tabStripModel_->GetTabContentsAt(removing_index)->controller();
	 int index = tabStripModel_->GetIndexOfNextTabContentsOpenedBy(
	 removed_controller, removing_index, false);
	 if (index != TabStripModel::kNoTab)
	 return GetValidIndex(index, removing_index, is_remove);
	 
	 if (parent_opener) {
	 // If the tab was in a group, shift selection to the next tab in the group.
	 int index = tabStripModel_->GetIndexOfNextTabContentsOpenedBy(
	 parent_opener, removing_index, false);
	 if (index != TabStripModel::kNoTab)
	 return GetValidIndex(index, removing_index, is_remove);
	 
	 // If we can't find a subsequent group member, just fall back to the
	 // parent_opener itself. Note that we use "group" here since opener is
	 // reset by select operations..
	 index = tabStripModel_->GetIndexOfController(parent_opener);
	 if (index != TabStripModel::kNoTab)
	 return GetValidIndex(index, removing_index, is_remove);
	 }*/
}

#pragma mark private
///////////////////////////////////////////////////////////////////////////////
// CTTabStripModelOrderController, private:

- (int)getValidIndex:(int)index
		 afterRemove:(int)removingIndex {
	if (removingIndex < index)
		index = MAX(0, index - 1);
	return index;
}
@end
