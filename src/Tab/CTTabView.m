// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabView.h"

#import "CTTabController.h"
#import "CTTabWindowController.h"
#import "NSWindow+CTThemed.h"

#import "CTTabStripView.h"
#import "HoverCloseButton.h"

// Constants for inset and control points for tab shape.
const CGFloat kInsetMultiplier = 2.0/3.0;
const CGFloat kControlPoint1Multiplier = 1.0/3.0;
const CGFloat kControlPoint2Multiplier = 3.0/8.0;

// The amount of time in seconds during which each type of glow increases, holds
// steady, and decreases, respectively.
const NSTimeInterval kHoverShowDuration = 0.2;
const NSTimeInterval kHoverHoldDuration = 0.02;
const NSTimeInterval kHoverHideDuration = 0.4;
const NSTimeInterval kAlertShowDuration = 0.4;
const NSTimeInterval kAlertHoldDuration = 0.4;
const NSTimeInterval kAlertHideDuration = 0.4;

// The default time interval in seconds between glow updates (when
// increasing/decreasing).
const NSTimeInterval kGlowUpdateInterval = 0.025;

// This is used to judge whether the mouse has moved during rapid closure; if it
// has moved less than the threshold, we want to close the tab.
const CGFloat kRapidCloseDist = 2.5;

@interface CTTabView(Private)

- (void)resetLastGlowUpdateTime;
- (NSTimeInterval)timeElapsedSinceLastGlowUpdate;
- (void)adjustGlowValue;
- (NSBezierPath*)bezierPathForRect:(NSRect)rect;

@end  // CTTabView(Private)

@implementation CTTabView {
@private
	IBOutlet CTTabController* tabController_;
	// TODO(rohitrao): Add this button to a CoreAnimation layer so we can fade it
	// in and out on mouseovers.
	IBOutlet HoverCloseButton* closeButton_;
	BOOL isClosing_;
	
	// Tracking area for close button mouseover images.
	NSTrackingArea* closeTrackingArea_;
	
	BOOL isMouseInside_;  // Is the mouse hovering over?
	AlertState alertState_;
	
	CGFloat hoverAlpha_;  // How strong the hover glow is.
	NSTimeInterval hoverHoldEndTime_;  // When the hover glow will begin dimming.
	
	CGFloat alertAlpha_;  // How strong the alert glow is.
	NSTimeInterval alertHoldEndTime_;  // When the hover glow will begin dimming.
	
	NSTimeInterval lastGlowUpdate_;  // Time either glow was last updated.
	
	NSPoint hoverPoint_;  // Current location of hover in view coords.
	
	// The location of the current mouseDown event in window coordinates.
	NSPoint mouseDownPoint_;
	
	NSCellStateValue state_;
}

@synthesize state = state_;
@synthesize hoverAlpha = hoverAlpha_;
@synthesize alertAlpha = alertAlpha_;
@synthesize isClosing = isClosing_;

+ (CGFloat)insetMultiplier {
	return kInsetMultiplier;
}

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		[self setShowsDivider:NO];
	}
	return self;
}

- (void)awakeFromNib {
	[self setShowsDivider:NO];
}

