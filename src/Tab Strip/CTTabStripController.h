// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.
#pragma once

#import <Cocoa/Cocoa.h>

#import "CTTabControllerTarget.h"
#import "URLDropTarget.h"

@class NewTabButton;
@class CTTabContentsController;
@class CTTabView;
@class CTTabStripView;

@class CTTabContents;
@class CTBrowser;

@class CTTabStripModel;

// A class that handles managing the tab strip in a browser window. It uses
// a supporting C++ bridge object to register for notifications from the
// TabStripModel. The Obj-C part of this class handles drag and drop and all
// the other Cocoa-y aspects.
//
// For a full description of the design, see
// http://www.chromium.org/developers/design-documents/tab-strip-mac
@interface CTTabStripController : NSObject<CTTabControllerTarget, URLDropTargetController>

@property(nonatomic) CGFloat indentForControls;

// Show or hide the new tab button. The button is hidden immediately, but
// waits until the next call to |-layoutTabs| to show it again.
@property(nonatomic, assign) BOOL showsNewTabButton;

// Initialize the controller with a view and browser that contains
// everything else we'll need. |switchView| is the view whose contents get
// "switched" every time the user switches tabs. The children of this view
// will be released, so if you want them to stay around, make sure
// you have retained them.
- (id)initWithView:(CTTabStripView*)view
        switchView:(NSView*)switchView
           browser:(CTBrowser*)browser;

// Return the view for the currently active tab.
- (NSView*)activeTabView;

// Set the frame of the active tab, also updates the internal frame dict.
- (void)setFrameOfActiveTab:(NSRect)frame;

// Move the given tab at index |from| in this window to the location of the
// current placeholder.
- (void)moveTabFromIndex:(NSInteger)from;

// Drop a given CTTabContents at the location of the current placeholder. If there
// is no placeholder, it will go at the end. Used when dragging from another
// window when we don't have access to the CTTabContents as part of our strip.
// |frame| is in the coordinate system of the tab strip view and represents
// where the user dropped the new tab so it can be animated into its correct
// location when the tab is added to the model. If the tab was pinned in its
// previous window, setting |pinned| to YES will propagate that state to the
// new window. Mini-tabs are either app or pinned tabs; the app state is stored
// by the |contents|, but the |pinned| state is the caller's responsibility.
- (void)dropTabContents:(CTTabContents*)contents
              withFrame:(NSRect)frame
            asPinnedTab:(BOOL)pinned;

// Returns the index of the subview |view|. Returns -1 if not present. Takes
// closing tabs into account such that this index will correctly match the tab
// model. If |view| is in the process of closing, returns -1, as closing tabs
// are no longer in the model.
- (NSInteger)modelIndexForTabView:(NSView*)view;

// Return the view at a given index.
- (NSView*)viewAtIndex:(NSUInteger)index;

// Return the number of tab views in the tab strip. It's same as number of tabs
// in the model, except when a tab is closing, which will be counted in views
// count, but no longer in the model.
- (NSUInteger)viewsCount;

// Set the placeholder for a dragged tab, allowing the |frame| and |strechiness|
// to be specified. This causes this tab to be rendered in an arbitrary position
- (void)insertPlaceholderForTab:(CTTabView*)tab
                          frame:(NSRect)frame;

// Returns whether or not |tab| can still be fully seen in the tab strip or if
// its current position would cause it be obscured by things such as the edge
// of the window or the window decorations. Returns YES only if the entire tab
// is visible.
- (BOOL)isTabFullyVisible:(CTTabView*)tab;

// Force the tabs to rearrange themselves to reflect the current model.
- (void)layoutTabs;
- (void)layoutTabsWithoutAnimation;

// Are we in rapid (tab) closure mode? I.e., is a full layout deferred (while
// the user closes tabs)? Needed to overcome missing clicks during rapid tab
// closure.
- (BOOL)inRapidClosureMode;

// Returns YES if the user is allowed to drag tabs on the strip at this moment.
// For example, this returns NO if there are any pending tab close animtations.
- (BOOL)tabDraggingAllowed;

// Default height for tabs.
+ (CGFloat)defaultTabHeight;

// Default indentation for tabs (see |indentForControls_|).
+ (CGFloat)defaultIndentForControls;

// Returns the (lazily created) window sheet controller of this window. Used
// for the per-tab sheets.
//- (GTMWindowSheetController*)sheetController;

// Destroys the window sheet controller of this window, if it exists.  The sheet
// controller can be recreated by a subsequent call to |-sheetController|.  Must
// not be called if any sheets are currently open.
// TODO(viettrungluu): This is temporary code needed to allow sheets to work
// (read: not crash) in fullscreen mode.  Once GTMWindowSheetController is
// modified to support moving sheets between windows, this code can go away.
// http://crbug.com/19093.
//- (void)destroySheetController;

// Returns the currently active CTTabContentsController.
- (CTTabContentsController*)activeTabContentsController;

// See comments in browser_window_controller.h for documentation about these
// functions.
//- (void)attachConstrainedWindow:(ConstrainedWindowMac*)window;
//- (void)removeConstrainedWindow:(ConstrainedWindowMac*)window;
//- (void)updateDevToolsForContents:(CTTabContents*)contents;

@end

// Notification sent when the number of tabs changes. The object will be this
// controller.
extern NSString* const kTabStripNumberOfTabsChanged;
