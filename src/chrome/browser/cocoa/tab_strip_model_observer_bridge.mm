// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "tab_strip_model_observer_bridge.h"

TabStripModelObserverBridge::TabStripModelObserverBridge(CTTabStripModel* model,
                                                         id controller)
    : controller_(controller), model_(model) {
  assert(model && controller);
  // Register to be a listener on the model so we can get updates and tell
  // |controller_| about them in the future.
  model_->AddObserver(this);
}

TabStripModelObserverBridge::~TabStripModelObserverBridge() {
  // Remove ourselves from receiving notifications.
  model_->RemoveObserver(this);
}

void TabStripModelObserverBridge::TabInsertedAt(CTTabContents* contents,
                                                int index,
                                                bool foreground) {
  if ([controller_ respondsToSelector:
          @selector(insertTabWithContents:atIndex:inForeground:)]) {
    [controller_ insertTabWithContents:contents
                               atIndex:index
                          inForeground:foreground];
  }
}

void TabStripModelObserverBridge::TabClosingAt(CTTabContents* contents,
                                               int index) {
  if ([controller_ respondsToSelector:
          @selector(tabClosingWithContents:atIndex:)]) {
    [controller_ tabClosingWithContents:contents atIndex:index];
  }
}

void TabStripModelObserverBridge::TabDetachedAt(CTTabContents* contents,
                                                int index) {
  if ([controller_ respondsToSelector:
          @selector(tabDetachedWithContents:atIndex:)]) {
    [controller_ tabDetachedWithContents:contents atIndex:index];
  }
}

void TabStripModelObserverBridge::TabSelectedAt(CTTabContents* old_contents,
                                                CTTabContents* new_contents,
                                                int index,
                                                bool user_gesture) {
  if ([controller_ respondsToSelector:
          @selector(selectTabWithContents:previousContents:atIndex:
                    userGesture:)]) {
    [controller_ selectTabWithContents:new_contents
                      previousContents:old_contents
                               atIndex:index
                           userGesture:user_gesture];
  }
}

void TabStripModelObserverBridge::TabMoved(CTTabContents* contents,
                                           int from_index,
                                           int to_index) {
  if ([controller_ respondsToSelector:
       @selector(tabMovedWithContents:fromIndex:toIndex:)]) {
    [controller_ tabMovedWithContents:contents
                            fromIndex:from_index
                              toIndex:to_index];
  }
}

void TabStripModelObserverBridge::TabChangedAt(CTTabContents* contents,
                                               int index,
                                               CTTabChangeType change_type) {
  if ([controller_ respondsToSelector:
          @selector(tabChangedWithContents:atIndex:changeType:)]) {
    [controller_ tabChangedWithContents:contents
                                atIndex:index
                             changeType:change_type];
  }
}

void TabStripModelObserverBridge::TabReplacedAt(CTTabContents* old_contents,
                                                CTTabContents* new_contents,
                                                int index) {
  TabChangedAt(new_contents, index, ALL);
}

void TabStripModelObserverBridge::TabMiniStateChanged(CTTabContents* contents,
                                                      int index) {
  if ([controller_ respondsToSelector:
          @selector(tabMiniStateChangedWithContents:atIndex:)]) {
    [controller_ tabMiniStateChangedWithContents:contents atIndex:index];
  }
}

void TabStripModelObserverBridge::TabStripEmpty() {
  if ([controller_ respondsToSelector:@selector(tabStripEmpty)])
    [controller_ tabStripEmpty];
}
