// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

// CTBrowserFrameView is a class whose methods we swizzle into NSGrayFrame
// (an AppKit framework class) so that we can support custom frame drawing, and
// have the ability to move our window widgets (close, zoom, miniaturize) where
// we want them.
// This class is never to be instantiated on its own.
// We explored a variety of ways to support custom frame drawing and custom
// window widgets.
// Our requirements were:
// a) that we could fall back on standard system drawing at any time for the
//    "default theme"
// b) We needed to be able to draw both a background pattern, and an overlay
//    graphic, and we need to be able to set the pattern phase of our background
//    window.
// c) We had to be able to support "transparent" themes, so that you could see
//    through to the underlying windows in places without the system theme
//    getting in the way.
// d) We had to support having the custom window controls moved down by a couple
//    of pixels and rollovers, accessibility, etc. all had to work.
//
// Since we want "A" we couldn't just do a transparent borderless window. At
// least I couldn't find the right combination of HITheme calls to make it draw
// nicely, and I don't trust that the HITheme calls are going to exist in future
// system versions.
// "C" precluded us from inserting a view between the system frame and the
// the content frame in Z order. To get the transparency we actually need to
// replace the drawing of the system frame.
// "D" required us to override _mouseInGroup to get our custom widget rollovers
// drawing correctly. The widgets call _mouseInGroup on their superview to
// decide whether they should draw in highlight mode or not.
// "B" precluded us from just setting a background color on the window.
//
// Originally we tried overriding the private API +frameViewForStyleMask: to
// add our own subclass of NSGrayView to our window. Turns out that if you
// subclass NSGrayView it does not draw correctly when you call NSGrayView's
// drawRect. It appears that NSGrayView's drawRect: method (and that of its
// superclasses) do lots of "isMemberOfClass/isKindOfClass" calls, and if your
// class is NOT an instance of NSGrayView (as opposed to a subclass of
// NSGrayView) then the system drawing will not work correctly.
//
// Given all of the above, we found swizzling drawRect, and adding an
// implementation of _mouseInGroup and updateTrackingAreas, in _load to be the
// easiest and safest method of achieving our goals. We do the best we can to
// check that everything is safe, and attempt to fallback gracefully if it is
// not.
@interface CTBrowserFrameView : NSView
@end
