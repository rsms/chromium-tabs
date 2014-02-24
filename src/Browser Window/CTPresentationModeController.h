//
//  CTPresentationModeController.h
//  chromium-tabs
//
//  Created by KOed on 12-4-19.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@class CTBrowserWindowController;
@class DropdownAnimation;

// Provides a controller to manage presentation mode for a single browser
// window.  This class handles running animations, showing and hiding the
// floating dropdown bar, and managing the tracking area associated with the
// dropdown.  This class does not directly manage any views -- the
// BrowserWindowController is responsible for positioning and z-ordering views.
//
// Tracking areas are disabled while animations are running.  If
// |overlayFrameChanged:| is called while an animation is running, the
// controller saves the new frame and installs the appropriate tracking area
// when the animation finishes.  This is largely done for ease of
// implementation; it is easier to check the mouse location at each animation
// step than it is to manage a constantly-changing tracking area.
@interface CTPresentationModeController : NSObject<NSAnimationDelegate>

@property(readonly, nonatomic) BOOL inPresentationMode;

// Designated initializer.
- (id)initWithBrowserController:(CTBrowserWindowController*)controller;

// Informs the controller that the browser has entered or exited presentation
// mode. |-enterPresentationModeForContentView:showDropdown:| should be called
// after the window is setup, just before it is shown. |-exitPresentationMode|
// should be called before any views are moved back to the non-fullscreen
// window.  If |-enterPresentationModeForContentView:showDropdown:| is called,
// it must be balanced with a call to |-exitPresentationMode| before the
// controller is released.
- (void)enterPresentationModeForContentView:(NSView*)contentView
                               showDropdown:(BOOL)showDropdown;
- (void)exitPresentationMode;

// Returns the amount by which the floating bar should be offset downwards (to
// avoid the menu) and by which the overlay view should be enlarged vertically.
// Generally, this is > 0 when the window is on the primary screen and 0
// otherwise.
- (CGFloat)floatingBarVerticalOffset;

// Informs the controller that the overlay's frame has changed.  The controller
// uses this information to update its tracking areas.
- (void)overlayFrameChanged:(NSRect)frame;

// Informs the controller that the overlay should be shown/hidden, possibly with
// animation, possibly after a delay (only applicable for the animated case).
- (void)ensureOverlayShownWithAnimation:(BOOL)animate delay:(BOOL)delay;
- (void)ensureOverlayHiddenWithAnimation:(BOOL)animate delay:(BOOL)delay;

// Cancels any running animation and timers.
- (void)cancelAnimationAndTimers;

// Gets the current floating bar shown fraction.
- (CGFloat)floatingBarShownFraction;

// Sets a new current floating bar shown fraction.  NOTE: This function has side
// effects, such as modifying the system fullscreen mode (menu bar shown state).
- (void)changeFloatingBarShownFraction:(CGFloat)fraction;

@end

// Notification posted when we're about to enter or leave fullscreen.
extern NSString* const kWillEnterFullscreenNotification;
extern NSString* const kWillLeaveFullscreenNotification;