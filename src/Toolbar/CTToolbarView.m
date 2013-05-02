// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "CTToolbarView.h"
#import "NSWindow+CTThemed.h"

@implementation CTToolbarView {
	// The opacity of the divider line (at the bottom of the toolbar); used when
	// the detached bookmark bar is morphing to the normal bar and vice versa.
	CGFloat dividerOpacity_;
}

@synthesize dividerOpacity = dividerOpacity_;

// Prevent mouse down events from moving the parent window around.
- (BOOL)mouseDownCanMoveWindow {
  return NO;
}

- (void)drawRect:(NSRect)rect {
  // The toolbar's background pattern is phased relative to the tab strip view's
  // background pattern.
  NSPoint phase = [[self window] themePatternPhase];
  [[NSGraphicsContext currentContext] setPatternPhase:phase];
  [self drawBackground];
}

// Override of |-[BackgroundGradientView strokeColor]|; make it respect opacity.
- (NSColor*)strokeColor {
  return [[super strokeColor] colorWithAlphaComponent:[self dividerOpacity]];
}

- (BOOL)accessibilityIsIgnored {
  return NO;
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
  if ([attribute isEqual:NSAccessibilityRoleAttribute])
    return NSAccessibilityToolbarRole;
  return [super accessibilityAttributeValue:attribute];
}

@end
