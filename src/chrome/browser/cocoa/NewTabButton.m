// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "NewTabButton.h"

@implementation NewTabButton {
	NSBezierPath* imagePath_;
}

// Approximate the shape. It doesn't need to be perfect. This will need to be
// updated if the size or shape of the icon ever changes.
// TODO(pinkerton): use a click mask image instead of hard-coding points.
- (NSBezierPath*)pathForButton {
	if (imagePath_)
		return imagePath_;
	
	// Cache the path as it doesn't change (the coordinates are local to this
	// view). There's not much point making constants for these, as they are
	// custom.
	imagePath_ = [NSBezierPath bezierPath];
	[imagePath_ moveToPoint:NSMakePoint(9, 7)];
	[imagePath_ lineToPoint:NSMakePoint(26, 7)];
	[imagePath_ lineToPoint:NSMakePoint(33, 23)];
	[imagePath_ lineToPoint:NSMakePoint(14, 23)];
	[imagePath_ lineToPoint:NSMakePoint(9, 7)];
	return imagePath_;
}

- (BOOL)pointIsOverButton:(NSPoint)point {
	NSPoint localPoint = [self convertPoint:point fromView:[self superview]];
	NSBezierPath* buttonPath = [self pathForButton];
	return [buttonPath containsPoint:localPoint];
}

// Override to only accept clicks within the bounds of the defined path, not
// the entire bounding box. |aPoint| is in the superview's coordinate system.
- (NSView*)hitTest:(NSPoint)aPoint {
	if ([self pointIsOverButton:aPoint])
		return [super hitTest:aPoint];
	return nil;
}

@end
