// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "HoverButton.h"


@implementation HoverButton {
@private
	// Tracking area for button mouseover states.
	NSTrackingArea* trackingArea_;
}

- (id)initWithFrame:(NSRect)frameRect {
	if ((self = [super initWithFrame:frameRect])) {
		[self setTrackingEnabled:YES];
		hoverState_ = kHoverStateNone;
		[self updateTrackingAreas];
	}
	return self;
}

- (void)awakeFromNib {
	[self setTrackingEnabled:YES];
	hoverState_ = kHoverStateNone;
	[self updateTrackingAreas];
}

- (void)dealloc {
	[self setTrackingEnabled:NO];
}

- (void)mouseEntered:(NSEvent*)theEvent {
	hoverState_ = kHoverStateMouseOver;
	[self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent*)theEvent {
	hoverState_ = kHoverStateNone;
	[self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent*)theEvent {
	hoverState_ = kHoverStateMouseDown;
	[self setNeedsDisplay:YES];
	// The hover button needs to hold onto itself here for a bit.  Otherwise,
	// it can be freed while |super mouseDown:| is in it's loop, and the
	// |checkImageState| call will crash.
	// http://crbug.com/28220
	//  scoped_nsobject<HoverButton> myself([self retain]);
	
	[super mouseDown:theEvent];
	// We need to check the image state after the mouseDown event loop finishes.
	// It's possible that we won't get a mouseExited event if the button was
	// moved under the mouse during tab resize, instead of the mouse moving over
	// the button.
	// http://crbug.com/31279
	[self checkImageState];
}

- (void)setTrackingEnabled:(BOOL)enabled {
	if (enabled) {
		trackingArea_ = [[NSTrackingArea alloc] initWithRect:[self bounds]
													 options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
													   owner:self
													userInfo:nil];
		[self addTrackingArea:trackingArea_];
		
		// If you have a separate window that overlaps the close button, and you
		// move the mouse directly over the close button without entering another
		// part of the tab strip, we don't get any mouseEntered event since the
		// tracking area was disabled when we entered.
		[self checkImageState];
	} else if (trackingArea_) {
		[self removeTrackingArea:trackingArea_];
		trackingArea_ = nil;
	}
}


- (void)updateTrackingAreas {
	[super updateTrackingAreas];
	[self checkImageState];
}

- (void)checkImageState {
	if (!trackingArea_)
		return;
	
	// Update the button's state if the button has moved.
	NSPoint mouseLoc = [[self window] mouseLocationOutsideOfEventStream];
	mouseLoc = [self convertPoint:mouseLoc fromView:nil];
	hoverState_ = NSPointInRect(mouseLoc, [self bounds]) ?
	kHoverStateMouseOver : kHoverStateNone;
	[self setNeedsDisplay:YES];
}

@end
