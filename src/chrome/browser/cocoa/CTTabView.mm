// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabView.h"

#import "scoped_cftyperef.h"
#import "CTTabController.h"
#import "CTTabWindowController.h"
#import "NSWindow+CTThemed.h"

// ported from mac_util.mm:
static CFTypeRef GetValueFromDictionary(CFDictionaryRef dict,
                                        CFStringRef key,
                                        CFTypeID expected_type) {
  CFTypeRef value = CFDictionaryGetValue(dict, key);
  if (!value)
    return value;

  if (CFGetTypeID(value) != expected_type) {
    scoped_cftyperef<CFStringRef> expected_type_ref(
        CFCopyTypeIDDescription(expected_type));
    scoped_cftyperef<CFStringRef> actual_type_ref(
        CFCopyTypeIDDescription(CFGetTypeID(value)));
    NSLog(@"warning: Expected value for key %@ to be %@ but it was %@ instead",
          key, expected_type_ref.get(), actual_type_ref.get());
    return NULL;
  }

  return value;
}


namespace {

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

const CGFloat kTearDistance = 36.0;
const NSTimeInterval kTearDuration = 0.333;

// This is used to judge whether the mouse has moved during rapid closure; if it
// has moved less than the threshold, we want to close the tab.
const CGFloat kRapidCloseDist = 2.5;

}  // namespace

@interface CTTabView(Private)

- (void)resetLastGlowUpdateTime;
- (NSTimeInterval)timeElapsedSinceLastGlowUpdate;
- (void)adjustGlowValue;
// TODO(davidben): When we stop supporting 10.5, this can be removed.
- (int)getWorkspaceID:(NSWindow*)window useCache:(BOOL)useCache;
- (NSBezierPath*)bezierPathForRect:(NSRect)rect;

@end  // CTTabView(Private)

@implementation CTTabView

@synthesize state = state_;
@synthesize hoverAlpha = hoverAlpha_;
@synthesize alertAlpha = alertAlpha_;
@synthesize closing = closing_;

- (id)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setShowsDivider:NO];
    // TODO(alcor): register for theming
  }
  return self;
}

- (void)awakeFromNib {
  [self setShowsDivider:NO];
}

- (void)dealloc {
  // Cancel any delayed requests that may still be pending (drags or hover).
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  [super dealloc];
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
  NSPoint viewPoint = [self convertPoint:aPoint fromView:[self superview]];
  NSRect frame = [self frame];

  // Reduce the width of the hit rect slightly to remove the overlap
  // between adjacent tabs.  The drawing code in TabCell has the top
  // corners of the tab inset by height*2/3, so we inset by half of
  // that here.  This doesn't completely eliminate the overlap, but it
  // works well enough.
  NSRect hitRect = NSInsetRect(frame, frame.size.height / 3.0f, 0);
  if (![closeButton_ isHidden])
    if (NSPointInRect(viewPoint, [closeButton_ frame])) return closeButton_;
  if (NSPointInRect(aPoint, hitRect)) return self;
  return nil;
}

// Returns |YES| if this tab can be torn away into a new window.
- (BOOL)canBeDragged {
  if ([self isClosing])
    return NO;
  NSWindowController* controller = [sourceWindow_ windowController];
  if ([controller isKindOfClass:[CTTabWindowController class]]) {
    CTTabWindowController* realController =
        static_cast<CTTabWindowController*>(controller);
    return [realController isTabDraggable:self];
  }
  return YES;
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
    } else {
      // TODO(davidben): When we stop supporting 10.5, this can be
      // removed.
      //
      // We don't cache the workspace of |dragWindow| because it may
      // move around spaces.
      if ([self getWorkspaceID:dragWindow useCache:NO] !=
          [self getWorkspaceID:window useCache:YES])
        continue;
    }
    NSWindowController* controller = [window windowController];
    if ([controller isKindOfClass:[CTTabWindowController class]]) {
      CTTabWindowController* realController =
          static_cast<CTTabWindowController*>(controller);
      if ([realController canReceiveFrom:dragController])
        [targets addObject:controller];
    }
  }
  return targets;
}

