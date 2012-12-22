// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "CTTabStripDragController.h"

#import "CTTabController.h"
#import "CTTabControllerTarget.h"
#import "CTTabView.h"
#import "CTTabStripView.h"
#import "CTTabWindowController.h"

// Replicate specific 10.7 SDK declarations for building with prior SDKs.
#if !defined(MAC_OS_X_VERSION_10_7) || \
MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_7

enum {
	NSWindowAnimationBehaviorDefault = 0,
	NSWindowAnimationBehaviorNone = 2,
	NSWindowAnimationBehaviorDocumentWindow = 3,
	NSWindowAnimationBehaviorUtilityWindow = 4,
	NSWindowAnimationBehaviorAlertPanel = 5
};
typedef NSInteger NSWindowAnimationBehavior;

@interface NSWindow (LionSDKDeclarations)
- (NSWindowAnimationBehavior)animationBehavior;
- (void)setAnimationBehavior:(NSWindowAnimationBehavior)newAnimationBehavior;
@end

#endif  // MAC_OS_X_VERSION_10_7

const CGFloat kTearDistance = 36.0;
const NSTimeInterval kTearDuration = 0.333;

#define kVK_Escape 0x1B

@interface CTTabStripDragController (Private)
- (void)resetDragControllers;
- (NSArray*)dropTargetsForController:(CTTabWindowController*)dragController;
- (void)setWindowBackgroundVisibility:(BOOL)shouldBeVisible;
- (void)endDrag:(NSEvent*)event;
- (void)continueDrag:(NSEvent*)event;
@end

////////////////////////////////////////////////////////////////////////////////

@implementation CTTabStripDragController

- (id)initWithTabStripController:(CTTabStripController*)controller {
	if ((self = [super init])) {
		tabStrip_ = controller;
	}
	return self;
}

- (void)dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (BOOL)tabCanBeDragged:(CTTabController*)tab {
	if ([[tab tabView] isClosing])
		return NO;
	NSWindowController* controller = [sourceWindow_ windowController];
	if ([controller isKindOfClass:[CTTabWindowController class]]) {
		CTTabWindowController* realController = (CTTabWindowController*)controller;
		return [realController isTabDraggable:[tab tabView]];
	}
	return YES;
}

