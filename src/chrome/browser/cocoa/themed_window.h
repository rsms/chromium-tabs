// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CHROME_BROWSER_COCOA_THEMED_WINDOW_H_
#define CHROME_BROWSER_COCOA_THEMED_WINDOW_H_
#pragma once

#import <Cocoa/Cocoa.h>

class ThemeProvider;

// Bit flags; mix-and-match as necessary.
enum {
  THEMED_NORMAL    = 0,
  THEMED_INCOGNITO = 1 << 0,
  THEMED_POPUP     = 1 << 1,
  THEMED_DEVTOOLS  = 1 << 2
};
typedef NSUInteger ThemedWindowStyle;

// Implemented by windows that support theming.

@interface NSWindow (ThemeProvider)
- (ThemeProvider*)themeProvider;
- (ThemedWindowStyle)themedWindowStyle;
- (NSPoint)themePatternPhase;
@end

#endif  // CHROME_BROWSER_COCOA_THEMED_WINDOW_H_
