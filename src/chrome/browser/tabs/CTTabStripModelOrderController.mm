// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabStripModelOrderController.h"
#import "CTTabContents.h"

///////////////////////////////////////////////////////////////////////////////
// CTTabStripModelOrderController, public:

CTTabStripModelOrderController::CTTabStripModelOrderController(
    CTTabStripModel* tab_strip_model)
    : tabStripModel_(tab_strip_model),
      insertion_policy_(CTTabStripModel::INSERT_AFTER) {
  tabStripModel_->AddObserver(this);
}

CTTabStripModelOrderController::~CTTabStripModelOrderController() {
  tabStripModel_->RemoveObserver(this);
}

int CTTabStripModelOrderController::DetermineInsertionIndex(
    CTTabContents* new_contents,
    CTPageTransition transition,
    bool foreground) {
  int tab_count = tabStripModel_->count();
  if (!tab_count)
    return 0;

  // NOTE: TabStripModel enforces that all non-mini-tabs occur after mini-tabs,
  // so we don't have to check here too.
  if (transition == CTPageTransitionLink &&
      tabStripModel_->selected_index() != -1) {
    int delta = (insertion_policy_ == CTTabStripModel::INSERT_AFTER) ? 1 : 0;
    if (foreground) {
      // If the page was opened in the foreground by a link click in another
      // tab, insert it adjacent to the tab that opened that link.
      return tabStripModel_->selected_index() + delta;
    }
    /*NavigationController* opener =
        &tabStripModel_->GetSelectedTabContents()->controller();
    // Get the index of the next item opened by this tab, and insert after
    // it...
    int index;
    if (insertion_policy_ == TabStripModel::INSERT_AFTER) {
      index = tabStripModel_->GetIndexOfLastTabContentsOpenedBy(
          opener, tabStripModel_->selected_index());
    } else {
      index = tabStripModel_->GetIndexOfFirstTabContentsOpenedBy(
          opener, tabStripModel_->selected_index());
    }
    if (index != TabStripModel::kNoTab)
      return index + delta;*/
    // Otherwise insert adjacent to opener...
    return tabStripModel_->selected_index() + delta;
  }
  // In other cases, such as Ctrl+T, open at the end of the strip.
  return DetermineInsertionIndexForAppending();
}

int CTTabStripModelOrderController::DetermineInsertionIndexForAppending() {
  return (insertion_policy_ == CTTabStripModel::INSERT_AFTER) ?
      tabStripModel_->count() : 0;
}

int CTTabStripModelOrderController::DetermineNewSelectedIndex(
    int removing_index,
    bool is_remove) const {
  int tab_count = tabStripModel_->count();
  assert(removing_index >= 0 && removing_index < tab_count);

  // if the closing tab has a valid parentOpener tab, return its index
  CTTabContents* parentOpener =
      tabStripModel_->GetTabContentsAt(removing_index).parentOpener;
  if (parentOpener) {
    int index = tabStripModel_->GetIndexOfTabContents(parentOpener);
    if (index != CTTabStripModel::kNoTab)
      return GetValidIndex(index, removing_index, is_remove);
  }

  // No opener set, fall through to the default handler...
  int selected_index = tabStripModel_->selected_index();
  if (is_remove && selected_index >= (tab_count - 1))
    return selected_index - 1;
  return selected_index;

  // Chromium legacy code keept for documentation purposes
  /*NavigationController* parent_opener =
      tabStripModel_->GetOpenerOfTabContentsAt(removing_index);
  // First see if the index being removed has any "child" tabs. If it does, we
  // want to select the first in that child group, not the next tab in the same
  // group of the removed tab.
  NavigationController* removed_controller =
      &tabStripModel_->GetTabContentsAt(removing_index)->controller();
  int index = tabStripModel_->GetIndexOfNextTabContentsOpenedBy(
      removed_controller, removing_index, false);
  if (index != TabStripModel::kNoTab)
    return GetValidIndex(index, removing_index, is_remove);

  if (parent_opener) {
    // If the tab was in a group, shift selection to the next tab in the group.
    int index = tabStripModel_->GetIndexOfNextTabContentsOpenedBy(
        parent_opener, removing_index, false);
    if (index != TabStripModel::kNoTab)
      return GetValidIndex(index, removing_index, is_remove);

    // If we can't find a subsequent group member, just fall back to the
    // parent_opener itself. Note that we use "group" here since opener is
    // reset by select operations..
    index = tabStripModel_->GetIndexOfController(parent_opener);
    if (index != TabStripModel::kNoTab)
      return GetValidIndex(index, removing_index, is_remove);
  }*/
}

void CTTabStripModelOrderController::TabSelectedAt(CTTabContents* old_contents,
                                                 CTTabContents* new_contents,
                                                 int index,
                                                 bool user_gesture) {
  /*NavigationController* old_opener = NULL;
  if (old_contents) {
    int index = tabStripModel_->GetIndexOfTabContents(old_contents);
    if (index != TabStripModel::kNoTab) {
      old_opener = tabStripModel_->GetOpenerOfTabContentsAt(index);

      // Forget any group/opener relationships that need to be reset whenever
      // selection changes (see comment in TabStripModel::AddTabContentsAt).
      if (tabStripModel_->ShouldResetGroupOnSelect(old_contents))
        tabStripModel_->ForgetGroup(old_contents);
    }
  }
  NavigationController* new_opener =
      tabStripModel_->GetOpenerOfTabContentsAt(index);
  if (user_gesture && new_opener != old_opener &&
      new_opener != &old_contents->controller() &&
      old_opener != &new_contents->controller()) {
    tabStripModel_->ForgetAllOpeners();
  }*/
}

///////////////////////////////////////////////////////////////////////////////
// CTTabStripModelOrderController, private:

int CTTabStripModelOrderController::GetValidIndex(int index,
                                                int removing_index,
                                                bool is_remove) const {
  if (is_remove && removing_index < index)
    index = std::max(0, index - 1);
  return index;
}
