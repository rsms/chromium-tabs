//
//  CTTabStripModel.h
//  chromium-tabs
//
//  Created by KOed on 11-4-2.
// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import <Foundation/Foundation.h>

#import <vector>

#import "CTPageTransition.h"
#import "observer_list.h"

#import "CTTabStripModelDelegate.h"
#import "CTTabStripModelProtocol.h"

@class CTTabStripModelOrderController;
@class CTTabContents;

extern const int kNoTab;

typedef std::vector<CTTabContents*> TabContentsDataVector;
typedef ObserverList<NSObject <CTTabStripModelObserver> > TabStripModelObservers;

@interface CTTabStripModel : NSObject {
	// Policy for how new tabs are inserted.
	enum InsertionPolicy {
		// Newly created tabs are created after the selection. This is the default.
		INSERT_AFTER,
		
		// Newly created tabs are inserted before the selection.
		INSERT_BEFORE,
	};
	
	// Used to specify what should happen when the tab is closed.
	enum CloseTypes {
		CLOSE_NONE                     = 0,
		
		// Indicates the tab was closed by the user. If true,
		// CTTabContents::set_closed_by_user_gesture(true) is invoked.
		CLOSE_USER_GESTURE             = 1 << 0,
		
		// If true the history is recorded so that the tab can be reopened later.
		// You almost always want to set this.
		CLOSE_CREATE_HISTORICAL_TAB    = 1 << 1,
	};
	
	// Constants used when adding tabs.
	enum AddTabTypes {
		// Used to indicate nothing special should happen to the newly inserted
		// tab.
		ADD_NONE          = 0,
		
		// The tab should be selected.
		ADD_SELECTED      = 1 << 0,
		
		// The tab should be pinned.
		ADD_PINNED        = 1 << 1,
		
		// If not set the insertion index of the CTTabContents is left up to the Order
		// Controller associated, so the final insertion index may differ from the
		// specified index. Otherwise the index supplied is used.
		ADD_FORCE_INDEX   = 1 << 2,
		
		// If set the newly inserted tab inherits the group of the currently
		// selected tab. If not set the tab may still inherit the group under
		// certain situations.
		ADD_INHERIT_GROUP = 1 << 3,
		
		// If set the newly inserted tab's opener is set to the currently selected
		// tab. If not set the tab may still inherit the group/opener under certain
		// situations.
		// NOTE: this is ignored if ADD_INHERIT_GROUP is set.
		ADD_INHERIT_OPENER = 1 << 4,
	};
	
	// Context menu functions.
	enum ContextMenuCommand {
		CommandFirst = 0,
		CommandNewTab,
		CommandReload,
		CommandDuplicate,
		CommandCloseTab,
		CommandCloseOtherTabs,
		CommandCloseTabsToRight,
		CommandRestoreTab,
		CommandTogglePinned,
		CommandBookmarkAllTabs,
		CommandUseVerticalTabs,
		CommandLast
	};
@private
	// Our delegate.
    NSObject<CTTabStripModelDelegate> *delegate_;
	
	// The CTTabContents data currently hosted within this TabStripModel.
	NSMutableArray *contents_data_;
	
	// The index of the CTTabContents in |contents_| that is currently selected.
	int selected_index_;
	
	// A profile associated with this TabStripModel, used when creating new Tabs.
	//Profile* profile_;
	
	// True if all tabs are currently being closed via CloseAllTabs.
	bool closing_all_;
	
	// An object that determines where new Tabs should be inserted and where
	// selection should move when a Tab is closed.
	CTTabStripModelOrderController *order_controller_;
	
	// Our observers.
	TabStripModelObservers observers_;
	
	// A scoped container for notification registries.
	//NotificationRegistrar registrar_;	
}

// The CTTabStripModelDelegate associated with this TabStripModel.
@property (readonly) NSObject<CTTabStripModelDelegate> *delegate;
// The index of the currently selected CTTabContents.
@property (readonly, nonatomic) int selected_index;
// Returns true if the tabstrip is currently closing all open tabs (via a
// call to CloseAllTabs). As tabs close, the selection in the tabstrip
// changes which notifies observers, which can use this as an optimization to
// avoid doing meaningless or unhelpful work.
@property (readonly, nonatomic) bool closing_all;
// Access the order controller. Exposed only for unit tests.
@property (readonly) CTTabStripModelOrderController* order_controller;

- (id)initWithDelegate:(NSObject<CTTabStripModelDelegate> *)delegate;
- (void)AddObserver:(NSObject <CTTabStripModelObserver> *)observer;
- (void)RemoveObserver:(NSObject <CTTabStripModelObserver> *)observer;

// Retrieve the number of CTTabContentses/emptiness of the TabStripModel.
- (int)count;
- (bool)empty;

// Returns true if there are any non-phantom tabs. When there are no
// non-phantom tabs the delegate is notified by way of TabStripEmpty and the
// browser closes.
- (bool)hasNonPhantomTabs;

// Sets the insertion policy. Default is INSERT_AFTER.
- (void)SetInsertionPolicy:(InsertionPolicy)policy;
- (InsertionPolicy)insertion_policy;

