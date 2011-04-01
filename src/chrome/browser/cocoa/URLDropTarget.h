//
//  URLDropTarget.h
//  chromium-tabs
//
//  Created by Liu Junliang on 11-4-2.
//  Copyright 2011年 HKUST. All rights reserved.
//

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
