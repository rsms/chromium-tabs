// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabContentsController.h"
#import "CTTabContents.h"
#import "util.h"

// Default offset of the contents splitter in pixels.
static const int kDefaultContentsSplitOffset = 400;

// Never make the web part of the tab contents smaller than this (needed if the
// window is only a few pixels high).
static const int kMinWebHeight = 50;


@implementation CTTabContentsController

- (id)initWithContents:(CTTabContents*)contents {
  // subclasses might override this to load a different nib
  NSBundle *bundle = [util bundleForResource:@"TabContents" ofType:@"nib"];
  return [self initWithNibName:@"TabContents" bundle:bundle contents:contents];
}

- (id)initWithNibName:(NSString*)name
               bundle:(NSBundle*)bundle
             contents:(CTTabContents*)contents {
  if ((self = [super initWithNibName:name bundle:bundle])) {
    contents_ = contents;
  }
  return self;
}

- (void)dealloc {
  // make sure our contents have been removed from the window
  [[self view] removeFromSuperview];
  [super dealloc];
}

// Call when the tab view is properly sized and the render widget host view
// should be put into the view hierarchy.
- (void)ensureContentsVisible {
  NSArray* subviews = [contentsContainer_ subviews];
  if ([subviews count] == 0)
    [contentsContainer_ addSubview:contents_.view];
  else if ([subviews objectAtIndex:0] != contents_.view)
    [contentsContainer_ replaceSubview:[subviews objectAtIndex:0]
                                  with:contents_.view];
}

// Returns YES if the tab represented by this controller is the front-most.
- (BOOL)isCurrentTab {
  // We're the current tab if we're in the view hierarchy, otherwise some other
  // tab is.
  return [[self view] superview] ? YES : NO;
}

- (void)willBecomeUnselectedTab {
  /*RenderViewHost* rvh = contents_->render_view_host();
  if (rvh)
    rvh->Blur();*/
}

- (void)willBecomeSelectedTab {
  /*RenderViewHost* rvh = contents_->render_view_host();
  if (rvh)
    rvh->Focus();*/
}

- (void)tabDidChange:(CTTabContents*)updatedContents {
  // Calling setContentView: here removes any first responder status
  // the view may have, so avoid changing the view hierarchy unless
  // the view is different.
  if (contents_ != updatedContents) {
    contents_ = updatedContents;
    [self ensureContentsVisible];
  }
}

@end