// Returns true if |observer| is in the list of observers. This is intended
// for debugging.
- (bool)HasObserver:(NSObject *)observer;

#pragma mark -
#pragma mark Basic API
// Basic API /////////////////////////////////////////////////////////////////

// Determines if the specified index is contained within the TabStripModel.
- (bool)ContainsIndex:(int)index;

// Adds the specified CTTabContents in the default location. Tabs opened in the
// foreground inherit the group of the previously selected tab.
- (void)appendTabContents:(CTTabContents *)contents
			 inForeground:(bool)foreground;

// Adds the specified CTTabContents at the specified location. |add_types| is a
// bitmask of AddTypes; see it for details.
//
// All append/insert methods end up in this method.
//
// NOTE: adding a tab using this method does NOT query the order controller,
// as such the ADD_FORCE_INDEX AddType is meaningless here.  The only time the
// |index| is changed is if using the index would result in breaking the
// constraint that all mini-tabs occur before non-mini-tabs.
// See also AddTabContents.
- (void)insertTabContents:(CTTabContents *)contents
				  atIndex:(int)index 
			 withAddTypes:(int)add_types;

// Closes the CTTabContents at the specified index. This causes the CTTabContents
// to be destroyed, but it may not happen immediately (e.g. if it's a
// CTTabContents). |close_types| is a bitmask of CloseTypes.
// Returns true if the CTTabContents was closed immediately, false if it was not
// closed (we may be waiting for a response from an onunload handler, or
// waiting for the user to confirm closure).
- (bool)closeTabContentsAtIndex:(int)index 
				 closeTypes:(uint32)close_types;

// Replaces the entire state of a the tab at index by switching in a
// different NavigationController. This is used through the recently
// closed tabs list, which needs to replace a tab's current state
// and history with another set of contents and history.
//
// The old NavigationController is deallocated and this object takes
// ownership of the passed in controller.
//void ReplaceNavigationControllerAt(int index,
//                                   NavigationController* controller);

// Replaces the tab contents at |index| with |new_contents|. |type| is passed
// to the observer. This deletes the CTTabContents currently at |index|.
- (void)replaceTabContentsAtIndex:(int)index
					 withContents:(CTTabContents *)new_contents 
					  replaceType:(CTTabReplaceType)type;

// Detaches the CTTabContents at the specified index from this strip. The
// CTTabContents is not destroyed, just removed from display. The caller is
// responsible for doing something with it (e.g. stuffing it into another
// strip).
- (CTTabContents*)detachTabContentsAtIndex:(int)index;

// Select the CTTabContents at the specified index. |user_gesture| is true if
// the user actually clicked on the tab or navigated to it using a keyboard
// command, false if the tab was selected as a by-product of some other
// action.
- (void)selectTabContentsAtIndex:(int)index 
					 userGesture:(BOOL)userGesture;

// Move the CTTabContents at the specified index to another index. This method
// does NOT send Detached/Attached notifications, rather it moves the
// CTTabContents inline and sends a Moved notification instead.
// If |select_after_move| is false, whatever tab was selected before the move
// will still be selected, but it's index may have incremented or decremented
// one slot.
// NOTE: this does nothing if the move would result in app tabs and non-app
// tabs mixing.
- (void)moveTabContentsAtIndex:(int)index 
					   toIndex:(int)to_position 
			   selectAfterMove:(bool)select_after_move;

// Returns the currently selected CTTabContents, or NULL if there is none.
- (CTTabContents *)selectedTabContents;

// Returns the CTTabContents at the specified index, or NULL if there is none.
- (CTTabContents *)tabContentsAtIndex:(int)index;

// Returns the index of the specified CTTabContents, or CTTabContents::kNoTab if
// the CTTabContents is not in this TabStripModel.
- (int)indexOfTabContents:(const CTTabContents *)contents;

// Returns the index of the specified NavigationController, or -1 if it is
// not in this TabStripModel.
//int GetIndexOfController(const NavigationController* controller) const;

// Notify any observers that the CTTabContents at the specified index has
// changed in some way. See TabChangeType for details of |change_type|.
- (void)updateTabContentsStateAtIndex:(int)index 
						   changeType:(CTTabChangeType)change_type;

// Make sure there is an auto-generated New Tab tab in the TabStripModel.
// If |force_create| is true, the New Tab will be created even if the
// preference is set to false (used by startup).
//- (void)ensureNewTabVisible:(bool)force_create;

// Close all tabs at once. Code can use closing_all() above to defer
// operations that might otherwise by invoked by the flurry of detach/select
// notifications this method causes.
- (void)closeAllTabs;

// Returns true if there are any CTTabContents that are currently loading.
- (bool)tabsAreLoading;


// Returns the controller controller that opened the CTTabContents at |index|.
//NavigationController* GetOpenerOfTabContentsAt(int index);