- (void)dealloc {
	// Cancel any delayed requests that may still be pending (drags or hover).
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

// Called to obtain the context menu for when the user hits the right mouse
// button (or control-clicks). (Note that -rightMouseDown: is *not* called for
// control-click.)
- (NSMenu*)menu {
	if ([self isClosing])
		return nil;
	
	// Sheets, being window-modal, should block contextual menus. For some reason
	// they do not. Disallow them ourselves.
	if ([[self window] attachedSheet])
		return nil;
	
	return [tabController_ menu];
}

// Overridden so that mouse clicks come to this view (the parent of the
// hierarchy) first. We want to handle clicks and drags in this class and
// leave the background button for display purposes only.
- (BOOL)acceptsFirstMouse:(NSEvent*)theEvent {
	return YES;
}

- (void)mouseEntered:(NSEvent*)theEvent {
	isMouseInside_ = YES;
	[self resetLastGlowUpdateTime];
	[self adjustGlowValue];
}

- (void)mouseMoved:(NSEvent*)theEvent {
	hoverPoint_ = [self convertPoint:[theEvent locationInWindow]
							fromView:nil];
	[self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent*)theEvent {
	isMouseInside_ = NO;
	hoverHoldEndTime_ =
		[NSDate timeIntervalSinceReferenceDate] + kHoverHoldDuration;
	[self resetLastGlowUpdateTime];
	[self adjustGlowValue];
}

- (void)setTrackingEnabled:(BOOL)enabled {
	[closeButton_ setTrackingEnabled:enabled];
}

// Determines which view a click in our frame actually hit. It's either this
// view or our child close button.
- (NSView*)hitTest:(NSPoint)aPoint {
//	NSPoint viewPoint = [self convertPoint:aPoint fromView:[self superview]];
//	NSRect frame = [self frame];
//	
//	// Reduce the width of the hit rect slightly to remove the overlap
//	// between adjacent tabs.  The drawing code in TabCell has the top
//	// corners of the tab inset by height*2/3, so we inset by half of
//	// that here.  This doesn't completely eliminate the overlap, but it
//	// works well enough.
//	NSRect hitRect = NSInsetRect(frame, frame.size.height / 3.0f, 0);
//	if (![closeButton_ isHidden])
//		if (NSPointInRect(viewPoint, [closeButton_ frame])) return closeButton_;
//	if (NSPointInRect(aPoint, hitRect)) return self;
//	return nil;
	NSPoint viewPoint = [self convertPoint:aPoint fromView:[self superview]];
	NSRect rect = [self bounds];
	NSBezierPath* path = [self bezierPathForRect:rect];
	
	if (![closeButton_ isHidden])
		if (NSPointInRect(viewPoint, [closeButton_ frame])) return closeButton_;
	if ([path containsPoint:viewPoint]) return self;
	return nil;
}

// Returns |YES| if this tab can be torn away into a new window.
- (BOOL)canBeDragged {
	return [tabController_ tabCanBeDragged:tabController_];
}

// Handle clicks and drags in this button. We get here because we have
// overridden acceptsFirstMouse: and the click is within our bounds.
- (void)mouseDown:(NSEvent*)theEvent {
	if ([self isClosing])
		return;
	
	// Record the point at which this event happened. This is used by other mouse
	// events that are dispatched from |-maybeStartDrag::|.
	mouseDownPoint_ = [theEvent locationInWindow];
	
	// Record the state of the close button here, because selecting the tab will
	// unhide it.
	BOOL closeButtonActive = ![closeButton_ isHidden];
	
	// During the tab closure animation (in particular, during rapid tab closure),
	// we may get incorrectly hit with a mouse down. If it should have gone to the
	// close button, we send it there -- it should then track the mouse, so we
	// don't have to worry about mouse ups.
	if (closeButtonActive && [tabController_ inRapidClosureMode]) {
		NSPoint hitLocation = [[self superview] convertPoint:mouseDownPoint_
													fromView:nil];
		if ([self hitTest:hitLocation] == closeButton_) {
			[closeButton_ mouseDown:theEvent];
			return;
		}
	}
	
	// Try to initiate a drag. This will spin a custom event loop and may
	// dispatch other mouse events.
	[tabController_ maybeStartDrag:theEvent forTab:tabController_];
	
	// The custom loop has ended, so clear the point.
	mouseDownPoint_ = NSZeroPoint;
}

- (void)mouseUp:(NSEvent*)theEvent {
	// Check for rapid tab closure.
	if ([theEvent type] == NSLeftMouseUp) {
		NSPoint upLocation = [theEvent locationInWindow];
		CGFloat dx = upLocation.x - mouseDownPoint_.x;
		CGFloat dy = upLocation.y - mouseDownPoint_.y;
		
		// During rapid tab closure (mashing tab close buttons), we may get hit
		// with a mouse down. As long as the mouse up is over the close button,
		// and the mouse hasn't moved too much, we close the tab.
		if (![closeButton_ isHidden] &&
			(dx*dx + dy*dy) <= kRapidCloseDist*kRapidCloseDist &&
			[tabController_ inRapidClosureMode]) {
			NSPoint hitLocation =
			[[self superview] convertPoint:[theEvent locationInWindow]
								  fromView:nil];
			if ([self hitTest:hitLocation] == closeButton_) {
				[tabController_ closeTab:self];
				return;
			}
		}
	}
	
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	// Fire the action to select the tab.
	if ([[tabController_ target] respondsToSelector:[tabController_ action]])
		[[tabController_ target] performSelector:[tabController_ action]
									  withObject:self];
	#pragma clang diagnostic pop
    
	// Messaging the drag controller with |-endDrag:| would seem like the right
	// thing to do here. But, when a tab has been detached, the controller's
	// target is nil until the drag is finalized. Since |-mouseUp:| gets called
	// via the manual event loop inside -[TabStripDragController
	// maybeStartDrag:forTab:], the drag controller can end the dragging session
	// itself directly after calling this.
}

- (void)otherMouseUp:(NSEvent*)theEvent {
	if ([self isClosing])
		return;
	
	// Support middle-click-to-close.
	if ([theEvent buttonNumber] == 2) {
		// |-hitTest:| takes a location in the superview's coordinates.
		NSPoint upLocation =
			[[self superview] convertPoint:[theEvent locationInWindow]
								  fromView:nil];
		// If the mouse up occurred in our view or over the close button, then
		// close.
		if ([self hitTest:upLocation])
			[tabController_ closeTab:self];
	}
}

- (void)drawRect:(NSRect)dirtyRect {
	NSGraphicsContext* context = [NSGraphicsContext currentContext];
	[context saveGraphicsState];
	[context setPatternPhase:[[self window] themePatternPhase]];
	
	NSRect rect = [self bounds];
	NSBezierPath* path = [self bezierPathForRect:rect];
	
	BOOL isActive = [self state];
	// Don't draw the window/tab bar background when active, since the tab
	// background overlay drawn over it (see below) will be fully opaque.
	if (!isActive) {
		// Use the window's background color rather than |[NSColor
		// windowBackgroundColor]|, which gets confused by the fullscreen window.
		// (The result is the same for normal, non-fullscreen windows.)
		[[[self window] backgroundColor] set];
		[path fill];
		[[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] set];
		[path fill];
	}
	
	[context saveGraphicsState];
	[path addClip];
	
	// Use the same overlay for the active state and for hover and alert glows;
	// for the active state, it's fully opaque.
	CGFloat hoverAlpha = [self hoverAlpha];
	CGFloat alertAlpha = [self alertAlpha];
	if (isActive || hoverAlpha > 0 || alertAlpha > 0) {
		// Draw the active background / glow overlay.
		[context saveGraphicsState];
		CGContextRef cgContext = [context graphicsPort];
		CGContextBeginTransparencyLayer(cgContext, 0);
		if (!isActive) {
			// The alert glow overlay is like the active state but at most at most
			// 80% opaque. The hover glow brings up the overlay's opacity at most 50%.
			CGFloat backgroundAlpha = 0.8 * alertAlpha;
			backgroundAlpha += (1 - backgroundAlpha) * 0.5 * hoverAlpha;
			CGContextSetAlpha(cgContext, backgroundAlpha);
		}
		[path addClip];
		[context saveGraphicsState];
		[super drawBackground];
		[context restoreGraphicsState];
		
		// Draw a mouse hover gradient for the default themes.
		if (!isActive && hoverAlpha > 0) {
			NSGradient* glow = [[NSGradient alloc] 
				initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0	alpha:1.0 * hoverAlpha]
						  endingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];
			NSPoint point = hoverPoint_;
			point.y = NSHeight(rect);
			[glow drawFromCenter:point
						  radius:0.0
						toCenter:point
						  radius:NSWidth(rect) / 3.0
						 options:NSGradientDrawsBeforeStartingLocation];
			
			[glow drawInBezierPath:path relativeCenterPosition:hoverPoint_];
		}
		
		CGContextEndTransparencyLayer(cgContext);
		[context restoreGraphicsState];
	}
	
	BOOL active = [[self window] isKeyWindow] || [[self window] isMainWindow];
	CGFloat borderAlpha = isActive ? (active ? 0.3 : 0.2) : 0.2;
	// TODO: cache colors
	NSColor* borderColor = [NSColor colorWithDeviceWhite:0.0 alpha:borderAlpha];
	NSColor* highlightColor = [NSColor colorWithCalibratedWhite:0xf7/255.0 alpha:1.0];
	// Draw the top inner highlight within the currently active tab if using
	// the default theme.
	if (isActive) {
		NSAffineTransform* highlightTransform = [NSAffineTransform transform];
		[highlightTransform translateXBy:1.0 yBy:-1.0];
		NSBezierPath* highlightPath = [path copy];
		[highlightPath transformUsingAffineTransform:highlightTransform];
		[highlightColor setStroke];
		[highlightPath setLineWidth:1.0];
		[highlightPath stroke];
		highlightTransform = [NSAffineTransform transform];
		[highlightTransform translateXBy:-2.0 yBy:0.0];
		[highlightPath transformUsingAffineTransform:highlightTransform];
		[highlightPath stroke];
	}
	
	[context restoreGraphicsState];
	
	// Draw the top stroke.
	[context saveGraphicsState];
	[borderColor set];
	[path setLineWidth:1.0];
	[path stroke];
	[context restoreGraphicsState];
	
	// Mimic the tab strip's bottom border, which consists of a dark border
	// and light highlight.
	if (!isActive) {
		[path addClip];
		NSRect borderRect = rect;
		borderRect.origin.y = 1;
		borderRect.size.height = 1;
		[borderColor set];
		NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
		
		borderRect.origin.y = 0;
		[highlightColor set];
		NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
	}
	
	[context restoreGraphicsState];
}

- (void)viewDidMoveToWindow {
	[super viewDidMoveToWindow];
	if ([self window]) {
		[tabController_ updateTitleColor];
	}
}

- (void)setClosing:(BOOL)closing {
	isClosing_ = closing;  // Safe because the property is nonatomic.
	// When closing, ensure clicks to the close button go nowhere.
	if (closing) {
		[closeButton_ setTarget:nil];
		[closeButton_ setAction:nil];
	}
}

- (void)startAlert {
	// Do not start a new alert while already alerting or while in a decay cycle.
	if (alertState_ == kAlertNone) {
		alertState_ = kAlertRising;
		[self resetLastGlowUpdateTime];
		[self adjustGlowValue];
	}
}

- (void)cancelAlert {
	if (alertState_ != kAlertNone) {
		alertState_ = kAlertFalling;
		alertHoldEndTime_ =
        [NSDate timeIntervalSinceReferenceDate] + kGlowUpdateInterval;
		[self resetLastGlowUpdateTime];
		[self adjustGlowValue];
	}
}

- (BOOL)accessibilityIsIgnored {
	return NO;
}

- (NSArray*)accessibilityActionNames {
	NSArray* parentActions = [super accessibilityActionNames];
	
	return [parentActions arrayByAddingObject:NSAccessibilityPressAction];
}

- (NSArray*)accessibilityAttributeNames {
	NSMutableArray* attributes =
	[[super accessibilityAttributeNames] mutableCopy];
	[attributes addObject:NSAccessibilityTitleAttribute];
	[attributes addObject:NSAccessibilityEnabledAttribute];
	
	return attributes;
}

- (BOOL)accessibilityIsAttributeSettable:(NSString*)attribute {
	if ([attribute isEqual:NSAccessibilityTitleAttribute])
		return NO;
	
	if ([attribute isEqual:NSAccessibilityEnabledAttribute])
		return NO;
	
	return [super accessibilityIsAttributeSettable:attribute];
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
	if ([attribute isEqual:NSAccessibilityRoleAttribute])
		return NSAccessibilityButtonRole;
	
	if ([attribute isEqual:NSAccessibilityTitleAttribute])
		return [tabController_ title];
	
	if ([attribute isEqual:NSAccessibilityEnabledAttribute])
		return [NSNumber numberWithBool:YES];
	
	if ([attribute isEqual:NSAccessibilityChildrenAttribute]) {
		// The subviews (icon and text) are clutter; filter out everything but
		// useful controls.
		NSArray* children = [super accessibilityAttributeValue:attribute];
		NSMutableArray* okChildren = [NSMutableArray array];
		for (id child in children) {
			if ([child isKindOfClass:[NSButtonCell class]])
				[okChildren addObject:child];
		}
		
		return okChildren;
	}
	
	return [super accessibilityAttributeValue:attribute];
}

@end  // @implementation CTTabView

@implementation CTTabView (TabControllerInterface)

- (void)setController:(CTTabController*)controller {
	tabController_ = controller;
}
- (CTTabController*)controller { return tabController_; }

@end  // @implementation CTTabView (TabControllerInterface)

@implementation CTTabView(Private)

- (void)resetLastGlowUpdateTime {
	lastGlowUpdate_ = [NSDate timeIntervalSinceReferenceDate];
}

- (NSTimeInterval)timeElapsedSinceLastGlowUpdate {
	return [NSDate timeIntervalSinceReferenceDate] - lastGlowUpdate_;
}

- (void)adjustGlowValue {
	// A time interval long enough to represent no update.
	const NSTimeInterval kNoUpdate = 1000000;
	
	// Time until next update for either glow.
	NSTimeInterval nextUpdate = kNoUpdate;
	
	NSTimeInterval elapsed = [self timeElapsedSinceLastGlowUpdate];
	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
	
	// TODO(viettrungluu): <http://crbug.com/30617> -- split off the stuff below
	// into a pure function and add a unit test.
	
	CGFloat hoverAlpha = [self hoverAlpha];
	if (isMouseInside_) {
		// Increase hover glow until it's 1.
		if (hoverAlpha < 1) {
			hoverAlpha = MIN(hoverAlpha + elapsed / kHoverShowDuration, 1);
			[self setHoverAlpha:hoverAlpha];
			nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
		}  // Else already 1 (no update needed).
	} else {
		if (currentTime >= hoverHoldEndTime_) {
			// No longer holding, so decrease hover glow until it's 0.
			if (hoverAlpha > 0) {
				hoverAlpha = MAX(hoverAlpha - elapsed / kHoverHideDuration, 0);
				[self setHoverAlpha:hoverAlpha];
				nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
			}  // Else already 0 (no update needed).
		} else {
			// Schedule update for end of hold time.
			nextUpdate = MIN(hoverHoldEndTime_ - currentTime, nextUpdate);
		}
	}
	
	CGFloat alertAlpha = [self alertAlpha];
	if (alertState_ == kAlertRising) {
		// Increase alert glow until it's 1 ...
		alertAlpha = MIN(alertAlpha + elapsed / kAlertShowDuration, 1);
		[self setAlertAlpha:alertAlpha];
		
		// ... and having reached 1, switch to holding.
		if (alertAlpha >= 1) {
			alertState_ = kAlertHolding;
			alertHoldEndTime_ = currentTime + kAlertHoldDuration;
			nextUpdate = MIN(kAlertHoldDuration, nextUpdate);
		} else {
			nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
		}
	} else if (alertState_ != kAlertNone) {
		if (alertAlpha > 0) {
			if (currentTime >= alertHoldEndTime_) {
				// Stop holding, then decrease alert glow (until it's 0).
				if (alertState_ == kAlertHolding) {
					alertState_ = kAlertFalling;
					nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
				} else {
					DCHECK_EQ(kAlertFalling, alertState_);
					alertAlpha = MAX(alertAlpha - elapsed / kAlertHideDuration, 0);
					[self setAlertAlpha:alertAlpha];
					nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
				}
			} else {
				// Schedule update for end of hold time.
				nextUpdate = MIN(alertHoldEndTime_ - currentTime, nextUpdate);
			}
		} else {
			// Done the alert decay cycle.
			alertState_ = kAlertNone;
		}
	}
	
	if (nextUpdate < kNoUpdate)
		[self performSelector:_cmd withObject:nil afterDelay:nextUpdate];
	
	[self resetLastGlowUpdateTime];
	[self setNeedsDisplay:YES];
}

// Returns the bezier path used to draw the tab given the bounds to draw it in.
- (NSBezierPath*)bezierPathForRect:(NSRect)rect {
	// Outset by 0.5 in order to draw on pixels rather than on borders (which
	// would cause blurry pixels). Subtract 1px of height to compensate, otherwise
	// clipping will occur.
	rect = NSInsetRect(rect, -0.5, -0.5);
	rect.size.height -= 1.0;
	
	NSPoint bottomLeft = NSMakePoint(NSMinX(rect), NSMinY(rect) + 2);
	NSPoint bottomRight = NSMakePoint(NSMaxX(rect), NSMinY(rect) + 2);
	NSPoint topRight =
	NSMakePoint(NSMaxX(rect) - kInsetMultiplier * NSHeight(rect),
				NSMaxY(rect));
	NSPoint topLeft =
	NSMakePoint(NSMinX(rect)  + kInsetMultiplier * NSHeight(rect),
				NSMaxY(rect));
	
	CGFloat baseControlPointOutset = NSHeight(rect) * kControlPoint1Multiplier;
	CGFloat bottomControlPointInset = NSHeight(rect) * kControlPoint2Multiplier;
	
	// Outset many of these values by 1 to cause the fill to bleed outside the
	// clip area.
	NSBezierPath* path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(bottomLeft.x - 1, bottomLeft.y - 2)];
	[path lineToPoint:NSMakePoint(bottomLeft.x - 1, bottomLeft.y)];
	[path lineToPoint:bottomLeft];
	[path curveToPoint:topLeft
		 controlPoint1:NSMakePoint(bottomLeft.x + baseControlPointOutset,
								   bottomLeft.y)
		 controlPoint2:NSMakePoint(topLeft.x - bottomControlPointInset,
								   topLeft.y)];
	[path lineToPoint:topRight];
	[path curveToPoint:bottomRight
		 controlPoint1:NSMakePoint(topRight.x + bottomControlPointInset,
								   topRight.y)
		 controlPoint2:NSMakePoint(bottomRight.x - baseControlPointOutset,
								   bottomRight.y)];
	[path lineToPoint:NSMakePoint(bottomRight.x + 1, bottomRight.y)];
	[path lineToPoint:NSMakePoint(bottomRight.x + 1, bottomRight.y - 2)];
	return path;
}

@end  // @implementation CTTabView(Private)
