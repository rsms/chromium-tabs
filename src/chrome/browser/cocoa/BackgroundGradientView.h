// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#pragma once

#import <Cocoa/Cocoa.h>

// A custom view that draws a 'standard' background gradient.
// Base class for other Chromium views.
@interface BackgroundGradientView : NSView
// The color used for the bottom stroke. Public so subclasses can use.
- (NSColor *)strokeColor;

// Draws the background for this view. Make sure that your patternphase
// is set up correctly in your graphics context before calling.
- (void)drawBackground;

// Controls whether the bar draws a dividing line at the bottom.
@property(nonatomic, assign) BOOL showsDivider;
@end
