// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#ifndef CHROME_BROWSER_COCOA_TAB_CONTROLLER_H_
#define CHROME_BROWSER_COCOA_TAB_CONTROLLER_H_
#pragma once

#import <Cocoa/Cocoa.h>
#import "CTTabStripDragController.h"

// The loading/waiting state of the tab.
typedef enum {
	CTTabLoadingStateDone,
	CTTabLoadingStateLoading,
	CTTabLoadingStateWaiting,
	CTTabLoadingStateCrashed,
} CTTabLoadingState;

@class CTTabView;
@protocol CTTabControllerTarget;

// A class that manages a single tab in the tab strip. Set its target/action
// to be sent a message when the tab is selected by the user clicking. Setting
// the |loading| property to YES visually indicates that this tab is currently
// loading content via a spinner.
//
// The tab has the notion of an "icon view" which can be used to display
// identifying characteristics such as a favicon, or since it's a full-fledged
// view, something with state and animation such as a throbber for illustrating
// progress. The default in the nib is an image view so nothing special is
// required if that's all you need.

@interface CTTabController : NSViewController<TabDraggingEventTarget>

@property(assign, nonatomic) CTTabLoadingState loadingState;

@property(assign, nonatomic) SEL action;
@property(assign, nonatomic, setter = setApp:) BOOL isApp;
@property(assign, nonatomic, setter = setMini:) BOOL isMini;
@property(assign, nonatomic, setter = setPinned:) BOOL isPinned;
@property(assign, nonatomic, setter = setActive:) BOOL isActive;
@property(retain, nonatomic) id target;

// Minimum and maximum allowable tab width. The minimum width does not show
// the icon or the close button. The active tab always has at least a close
// button so it has a different minimum width.
+ (CGFloat)minTabWidth;
+ (CGFloat)maxTabWidth;
+ (CGFloat)minActiveTabWidth;
+ (CGFloat)miniTabWidth;
+ (CGFloat)appTabWidth;

// Initialize a new controller. The default implementation will locate a nib
// called "TabView" in the app bundle and if not found there, will use the
// default nib from the framework bundle. If you need to rename the nib or load
// if from somepleace else, you should override this method and then call
// initWithNibName:bundle:.
- (id)init;

// Does the actual initialization work
- (id)initWithNibName:(NSString*)nibName bundle:(NSBundle*)bundle;

// The view associated with this controller, pre-casted as a CTTabView
- (CTTabView*)tabView;

// Closes the associated CTTabView by relaying the message to |target_| to
// perform the close.
- (IBAction)closeTab:(id)sender;

// Replace the current icon view with the given view. |iconView| will be
// resized to the size of the current icon view.
- (void)setIconView:(NSView*)iconView;
- (NSView*)iconView;

// Called by the tabs to determine whether we are in rapid (tab) closure mode.
// In this mode, we handle clicks slightly differently due to animation.
// Ideally, tabs would know about their own animation and wouldn't need this.
- (BOOL)inRapidClosureMode;

// Updates the visibility of certain subviews, such as the icon and close
// button, based on criteria such as the tab's active state and its current
// width.
- (void)updateVisibility;

// Update the title color to match the tabs current state.
- (void)updateTitleColor;
@end

@interface CTTabController(TestingAPI)
- (NSString*)toolTip;
- (CGFloat)iconCapacity;
- (BOOL)shouldShowIcon;
- (BOOL)shouldShowCloseButton;
@end  // CTTabController(TestingAPI)

#endif  // CHROME_BROWSER_COCOA_TAB_CONTROLLER_H_
