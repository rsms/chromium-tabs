// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "chrome/browser/cocoa/background_gradient_view.h"
//#import "chrome/browser/browser_theme_provider.h"
//#import "chrome/browser/cocoa/themed_window.h"
#import "third_party/gtm-subset/GTMNSColor+Luminance.h"

#define kToolbarTopOffset 12
#define kToolbarMaxHeight 100

@implementation BackgroundGradientView
@synthesize showsDivider = showsDivider_;

- (id)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self != nil) {
    showsDivider_ = YES;
  }
  return self;
}

- (void)awakeFromNib {
  showsDivider_ = YES;
}

- (void)setShowsDivider:(BOOL)show {
  showsDivider_ = show;
  [self setNeedsDisplay:YES];
}

- (void)drawBackground {
  BOOL isKey = [[self window] isKeyWindow];
	
	// TODO: cache the resulting NSGradient
	NSColor* base_color = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
	BOOL faded = !isKey;
	NSColor* start_color =
			[base_color gtm_colorAdjustedFor:GTMColorationLightHighlight
																 faded:faded];
	NSColor* mid_color =
			[base_color gtm_colorAdjustedFor:GTMColorationLightMidtone
																 faded:faded];
	NSColor* end_color =
			[base_color gtm_colorAdjustedFor:GTMColorationLightShadow
																 faded:faded];
	NSColor* glow_color =
			[base_color gtm_colorAdjustedFor:GTMColorationLightPenumbra
																 faded:faded];

	NSGradient *gradient =
			[[NSGradient alloc] initWithColorsAndLocations:start_color, 0.0,
																										 mid_color, 0.25,
																										 end_color, 0.5,
																										 glow_color, 0.75,
																										 nil];


	CGFloat winHeight = NSHeight([[self window] frame]);
	NSPoint startPoint =
			[self convertPoint:NSMakePoint(0, winHeight - kToolbarTopOffset)
								fromView:nil];
	NSPoint endPoint =
			NSMakePoint(0, winHeight - kToolbarTopOffset - kToolbarMaxHeight);
	endPoint = [self convertPoint:endPoint fromView:nil];

	[gradient drawFromPoint:startPoint
									toPoint:endPoint
									options:(NSGradientDrawsBeforeStartingLocation |
													 NSGradientDrawsAfterEndingLocation)];

	if (showsDivider_) {
		// Draw bottom stroke
		[[self strokeColor] set];
		NSRect borderRect, contentRect;
		NSDivideRect([self bounds], &borderRect, &contentRect, 1, NSMinYEdge);
		NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
	}
}

- (NSColor*)strokeColor {
	static NSColor* kDefaultColorToolbarStroke =
		[NSColor colorWithCalibratedWhite: 0x67 / 0xff alpha:1.0];
	static NSColor* kDefaultColorToolbarStrokeInactive =
		[NSColor colorWithCalibratedWhite: 0x7b / 0xff alpha:1.0];
  BOOL isKey = [[self window] isKeyWindow];
  return isKey ? kDefaultColorToolbarStroke :
							   kDefaultColorToolbarStrokeInactive;
}

@end
