// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabStripView.h"
#import "CTTabStripController.h"
#import "URLDropTarget.h"

// ripped out from libbase mac_util.mm:
static BOOL ShouldWindowsMiniaturizeOnDoubleClick() {
	// We use an undocumented method in Cocoa; if it doesn't exist, default to
	// |true|. If it ever goes away, we can do (using an undocumented pref key):
	//   NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	//   return ![defaults objectForKey:@"AppleMiniaturizeOnDoubleClick"] ||
	//          [defaults boolForKey:@"AppleMiniaturizeOnDoubleClick"];
	BOOL methodImplemented =
	[NSWindow respondsToSelector:@selector(_shouldMiniaturizeOnDoubleClick)];
	assert(methodImplemented); // if this happens, se discussion above
	return !methodImplemented ||
	[NSWindow performSelector:@selector(_shouldMiniaturizeOnDoubleClick)];
}

@implementation CTTabStripView {
	NSTimeInterval lastMouseUp_;
	
	// Handles being a drag-and-drop target.
	URLDropTargetHandler *dropHandler_;
	
	// Weak; the following come from the nib.
	NewTabButton* addTabButton_;
	
	// Whether the drop-indicator arrow is shown, and if it is, the coordinate of
	// its tip.
	BOOL dropArrowShown_;
	NSPoint dropArrowPosition_;
}

@synthesize addTabButton = addTabButton_;
@synthesize dropArrowShown = dropArrowShown_;
@synthesize dropArrowPosition = dropArrowPosition_;

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		// Set lastMouseUp_ = -1000.0 so that timestamp-lastMouseUp_ is big unless
		// lastMouseUp_ has been reset.
		lastMouseUp_ = -1000.0;
		
		// Register to be an URL drop target.
		dropHandler_ = [[URLDropTargetHandler alloc] initWithView:self];
	}
	return self;
}

// Draw bottom border (a dark border and light highlight). Each tab is
// responsible for mimicking this bottom border, unless it's the active
// tab.
- (void)drawBorder:(NSRect)bounds {
	NSRect borderRect, contentRect;
	
	borderRect = bounds;
	borderRect.origin.y = 1;
	borderRect.size.height = 1;
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] set];
	NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
	NSDivideRect(bounds, &borderRect, &contentRect, 1, NSMinYEdge);
	// TODO: cache this color
	NSColor* bezelColor = [NSColor colorWithCalibratedWhite:0xf7/255.0
													  alpha:1.0];
	[bezelColor set];
	NSRectFill(borderRect);
	NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
}

- (void)drawRect:(NSRect)rect {
	NSRect boundsRect = [self bounds];
	
	[self drawBorder:boundsRect];
	
	// Draw drop-indicator arrow (if appropriate).
	// TODO(viettrungluu): this is all a stop-gap measure.
	if ([self dropArrowShown]) {
		// Programmer art: an arrow parametrized by many knobs. Note that the arrow
		// points downwards (so understand "width" and "height" accordingly).
		
		// How many (pixels) to inset on the top/bottom.
		const CGFloat kArrowTopInset = 1.5;
		const CGFloat kArrowBottomInset = 1;
		
		// What proportion of the vertical space is dedicated to the arrow tip,
		// i.e., (arrow tip height)/(amount of vertical space).
		const CGFloat kArrowTipProportion = 0.5;
		
		// This is a slope, i.e., (arrow tip height)/(0.5 * arrow tip width).
		const CGFloat kArrowTipSlope = 1.2;
		
		// What proportion of the arrow tip width is the stem, i.e., (stem
		// width)/(arrow tip width).
		const CGFloat kArrowStemProportion = 0.33;
		
		NSPoint arrowTipPos = [self dropArrowPosition];
		arrowTipPos.y += kArrowBottomInset;  // Inset on the bottom.
		
		// Height we have to work with (insetting on the top).
		CGFloat availableHeight =
        NSMaxY(boundsRect) - arrowTipPos.y - kArrowTopInset;
		assert(availableHeight >= 5);
		
		// Based on the knobs above, calculate actual dimensions which we'll need
		// for drawing.
		CGFloat arrowTipHeight = kArrowTipProportion * availableHeight;
		CGFloat arrowTipWidth = 2 * arrowTipHeight / kArrowTipSlope;
		CGFloat arrowStemHeight = availableHeight - arrowTipHeight;
		CGFloat arrowStemWidth = kArrowStemProportion * arrowTipWidth;
		CGFloat arrowStemInset = (arrowTipWidth - arrowStemWidth) / 2;
		
		// The line width is arbitrary, but our path really should be mitered.
		NSBezierPath* arrow = [NSBezierPath bezierPath];
		[arrow setLineJoinStyle:NSMiterLineJoinStyle];
		[arrow setLineWidth:1];
		
		// Define the arrow's shape! We start from the tip and go clockwise.
		[arrow moveToPoint:arrowTipPos];
		[arrow relativeLineToPoint:NSMakePoint(-arrowTipWidth / 2, arrowTipHeight)];
		[arrow relativeLineToPoint:NSMakePoint(arrowStemInset, 0)];
		[arrow relativeLineToPoint:NSMakePoint(0, arrowStemHeight)];
		[arrow relativeLineToPoint:NSMakePoint(arrowStemWidth, 0)];
		[arrow relativeLineToPoint:NSMakePoint(0, -arrowStemHeight)];
		[arrow relativeLineToPoint:NSMakePoint(arrowStemInset, 0)];
		[arrow closePath];
		
		// Draw and fill the arrow.
		// TODO: cache colors
		[[NSColor colorWithCalibratedWhite:0 alpha:0.67] set];
		[arrow stroke];
		[[NSColor colorWithCalibratedWhite:1 alpha:0.67] setFill];
		[arrow fill];
	}
}

