//
//  CTTabStripModel.m
//  chromium-tabs
//
// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.
//

#import "CTTabStripModel.h"
#import "CTTabStripModelOrderController.h"
#import "CTPageTransition.h"

#import "CTTabContents.h"

@interface CTTabStripModel (PrivateMethods)
// Returns true if the specified CTTabContents is a New Tab at the end of the
// TabStrip. We check for this because opener relationships are _not_
// forgotten for the New Tab page opened as a result of a New Tab gesture
// (e.g. Ctrl+T, etc) since the user may open a tab transiently to look up
// something related to their current activity.
- (BOOL)isNewTabAtEndOfTabStrip:(CTTabContents *)contents;

// Closes the CTTabContents at the specified indices. This causes the
// CTTabContents to be destroyed, but it may not happen immediately.  If the
// page in question has an unload event the CTTabContents will not be destroyed
// until after the event has completed, which will then call back into this
// method.
//
// Returns true if the CTTabContents were closed immediately, false if we are
// waiting for the result of an onunload handler.
- (BOOL)internalCloseTabs:(NSArray *)indices
			   closeTypes:(uint32)closeTypes;

// Invoked from InternalCloseTabs and when an extension is removed for an app
// tab. Notifies observers of TabClosingAt and deletes |contents|. If
// |createHistoricalTabs| is true, CreateHistoricalTab is invoked on the
// delegate.
//
// The boolean parameter create_historical_tab controls whether to
// record these tabs and their history for reopening recently closed
// tabs.
- (void)internalCloseTab:(CTTabContents *)contents
				 atIndex:(int)index
	 createHistoricalTab:(BOOL)createHistoricalTabs;

// The actual implementation of SelectTabContentsAt. Takes the previously
// active contents in |old_contents|, which may actually not be in
// |contents_| anymore because it may have been removed by a call to say
// DetachTabContentsAt...
- (void)changeSelectedContentsFrom:(CTTabContents *)oldContents
						   toIndex:(int)toIndex
					   userGesture:(BOOL)userGesture;

// Returns the number of New Tab tabs in the TabStripModel.
//- (int)newTabCount;

// Selects either the next tab (|foward| is true), or the previous tab
// (|forward| is false).
- (void)selectRelativeTab:(BOOL)forward;

// Does the work of MoveTabContentsAt. This has no checks to make sure the
// position is valid, those are done in MoveTabContentsAt.
- (void)moveTabContentsAtImpl:(int)index
				   toPosition:(int)toPosition
			  selectAfterMove:(BOOL)selectAfterMove;

// Does the work for ReplaceTabContentsAt returning the old CTTabContents.
// The caller owns the returned CTTabContents.
- (CTTabContents *)replaceTabContentsAtImpl:(int)index
							   withContents:(CTTabContents *)newContents;
@end

@interface TabContentsData : NSObject {
@public
    CTTabContents* contents;
	BOOL isPinned;
	BOOL isBlocked;
}
@end

@implementation TabContentsData

@end

@implementation CTTabStripModel {
	// Our delegate.
    NSObject<CTTabStripModelDelegate> *delegate_;
	
	// The CTTabContents data currently hosted within this TabStripModel.
	NSMutableArray *contentsData_;
	
	// The index of the CTTabContents in |contents_| that is currently active.
	int activeIndex_;
	
	// A profile associated with this TabStripModel, used when creating new Tabs.
	//Profile* profile_;
	
	// True if all tabs are currently being closed via CloseAllTabs.
	BOOL closingAll_;
	
	// An object that determines where new Tabs should be inserted and where
	// selection should move when a Tab is closed.
	CTTabStripModelOrderController *orderController_;
}

@synthesize delegate = delegate_;
@synthesize activeIndex = activeIndex_;
@synthesize closingAll = closingAll_;

