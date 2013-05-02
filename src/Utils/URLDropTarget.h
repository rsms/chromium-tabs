// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#pragma once

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

// Protocol for the controller which handles the actual drop data/drop updates.
@protocol URLDropTargetController

// The given URLs (an |NSArray| of |NSString|s) were dropped in the given view
// at the given point (in that view's coordinates).
- (void)dropURLs:(NSArray*)urls inView:(NSView*)view at:(NSPoint)point;

// Dragging is in progress over the owner view (at the given point, in view
// coordinates) and any indicator of location -- e.g., an arrow -- should be
// updated/shown.
- (void)indicateDropURLsInView:(NSView*)view at:(NSPoint)point;

// Dragging is over, and any indicator should be hidden.
- (void)hideDropURLsIndicatorInView:(NSView*)view;

@end  // @protocol URLDropTargetController


// Protocol which views that are URL drop targets and use |URLDropTargetHandler|
// must implement.
@protocol URLDropTarget

// Returns the controller which handles the drop.
- (id<URLDropTargetController>)urlDropController;

// The following, which come from |NSDraggingDestination|, must be implemented
// by calling the |URLDropTargetHandler|'s implementations.
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender;
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender;
- (void)draggingExited:(id<NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender;

@end  // @protocol URLDropTarget

// Object which coordinates the dropping of URLs on a given view, sending data
// and updates to a controller.
@interface URLDropTargetHandler : NSObject
// Initialize the given view, which must implement the |URLDropTarget| (below),
// to accept drops of URLs.
- (id)initWithView:(NSView<URLDropTarget>*)view;

// The owner view should implement the following methods by calling the
// |URLDropTargetHandler|'s version, and leave the others to the default
// implementation provided by |NSView|/|NSWindow|.
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender;
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender;
- (void)draggingExited:(id<NSDraggingInfo>)sender;
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender;

@end  // @interface URLDropTargetHandler
