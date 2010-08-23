// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "chrome/browser/cocoa/tab_contents_controller.h"
#import "TabContents.h"

#include "base/mac_util.h"

// Default offset of the contents splitter in pixels.
static const int kDefaultContentsSplitOffset = 400;

// Never make the web part of the tab contents smaller than this (needed if the
// window is only a few pixels high).
static const int kMinWebHeight = 50;


@implementation TabContentsController

- (id)initWithNibName:(NSString*)name /* @"TabContents" */
             contents:(TabContents*)contents {
  if ((self = [super initWithNibName:name
                              bundle:mac_util::MainAppBundle()])) {
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

- (void)tabDidChange:(TabContents*)updatedContents {
  // Calling setContentView: here removes any first responder status
  // the view may have, so avoid changing the view hierarchy unless
  // the view is different.
  if (contents_ != updatedContents) {
    contents_ = updatedContents;
    [self ensureContentsVisible];
  }
}

/*- (void)showDevToolsContents:(TabContents*)devToolsContents {
  NSArray* subviews = [contentsContainer_ subviews];
  if (devToolsContents) {
    DCHECK_GE([subviews count], 1u);

    // Load the default split offset.  If we are already showing devtools, we
    // will replace the default with the current devtools height.
    CGFloat splitOffset = g_browser_process->local_state()->GetInteger(
        prefs::kDevToolsSplitLocation);
    if (splitOffset == -1) {
      // Initial load, set to default value.
      splitOffset = kDefaultContentsSplitOffset;
    }

    // |devtoolsView| is a TabContentsViewCocoa object, whose ViewID was
    // set to VIEW_ID_TAB_CONTAINER initially, so we need to change it to
    // VIEW_ID_DEV_TOOLS_DOCKED here.
    NSView* devtoolsView = devToolsContents->GetNativeView();
    view_id_util::SetID(devtoolsView, VIEW_ID_DEV_TOOLS_DOCKED);
    if ([subviews count] == 1) {
      [contentsContainer_ addSubview:devtoolsView];
    } else {
      DCHECK_EQ([subviews count], 2u);
      [contentsContainer_ replaceSubview:[subviews objectAtIndex:1]
                                    with:devToolsContents->GetNativeView()];
      // If devtools are already visible, keep the current size.
      splitOffset = NSHeight([devtoolsView frame]);
    }

    // Make sure |splitOffset| isn't too large or too small.
    splitOffset = MIN(splitOffset,
                      NSHeight([contentsContainer_ frame]) - kMinWebHeight);
    DCHECK_GE(splitOffset, 0) << "kMinWebHeight needs to be smaller than "
                              << "smallest available tab contents space.";
    splitOffset = MAX(0, splitOffset);

    // It seems as if |-setPosition:ofDividerAtIndex:| should do what's needed,
    // but I can't figure out how to use it. Manually resize web and devtools.
    NSRect devtoolsFrame = [devtoolsView frame];
    devtoolsFrame.size.height = splitOffset;
    [devtoolsView setFrame:devtoolsFrame];

    NSRect webFrame = [[subviews objectAtIndex:0] frame];
    webFrame.size.height = NSHeight([contentsContainer_ frame]) -
                           [self devToolsHeight];
    [[subviews objectAtIndex:0] setFrame:webFrame];

    [contentsContainer_ adjustSubviews];
  } else {
    if ([subviews count] > 1) {
      NSView* oldDevToolsContentsView = [subviews objectAtIndex:1];
      // Store split offset when hiding devtools window only.
      int splitOffset = NSHeight([oldDevToolsContentsView frame]);
      g_browser_process->local_state()->SetInteger(
          prefs::kDevToolsSplitLocation, splitOffset);
      [oldDevToolsContentsView removeFromSuperview];
    }
  }
}

- (CGFloat)devToolsHeight {
  NSArray* subviews = [contentsContainer_ subviews];
  if ([subviews count] < 2)
    return 0;
  return NSHeight([[subviews objectAtIndex:1] frame]) +
         [contentsContainer_ dividerThickness];
}*/

@end
