// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#import <Cocoa/Cocoa.h>
#import "BackgroundGradientView.h"

// A view that handles any special rendering of the toolbar bar. At this time it
// simply draws a gradient and an optional divider at the bottom.

@interface CTToolbarView : BackgroundGradientView
@property(assign, nonatomic) CGFloat dividerOpacity;
@end
