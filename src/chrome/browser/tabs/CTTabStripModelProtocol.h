//
//  CTTabStripModelProtocol.h
//  chromium-tabs
//
// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.
//

#import <Foundation/Foundation.h>

// Enumeration of the possible values supplied to TabChangedAt.
typedef enum {
	// Only the loading state changed.
	CTTabChangeTypeLoadingOnly,
	
	// Only the title changed and page isn't loading.
	CTTabChangeTypeTitleNotLoading,
	
	// Change not characterized by CTTabChangeTypeLoadingOnly or CTTabChangeTypeTitleNotLoading.
	CTTabChangeTypeAll
} CTTabChangeType;

// Enum used by ReplaceTabContentsAt.
typedef enum {
	// The replace is the result of the tab being made phantom.
	REPLACE_MADE_PHANTOM,
	
	// The replace is the result of the match preview being committed.
	REPLACE_MATCH_PREVIEW
} CTTabReplaceType;

@class CTTabContents;
////////////////////////////////////////////////////////////////////////////////
//
// TabStripModelObserver
//
//  Objects implement this interface when they wish to be notified of changes
//  to the TabStripModel.
//
//  Two major implementers are the TabStrip, which uses notifications sent
//  via this interface to update the presentation of the strip, and the CTBrowser
//  object, which updates bookkeeping and shows/hides individual TabContentses.
//
//  Register your TabStripModelObserver with the TabStripModel using its
//  Add/RemoveObserver methods.
//
////////////////////////////////////////////////////////////////////////////////
@protocol CTTabStripModelObserver
@optional
// A new CTTabContents was inserted into the TabStripModel at the specified
// index. |foreground| is whether or not it was opened in the foreground
// (selected).
- (void)tabInsertedWithContents:(CTTabContents*)contents
						atIndex:(NSInteger)index
				   inForeground:(bool)inForeground;

// The specified CTTabContents at |index| is being closed (and eventually
// destroyed).
- (void)tabClosingWithContents:(CTTabContents*)contents
                       atIndex:(NSInteger)index;

// The specified CTTabContents at |index| is being detached, perhaps to be
// inserted in another TabStripModel. The implementer should take whatever
// action is necessary to deal with the CTTabContents no longer being present.
- (void)tabDetachedWithContents:(CTTabContents*)contents
                        atIndex:(NSInteger)index;

// The selected CTTabContents is about to change from |old_contents| at |index|.
// This gives observers a chance to prepare for an impending switch before it
// happens.
- (void)tabDeselectedWithContents:(CTTabContents *)contents
						  atIndex:(int)index;

// The selected CTTabContents changed from |old_contents| to |new_contents| at
// |index|. |user_gesture| specifies whether or not this was done by a user
// input event (e.g. clicking on a tab, keystroke) or as a side-effect of
// some other function.
- (void)tabSelectedWithContents:(CTTabContents*)newContents
			   previousContents:(CTTabContents*)oldContents
						atIndex:(NSInteger)index
					userGesture:(bool)wasUserGesture;

// The specified CTTabContents at |from_index| was moved to |to_index|.
- (void)tabMovedWithContents:(CTTabContents*)contents
				   fromIndex:(NSInteger)from
					 toIndex:(NSInteger)to;


// The specified CTTabContents at |index| changed in some way. |contents| may
// be an entirely different object and the old value is no longer available
// by the time this message is delivered.
//
// See TabChangeType for a description of |change_type|.
- (void)tabChangedWithContents:(CTTabContents*)contents
                       atIndex:(NSInteger)index
                    changeType:(CTTabChangeType)change;

// The tab contents was replaced at the specified index. This is invoked when
// a tab becomes phantom. See description of phantom tabs in class description
// of TabStripModel for details.
// TODO(sky): nuke this in favor of the 4 arg variant.
- (void)tabReplacedWithContents:(CTTabContents*)contents
                    oldContents:(CTTabContents*)oldContents
                        atIndex:(NSInteger)index;

// The tab contents was replaced at the specified index. |type| describes
// the type of replace.
// This invokes TabReplacedAt with three args.
- (void)tabReplacedWithContents:(CTTabContents *)new_contents
					oldContents:(CTTabContents *)old_contents
						atIndex:(NSInteger)index
					replaceType:(CTTabReplaceType)type;

// Invoked when the pinned state of a tab changes. This is not invoked if the
// tab ends up moving as a result of the mini state changing.
// See note in TabMiniStateChanged as to how this relates to
// TabMiniStateChanged.
- (void)tabPinnedStateChangedWithContents:(CTTabContents*)contents
								  atIndex:(int)index;

// Invoked if the mini state of a tab changes.  This is not invoked if the
// tab ends up moving as a result of the mini state changing.
// NOTE: this is sent when the pinned state of a non-app tab changes and is
// sent in addition to TabPinnedStateChanged. UI code typically need not care
// about TabPinnedStateChanged, but instead this.
- (void)tabMiniStateChangedWithContents:(CTTabContents*)contents
                                atIndex:(NSInteger)index;

// Invoked when the blocked state of a tab changes.
// NOTE: This is invoked when a tab becomes blocked/unblocked by a tab modal
// window.
- (void)tabBlockedStateChangedWithContents:(CTTabContents*)contents
								   atIndex:(NSInteger)index;

// The TabStripModel now no longer has any phantom tabs. The implementer may
// use this as a trigger to try and close the window containing the
// TabStripModel, for example...
- (void)tabStripEmpty;

// Sent when the tabstrip model is about to be deleted and any reference held
// must be dropped.
- (void)tabStripModelDeleted;
@end