// Call to clear out transient weak references we hold during drags.
- (void)resetDragControllers {
  draggedController_ = nil;
  dragWindow_ = nil;
  dragOverlay_ = nil;
  sourceController_ = nil;
  sourceWindow_ = nil;
  targetController_ = nil;
  workspaceIDCache_.clear();
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

// Handle clicks and drags in this button. We get here because we have
// overridden acceptsFirstMouse: and the click is within our bounds.
- (void)mouseDown:(NSEvent*)theEvent {
  if ([self isClosing])
    return;

  NSPoint downLocation = [theEvent locationInWindow];

  // Record the state of the close button here, because selecting the tab will
  // unhide it.
  BOOL closeButtonActive = [closeButton_ isHidden] ? NO : YES;

  // During the tab closure animation (in particular, during rapid tab closure),
  // we may get incorrectly hit with a mouse down. If it should have gone to the
  // close button, we send it there -- it should then track the mouse, so we
  // don't have to worry about mouse ups.
  if (closeButtonActive && [tabController_ inRapidClosureMode]) {
    NSPoint hitLocation = [[self superview] convertPoint:downLocation
                                                fromView:nil];
    if ([self hitTest:hitLocation] == closeButton_) {
      [closeButton_ mouseDown:theEvent];
      return;
    }
  }

  // Fire the action to select the tab.
  if ([[tabController_ target] respondsToSelector:[tabController_ action]])
    [[tabController_ target] performSelector:[tabController_ action]
                               withObject:self];

  [self resetDragControllers];

  // Resolve overlay back to original window.
  sourceWindow_ = [self window];
  if ([sourceWindow_ isKindOfClass:[NSPanel class]]) {
    sourceWindow_ = [sourceWindow_ parentWindow];
  }

  sourceWindowFrame_ = [sourceWindow_ frame];
  sourceTabFrame_ = [self frame];
  sourceController_ = [sourceWindow_ windowController];
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
      ![self canBeDragged] ||
      ![sourceController_ tabDraggingAllowed];
  // If we are dragging a tab, a window with a single tab should immediately
  // snap off and not drag within the tab strip.
  if (!moveWindowOnDrag_)
    draggingWithinTabStrip_ = [sourceController_ numberOfTabs] > 1;

  if (!draggingWithinTabStrip_) {
    [sourceController_ willStartTearingTab];
  }

  dragOrigin_ = [NSEvent mouseLocation];

  // If the tab gets torn off, the tab controller will be removed from the tab
  // strip and then deallocated. This will also result in *us* being
  // deallocated. Both these are bad, so we prevent this by retaining the
  // controller.
  scoped_nsobject<CTTabController> controller([tabController_ retain]);

  // Because we move views between windows, we need to handle the event loop
  // ourselves. Ideally we should use the standard event loop.
  while (1) {
    theEvent =
        [NSApp nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask
                           untilDate:[NSDate distantFuture]
                              inMode:NSDefaultRunLoopMode dequeue:YES];
    NSEventType type = [theEvent type];
    if (type == NSLeftMouseDragged) {
      [self mouseDragged:theEvent];
    } else if (type == NSLeftMouseUp) {
      NSPoint upLocation = [theEvent locationInWindow];
      CGFloat dx = upLocation.x - downLocation.x;
      CGFloat dy = upLocation.y - downLocation.y;

      // During rapid tab closure (mashing tab close buttons), we may get hit
      // with a mouse down. As long as the mouse up is over the close button,
      // and the mouse hasn't moved too much, we close the tab.
      if (closeButtonActive &&
          (dx*dx + dy*dy) <= kRapidCloseDist*kRapidCloseDist &&
          [controller inRapidClosureMode]) {
        NSPoint hitLocation =
            [[self superview] convertPoint:[theEvent locationInWindow]
                                  fromView:nil];
        if ([self hitTest:hitLocation] == closeButton_) {
          [controller closeTab:self];
          break;
        }
      }

      [self mouseUp:theEvent];
      break;
    } else {
      // TODO(viettrungluu): [crbug.com/23830] We can receive right-mouse-ups
      // (and maybe even others?) for reasons I don't understand. So we
      // explicitly check for both events we're expecting, and log others. We
      // should figure out what's going on.
      WLOG("Spurious event received of type %@", type);
    }
  }
}

- (void)mouseDragged:(NSEvent*)theEvent {
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
    CGFloat stretchiness = thisPoint.y - dragOrigin_.y;
    stretchiness = copysign(sqrtf(fabs(stretchiness))/sqrtf(kTearDistance),
                            stretchiness) / 2.0;
    CGFloat offset = thisPoint.x - dragOrigin_.x;
    if (fabsf(offset) > 100) stretchiness = 0;
    [sourceController_ insertPlaceholderForTab:self
                                         frame:NSOffsetRect(sourceTabFrame_,
                                                            offset, 0)
                                 yStretchiness:stretchiness];
    // Check that we haven't pulled the tab too far to start a drag. This
    // can include either pulling it too far down, or off the side of the tab
    // strip that would cause it to no longer be fully visible.
    BOOL stillVisible = [sourceController_ isTabFullyVisible:self];
    CGFloat tearForce = fabs(thisPoint.y - dragOrigin_.y);
    if ([sourceController_ tabTearingAllowed] &&
        (tearForce > kTearDistance || !stillVisible)) {
      draggingWithinTabStrip_ = NO;
      [sourceController_ willStartTearingTab];
      // When you finally leave the strip, we treat that as the origin.
      dragOrigin_.x = thisPoint.x;
    } else {
      // Still dragging within the tab strip, wait for the next drag event.
      return;
    }
  }

  // Do not start dragging until the user has "torn" the tab off by
  // moving more than 3 pixels.
  NSDate* targetDwellDate = nil;  // The date this target was first chosen.

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
    targetDwellDate = [NSDate date];
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
    draggedController_ = [sourceController_ detachTabToNewWindow:self];
    dragWindow_ = [draggedController_ window];
    [dragWindow_ setAlphaValue:0.0];
    if (![sourceController_ hasLiveTabs]) {
      sourceController_ = draggedController_;
      sourceWindow_ = dragWindow_;
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
    draggedController_.didShowNewTabButtonBeforeTemporalAction =
        draggedController_.showsNewTabButton;
    draggedController_.showsNewTabButton = NO;
    tearTime_ = [NSDate timeIntervalSinceReferenceDate];
    tearOrigin_ = sourceWindowFrame_.origin;
  }

  // TODO(pinkerton): http://crbug.com/25682 demonstrates a way to get here by
  // some weird circumstance that doesn't first go through mouseDown:. We
  // really shouldn't go any farther.
  if (!draggedController_ || !sourceController_)
    return;

  // When the user first tears off the window, we want slide the window to
  // the current mouse location (to reduce the jarring appearance). We do this
  // by calling ourselves back with additional mouseDragged calls (not actual
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
    // sure these get cancelled in mouseUp:.
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(mouseDragged:)
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
    if (![[targetController_ window] isKeyWindow]) {
      // && ([targetDwellDate timeIntervalSinceNow] < -REQUIRED_DWELL)) {
      [[targetController_ window] orderFront:nil];
      targetDwellDate = nil;
    }

    // Compute where placeholder should go and insert it into the
    // destination tab strip.
    CTTabView* draggedTabView = (CTTabView*)[draggedController_ selectedTabView];
    NSRect tabFrame = [draggedTabView frame];
    tabFrame.origin = [dragWindow_ convertBaseToScreen:tabFrame.origin];
    tabFrame.origin = [[targetController_ window]
                        convertScreenToBase:tabFrame.origin];
    tabFrame = [[targetController_ tabStripView]
                convertRect:tabFrame fromView:nil];
    [targetController_ insertPlaceholderForTab:self
                                         frame:tabFrame
                                 yStretchiness:0];
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

- (void)mouseUp:(NSEvent*)theEvent {
  // The drag/click is done. If the user dragged the mouse, finalize the drag
  // and clean up.

  // Special-case this to keep the logic below simpler.
  if (moveWindowOnDrag_)
    return;

  // Cancel any delayed -mouseDragged: requests that may still be pending.
  [NSObject cancelPreviousPerformRequestsWithTarget:self];

  // TODO(pinkerton): http://crbug.com/25682 demonstrates a way to get here by
  // some weird circumstance that doesn't first go through mouseDown:. We
  // really shouldn't go any farther.
  if (!sourceController_)
    return;

  // We are now free to re-display the new tab button in the window we're
  // dragging. It will show when the next call to -layoutTabs (which happens
  // indrectly by several of the calls below, such as removing the placeholder).
  draggedController_.showsNewTabButton =
      draggedController_.didShowNewTabButtonBeforeTemporalAction;

  if (draggingWithinTabStrip_) {
    if (tabWasDragged_) {
      // Move tab to new location.
      assert([sourceController_ numberOfTabs]);
      [sourceController_ moveTabView:[sourceController_ selectedTabView]
                      fromController:nil];
    }
  } else {
    // call willEndTearingTab before potentially moving the tab so the same
    // controller which got willStartTearingTab can reference the tab.
    [draggedController_ willEndTearingTab];
    if (targetController_) {
      // Move between windows. If |targetController_| is nil, we're not dropping
      // into any existing window.
      NSView* draggedTabView = [draggedController_ selectedTabView];
      [targetController_ moveTabView:draggedTabView
                      fromController:draggedController_];
      // Force redraw to avoid flashes of old content before returning to event
      // loop.
      [[targetController_ window] display];
      [targetController_ showWindow:nil];
      //[draggedController_ removeOverlay]; // <- causes an exception
      //DLOG_EXPR(targetController_);
      [targetController_ didEndTearingTab];
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
      //DLOG_EXPR(draggedController_);
      [draggedController_ didEndTearingTab];
    }
  }
  [sourceController_ removePlaceholder];
  chromeIsVisible_ = YES;

  [self resetDragControllers];
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
  // If this tab is phantom, do not draw the tab background itself. The only UI
  // element that will represent this tab is the favicon.
  if ([tabController_ phantom])
    return;

  NSGraphicsContext* context = [NSGraphicsContext currentContext];
  [context saveGraphicsState];
  [context setPatternPhase:[[self window] themePatternPhase]];

  NSRect rect = [self bounds];
  NSBezierPath* path = [self bezierPathForRect:rect];

  BOOL selected = [self state];
  // Don't draw the window/tab bar background when selected, since the tab
  // background overlay drawn over it (see below) will be fully opaque.
  if (!selected) {
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

  // Use the same overlay for the selected state and for hover and alert glows;
  // for the selected state, it's fully opaque.
  CGFloat hoverAlpha = [self hoverAlpha];
  CGFloat alertAlpha = [self alertAlpha];
  if (selected || hoverAlpha > 0 || alertAlpha > 0) {
    // Draw the selected background / glow overlay.
    [context saveGraphicsState];
    CGContextRef cgContext = static_cast<CGContextRef>([context graphicsPort]);
    CGContextBeginTransparencyLayer(cgContext, 0);
    if (!selected) {
      // The alert glow overlay is like the selected state but at most at most
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
    if (!selected && hoverAlpha > 0) {
      scoped_nsobject<NSGradient> glow([NSGradient alloc]);
      [glow initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0
                                      alpha:1.0 * hoverAlpha]
                      endingColor:[NSColor colorWithCalibratedWhite:1.0
                                                              alpha:0.0]];

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
  CGFloat borderAlpha = selected ? (active ? 0.3 : 0.2) : 0.2;
  // TODO: cache colors
  NSColor* borderColor = [NSColor colorWithDeviceWhite:0.0 alpha:borderAlpha];
  NSColor* highlightColor = [NSColor colorWithCalibratedWhite:0xf7/255.0 alpha:1.0];
  // Draw the top inner highlight within the currently selected tab if using
  // the default theme.
  if (selected) {
    NSAffineTransform* highlightTransform = [NSAffineTransform transform];
    [highlightTransform translateXBy:1.0 yBy:-1.0];
    scoped_nsobject<NSBezierPath> highlightPath([path copy]);
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
  if (!selected) {
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
  closing_ = closing;  // Safe because the property is nonatomic.
  // When closing, ensure clicks to the close button go nowhere.
  if (closing) {
    [closeButton_ setTarget:nil];
    [closeButton_ setAction:nil];
  }
}

- (void)startAlert {
  // Do not start a new alert while already alerting or while in a decay cycle.
  if (alertState_ == tabs::kAlertNone) {
    alertState_ = tabs::kAlertRising;
    [self resetLastGlowUpdateTime];
    [self adjustGlowValue];
  }
}

- (void)cancelAlert {
  if (alertState_ != tabs::kAlertNone) {
    alertState_ = tabs::kAlertFalling;
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
  if (alertState_ == tabs::kAlertRising) {
    // Increase alert glow until it's 1 ...
    alertAlpha = MIN(alertAlpha + elapsed / kAlertShowDuration, 1);
    [self setAlertAlpha:alertAlpha];

    // ... and having reached 1, switch to holding.
    if (alertAlpha >= 1) {
      alertState_ = tabs::kAlertHolding;
      alertHoldEndTime_ = currentTime + kAlertHoldDuration;
      nextUpdate = MIN(kAlertHoldDuration, nextUpdate);
    } else {
      nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
    }
  } else if (alertState_ != tabs::kAlertNone) {
    if (alertAlpha > 0) {
      if (currentTime >= alertHoldEndTime_) {
        // Stop holding, then decrease alert glow (until it's 0).
        if (alertState_ == tabs::kAlertHolding) {
          alertState_ = tabs::kAlertFalling;
          nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
        } else {
          DCHECK_EQ(tabs::kAlertFalling, alertState_);
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
      alertState_ = tabs::kAlertNone;
    }
  }

  if (nextUpdate < kNoUpdate)
    [self performSelector:_cmd withObject:nil afterDelay:nextUpdate];

  [self resetLastGlowUpdateTime];
  [self setNeedsDisplay:YES];
}

// Returns the workspace id of |window|. If |useCache|, then lookup
// and remember the value in |workspaceIDCache_| until the end of the
// current drag.
- (int)getWorkspaceID:(NSWindow*)window useCache:(BOOL)useCache {
  CGWindowID windowID = [window windowNumber];
  if (useCache) {
    std::map<CGWindowID, int>::iterator iter =
        workspaceIDCache_.find(windowID);
    if (iter != workspaceIDCache_.end())
      return iter->second;
  }

  int workspace = -1;
  // It's possible to query in bulk, but probably not necessary.
  scoped_cftyperef<CFArrayRef> windowIDs(CFArrayCreate(
      NULL, reinterpret_cast<const void **>(&windowID), 1, NULL));
  scoped_cftyperef<CFArrayRef> descriptions(
      CGWindowListCreateDescriptionFromArray(windowIDs));
  assert(CFArrayGetCount(descriptions.get()) <= 1);
  if (CFArrayGetCount(descriptions.get()) > 0) {
    CFDictionaryRef dict = static_cast<CFDictionaryRef>(
        CFArrayGetValueAtIndex(descriptions.get(), 0));
    assert(CFGetTypeID(dict) == CFDictionaryGetTypeID());

    // Sanity check the ID.
    CFNumberRef otherIDRef = (CFNumberRef)GetValueFromDictionary(
        dict, kCGWindowNumber, CFNumberGetTypeID());
    CGWindowID otherID;
    if (otherIDRef &&
        CFNumberGetValue(otherIDRef, kCGWindowIDCFNumberType, &otherID) &&
        otherID == windowID) {
      // And then get the workspace.
      CFNumberRef workspaceRef = (CFNumberRef)GetValueFromDictionary(
          dict, kCGWindowWorkspace, CFNumberGetTypeID());
      if (!workspaceRef ||
          !CFNumberGetValue(workspaceRef, kCFNumberIntType, &workspace)) {
        workspace = -1;
      }
    } else {
      NOTREACHED();
    }
  }
  if (useCache) {
    workspaceIDCache_[windowID] = workspace;
  }
  return workspace;
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