NSString* const CTTabInsertedNotification = @"CTTabInsertedNotification";
NSString* const CTTabClosingNotification = @"CTTabClosingNotification";
NSString* const CTTabDetachedNotification = @"CTTabDetachedNotification";
NSString* const CTTabDeselectedNotification = @"CTTabDeselectedNotification";
NSString* const CTTabSelectedNotification = @"CTTabSelectedNotification";
NSString* const CTTabMovedNotification = @"CTTabMovedNotification";
NSString* const CTTabChangedNotification = @"CTTabChangedNotification";
NSString* const CTTabReplacedNotification = @"CTTabReplacedNotification";
NSString* const CTTabPinnedStateChangedNotification = @"CTTabPinnedStateChangedNotification";
NSString* const CTTabBlockedStateChangedNotification = @"CTTabBlockedStateChangedNotification";
NSString* const CTTabMiniStateChangedNotification = @"CTTabMiniStateChangedNotification";
NSString* const CTTabStripEmptyNotification = @"CTTabStripEmptyNotification";
NSString* const CTTabStripModelDeletedNotification = @"CTTabStripModelDeletedNotification";

NSString* const CTTabContentsUserInfoKey = @"CTTabContentsUserInfoKey";
NSString* const CTTabNewContentsUserInfoKey = @"CTTabNewContentsUserInfoKey";
NSString* const CTTabIndexUserInfoKey = @"CTTabIndexUserInfoKey";
NSString* const CTTabToIndexUserInfoKey = @"CTTabToIndexUserInfoKey";
NSString* const CTTabForegroundUserInfoKey = @"CTTabForegroundUserInfoKey";
NSString* const CTTabUserGestureUserInfoKey = @"CTTaUserGestureUserInfoKey";
NSString* const CTTabOptionsUserInfoKey = @"CTTaOptionsInfoKey";

const int kNoTab = NSNotFound;

- (id)initWithDelegate:(NSObject <CTTabStripModelDelegate>*)delegate {
	self = [super init];
	if (self) {	
		contentsData_ = [[NSMutableArray alloc] init];
		activeIndex_ = kNoTab;
		closingAll_ = NO;
		
		delegate_ = delegate; // weak
		// TODO replace with nsnotificationcenter?
		/*registrar_.Add(this,
		 NotificationType::TAB_CONTENTS_DESTROYED,
		 NotificationService::AllSources());
		 registrar_.Add(this,
		 NotificationType::EXTENSION_UNLOADED);*/
		orderController_ = [[CTTabStripModelOrderController alloc] initWithTabStripModel:self];
		
	}

	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabStripModelDeletedNotification 
														object:self];
}

#pragma mark -
#pragma mark getters/setters
- (NSUInteger)count {
	return [contentsData_ count];
}

// Sets the insertion policy. Default is INSERT_AFTER.
- (void)setInsertionPolicy:(InsertionPolicy)policy {
	[orderController_ setInsertionPolicy:policy];
}

- (InsertionPolicy)insertionPolicy {
	return orderController_.insertionPolicy;
}

#pragma mark -
#pragma mark Basic API
- (BOOL)containsIndex:(NSInteger)index {
    return index >= 0 && index < [self count];
}

- (void)appendTabContents:(CTTabContents *)contents
			 inForeground:(BOOL)foreground {
	int index = [orderController_ determineInsertionIndexForAppending];
	[self insertTabContents:contents 
					atIndex:index 
			   withAddTypes:foreground ? (ADD_INHERIT_GROUP | ADD_ACTIVE) :
	 ADD_NONE];
}

- (void)insertTabContents:(CTTabContents *)contents
				  atIndex:(int)index 
			 withAddTypes:(int)addTypes {
	BOOL foreground = addTypes & ADD_ACTIVE;
	// Force app tabs to be pinned.
	BOOL pin = contents.isApp || addTypes & ADD_PINNED;
	index = [self constrainInsertionIndex:index 
								  miniTab:pin];
	
	// In tab dragging situations, if the last tab in the window was detached
	// then the user aborted the drag, we will have the |closing_all_| member
	// set (see DetachTabContentsAt) which will mess with our mojo here. We need
	// to clear this bit.
	closingAll_ = NO;
	
	// Have to get the active contents before we monkey with |contents_|
	// otherwise we run into problems when we try to change the active contents
	// since the old contents and the new contents will be the same...
	CTTabContents* activeContents = [self activeTabContents];
	TabContentsData* data = [[TabContentsData alloc] init];
	data->contents = contents;
	data->isPinned = pin;
	
	[contentsData_ insertObject:data atIndex:index];
	
	if (index <= activeIndex_) {
		// If a tab is inserted before the current active index,
		// then |activeIndex| needs to be incremented.
		++activeIndex_;
	}
	
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              contents, CTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
                              [NSNumber numberWithBool:foreground], CTTabForegroundUserInfoKey, 
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabInsertedNotification 
														object:self 
													  userInfo:userInfo];
	
	if (foreground)
		[self changeSelectedContentsFrom:activeContents
								 toIndex:index
							 userGesture:NO];
}


