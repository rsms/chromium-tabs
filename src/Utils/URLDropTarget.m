// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "URLDropTarget.h"
#import "NSPasteboard+Utils.h"

@interface URLDropTargetHandler(Private)

// Gets the appropriate drag operation given the |NSDraggingInfo|.
- (NSDragOperation)getDragOperation:(id<NSDraggingInfo>)sender;

// Tell the window controller to hide the drop indicator.
- (void)hideIndicator;

@end  // @interface URLDropTargetHandler(Private)

@implementation URLDropTargetHandler {
	NSView<URLDropTarget>* view_;  // weak
}

- (id)initWithView:(NSView<URLDropTarget>*)view {
	if ((self = [super init])) {
		view_ = view;
		[view_ registerForDraggedTypes:
         [NSArray arrayWithObjects:kWebURLsWithTitlesPboardType,
		  NSURLPboardType,
		  NSStringPboardType,
		  NSFilenamesPboardType,
		  nil]];
	}
	return self;
}

// The following four methods implement parts of the |NSDraggingDestination|
// protocol, which the owner should "forward" to its |URLDropTargetHandler|
// (us).

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	return [self getDragOperation:sender];
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
	NSDragOperation dragOp = [self getDragOperation:sender];
	if (dragOp == NSDragOperationCopy) {
		// Just tell the window controller to update the indicator.
		NSPoint hoverPoint = [view_ convertPoint:[sender draggingLocation]
										fromView:nil];
		[[view_ urlDropController] indicateDropURLsInView:view_ at:hoverPoint];
	}
	return dragOp;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
	[self hideIndicator];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	[self hideIndicator];
	
	NSPasteboard* pboard = [sender draggingPasteboard];
	if ([pboard containsURLData]) {
		NSArray* urls = nil;
		NSArray* titles;  // discarded
		[pboard getURLs:&urls andTitles:&titles convertingFilenames:YES];
		
		if ([urls count]) {
			// Tell the window controller about the dropped URL(s).
			NSPoint dropPoint =
			[view_ convertPoint:[sender draggingLocation] fromView:nil];
			[[view_ urlDropController] dropURLs:urls inView:view_ at:dropPoint];
			return YES;
		}
	}
	
	return NO;
}

@end  // @implementation URLDropTargetHandler

@implementation URLDropTargetHandler(Private)

- (NSDragOperation)getDragOperation:(id<NSDraggingInfo>)sender {
	if (![[sender draggingPasteboard] containsURLData])
		return NSDragOperationNone;
	
	// Only allow the copy operation.
	return [sender draggingSourceOperationMask] & NSDragOperationCopy;
}

- (void)hideIndicator {
	[[view_ urlDropController] hideDropURLsIndicatorInView:view_];
}

@end  // @implementation URLDropTargetHandler(Private)