- (void)maybeStartDrag:(NSEvent*)theEvent forTab:(CTTabController*)tab {
	[self resetDragControllers];
	
	// Resolve overlay back to original window.
	sourceWindow_ = [[tab view] window];
	if ([sourceWindow_ isKindOfClass:[NSPanel class]]) {
		sourceWindow_ = [sourceWindow_ parentWindow];
	}
	
	sourceWindowFrame_ = [sourceWindow_ frame];
	sourceTabFrame_ = [[tab view] frame];
	sourceController_ = [sourceWindow_ windowController];
	draggedTab_ = tab;
	tabWasDragged_ = NO;
	tearTime_ = 0.0;
	draggingWithinTabStrip_ = YES;
	chromeIsVisible_ = NO;
	
	// If there's more than one potential window to be a drop target, we want to
	// treat a drag of a tab just like dragging around a tab that's already
	// detached. Note that unit tests might have |-numberOfTabs| reporting zero
	// since the model won't be fully hooked up. We need to be prepared for that
	// and not send them into the "magnetic" codepath.
	NSArray* targets = [self dropTargetsForController:sourceController_];
	moveWindowOnDrag_ =
	([sourceController_ numberOfTabs] < 2 && ![targets count]) ||
	![self tabCanBeDragged:tab] ||
	![sourceController_ tabDraggingAllowed];
	// If we are dragging a tab, a window with a single tab should immediately
	// snap off and not drag within the tab strip.
	if (!moveWindowOnDrag_)
		draggingWithinTabStrip_ = [sourceController_ numberOfTabs] > 1;
	
	dragOrigin_ = [NSEvent mouseLocation];
	
	// When spinning the event loop, a tab can get detached, which could lead to
	// our own destruction. Keep ourselves around while spinning the loop.
//	CTTabStripDragController* keepAlive = [self retain];
	
	// Because we move views between windows, we need to handle the event loop
	// ourselves. Ideally we should use the standard event loop.
	while (1) {
		const NSUInteger mask =
        NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSKeyUpMask;
		theEvent =
        [NSApp nextEventMatchingMask:mask
                           untilDate:[NSDate distantFuture]
                              inMode:NSDefaultRunLoopMode
                             dequeue:YES];
		NSEventType type = [theEvent type];
		if (type == NSKeyUp) {
			if ([theEvent keyCode] == kVK_Escape) {
				// Cancel the drag and restore the previous state.
				if (draggingWithinTabStrip_) {
					// Simply pretend the tab wasn't dragged (far enough).
					tabWasDragged_ = NO;
				} else {
					[targetController_ removePlaceholder];
					if ([sourceController_ numberOfTabs] < 2) {
						// Revert to a single-tab window.
						targetController_ = nil;
					} else {
						// Change the target to the source controller.
						targetController_ = sourceController_;
						[targetController_ insertPlaceholderForTab:[tab tabView]
															 frame:sourceTabFrame_];
					}
				}
				// Simply end the drag at this point.
				[self endDrag:theEvent];
				break;
			}
		} else if (type == NSLeftMouseDragged) {
			[self continueDrag:theEvent];
		} else if (type == NSLeftMouseUp) {
			if(![tab inRapidClosureMode]) {
                [[tab view] mouseUp:theEvent];
                [self endDrag:theEvent];
            }
			break;
		} else {
			// TODO(viettrungluu): [crbug.com/23830] We can receive right-mouse-ups
			// (and maybe even others?) for reasons I don't understand. So we
			// explicitly check for both events we're expecting, and log others. We
			// should figure out what's going on.
//			LOG(WARNING) << "Spurious event received of type " << type << ".";
		}
	}
}