- (void)replaceTabContentsAtIndex:(int)index 
					withContents:(CTTabContents *)newContents {
	[self replaceTabContentsAtImpl:index
					  withContents:newContents];
}

- (CTTabContents *)detachTabContentsAtIndex:(int)index {
	if ([contentsData_ count] == 0)
		return NULL;
	
	assert([self containsIndex:index]);
	
	CTTabContents* removedContents = [self tabContentsAtIndex:index];
	int nextActiveIndex =
		[orderController_ determineNewSelectedIndexAfterClose:index];
	[contentsData_ removeObjectAtIndex:index];
	if ([self count] > 0)
		closingAll_ = YES;
	
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              removedContents, CTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabDetachedNotification 
														object:self 
													  userInfo:userInfo];
    if (![self count]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CTTabStripEmptyNotification 
															object:self 
														  userInfo:nil];
    }
	if ([self count] > 0) {
		if (index == activeIndex_) {
			[self changeSelectedContentsFrom:removedContents
									 toIndex:nextActiveIndex
								 userGesture:NO];
		} else if (index < activeIndex_) {
			// The active tab didn't change, but its position shifted; update our
			// index to continue to point at it.
			--activeIndex_;
		}
	}
	return removedContents;
}

- (void)selectTabContentsAtIndex:(int)index 
					 userGesture:(BOOL)userGesture {
	if ([self containsIndex:index]) {
		[self changeSelectedContentsFrom:[self activeTabContents]
								 toIndex:index
							 userGesture:userGesture];
	} else {
		DLOG("[ChromiumTabs] internal inconsistency: !ContainsIndex(index) in %s",
			 __PRETTY_FUNCTION__);
	}
}

- (void)moveTabContentsAtIndex:(int)index 
					   toIndex:(int)toPosition 
			   selectAfterMove:(BOOL)selectAfterMove {
	assert([self containsIndex:index]);
	if (index == toPosition)
		return;
	
	int firstNonMiniTab = [self indexOfFirstNonMiniTab];
	if ((index < firstNonMiniTab && toPosition >= firstNonMiniTab) ||
		(toPosition < firstNonMiniTab && index >= firstNonMiniTab)) {
		// This would result in mini tabs mixed with non-mini tabs. We don't allow
		// that.
		return;
	}
	
	[self moveTabContentsAtImpl:index
					 toPosition:toPosition
				selectAfterMove:selectAfterMove];
}

- (CTTabContents *)activeTabContents {
	return [self tabContentsAtIndex:activeIndex_];
}

- (CTTabContents *)tabContentsAtIndex:(int)index {
    if ([self containsIndex:index]) {
		TabContentsData* data = [contentsData_ objectAtIndex:index];
		return data->contents;
    }
    return nil;
}

- (int)indexOfTabContents:(const CTTabContents *)contents {
	int index = 0;
    for (TabContentsData* data in contentsData_) {
        if (data->contents == contents) {
            return index;
        }
        index++;
    }
	
	return kNoTab;
}

- (void)updateTabContentsStateAtIndex:(int)index 
						   changeType:(CTTabChangeType)changeType {
	assert([self containsIndex:index]);
	
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  [self tabContentsAtIndex:index], CTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
                              [NSNumber numberWithInt:changeType], CTTabOptionsUserInfoKey, 
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabChangedNotification 
														object:self 
													  userInfo:userInfo];
}

- (void)closeAllTabs {
	closingAll_ = YES;
	NSMutableArray *closing_tabs = [NSMutableArray array];
	for (int i = [self count] - 1; i >= 0; --i)
		[closing_tabs addObject:[NSNumber numberWithInt:i]];
	[self internalCloseTabs:closing_tabs closeTypes:CLOSE_CREATE_HISTORICAL_TAB];
}

- (BOOL)closeTabContentsAtIndex:(int)index 
				 closeTypes:(uint32)closeTypes {
	return [self internalCloseTabs:[NSArray arrayWithObject:[NSNumber numberWithInt:index]]
						closeTypes:closeTypes];
}

