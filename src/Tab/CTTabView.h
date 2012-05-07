// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#ifndef CHROME_BROWSER_COCOA_TAB_VIEW_H_
#define CHROME_BROWSER_COCOA_TAB_VIEW_H_
#pragma once

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>

//#import <map>

//#import "scoped_nsobject.h"
#import "BackgroundGradientView.h"

// Nomenclature:
// Tabs _glow_ under two different circumstances, when they are _hovered_ (by
// the mouse) and when they are _alerted_ (to show that the tab's title has
// changed).

// The state of alerting (to show a title change on an inactive, pinned tab).
// This is more complicated than a simple on/off since we want to allow the
// alert glow to go through a full rise-hold-fall cycle to avoid flickering (or
// always holding).
typedef enum {
  kAlertNone = 0,  // Obj-C initializes to this.
  kAlertRising,
  kAlertHolding,
  kAlertFalling
} AlertState;

@class CTTabController;

// A view that handles the event tracking (clicking and dragging) for a tab
// on the tab strip. Relies on an associated CTTabController to provide a
// target/action for selecting the tab.

@interface CTTabView : BackgroundGradientView

@property(assign, nonatomic) NSCellStateValue state;
@property(assign, nonatomic) CGFloat hoverAlpha;
@property(assign, nonatomic) CGFloat alertAlpha;

// Determines if the tab is in the process of animating closed. It may still
// be visible on-screen, but should not respond to/initiate any events. Upon
// setting to NO, clears the target/action of the close button to prevent
// clicks inside it from sending messages.
@property(assign, nonatomic, setter = setClosing:) BOOL isClosing;

// Returns the inset multiplier used to compute the inset of the top of the tab.
+ (CGFloat)insetMultiplier;

// Enables/Disables tracking regions for the tab.
- (void)setTrackingEnabled:(BOOL)enabled;

// Begin showing an "alert" glow (shown to call attention to an inactive
// pinned tab whose title changed).
- (void)startAlert;

// Stop showing the "alert" glow; this won't immediately wipe out any glow, but
// will make it fade away.
- (void)cancelAlert;

@end

// The CTTabController |tabController_| is not the only owner of this view. If the
// controller is released before this view, then we could be hanging onto a
// garbage pointer. To prevent this, the CTTabController uses this interface to
// clear the |tabController_| pointer when it is dying.
@interface CTTabView (TabControllerInterface)
- (void)setController:(CTTabController*)controller;
- (CTTabController*)controller;
@end

#endif  // CHROME_BROWSER_COCOA_TAB_VIEW_H_
