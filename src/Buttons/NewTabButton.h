// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.
#pragma once

#import <Cocoa/Cocoa.h>

//#import "scoped_nsobject.h"

// Overrides hit-test behavior to only accept clicks inside the image of the
// button, not just inside the bounding box. This could be abstracted to general
// use, but no other buttons are so irregularly shaped with respect to their
// bounding box.

@interface NewTabButton : NSButton
// Returns YES if the given point is over the button.  |point| is in the
// superview's coordinate system.
- (BOOL)pointIsOverButton:(NSPoint)point;
@end