- (BOOL)tabsAreLoading {
	for (TabContentsData *data in contentsData_) {
		if (data->contents.isLoading)
			return YES;
	}
	return NO;
}

- (void)tabNavigating:(CTTabContents *)contents
	   withTransition:(CTPageTransition)transition {
	
}

- (void)setTabAtIndex:(int)index 
			  blocked:(BOOL)blocked {
	assert([self containsIndex:index]);
	TabContentsData *data = [contentsData_ objectAtIndex:index];
	CTTabContents *contents = data->contents;
	if (data->isBlocked == blocked) {
		return;
	}
	data->isBlocked = blocked;
	
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  contents, CTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
                              [NSNumber numberWithInt:blocked], CTTabOptionsUserInfoKey, 
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabBlockedStateChangedNotification
														object:self 
													  userInfo:userInfo];
}

- (void)setTabAtIndex:(int)index 
			   pinned:(BOOL)pinned {
	TabContentsData *data = [contentsData_ objectAtIndex:index];
	CTTabContents *contents = data->contents;
	if (data->isPinned == pinned)
		return;
	
	if ([self isAppTabAtIndex:index]) {
		if (!pinned) {
			// App tabs should always be pinned.
			NOTREACHED();
			return;
		}
		// Changing the pinned state of an app tab doesn't effect it's mini-tab
		// status.
		data->isPinned = pinned;
	} else {
		// The tab is not an app tab, it's position may have to change as the
		// mini-tab state is changing.
		int non_miniTab_index = [self indexOfFirstNonMiniTab];
		data->isPinned = pinned;
		if (pinned && index != non_miniTab_index) {
			[self moveTabContentsAtImpl:index toPosition:non_miniTab_index selectAfterMove:NO];
			return;  // Don't send TabPinnedStateChanged notification.
		} else if (!pinned && index + 1 != non_miniTab_index) {
			[self moveTabContentsAtImpl:index toPosition:non_miniTab_index - 1 selectAfterMove:NO];
			return;  // Don't send TabPinnedStateChanged notification.
		}
	
	    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  contents, CTTabContentsUserInfoKey,
								  [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
								  nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:CTTabMiniStateChangedNotification
															object:self 
														  userInfo:userInfo];
	}
	
	// else: the tab was at the boundary and it's position doesn't need to
	// change.
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  contents, CTTabContentsUserInfoKey,
							  [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
							  [NSNumber numberWithInt:pinned], CTTabOptionsUserInfoKey, 
							  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:CTTabPinnedStateChangedNotification
														object:self
													  userInfo:userInfo];
}

- (BOOL)isTabPinnedAtIndex:(int)index {
	return ((TabContentsData *)[contentsData_ objectAtIndex:index])->isPinned;
}

- (BOOL)isMiniTabAtIndex:(int)index {
	return [self isTabPinnedAtIndex:index] || [self isAppTabAtIndex:index];
}

- (BOOL)isAppTabAtIndex:(int)index {
	CTTabContents* contents = [self tabContentsAtIndex:index];
	return contents && contents.isApp;
}

- (BOOL)isTabBlockedAtIndex:(int)index {
	return ((TabContentsData *)[contentsData_ objectAtIndex:index])->isBlocked;
}

- (int)indexOfFirstNonMiniTab {
	for (int i = 0; i < [contentsData_ count]; ++i) {
		if (![self isMiniTabAtIndex:i])
			return i;
	}
	// No non-mini-tabs.
	return [self count];
}

- (int)constrainInsertionIndex:(int)index 
					   miniTab:(BOOL)miniTab {
//	return miniTab ? std::min(std::max(0, index), [self IndexOfFirstNonMiniTab]) :
//	std::min([self count], std::max(index, [self IndexOfFirstNonMiniTab]));
    return miniTab ? MIN(MAX(0, index), [self indexOfFirstNonMiniTab]) : MIN(self.count, MAX(index, [self indexOfFirstNonMiniTab]));
}

