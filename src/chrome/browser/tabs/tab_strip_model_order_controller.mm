// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "tab_strip_model_order_controller.h"
#import "CTTabContents.h"

///////////////////////////////////////////////////////////////////////////////
// TabStripModelOrderController, public:

TabStripModelOrderController::TabStripModelOrderController(
    TabStripModel* tab_strip_model)
    : tab_strip_model_(tab_strip_model),
      insertion_policy_(TabStripModel::INSERT_AFTER) {
  tab_strip_model_->AddObserver(this);
}

TabStripModelOrderController::~TabStripModelOrderController() {
  tab_strip_model_->RemoveObserver(this);
}

int TabStripModelOrderController::DetermineInsertionIndex(
    CTTabContents* new_contents,
    CTPageTransition transition,
    bool foreground) {
  int tab_count = tab_strip_model_->count();
  if (!tab_count)
    return 0;

  // NOTE: TabStripModel enforces that all non-mini-tabs occur after mini-tabs,
  // so we don't have to check here too.
  if (transition == CTPageTransitionLink &&
      tab_strip_model_->selected_index() != -1) {
    int delta = (insertion_policy_ == TabStripModel::INSERT_AFTER) ? 1 : 0;
    if (foreground) {
      // If the page was opened in the foreground by a link click in another
      // tab, insert it adjacent to the tab that opened that link.
      return tab_strip_model_->selected_index() + delta;
    }
    /*NavigationController* opener =
        &tab_strip_model_->GetSelectedTabContents()->controller();
    // Get the index of the next item opened by this tab, and insert after
    // it...
    int index;
    if (insertion_policy_ == TabStripModel::INSERT_AFTER) {
      index = tab_strip_model_->GetIndexOfLastTabContentsOpenedBy(
          opener, tab_strip_model_->selected_index());
    } else {
      index = tab_strip_model_->GetIndexOfFirstTabContentsOpenedBy(
          opener, tab_strip_model_->selected_index());
    }
    if (index != TabStripModel::kNoTab)
      return index + delta;*/
    // Otherwise insert adjacent to opener...
    return tab_strip_model_->selected_index() + delta;
  }
  // In other cases, such as Ctrl+T, open at the end of the strip.
  return DetermineInsertionIndexForAppending();
}

int TabStripModelOrderController::DetermineInsertionIndexForAppending() {
  return (insertion_policy_ == TabStripModel::INSERT_AFTER) ?
      tab_strip_model_->count() : 0;
}

int TabStripModelOrderController::DetermineNewSelectedIndex(
    int removing_index,
    bool is_remove) const {
  int tab_count = tab_strip_model_->count();
  assert(removing_index >= 0 && removing_index < tab_count);
  /*NavigationController* parent_opener =
      tab_strip_model_->GetOpenerOfTabContentsAt(removing_index);
  // First see if the index being removed has any "child" tabs. If it does, we
  // want to select the first in that child group, not the next tab in the same
  // group of the removed tab.
  NavigationController* removed_controller =
      &tab_strip_model_->GetTabContentsAt(removing_index)->controller();
  int index = tab_strip_model_->GetIndexOfNextTabContentsOpenedBy(
      removed_controller, removing_index, false);
  if (index != TabStripModel::kNoTab)
    return GetValidIndex(index, removing_index, is_remove);

  if (parent_opener) {
    // If the tab was in a group, shift selection to the next tab in the group.
    int index = tab_strip_model_->GetIndexOfNextTabContentsOpenedBy(
        parent_opener, removing_index, false);
    if (index != TabStripModel::kNoTab)
      return GetValidIndex(index, removing_index, is_remove);

    // If we can't find a subsequent group member, just fall back to the
    // parent_opener itself. Note that we use "group" here since opener is
    // reset by select operations..
    index = tab_strip_model_->GetIndexOfController(parent_opener);
    if (index != TabStripModel::kNoTab)
      return GetValidIndex(index, removing_index, is_remove);
  }*/

  // No opener set, fall through to the default handler...
  int selected_index = tab_strip_model_->selected_index();
  if (is_remove && selected_index >= (tab_count - 1))
    return selected_index - 1;
  return selected_index;
}

void TabStripModelOrderController::TabSelectedAt(CTTabContents* old_contents,
                                                 CTTabContents* new_contents,
                                                 int index,
                                                 bool user_gesture) {
  DLOG("TabSelectedAt %d", index);
  /*NavigationController* old_opener = NULL;
  if (old_contents) {
    int index = tab_strip_model_->GetIndexOfTabContents(old_contents);
    if (index != TabStripModel::kNoTab) {
      old_opener = tab_strip_model_->GetOpenerOfTabContentsAt(index);

      // Forget any group/opener relationships that need to be reset whenever
      // selection changes (see comment in TabStripModel::AddTabContentsAt).
      if (tab_strip_model_->ShouldResetGroupOnSelect(old_contents))
        tab_strip_model_->ForgetGroup(old_contents);
    }
  }
  NavigationController* new_opener =
      tab_strip_model_->GetOpenerOfTabContentsAt(index);
  if (user_gesture && new_opener != old_opener &&
      new_opener != &old_contents->controller() &&
      old_opener != &new_contents->controller()) {
    tab_strip_model_->ForgetAllOpeners();
  }*/
}

///////////////////////////////////////////////////////////////////////////////
// TabStripModelOrderController, private:

int TabStripModelOrderController::GetValidIndex(int index,
                                                int removing_index,
                                                bool is_remove) const {
  if (is_remove && removing_index < index)
    index = std::max(0, index - 1);
  return index;
}