// YES if a double-click in the background of the tab strip minimizes the
// window.
- (BOOL)doubleClickMinimizesWindow {
	return YES;
}

// We accept first mouse so clicks onto close/zoom/miniaturize buttons and
// title bar double-clicks are properly detected even when the window is in the
// background.
- (BOOL)acceptsFirstMouse:(NSEvent*)event {
	return YES;
}

// Trap double-clicks and make them miniaturize the browser window.
- (void)mouseUp:(NSEvent*)event {
	// Bail early if double-clicks are disabled.
	if (![self doubleClickMinimizesWindow]) {
		[super mouseUp:event];
		return;
	}
	
	NSInteger clickCount = [event clickCount];
	NSTimeInterval timestamp = [event timestamp];
	
	// Double-clicks on Zoom/Close/Mininiaturize buttons shouldn't cause
	// miniaturization. For those, we miss the first click but get the second
	// (with clickCount == 2!). We thus check that we got a first click shortly
	// before (measured up-to-up) a double-click. Cocoa doesn't have a documented
	// way of getting the proper interval (= (double-click-threshold) +
	// (drag-threshold); the former is Carbon GetDblTime()/60.0 or
	// com.apple.mouse.doubleClickThreshold [undocumented]). So we hard-code
	// "short" as 0.8 seconds. (Measuring up-to-up isn't enough to properly
	// detect double-clicks, but we're actually using Cocoa for that.)
	if (clickCount == 2 && (timestamp - lastMouseUp_) < 0.8) {
		if (ShouldWindowsMiniaturizeOnDoubleClick())
			[[self window] performMiniaturize:self];
	} else {
		[super mouseUp:event];
	}
	
	// If clickCount is 0, the drag threshold was passed.
	lastMouseUp_ = (clickCount == 1) ? timestamp : -1000.0;
}

// (URLDropTarget protocol)
- (id<URLDropTargetController>)urlDropController {
	//CTBrowserWindowController* windowController = [[self window] windowController];
	//assert([windowController isKindOfClass:[CTBrowserWindowController class]]);
	//return [windowController tabStripController];
	return nil;
}

// (URLDropTarget protocol)
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	return [dropHandler_ draggingEntered:sender];
}

// (URLDropTarget protocol)
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
	return [dropHandler_ draggingUpdated:sender];
}

// (URLDropTarget protocol)
- (void)draggingExited:(id<NSDraggingInfo>)sender {
	return [dropHandler_ draggingExited:sender];
}

// (URLDropTarget protocol)
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	return [dropHandler_ performDragOperation:sender];
}

- (BOOL)accessibilityIsIgnored {
	return NO;
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
	if ([attribute isEqual:NSAccessibilityRoleAttribute])
		return NSAccessibilityGroupRole;
	
	return [super accessibilityAttributeValue:attribute];
}

@end
