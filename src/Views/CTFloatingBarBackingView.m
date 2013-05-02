// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "CTFloatingBarBackingView.h"

#import "CTBrowserFrameView.h"

@implementation CTFloatingBarBackingView

- (void)drawRect:(NSRect)rect {
  NSWindow* window = [self window];
  BOOL isMainWindow = [window isMainWindow];

  if (isMainWindow)
    [[NSColor windowFrameColor] set];
  else
    [[NSColor windowBackgroundColor] set];
  NSRectFill(rect);

  // TODO(rohitrao): Don't assume -22 here.
//  [CTBrowserFrameView drawWindowThemeInDirtyRect:rect
//										 forView:self
//										  bounds:[self bounds]
//										  offset:NSMakePoint(0, -22)
//							forceBlackBackground:YES];

}

// Eat all mouse events (and do *not* pass them on to the next responder!).
- (void)mouseDown:(NSEvent*)event {}
- (void)rightMouseDown:(NSEvent*)event {}
- (void)otherMouseDown:(NSEvent*)event {}
- (void)rightMouseUp:(NSEvent*)event {}
- (void)otherMouseUp:(NSEvent*)event {}
- (void)mouseMoved:(NSEvent*)event {}
- (void)mouseDragged:(NSEvent*)event {}
- (void)rightMouseDragged:(NSEvent*)event {}
- (void)otherMouseDragged:(NSEvent*)event {}

// Eat this too, except that ...
- (void)mouseUp:(NSEvent*)event {
  // a double-click in the blank area should try to minimize, to be consistent
  // with double-clicks on the contiguous tab strip area. (It'll fail and beep.)
  if ([event clickCount] == 2 &&
      (![NSWindow respondsToSelector:@selector(_shouldMiniaturizeOnDoubleClick)] ||
	   [NSWindow performSelector:@selector(_shouldMiniaturizeOnDoubleClick)]))
    [[self window] performMiniaturize:self];
}

@end  // @implementation FloatingBarBackingView