// Returns the index of the next CTTabContents in the sequence of CTTabContentses
// spawned by the specified NavigationController after |start_index|.
// If |use_group| is true, the group property of the tab is used instead of
// the opener to find the next tab. Under some circumstances the group
// relationship may exist but the opener may not.
// NOTE: this skips phantom tabs.
//int GetIndexOfNextTabContentsOpenedBy(const NavigationController* opener,
//                                      int start_index,
//                                      bool use_group) const;

// Returns the index of the first CTTabContents in the model opened by the
// specified opener.
// NOTE: this skips phantom tabs.
//int GetIndexOfFirstTabContentsOpenedBy(const NavigationController* opener,
//                                       int start_index) const;

// Returns the index of the last CTTabContents in the model opened by the
// specified opener, starting at |start_index|.
// NOTE: this skips phantom tabs.
//int GetIndexOfLastTabContentsOpenedBy(const NavigationController* opener,
//                                      int start_index) const;

// Called by the CTBrowser when a navigation is about to occur in the specified
// CTTabContents. Depending on the tab, and the transition type of the
// navigation, the TabStripModel may adjust its selection and grouping
// behavior.
- (void)TabNavigating:(CTTabContents *)contents
	   withTransition:(CTPageTransition)transition;

// Changes the blocked state of the tab at |index|.
- (void)setTabAtIndex:(int)index 
			  blocked:(bool)blocked;

// Changes the pinned state of the tab at |index|. See description above
// class for details on this.
- (void)setTabAtIndex:(int)index 
			   pinned:(bool)pinned;

// Returns true if the tab at |index| is pinned.
// See description above class for details on pinned tabs.
- (bool)IsTabPinned:(int)index;

// Is the tab a mini-tab?
// See description above class for details on this.
- (bool)IsMiniTab:(int)index;

// Is the tab at |index| an app?
// See description above class for details on app tabs.
- (bool)IsAppTab:(int)index;

// Returns true if the tab is a phantom tab. A phantom tab is one where the
// renderer has not been loaded.
// See description above class for details on phantom tabs.
- (bool)IsPhantomTab:(int)index;

// Returns true if the tab at |index| is blocked by a tab modal dialog.
- (bool)IsTabBlocked:(int)index;

// Returns the index of the first tab that is not a mini-tab. This returns
// |count()| if all of the tabs are mini-tabs, and 0 if none of the tabs are
// mini-tabs.
- (int)IndexOfFirstNonMiniTab;

// Returns a valid index for inserting a new tab into this model. |index| is
// the proposed index and |mini_tab| is true if inserting a tab will become
// mini (pinned or app). If |mini_tab| is true, the returned index is between
// 0 and IndexOfFirstNonMiniTab. If |mini_tab| is false, the returned index
// is between IndexOfFirstNonMiniTab and count().
- (int)constrainInsertionIndex:(int)index 
					   miniTab:(bool)mini_tab;

// Returns the index of the first tab that is not a phantom tab. This returns
// kNoTab if all of the tabs are phantom tabs.
- (int)IndexOfFirstNonPhantomTab;

// Returns the number of non phantom tabs in the TabStripModel.
- (int)nonPhantomTabCount;

#pragma mark -
#pragma mark Command level API

// Command level API /////////////////////////////////////////////////////////

// Adds a CTTabContents at the best position in the TabStripModel given the
// specified insertion index, transition, etc. |add_types| is a bitmask of
// AddTypes; see it for details. This method ends up calling into
// InsertTabContentsAt to do the actual inertion.
- (int)addTabContents:(CTTabContents *)contents 
			  atIndex:(int)index
	   withTransition:(CTPageTransition)transition
			 addTypes:(int)add_types;

// Closes the selected CTTabContents.
- (void)CloseSelectedTab;

// Select adjacent tabs
- (void)SelectNextTab;
- (void)SelectPreviousTab;

// Selects the last tab in the tab strip.
- (void)SelectLastTab;

// Swap adjacent tabs.
- (void)MoveTabNext;
- (void)MoveTabPrevious;

#pragma mark -
#pragma mark View API

// View API //////////////////////////////////////////////////////////////////

// Returns true if the specified command is enabled.
- (bool)isContextMenuCommandEnabled:(int)context_index
						  commandID:(ContextMenuCommand)command_id;

// Returns true if the specified command is checked.
- (bool)isContextMenuCommandChecked:(int)context_index
						  commandID:(ContextMenuCommand)command_id;

// Performs the action associated with the specified command for the given
// TabStripModel index |context_index|.
- (void)executeContextMenuCommand:(int)context_index
						commandID:(ContextMenuCommand)command_id;

// Returns a vector of indices of the tabs that will close when executing the
// command |id| for the tab at |index|. The returned indices are sorted in
// descending order.
- (NSArray *)GetIndicesClosedByCommand:(ContextMenuCommand)command_id
forTabAtIndex:(int)index;

// Overridden from notificationObserver:
/*virtual void Observe(NotificationType type,
 const NotificationSource& source,
 const NotificationDetails& details);*/
// TODO replace with NSNotification if possible:
- (void)TabContentsWasDestroyed:(CTTabContents *)contents;

@end