#pragma mark -
#pragma mark Command level API
- (int)addTabContents:(CTTabContents *)contents 
			  atIndex:(int)index
	   withTransition:(CTPageTransition)transition
			 addTypes:(int)addTypes {
	// If the newly-opened tab is part of the same task as the parent tab, we want
	// to inherit the parent's "group" attribute, so that if this tab is then
	// closed we'll jump back to the parent tab.
	BOOL inherit_group = (addTypes & ADD_INHERIT_GROUP) == ADD_INHERIT_GROUP;
	
	if (transition == CTPageTransitionLink &&
		(addTypes & ADD_FORCE_INDEX) == 0) {
		// We assume tabs opened via link clicks are part of the same task as their
		// parent.  Note that when |force_index| is true (e.g. when the user
		// drag-and-drops a link to the tab strip), callers aren't really handling
		// link clicks, they just want to score the navigation like a link click in
		// the history backend, so we don't inherit the group in this case.
		index = [orderController_ determineInsertionIndexWithContents:contents
															transition:transition
														  inForeground:addTypes & ADD_ACTIVE];
		inherit_group = YES;
	} else {
		// For all other types, respect what was passed to us, normalizing -1s and
		// values that are too large.
		if (index < 0 || index > [self count])
			index = [orderController_ determineInsertionIndexForAppending];
	}
	
	if (transition == CTPageTransitionTyped && index == [self count]) {
		// Also, any tab opened at the end of the TabStrip with a "TYPED"
		// transition inherit group as well. This covers the cases where the user
		// creates a New Tab (e.g. Ctrl+T, or clicks the New Tab button), or types
		// in the address bar and presses Alt+Enter. This allows for opening a new
		// Tab to quickly look up something. When this Tab is closed, the old one
		// is re-selected, not the next-adjacent.
		inherit_group = YES;
	}
	[self insertTabContents:contents 
					atIndex:index 
			   withAddTypes:addTypes | (inherit_group ? ADD_INHERIT_GROUP : 0)];
	// Reset the index, just in case insert ended up moving it on us.
	index = [self indexOfTabContents:contents];
		
	return index;
}

- (void)closeActiveTab {
	[self closeTabContentsAtIndex:activeIndex_
				   closeTypes:CLOSE_CREATE_HISTORICAL_TAB];
}

- (void)selectNextTab {
	[self selectRelativeTab:YES];
}

- (void)selectPreviousTab {
	[self selectRelativeTab:NO];
}

- (void)selectLastTab {
	[self selectTabContentsAtIndex:[self count]-1 
					   userGesture:YES];
}

- (void)moveTabNext {
	int newIndex = MIN(activeIndex_ + 1, [self count] - 1);
	[self moveTabContentsAtIndex:activeIndex_ 
						 toIndex:newIndex
				 selectAfterMove:YES];
}

- (void)moveTabPrevious {
	int newIndex = MAX(activeIndex_ - 1, 0);
	[self moveTabContentsAtIndex:activeIndex_
						 toIndex:newIndex
				 selectAfterMove:YES];
}

#pragma mark -
#pragma mark View API
- (BOOL)isContextMenuCommandEnabled:(int)contextIndex
						  commandID:(ContextMenuCommand)commandID {
	assert(commandID > CommandFirst && commandID < CommandLast);
	CTTabContents* contents;
	switch (commandID) {
		case CommandNewTab:
		case CommandCloseTab:
			return [delegate_ canCloseTab];
		case CommandReload:
			contents = [self tabContentsAtIndex:contextIndex];
			if (contents) {
				id delegate = contents.delegate;
				if ([delegate respondsToSelector:@selector(canReloadContents:)]) {
					return [delegate canReloadContents:contents];
				} else {
					return NO;
				}
			} else {
				return NO;
			}
		case CommandCloseOtherTabs: {
			int miniTabCount = [self indexOfFirstNonMiniTab];
			int nonMiniTabCount = [self count] - miniTabCount;
			// Close other doesn't effect mini-tabs.
			return nonMiniTabCount > 1 ||
			(nonMiniTabCount == 1 && contextIndex != miniTabCount);
		}
		case CommandCloseTabsToRight:
			// Close doesn't effect mini-tabs.
			return [self count] != [self indexOfFirstNonMiniTab] &&
			contextIndex < ([self count] - 1);
		case CommandDuplicate:
			return [delegate_ canDuplicateContentsAt:contextIndex];
		case CommandRestoreTab:
			return [delegate_ canRestoreTab];
		case CommandTogglePinned:
			return ![self isAppTabAtIndex:contextIndex];
		default:
			NOTREACHED();
	}
	return NO;
}

