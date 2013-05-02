// Copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#import <Cocoa/Cocoa.h>

@class CTTabController;
@class CTTabStripController;
@class CTTabWindowController;

////////////////////////////////////////////////////////////////////////////////

// This protocol is used to carry mouse events to the TabStripDragController,
// which manages the logic for actually dragging tabs.
@protocol TabDraggingEventTarget

// Returns YES if the tab represented by the controller can be dragged.
- (BOOL)tabCanBeDragged:(CTTabController*)tab;

// Initiates a dragging session with a mouseDown event. The tab controller
// passed here is the one used for the rest of the dragging session.
- (void)maybeStartDrag:(NSEvent*)event forTab:(CTTabController*)tab;

@end

////////////////////////////////////////////////////////////////////////////////

// This controller is owned by the TabStripController and is used to delegate
// all the logic for tab dragging from the TabView's events.
@interface CTTabStripDragController : NSObject<TabDraggingEventTarget> {
@private
	CTTabStripController* tabStrip_;  // Weak; owns this.
	
	// These are released on mouseUp:
	BOOL moveWindowOnDrag_;  // Set if the only tab of a window is dragged.
	BOOL tabWasDragged_;  // Has the tab been dragged?
	BOOL draggingWithinTabStrip_;  // Did drag stay in the current tab strip?
	BOOL chromeIsVisible_;
	
	NSTimeInterval tearTime_;  // Time since tear happened
	NSPoint tearOrigin_;  // Origin of the tear rect
	NSPoint dragOrigin_;  // Origin point of the drag
	
	CTTabWindowController* sourceController_;  // weak. controller starting the drag
	NSWindow* sourceWindow_;  // Weak. The window starting the drag.
	NSRect sourceWindowFrame_;
	NSRect sourceTabFrame_;
	
	CTTabController* draggedTab_;  // Weak. The tab controller being dragged.
	
	CTTabWindowController* draggedController_;  // Weak. Controller being dragged.
	NSWindow* dragWindow_;  // Weak. The window being dragged
	NSWindow* dragOverlay_;  // Weak. The overlay being dragged
	
	CTTabWindowController* targetController_;  // weak. Controller being targeted
}

// Designated initializer.
- (id)initWithTabStripController:(CTTabStripController*)controller;

// TabDraggingEventTarget methods are also implemented.

@end