- (void)continueDrag:(NSEvent*)theEvent {
	DCHECK(draggedTab_);
	
	// Cancel any delayed -continueDrag: requests that may still be pending.
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	// Special-case this to keep the logic below simpler.
	if (moveWindowOnDrag_) {
		if ([sourceController_ windowMovementAllowed]) {
			NSPoint thisPoint = [NSEvent mouseLocation];
			NSPoint origin = sourceWindowFrame_.origin;
			origin.x += (thisPoint.x - dragOrigin_.x);
			origin.y += (thisPoint.y - dragOrigin_.y);
			[sourceWindow_ setFrameOrigin:NSMakePoint(origin.x, origin.y)];
		}  // else do nothing.
		return;
	}
	
	// First, go through the magnetic drag cycle. We break out of this if
	// "stretchiness" ever exceeds a set amount.
	tabWasDragged_ = YES;
	
	if (draggingWithinTabStrip_) {
		NSPoint thisPoint = [NSEvent mouseLocation];
		CGFloat offset = thisPoint.x - dragOrigin_.x;
		[sourceController_ insertPlaceholderForTab:[draggedTab_ tabView]
											 frame:NSOffsetRect(sourceTabFrame_,
																offset, 0)];
		// Check that we haven't pulled the tab too far to start a drag. This
		// can include either pulling it too far down, or off the side of the tab
		// strip that would cause it to no longer be fully visible.
		BOOL stillVisible =
        [sourceController_ isTabFullyVisible:[draggedTab_ tabView]];
		CGFloat tearForce = fabs(thisPoint.y - dragOrigin_.y);
		if ([sourceController_ tabTearingAllowed] &&
			(tearForce > kTearDistance || !stillVisible)) {
			draggingWithinTabStrip_ = NO;
			// When you finally leave the strip, we treat that as the origin.
			dragOrigin_.x = thisPoint.x;
		} else {
			// Still dragging within the tab strip, wait for the next drag event.
			return;
		}
	}
	
	// Do not start dragging until the user has "torn" the tab off by
	// moving more than 3 pixels.
	NSPoint thisPoint = [NSEvent mouseLocation];
	
	// Iterate over possible targets checking for the one the mouse is in.
	// If the tab is just in the frame, bring the window forward to make it
	// easier to drop something there. If it's in the tab strip, set the new
	// target so that it pops into that window. We can't cache this because we
	// need the z-order to be correct.
	NSArray* targets = [self dropTargetsForController:draggedController_];
	CTTabWindowController* newTarget = nil;
	for (CTTabWindowController* target in targets) {
		NSRect windowFrame = [[target window] frame];
		if (NSPointInRect(thisPoint, windowFrame)) {
			[[target window] orderFront:self];
			NSRect tabStripFrame = [[target tabStripView] frame];
			tabStripFrame.origin = [[target window]
									convertBaseToScreen:tabStripFrame.origin];
			if (NSPointInRect(thisPoint, tabStripFrame)) {
				newTarget = target;
			}
			break;
		}
	}
	
	// If we're now targeting a new window, re-layout the tabs in the old
	// target and reset how long we've been hovering over this new one.
	if (targetController_ != newTarget) {
		[targetController_ removePlaceholder];
		targetController_ = newTarget;
		if (!newTarget) {
			tearTime_ = [NSDate timeIntervalSinceReferenceDate];
			tearOrigin_ = [dragWindow_ frame].origin;
		}
	}
	
	// Create or identify the dragged controller.
	if (!draggedController_) {
		// Get rid of any placeholder remaining in the original source window.
		[sourceController_ removePlaceholder];
		
		// Detach from the current window and put it in a new window. If there are
		// no more tabs remaining after detaching, the source window is about to
		// go away (it's been autoreleased) so we need to ensure we don't reference
		// it any more. In that case the new controller becomes our source
		// controller.
		draggedController_ =
        [sourceController_ detachTabToNewWindow:[draggedTab_ tabView]];
		dragWindow_ = [draggedController_ window];
		[dragWindow_ setAlphaValue:0.0];
		if (![sourceController_ hasLiveTabs]) {
			sourceController_ = draggedController_;
			sourceWindow_ = dragWindow_;
		}
		
		// Disable window animation before calling |orderFront:| when detatching
		// to a new window.
		NSWindowAnimationBehavior savedAnimationBehavior =
        NSWindowAnimationBehaviorDefault;
		BOOL didSaveAnimationBehavior = NO;
		if ([dragWindow_ respondsToSelector:@selector(animationBehavior)] &&
			[dragWindow_ respondsToSelector:@selector(setAnimationBehavior:)]) {
			didSaveAnimationBehavior = YES;
			savedAnimationBehavior = [dragWindow_ animationBehavior];
			[dragWindow_ setAnimationBehavior:NSWindowAnimationBehaviorNone];
		}
		
		// If dragging the tab only moves the current window, do not show overlay
		// so that sheets stay on top of the window.
		// Bring the target window to the front and make sure it has a border.
		[dragWindow_ setLevel:NSFloatingWindowLevel];
		[dragWindow_ setHasShadow:YES];
		[dragWindow_ orderFront:nil];
		[dragWindow_ makeMainWindow];
		[draggedController_ showOverlay];
		dragOverlay_ = [draggedController_ overlayWindow];
		// Force the new tab button to be hidden. We'll reset it on mouse up.
		[draggedController_ setShowsNewTabButton:NO];
		tearTime_ = [NSDate timeIntervalSinceReferenceDate];
		tearOrigin_ = sourceWindowFrame_.origin;
		
		// Restore window animation behavior.
		if (didSaveAnimationBehavior)
			[dragWindow_ setAnimationBehavior:savedAnimationBehavior];
	}
	
	// TODO(pinkerton): http://crbug.com/25682 demonstrates a way to get here by
	// some weird circumstance that doesn't first go through mouseDown:. We
	// really shouldn't go any farther.
	if (!draggedController_ || !sourceController_)
		return;
	
	// When the user first tears off the window, we want slide the window to
	// the current mouse location (to reduce the jarring appearance). We do this
	// by calling ourselves back with additional -continueDrag: calls (not actual
	// events). |tearProgress| is a normalized measure of how far through this
	// tear "animation" (of length kTearDuration) we are and has values [0..1].
	// We use sqrt() so the animation is non-linear (slow down near the end
	// point).
	NSTimeInterval tearProgress =
	[NSDate timeIntervalSinceReferenceDate] - tearTime_;
	tearProgress /= kTearDuration;  // Normalize.
	tearProgress = sqrtf(MAX(MIN(tearProgress, 1.0), 0.0));
	
	// Move the dragged window to the right place on the screen.
	NSPoint origin = sourceWindowFrame_.origin;
	origin.x += (thisPoint.x - dragOrigin_.x);
	origin.y += (thisPoint.y - dragOrigin_.y);
	
	if (tearProgress < 1) {
		// If the tear animation is not complete, call back to ourself with the
		// same event to animate even if the mouse isn't moving. We need to make
		// sure these get cancelled in -endDrag:.
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
		[self performSelector:@selector(continueDrag:)
				   withObject:theEvent
				   afterDelay:1.0f/30.0f];
		
		// Set the current window origin based on how far we've progressed through
		// the tear animation.
		origin.x = (1 - tearProgress) * tearOrigin_.x + tearProgress * origin.x;
		origin.y = (1 - tearProgress) * tearOrigin_.y + tearProgress * origin.y;
	}
	
	if (targetController_) {
		// In order to "snap" two windows of different sizes together at their
		// toolbar, we can't just use the origin of the target frame. We also have
		// to take into consideration the difference in height.
		NSRect targetFrame = [[targetController_ window] frame];
		NSRect sourceFrame = [dragWindow_ frame];
		origin.y = NSMinY(targetFrame) +
		(NSHeight(targetFrame) - NSHeight(sourceFrame));
	}
	[dragWindow_ setFrameOrigin:NSMakePoint(origin.x, origin.y)];
	
	// If we're not hovering over any window, make the window fully
	// opaque. Otherwise, find where the tab might be dropped and insert
	// a placeholder so it appears like it's part of that window.
	if (targetController_) {
		if (![[targetController_ window] isKeyWindow])
			[[targetController_ window] orderFront:nil];
		
		// Compute where placeholder should go and insert it into the
		// destination tab strip.
		CTTabView* draggedTabView = (CTTabView*)[draggedController_ activeTabView];
		NSRect tabFrame = [draggedTabView frame];
		tabFrame.origin = [dragWindow_ convertBaseToScreen:tabFrame.origin];
		tabFrame.origin = [[targetController_ window]
						   convertScreenToBase:tabFrame.origin];
		tabFrame = [[targetController_ tabStripView]
					convertRect:tabFrame fromView:nil];
		[targetController_ insertPlaceholderForTab:[draggedTab_ tabView]
											 frame:tabFrame];
		[targetController_ layoutTabs];
	} else {
		[dragWindow_ makeKeyAndOrderFront:nil];
	}
	
	// Adjust the visibility of the window background. If there is a drop target,
	// we want to hide the window background so the tab stands out for
	// positioning. If not, we want to show it so it looks like a new window will
	// be realized.
	BOOL chromeShouldBeVisible = targetController_ == nil;
	[self setWindowBackgroundVisibility:chromeShouldBeVisible];
}

