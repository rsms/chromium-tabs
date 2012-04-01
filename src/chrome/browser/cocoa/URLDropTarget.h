// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#ifndef CHROME_BROWSER_COCOA_URL_DROP_TARGET_H_
#define CHROME_BROWSER_COCOA_URL_DROP_TARGET_H_
#pragma once

#import <Cocoa/Cocoa.h>

@protocol URLDropTarget;
@protocol URLDropTargetController;

// Object which coordinates the dropping of URLs on a given view, sending data
// and updates to a controller.
@interface URLDropTargetHandler : NSObject {
 @private
  NSView<URLDropTarget>* view_;  // weak
}

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

#endif  // CHROME_BROWSER_COCOA_URL_DROP_TARGET_H_
