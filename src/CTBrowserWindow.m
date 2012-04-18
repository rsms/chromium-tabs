// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "CTBrowserWindow.h"

#import "CTBrowserWindowController.h"
#import "CTTabStripController.h"

// Size of the gradient. Empirically determined so that the gradient looks
// like what the heuristic does when there are just a few tabs.
const CGFloat kWindowGradientHeight = 24.0;


// Offsets from the top/left of the window frame to the top of the window
// controls (zoom, close, miniaturize) for a window with a tabstrip.
const NSInteger CTWindowButtonsWithTabStripOffsetFromTop = 11;
const NSInteger CTWindowButtonsWithTabStripOffsetFromLeft = 11;

// Offsets from the top/left of the window frame to the top of the window
// controls (zoom, close, miniaturize) for a window without a tabstrip.
const NSInteger CTWindowButtonsWithoutTabStripOffsetFromTop = 4;
const NSInteger CTWindowButtonsWithoutTabStripOffsetFromLeft = 8;

// Our browser window does some interesting things to get the behaviors that
// we want. We replace the standard window controls (zoom, close, miniaturize)
// with our own versions, so that we can position them slightly differently than
// the default window has them. To do this, we hide the ones that Apple provides
// us with, and create our own. This requires us to handle tracking for the
// buttons (so that they highlight and activate correctly) as well as implement
// the private method _mouseInGroup in our frame view class which is required
// to get the rollover highlight drawing to draw correctly.
@interface CTBrowserWindow(CTBrowserWindowPrivateMethods)
// Return the view that does the "frame" drawing.
- (NSView*)frameView;
@end

@implementation CTBrowserWindow {
	BOOL shouldHideTitle_;
	NSButton* closeButton_;
	NSButton* miniaturizeButton_;
	NSButton* zoomButton_;
	CGFloat windowButtonsInterButtonSpacing_;

	BOOL hasTabStrip_;
}
@synthesize windowButtonsInterButtonSpacing = windowButtonsInterButtonSpacing_;

- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag {
	if ((self = [super initWithContentRect:contentRect
								 styleMask:aStyle
								   backing:bufferingType
									 defer:flag])) {
		if (aStyle & NSTexturedBackgroundWindowMask) {
			// The following two calls fix http://www.crbug.com/25684 by preventing
			// the window from recalculating the border thickness as the window is
			// resized.
			// This was causing the window tint to change for the default system theme
			// when the window was being resized.
			[self setAutorecalculatesContentBorderThickness:NO forEdge:NSMaxYEdge];
			[self setContentBorderThickness:kWindowGradientHeight forEdge:NSMaxYEdge];
		}
		
		closeButton_ = [self standardWindowButton:NSWindowCloseButton];
		[closeButton_ setPostsFrameChangedNotifications:YES];
		miniaturizeButton_ = [self standardWindowButton:NSWindowMiniaturizeButton];
		[miniaturizeButton_ setPostsFrameChangedNotifications:YES];
		zoomButton_ = [self standardWindowButton:NSWindowZoomButton];
		[zoomButton_ setPostsFrameChangedNotifications:YES];
		
		windowButtonsInterButtonSpacing_ =
        NSMinX([miniaturizeButton_ frame]) - NSMaxX([closeButton_ frame]);
		
		NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
		[center addObserver:self
				   selector:@selector(adjustCloseButton:)
					   name:NSViewFrameDidChangeNotification
					 object:closeButton_];
		[center addObserver:self
				   selector:@selector(adjustMiniaturizeButton:)
					   name:NSViewFrameDidChangeNotification
					 object:miniaturizeButton_];
		[center addObserver:self
				   selector:@selector(adjustZoomButton:)
					   name:NSViewFrameDidChangeNotification
					 object:zoomButton_];
	}
	return self;
}

- (void)setWindowController:(NSWindowController*)controller {
	if (controller == [self windowController]) {
		return;
	}
	
	[super setWindowController:controller];
	
	CTBrowserWindowController* browserController = 
		(CTBrowserWindowController *)(controller);
	if ([browserController isKindOfClass:[CTBrowserWindowController class]]) {
		hasTabStrip_ = [browserController hasTabStrip];
	} else {
		hasTabStrip_ = NO;
	}
	
	// Force re-layout of the window buttons by wiggling the size of the frame
	// view.
	NSView* frameView = [[self contentView] superview];
	BOOL frameViewDidAutoresizeSubviews = [frameView autoresizesSubviews];
	[frameView setAutoresizesSubviews:NO];
	NSRect oldFrame = [frameView frame];
	[frameView setFrame:NSZeroRect];
	[frameView setFrame:oldFrame];
	[frameView setAutoresizesSubviews:frameViewDidAutoresizeSubviews];
}


- (void)adjustCloseButton:(NSNotification*)notification {
	[self adjustButton:[notification object]
				ofKind:NSWindowCloseButton];
}

- (void)adjustMiniaturizeButton:(NSNotification*)notification {
	[self adjustButton:[notification object]
				ofKind:NSWindowMiniaturizeButton];
}

- (void)adjustZoomButton:(NSNotification*)notification {
	[self adjustButton:[notification object]
				ofKind:NSWindowZoomButton];
}

