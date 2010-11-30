// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "CTBrowserWindow.h"

#import "CTBrowserWindowController.h"
#import "CTTabStripController.h"
//#import "chrome/browser/cocoa/themed_window.h"
//#import "chrome/browser/global_keyboard_shortcuts_mac.h"
//#import "chrome/browser/renderer_host/render_widget_host_view_mac.h"

namespace {
  // Size of the gradient. Empirically determined so that the gradient looks
  // like what the heuristic does when there are just a few tabs.
  const CGFloat kWindowGradientHeight = 24.0;
}

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

@implementation CTBrowserWindow

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
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  if (widgetTrackingArea_) {
    [[self frameView] removeTrackingArea:widgetTrackingArea_];
    widgetTrackingArea_.reset();
  }
  [super dealloc];
}

- (void)setWindowController:(NSWindowController*)controller {
  if (controller == [self windowController]) {
    return;
  }
  // Clean up our old stuff.
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  [closeButton_ removeFromSuperview];
  closeButton_ = nil;
  [miniaturizeButton_ removeFromSuperview];
  miniaturizeButton_ = nil;
  [zoomButton_ removeFromSuperview];
  zoomButton_ = nil;

  [super setWindowController:controller];

  CTBrowserWindowController* browserController
      = static_cast<CTBrowserWindowController*>(controller);
  if ([browserController isKindOfClass:[CTBrowserWindowController class]]) {
    //NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];
    //[defaultCenter addObserver:self
    //                  selector:@selector(themeDidChangeNotification:)
    //                      name:kBrowserThemeDidChangeNotification
    //                    object:nil];

    // Hook ourselves up to get notified if the user changes the system
    // theme on us.
    NSDistributedNotificationCenter* distCenter =
        [NSDistributedNotificationCenter defaultCenter];
    [distCenter addObserver:self
                   selector:@selector(systemThemeDidChangeNotification:)
                       name:@"AppleAquaColorVariantChanged"
                     object:nil];
    // Set up our buttons how we like them.
    NSView* frameView = [self frameView];
    NSRect frameViewBounds = [frameView bounds];

    // Find all the "original" buttons, and hide them. We can't use the original
    // buttons because the OS likes to move them around when we resize windows
    // and will put them back in what it considers to be their "preferred"
    // locations.
    NSButton* oldButton = [self standardWindowButton:NSWindowCloseButton];
    [oldButton setHidden:YES];
    oldButton = [self standardWindowButton:NSWindowMiniaturizeButton];
    [oldButton setHidden:YES];
    oldButton = [self standardWindowButton:NSWindowZoomButton];
    [oldButton setHidden:YES];

    // Create and position our new buttons.
    NSUInteger aStyle = [self styleMask];
    closeButton_ = [NSWindow standardWindowButton:NSWindowCloseButton
                                     forStyleMask:aStyle];
    NSRect closeButtonFrame = [closeButton_ frame];
    CGFloat yOffset = [browserController hasTabStrip] ?
        CTWindowButtonsWithTabStripOffsetFromTop :
        CTWindowButtonsWithoutTabStripOffsetFromTop;
    closeButtonFrame.origin =
        NSMakePoint(CTWindowButtonsOffsetFromLeft,
                    (NSHeight(frameViewBounds) -
                     NSHeight(closeButtonFrame) - yOffset));

    [closeButton_ setFrame:closeButtonFrame];
    [closeButton_ setTarget:self];
    [closeButton_ setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
    [frameView addSubview:closeButton_];

    miniaturizeButton_ =
        [NSWindow standardWindowButton:NSWindowMiniaturizeButton
                          forStyleMask:aStyle];
    NSRect miniaturizeButtonFrame = [miniaturizeButton_ frame];
    miniaturizeButtonFrame.origin =
        NSMakePoint((NSMaxX(closeButtonFrame) +
                     CTWindowButtonsInterButtonSpacing),
                    NSMinY(closeButtonFrame));
    [miniaturizeButton_ setFrame:miniaturizeButtonFrame];
    [miniaturizeButton_ setTarget:self];
    [miniaturizeButton_ setAutoresizingMask:(NSViewMaxXMargin |
                                             NSViewMinYMargin)];
    [frameView addSubview:miniaturizeButton_];

    zoomButton_ = [NSWindow standardWindowButton:NSWindowZoomButton
                                    forStyleMask:aStyle];
    NSRect zoomButtonFrame = [zoomButton_ frame];
    zoomButtonFrame.origin =
        NSMakePoint((NSMaxX(miniaturizeButtonFrame) +
                     CTWindowButtonsInterButtonSpacing),
                    NSMinY(miniaturizeButtonFrame));
    [zoomButton_ setFrame:zoomButtonFrame];
    [zoomButton_ setTarget:self];
    [zoomButton_ setAutoresizingMask:(NSViewMaxXMargin |
                                      NSViewMinYMargin)];

    [frameView addSubview:zoomButton_];
  }

  // Update our tracking areas. We want to update them even if we haven't
  // added buttons above as we need to remove the old tracking area. If the
  // buttons aren't to be shown, updateTrackingAreas won't add new ones.
  [self updateTrackingAreas];
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

// Map our custom buttons into the accessibility hierarchy correctly.
- (id)accessibilityAttributeValue:(NSString*)attribute {
  id value = nil;
  struct {
    NSString* attribute_;
    id value_;
  } attributeMap[] = {
    { NSAccessibilityCloseButtonAttribute, [closeButton_ cell]},
    { NSAccessibilityZoomButtonAttribute, [zoomButton_ cell]},
    { NSAccessibilityMinimizeButtonAttribute, [miniaturizeButton_ cell]},
  };

  for (size_t i = 0; i < sizeof(attributeMap) / sizeof(attributeMap[0]); ++i) {
    if ([attributeMap[i].attribute_ isEqualToString:attribute]) {
      value = attributeMap[i].value_;
      break;
    }
  }
  if (!value) {
    value = [super accessibilityAttributeValue:attribute];
  }
  return value;
}

- (void)updateTrackingAreas {
  NSView* frameView = [self frameView];
  if (widgetTrackingArea_) {
    [frameView removeTrackingArea:widgetTrackingArea_];
  }
  if (closeButton_) {
    NSRect trackingRect = [closeButton_ frame];
    trackingRect.size.width = NSMaxX([zoomButton_ frame]) -
        NSMinX(trackingRect);
    widgetTrackingArea_.reset(
        [[NSTrackingArea alloc] initWithRect:trackingRect
                                     options:(NSTrackingMouseEnteredAndExited |
                                              NSTrackingActiveAlways)
                                       owner:self
                                    userInfo:nil]);
    [frameView addTrackingArea:widgetTrackingArea_];

    // Check to see if the cursor is still in trackingRect.
    NSPoint point = [self mouseLocationOutsideOfEventStream];
    point = [[self contentView] convertPoint:point fromView:nil];
    BOOL newEntered = NSPointInRect (point, trackingRect);
    if (newEntered != entered_) {
      // Buttons have moved, so update button state.
      entered_ = newEntered;
      [closeButton_ setNeedsDisplay];
      [zoomButton_ setNeedsDisplay];
      [miniaturizeButton_ setNeedsDisplay];
    }
  }
}

- (void)windowMainStatusChanged {
  [closeButton_ setNeedsDisplay];
  [zoomButton_ setNeedsDisplay];
  [miniaturizeButton_ setNeedsDisplay];
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

- (void)systemThemeDidChangeNotification:(NSNotification*)aNotification {
  [closeButton_ setNeedsDisplay];
  [zoomButton_ setNeedsDisplay];
  [miniaturizeButton_ setNeedsDisplay];
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

// Update our buttons so that they highlight correctly.
- (void)mouseEntered:(NSEvent*)event {
  entered_ = YES;
  [closeButton_ setNeedsDisplay];
  [zoomButton_ setNeedsDisplay];
  [miniaturizeButton_ setNeedsDisplay];
}

// Update our buttons so that they highlight correctly.
- (void)mouseExited:(NSEvent*)event {
  entered_ = NO;
  [closeButton_ setNeedsDisplay];
  [zoomButton_ setNeedsDisplay];
  [miniaturizeButton_ setNeedsDisplay];
}

- (BOOL)mouseInGroup:(NSButton*)widget {
  return entered_;
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
