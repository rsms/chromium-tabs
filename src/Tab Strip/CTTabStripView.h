// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#pragma once

#import <Cocoa/Cocoa.h>

#import "URLDropTarget.h"

@class NewTabButton;
@class URLDropTargetHandler;

// A view class that handles rendering the tab strip and drops of URLS with
// a positioning locator for drop feedback.

@interface CTTabStripView : NSView<URLDropTarget>

@property(retain, nonatomic) IBOutlet NewTabButton* addTabButton;
@property(assign, nonatomic) BOOL dropArrowShown;
@property(assign, nonatomic) NSPoint dropArrowPosition;

@end

// Protected methods subclasses can override to alter behavior. Clients should
// not call these directly.
@interface CTTabStripView(Protected)
- (void)drawBottomBorder:(NSRect)bounds;
- (BOOL)doubleClickMinimizesWindow;
@end