- (void)adjustButton:(NSButton*)button
              ofKind:(NSWindowButton)kind {
	NSRect buttonFrame = [button frame];
	NSRect frameViewBounds = [[self frameView] bounds];
	
	CGFloat xOffset = hasTabStrip_ 
		? CTWindowButtonsWithTabStripOffsetFromLeft
		: CTWindowButtonsWithoutTabStripOffsetFromLeft;
	CGFloat yOffset = hasTabStrip_
		? CTWindowButtonsWithTabStripOffsetFromTop
		: CTWindowButtonsWithoutTabStripOffsetFromTop;
	buttonFrame.origin =
	NSMakePoint(xOffset, (NSHeight(frameViewBounds) -
						  NSHeight(buttonFrame) - yOffset));
	
	switch (kind) {
		case NSWindowZoomButton:
			buttonFrame.origin.x += NSWidth([miniaturizeButton_ frame]);
			buttonFrame.origin.x += windowButtonsInterButtonSpacing_;
			// fallthrough
		case NSWindowMiniaturizeButton:
			buttonFrame.origin.x += NSWidth([closeButton_ frame]);
			buttonFrame.origin.x += windowButtonsInterButtonSpacing_;
			// fallthrough
		default:
			break;
	}
	
	BOOL didPost = [button postsBoundsChangedNotifications];
	[button setPostsFrameChangedNotifications:NO];
	[button setFrame:buttonFrame];
	[button setPostsFrameChangedNotifications:didPost];
}

- (NSView*)frameView {
	return [[self contentView] superview];
}

// The tab strip view covers our window buttons. So we add hit testing here
// to find them properly and return them to the accessibility system.
- (id)accessibilityHitTest:(NSPoint)point {
	NSPoint windowPoint = [self convertScreenToBase:point];
	NSControl* controls[] = { closeButton_, zoomButton_, miniaturizeButton_ };
	id value = nil;
	for (size_t i = 0; i < sizeof(controls) / sizeof(controls[0]); ++i) {
		if (NSPointInRect(windowPoint, [controls[i] frame])) {
			value = [controls[i] accessibilityHitTest:point];
			break;
		}
	}
	if (!value) {
		value = [super accessibilityHitTest:point];
	}
	return value;
}

- (void)windowMainStatusChanged {
	NSView* frameView = [self frameView];
	NSView* contentView = [self contentView];
	NSRect updateRect = [frameView frame];
	NSRect contentRect = [contentView frame];
	CGFloat tabStripHeight = [CTTabStripController defaultTabHeight];
	updateRect.size.height -= NSHeight(contentRect) - tabStripHeight;
	updateRect.origin.y = NSMaxY(contentRect) - tabStripHeight;
	[[self frameView] setNeedsDisplayInRect:updateRect];
}

- (void)becomeMainWindow {
	[self windowMainStatusChanged];
	[super becomeMainWindow];
}

- (void)resignMainWindow {
	[self windowMainStatusChanged];
	[super resignMainWindow];
}

// Called after the current theme has changed.
- (void)themeDidChangeNotification:(NSNotification*)aNotification {
	[[self frameView] setNeedsDisplay:YES];
}

- (void)sendEvent:(NSEvent*)event {
	// For cocoa windows, clicking on the close and the miniaturize (but not the
	// zoom buttons) while a window is in the background does NOT bring that
	// window to the front. We don't get that behavior for free, so we handle
	// it here. Zoom buttons do bring the window to the front. Note that
	// Finder windows (in Leopard) behave differently in this regard in that
	// zoom buttons don't bring the window to the foreground.
	BOOL eventHandled = NO;
	if (![self isMainWindow]) {
		if ([event type] == NSLeftMouseDown) {
			NSView* frameView = [self frameView];
			NSPoint mouse = [frameView convertPoint:[event locationInWindow]
										   fromView:nil];
			if (NSPointInRect(mouse, [closeButton_ frame])) {
				[closeButton_ mouseDown:event];
				eventHandled = YES;
			} else if (NSPointInRect(mouse, [miniaturizeButton_ frame])) {
				[miniaturizeButton_ mouseDown:event];
				eventHandled = YES;
			}
		}
	}
	if (!eventHandled) {
		[super sendEvent:event];
	}
}

- (void)setShouldHideTitle:(BOOL)flag {
	shouldHideTitle_ = flag;
}

-(BOOL)_isTitleHidden {
	return shouldHideTitle_;
}

// This method is called whenever a window is moved in order to ensure it fits
// on the screen.  We cannot always handle resizes without breaking, so we
// prevent frame constraining in those cases.
- (NSRect)constrainFrameRect:(NSRect)frame toScreen:(NSScreen*)screen {
	// Do not constrain the frame rect if our delegate says no.  In this case,
	// return the original (unconstrained) frame.
	id delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(shouldConstrainFrameRect)] &&
		![delegate shouldConstrainFrameRect])
		return frame;
	return [super constrainFrameRect:frame toScreen:screen];
}

- (NSPoint)themePatternPhase {
	id delegate = [self delegate];
	if (![delegate respondsToSelector:@selector(themePatternPhase)])
		return NSMakePoint(0, 0);
	return [delegate themePatternPhase];
}
@end