- (void)endDrag:(NSEvent*)event {
	// Cancel any delayed -continueDrag: requests that may still be pending.
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	// Special-case this to keep the logic below simpler.
	if (moveWindowOnDrag_) {
		[self resetDragControllers];
		return;
	}
	
	// TODO(pinkerton): http://crbug.com/25682 demonstrates a way to get here by
	// some weird circumstance that doesn't first go through mouseDown:. We
	// really shouldn't go any farther.
	if (!sourceController_)
		return;
	
	// We are now free to re-display the new tab button in the window we're
	// dragging. It will show when the next call to -layoutTabs (which happens
	// indrectly by several of the calls below, such as removing the placeholder).
	[draggedController_ setShowsNewTabButton:YES];
	
	if (draggingWithinTabStrip_) {
		if (tabWasDragged_) {
			// Move tab to new location.
			DCHECK([sourceController_ numberOfTabs]);
			CTTabWindowController* dropController = sourceController_;
			[dropController moveTabView:[dropController activeTabView]
						 fromController:nil];
		}
	} else if (targetController_) {
		// Move between windows. If |targetController_| is nil, we're not dropping
		// into any existing window.
		NSView* draggedTabView = [draggedController_ activeTabView];
		[targetController_ moveTabView:draggedTabView
						fromController:draggedController_];
		// Force redraw to avoid flashes of old content before returning to event
		// loop.
		[[targetController_ window] display];
		[targetController_ showWindow:nil];
		[draggedController_ removeOverlay];
	} else {
		// Only move the window around on screen. Make sure it's set back to
		// normal state (fully opaque, has shadow, has key, etc).
		[draggedController_ removeOverlay];
		// Don't want to re-show the window if it was closed during the drag.
		if ([dragWindow_ isVisible]) {
			[dragWindow_ setAlphaValue:1.0];
			[dragOverlay_ setHasShadow:NO];
			[dragWindow_ setHasShadow:YES];
			[dragWindow_ makeKeyAndOrderFront:nil];
		}
		[[draggedController_ window] setLevel:NSNormalWindowLevel];
		[draggedController_ removePlaceholder];
	}
	[sourceController_ removePlaceholder];
	chromeIsVisible_ = YES;
	
	[self resetDragControllers];
}