- (BOOL)isContextMenuCommandChecked:(int)contextIndex
						  commandID:(ContextMenuCommand)commandID {
	switch (commandID) {
		default:
			NOTREACHED();
			break;
	}
	return NO;
}

- (void)executeContextMenuCommand:(int)contextIndex
						commandID:(ContextMenuCommand)commandID {
	assert(commandID > CommandFirst && commandID < CommandLast);
	switch (commandID) {
		case CommandNewTab:
			[delegate_ addBlankTabAtIndex:contextIndex+1 inForeground:YES];
			//delegate()->AddBlankTabAt(contextIndex + 1, true);
			break;
		case CommandReload:
			[[self tabContentsAtIndex:contextIndex].delegate reload];
			break;
		case CommandDuplicate:
			[delegate_ duplicateContentsAt:contextIndex];
			//delegate_->DuplicateContentsAt(contextIndex);
			break;
		case CommandCloseTab:
			[self closeTabContentsAtIndex:contextIndex
						   closeTypes:CLOSE_CREATE_HISTORICAL_TAB |
							   CLOSE_USER_GESTURE];
			break;
		case CommandCloseOtherTabs: {
			[self internalCloseTabs:[self getIndicesClosedByCommand:commandID 
													  forTabAtIndex:contextIndex]
						 closeTypes:CLOSE_CREATE_HISTORICAL_TAB];
			break;
		}
		case CommandCloseTabsToRight: {
			[self internalCloseTabs:[self getIndicesClosedByCommand:commandID 
													  forTabAtIndex:contextIndex]
						 closeTypes:CLOSE_CREATE_HISTORICAL_TAB];
			break;
		}
		case CommandRestoreTab: {
			[delegate_ restoreTab];
			//delegate_->RestoreTab();
			break;
		}
		case CommandTogglePinned: {
			[self selectTabContentsAtIndex:contextIndex
							   userGesture:YES];
			[self setTabAtIndex:contextIndex 
						 pinned:![self isTabPinnedAtIndex:contextIndex]];
			break;
		}

		default:
			NOTREACHED();
	}
}

- (NSArray *)getIndicesClosedByCommand:(ContextMenuCommand)commandID
						 forTabAtIndex:(int)index {
	assert([self containsIndex:index]);
	
	// NOTE: some callers assume indices are sorted in reverse order.
	NSMutableArray *indices = [NSMutableArray array];
	
	if (commandID != CommandCloseTabsToRight && commandID != CommandCloseOtherTabs)
		return indices;
	
	int start = (commandID == CommandCloseTabsToRight) ? index + 1 : 0;
	for (int i = [self count] - 1; i >= start; --i) {
		if (i != index && ![self isMiniTabAtIndex:i])
			[indices addObject:[NSNumber numberWithInt:i]];
	}
	return indices;
}

- (void)tabContentsWasDestroyed:(CTTabContents *)contents {
	int index = [self indexOfTabContents:contents];
	if (index != kNoTab) {
		// Note that we only detach the contents here, not close it - it's
		// already been closed. We just want to undo our bookkeeping.
		[self detachTabContentsAtIndex:index];
	}
}
	
#pragma mark -
#pragma mark Private methods
- (BOOL)isNewTabAtEndOfTabStrip:(CTTabContents *)contents {
	return !contents || contents == [self tabContentsAtIndex:([self count] - 1)];
	/*return LowerCaseEqualsASCII(contents->GetURL().spec(),
	 chrome::kChromeUINewTabURL) &&
	 contents == GetContentsAt(count() - 1) &&
	 contents->controller().entry_count() == 1;*/
}

