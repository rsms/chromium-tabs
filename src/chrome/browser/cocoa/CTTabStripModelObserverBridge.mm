// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabStripModelObserverBridge.h"

CTTabStripModelObserverBridge::CTTabStripModelObserverBridge(CTTabStripModel* model,
                                                         id controller)
    : controller_(controller), model_(model) {
  assert(model && controller);
  // Register to be a listener on the model so we can get updates and tell
  // |controller_| about them in the future.
  model_->AddObserver(this);
  
  // test which messages |controller| accepts
  #define TEST(sele) [controller_ respondsToSelector:@selector(sele)]
  TabInsertedAtOK_ = TEST(tabInsertedWithContents:atIndex:inForeground:);
  TabClosingAtOK_ = TEST(tabClosingWithContents:atIndex:);
  TabDetachedAtOK_ = TEST(tabDetachedWithContents:atIndex:);
  TabSelectedAtOK_ = TEST(tabSelectedWithContents:previousContents:atIndex:userGesture:);
  TabMovedOK_ = TEST(tabMovedWithContents:fromIndex:toIndex:);
  TabChangedAtOK_ = TEST(tabChangedWithContents:atIndex:changeType:);
  TabReplacedAtOK_ = TEST(tabReplacedWithContents:oldContents:atIndex:);
  TabMiniStateChangedOK_ = TEST(tabMiniStateChangedWithContents:atIndex:);
  TabStripEmptyOK_ = TEST(tabStripEmpty);
  #undef TEST
}

CTTabStripModelObserverBridge::~CTTabStripModelObserverBridge() {
  // Remove ourselves from receiving notifications.
  if (model_)
    model_->RemoveObserver(this);
}


void CTTabStripModelObserverBridge::TabInsertedAt(CTTabContents* contents,
                                                int index,
                                                bool foreground) {
  if (TabInsertedAtOK_) {
    [controller_ tabInsertedWithContents:contents
                                 atIndex:index
                            inForeground:foreground];
  }
}

void CTTabStripModelObserverBridge::TabClosingAt(CTTabContents* contents,
                                               int index) {
  if (TabClosingAtOK_) {
    [controller_ tabClosingWithContents:contents atIndex:index];
  }
}

void CTTabStripModelObserverBridge::TabDetachedAt(CTTabContents* contents,
                                                int index) {
  if (TabDetachedAtOK_) {
    [controller_ tabDetachedWithContents:contents atIndex:index];
  }
}

void CTTabStripModelObserverBridge::TabSelectedAt(CTTabContents* old_contents,
                                                CTTabContents* new_contents,
                                                int index,
                                                bool user_gesture) {
  if (TabSelectedAtOK_) {
    [controller_ tabSelectedWithContents:new_contents
                        previousContents:old_contents
                                 atIndex:index
                             userGesture:user_gesture];
  }
}

void CTTabStripModelObserverBridge::TabMoved(CTTabContents* contents,
                                           int from_index,
                                           int to_index) {
  if (TabMovedOK_) {
    [controller_ tabMovedWithContents:contents
                            fromIndex:from_index
                              toIndex:to_index];
  }
}

void CTTabStripModelObserverBridge::TabChangedAt(CTTabContents* contents,
                                               int index,
                                               CTTabChangeType change_type) {
  if (TabChangedAtOK_) {
    [controller_ tabChangedWithContents:contents
                                atIndex:index
                             changeType:change_type];
  }
}

void CTTabStripModelObserverBridge::TabReplacedAt(CTTabContents* old_contents,
                                                CTTabContents* new_contents,
                                                int index) {
  if (TabReplacedAtOK_) {
    [controller_ tabReplacedWithContents:new_contents
                             oldContents:old_contents
                                 atIndex:index];
  }
  TabChangedAt(new_contents, index, CTTabChangeTypeAll);
}

void CTTabStripModelObserverBridge::TabMiniStateChanged(CTTabContents* contents,
                                                      int index) {
  if (TabMiniStateChangedOK_) {
    [controller_ tabMiniStateChangedWithContents:contents atIndex:index];
  }
}

void CTTabStripModelObserverBridge::TabStripEmpty() {
  if (TabStripEmptyOK_)
    [controller_ tabStripEmpty];
}