// Private /////////////////////////////////////////////////////////////////////

// Call to clear out transient weak references we hold during drags.
- (void)resetDragControllers {
	draggedTab_ = nil;
	draggedController_ = nil;
	dragWindow_ = nil;
	dragOverlay_ = nil;
	sourceController_ = nil;
	sourceWindow_ = nil;
	targetController_ = nil;
}

// Returns an array of controllers that could be a drop target, ordered front to
// back. It has to be of the appropriate class, and visible (obviously). Note
// that the window cannot be a target for itself.
- (NSArray*)dropTargetsForController:(CTTabWindowController*)dragController {
	NSMutableArray* targets = [NSMutableArray array];
	NSWindow* dragWindow = [dragController window];
	for (NSWindow* window in [NSApp orderedWindows]) {
		if (window == dragWindow) continue;
		if (![window isVisible]) continue;
		// Skip windows on the wrong space.
		if ([window respondsToSelector:@selector(isOnActiveSpace)]) {
			if (![window performSelector:@selector(isOnActiveSpace)])
				continue;
		} 
		NSWindowController* controller = [window windowController];
		if ([controller isKindOfClass:[CTTabWindowController class]]) {
			CTTabWindowController* realController = (CTTabWindowController*)controller;
			if ([realController canReceiveFrom:dragController])
				[targets addObject:controller];
		}
	}
	return targets;
}

// Sets whether the window background should be visible or invisible when
// dragging a tab. The background should be invisible when the mouse is over a
// potential drop target for the tab (the tab strip). It should be visible when
// there's no drop target so the window looks more fully realized and ready to
// become a stand-alone window.
- (void)setWindowBackgroundVisibility:(BOOL)shouldBeVisible {
	if (chromeIsVisible_ == shouldBeVisible)
		return;
	
	// There appears to be a race-condition in CoreAnimation where if we use
	// animators to set the alpha values, we can't guarantee that we cancel them.
	// This has the side effect of sometimes leaving the dragged window
	// translucent or invisible. As a result, don't animate the alpha change.
	[[draggedController_ overlayWindow] setAlphaValue:1.0];
	if (targetController_) {
		[dragWindow_ setAlphaValue:0.0];
		[[draggedController_ overlayWindow] setHasShadow:YES];
		[[targetController_ window] makeMainWindow];
	} else {
		[dragWindow_ setAlphaValue:0.5];
		[[draggedController_ overlayWindow] setHasShadow:NO];
		[[draggedController_ window] makeMainWindow];
	}
	chromeIsVisible_ = shouldBeVisible;
}

@end