- (BOOL)internalCloseTabs:(NSArray *)indices
			   closeTypes:(uint32)closeTypes {
	BOOL retval = YES;
		
	// We now return to our regularly scheduled shutdown procedure.
	for (size_t i = 0; i < indices.count; ++i) {
		int index = [[indices objectAtIndex:i] intValue];
		CTTabContents* detachedContents = [self tabContentsAtIndex:index];
		[detachedContents closingOfTabDidStart:self]; // TODO notification
		
		if (![delegate_ canCloseContentsAt:index]) {
			retval = NO;
			continue;
		}
		
		// Update the explicitly closed state. If the unload handlers cancel the
		// close the state is reset in CTBrowser. We don't update the explicitly
		// closed state if already marked as explicitly closed as unload handlers
		// call back to this if the close is allowed.
		if (!detachedContents.closedByUserGesture) {
			detachedContents.closedByUserGesture = closeTypes & CLOSE_USER_GESTURE;
		}
		
		if ([delegate_ runUnloadListenerBeforeClosing:detachedContents]) {
			retval = NO;
			continue;
		}
		
		[self internalCloseTab:detachedContents
					   atIndex:index
		   createHistoricalTab:((closeTypes & CLOSE_CREATE_HISTORICAL_TAB) != 0)];
	}
	
	return retval;	
}

- (void)internalCloseTab:(CTTabContents *)contents
				 atIndex:(int)index
	 createHistoricalTab:(BOOL)createHistoricalTabs {
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              contents, CTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabClosingNotification 
														object:self 
													  userInfo:userInfo];
	
	// Ask the delegate to save an entry for this tab in the historical tab
	// database if applicable.
	if (createHistoricalTabs) {
		[delegate_ createHistoricalTab:contents];
	}
	
	// Deleting the CTTabContents will call back to us via NotificationObserver
	// and detach it.
	[self detachTabContentsAtIndex:index];
}


- (void)changeSelectedContentsFrom:(CTTabContents *)oldContents
						   toIndex:(int)toIndex
					   userGesture:(BOOL)userGesture {
	assert([self containsIndex:toIndex]);
	CTTabContents* newContents = [self tabContentsAtIndex:toIndex];
	if (oldContents == newContents)
		return;

	activeIndex_ = toIndex;
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              newContents, CTTabNewContentsUserInfoKey,
                              [NSNumber numberWithInt:self.activeIndex], CTTabIndexUserInfoKey,
                              [NSNumber numberWithBool:userGesture], CTTabUserGestureUserInfoKey,
                              oldContents, CTTabContentsUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabSelectedNotification 
														object:self 
													  userInfo:userInfo];
}

// Selects either the next tab (|foward| is true), or the previous tab
// (|forward| is NO).
- (void)selectRelativeTab:(BOOL)forward {
	// This may happen during automated testing or if a user somehow buffers
	// many key accelerators.
	if ([contentsData_ count] == 0)
		return;
	
	int index = activeIndex_;
	int delta = forward ? 1 : -1;
	index = (index + [self count] + delta) % [self count];
	
	[self selectTabContentsAtIndex:index 
					   userGesture:YES];
}

- (void)moveTabContentsAtImpl:(int)index
				   toPosition:(int)toPosition
			  selectAfterMove:(BOOL)selectAfterMove {
	TabContentsData* movedData = [contentsData_ objectAtIndex:index];
	[contentsData_ removeObjectAtIndex:index];
	[contentsData_ insertObject:movedData atIndex:toPosition];
	
	// if !selectAfterMove, keep the same tab active as was active before.
	if (selectAfterMove || index == activeIndex_) {
		activeIndex_ = toPosition;
	} else if (index < activeIndex_ && toPosition >= activeIndex_) {
		activeIndex_--;
	} else if (index > activeIndex_ && toPosition <= activeIndex_) {
		activeIndex_++;
	}
	
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              movedData->contents, CTTabNewContentsUserInfoKey,
                              [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
                              [NSNumber numberWithInt:toPosition], CTTabToIndexUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabMovedNotification 
														object:self 
													  userInfo:userInfo];
}

- (CTTabContents *)replaceTabContentsAtImpl:(int)index
							   withContents:(CTTabContents *)newContents {
	assert([self containsIndex:index]);
	CTTabContents* oldContents = [self tabContentsAtIndex:index];
	TabContentsData* data = [contentsData_ objectAtIndex:index];
	data->contents = newContents;
	
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              oldContents, CTTabContentsUserInfoKey,
                              newContents, CTTabNewContentsUserInfoKey,
                              [NSNumber numberWithInt:index], CTTabIndexUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:CTTabReplacedNotification 
														object:self 
													  userInfo:userInfo];
	return oldContents;
}
@end
