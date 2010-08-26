// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "chrome/browser/tabs/tab_strip_model.h"

#include <algorithm>

//#include "base/command_line.h"
#include "base/stl_util-inl.h"
//#include "base/string_util.h"
//#include "build/build_config.h" // included in precompiled header
//#include "chrome/browser/bookmarks/bookmark_model.h"
//#include "chrome/browser/browser_shutdown.h"
//#include "chrome/browser/defaults.h"
//#include "chrome/browser/extensions/extensions_service.h"
//#include "chrome/browser/metrics/user_metrics.h"
//#include "chrome/browser/profile.h"
//#include "chrome/browser/renderer_host/render_process_host.h"
//#include "chrome/browser/sessions/tab_restore_service.h"
#include "chrome/browser/tabs/tab_strip_model_order_controller.h"
#include "chrome/common/page_transition_types.h"
//#include "chrome/browser/tab_contents/navigation_controller.h"
//#include "chrome/browser/tab_contents/tab_contents.h"
//#include "chrome/browser/tab_contents/tab_contents_delegate.h"
//#include "chrome/browser/tab_contents/tab_contents_view.h"
//#include "chrome/common/chrome_switches.h"
//#include "chrome/common/extensions/extension.h"
//#include "chrome/common/notification_service.h"
//#include "chrome/common/url_constants.h"

#import "CTTabContents.h"

namespace {

// Returns true if the specified transition is one of the types that cause the
// opener relationships for the tab in which the transition occured to be
// forgotten. This is generally any navigation that isn't a link click (i.e.
// any navigation that can be considered to be the start of a new task distinct
// from what had previously occurred in that tab).
bool ShouldForgetOpenersForTransition(PageTransition::Type transition) {
  return transition == PageTransition::TYPED ||
      transition == PageTransition::AUTO_BOOKMARK ||
      transition == PageTransition::GENERATED ||
      transition == PageTransition::KEYWORD ||
      transition == PageTransition::START_PAGE;
}

}  // namespace

///////////////////////////////////////////////////////////////////////////////
// TabStripModelObserver, public:
void TabStripModelObserver::TabInsertedAt(CTTabContents* contents,
                                          int index,
                                          bool foreground) {
}

void TabStripModelObserver::TabClosingAt(CTTabContents* contents, int index) {
}

void TabStripModelObserver::TabDetachedAt(CTTabContents* contents, int index) {
}

void TabStripModelObserver::TabDeselectedAt(CTTabContents* contents, int index) {
}

void TabStripModelObserver::TabSelectedAt(CTTabContents* old_contents,
                                          CTTabContents* new_contents,
                                          int index,
                                          bool user_gesture) {
}

void TabStripModelObserver::TabMoved(CTTabContents* contents,
                                     int from_index,
                                     int to_index) {
}

void TabStripModelObserver::TabChangedAt(CTTabContents* contents, int index,
                                         TabChangeType change_type) {
}

void TabStripModelObserver::TabReplacedAt(CTTabContents* old_contents,
                                          CTTabContents* new_contents,
                                          int index) {
}

void TabStripModelObserver::TabReplacedAt(CTTabContents* old_contents,
                                          CTTabContents* new_contents,
                                          int index,
                                          TabReplaceType type) {
  TabReplacedAt(old_contents, new_contents, index);
}

void TabStripModelObserver::TabPinnedStateChanged(CTTabContents* contents,
                                                  int index) {
}

void TabStripModelObserver::TabMiniStateChanged(CTTabContents* contents,
                                                int index) {
}

void TabStripModelObserver::TabBlockedStateChanged(CTTabContents* contents,
                                                   int index) {
}

void TabStripModelObserver::TabStripEmpty() {}

void TabStripModelObserver::TabStripModelDeleted() {}

///////////////////////////////////////////////////////////////////////////////
// TabStripModelDelegate, public:

/*bool TabStripModelDelegate::CanCloseTab() const {
  return true;
}*/

///////////////////////////////////////////////////////////////////////////////
// TabStripModel, public:

TabStripModel::TabStripModel(NSObject<TabStripModelDelegate>* delegate)
    : selected_index_(kNoTab),
      closing_all_(false),
      order_controller_(NULL) {
  delegate_ = [delegate retain];
  assert(delegate_);
  // TODO replace with nsnotificationcenter?
  /*registrar_.Add(this,
                 NotificationType::TAB_CONTENTS_DESTROYED,
                 NotificationService::AllSources());
  registrar_.Add(this,
                 NotificationType::EXTENSION_UNLOADED);*/
  order_controller_ = new TabStripModelOrderController(this);
}

TabStripModel::~TabStripModel() {
  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
                    TabStripModelDeleted());

  [delegate_ release];
  delegate_ = NULL;

  // Before deleting any phantom tabs remove our notification observers so that
  // we don't attempt to notify our delegate or do any processing.
  //TODO: replace with nsnotificationcenter unregs
  //registrar_.RemoveAll();

  // Phantom tabs still have valid TabConents that we own and need to delete.
  /*for (int i = count() - 1; i >= 0; --i) {
    if (IsPhantomTab(i))
      delete contents_data_[i]->contents;
  }*/

  STLDeleteContainerPointers(contents_data_.begin(), contents_data_.end());
  delete order_controller_;
}

void TabStripModel::AddObserver(TabStripModelObserver* observer) {
  observers_.AddObserver(observer);
}

void TabStripModel::RemoveObserver(TabStripModelObserver* observer) {
  observers_.RemoveObserver(observer);
}

bool TabStripModel::HasNonPhantomTabs() const {
  /*for (int i = 0; i < count(); i++) {
    if (!IsPhantomTab(i))
      return true;
  }
  return false;*/
  return !!count();
}

void TabStripModel::SetInsertionPolicy(InsertionPolicy policy) {
  order_controller_->set_insertion_policy(policy);
}

TabStripModel::InsertionPolicy TabStripModel::insertion_policy() const {
  return order_controller_->insertion_policy();
}

bool TabStripModel::HasObserver(TabStripModelObserver* observer) {
  return observers_.HasObserver(observer);
}

bool TabStripModel::ContainsIndex(int index) const {
  return index >= 0 && index < count();
}

void TabStripModel::AppendTabContents(CTTabContents* contents, bool foreground) {
  int index = order_controller_->DetermineInsertionIndexForAppending();
  InsertTabContentsAt(index, contents,
                      foreground ? (ADD_INHERIT_GROUP | ADD_SELECTED) :
                                   ADD_NONE);
}

void TabStripModel::InsertTabContentsAt(int index,
                                        CTTabContents* contents,
                                        int add_types) {
  bool foreground = add_types & ADD_SELECTED;
  // Force app tabs to be pinned.
  bool pin = contents.isApp || add_types & ADD_PINNED;
  index = ConstrainInsertionIndex(index, pin);

  // In tab dragging situations, if the last tab in the window was detached
  // then the user aborted the drag, we will have the |closing_all_| member
  // set (see DetachTabContentsAt) which will mess with our mojo here. We need
  // to clear this bit.
  closing_all_ = false;

  // Have to get the selected contents before we monkey with |contents_|
  // otherwise we run into problems when we try to change the selected contents
  // since the old contents and the new contents will be the same...
  CTTabContents* selected_contents = GetSelectedTabContents();
  TabContentsData* data = new TabContentsData([contents retain]);
  data->pinned = pin;
  if ((add_types & ADD_INHERIT_GROUP) && selected_contents) {
    if (foreground) {
      // Forget any existing relationships, we don't want to make things too
      // confusing by having multiple groups active at the same time.
      ForgetAllOpeners();
    }
    // Anything opened by a link we deem to have an opener.
    //data->SetGroup(&selected_contents->controller());
  } else if ((add_types & ADD_INHERIT_OPENER) && selected_contents) {
    if (foreground) {
      // Forget any existing relationships, we don't want to make things too
      // confusing by having multiple groups active at the same time.
      ForgetAllOpeners();
    }
    //data->opener = &selected_contents->controller();
  }

  contents_data_.insert(contents_data_.begin() + index, data);

  if (index <= selected_index_) {
    // If a tab is inserted before the current selected index,
    // then |selected_index| needs to be incremented.
    ++selected_index_;
  }

  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
      TabInsertedAt(contents, index, foreground));

  if (foreground)
    ChangeSelectedContentsFrom(selected_contents, index, false);
}

void TabStripModel::ReplaceTabContentsAt(
    int index,
    CTTabContents* new_contents,
    TabReplaceType type) {
  CTTabContents* old_contents =
      ReplaceTabContentsAtImpl(index, new_contents, type);
  [old_contents destroy:this];
}

/*void TabStripModel::ReplaceNavigationControllerAt(
    int index, NavigationController* controller) {
  // This appears to be OK with no flicker since no redraw event
  // occurs between the call to add an aditional tab and one to close
  // the previous tab.
  InsertTabContentsAt(
      index + 1, controller->tab_contents(),
      ADD_SELECTED | ADD_INHERIT_GROUP);
  std::vector<int> closing_tabs;
  closing_tabs.push_back(index);
  InternalCloseTabs(closing_tabs, CLOSE_NONE);
}*/

CTTabContents* TabStripModel::DetachTabContentsAt(int index) {
  if (contents_data_.empty())
    return NULL;

  assert(ContainsIndex(index));

  CTTabContents* removed_contents = GetContentsAt(index);
  int next_selected_index =
      order_controller_->DetermineNewSelectedIndex(index, true);
  delete contents_data_.at(index);
  contents_data_.erase(contents_data_.begin() + index);
  next_selected_index = IndexOfNextNonPhantomTab(next_selected_index, -1);
  if (!HasNonPhantomTabs())
    closing_all_ = true;
  TabStripModelObservers::Iterator iter(observers_);
  while (TabStripModelObserver* obs = iter.GetNext()) {
    obs->TabDetachedAt(removed_contents, index);
    if (!HasNonPhantomTabs())
      obs->TabStripEmpty();
  }
  if (HasNonPhantomTabs()) {
    if (index == selected_index_) {
      ChangeSelectedContentsFrom(removed_contents, next_selected_index, false);
    } else if (index < selected_index_) {
      // The selected tab didn't change, but its position shifted; update our
      // index to continue to point at it.
      --selected_index_;
    }
  }
  return removed_contents;
}

void TabStripModel::SelectTabContentsAt(int index, bool user_gesture) {
  assert(ContainsIndex(index));
  ChangeSelectedContentsFrom(GetSelectedTabContents(), index, user_gesture);
}

void TabStripModel::MoveTabContentsAt(int index, int to_position,
                                      bool select_after_move) {
  assert(ContainsIndex(index));
  if (index == to_position)
    return;

  int first_non_mini_tab = IndexOfFirstNonMiniTab();
  if ((index < first_non_mini_tab && to_position >= first_non_mini_tab) ||
      (to_position < first_non_mini_tab && index >= first_non_mini_tab)) {
    // This would result in mini tabs mixed with non-mini tabs. We don't allow
    // that.
    return;
  }

  MoveTabContentsAtImpl(index, to_position, select_after_move);
}

CTTabContents* TabStripModel::GetSelectedTabContents() const {
  return GetTabContentsAt(selected_index_);
}

CTTabContents* TabStripModel::GetTabContentsAt(int index) const {
  if (ContainsIndex(index))
    return GetContentsAt(index);
  return NULL;
}

int TabStripModel::GetIndexOfTabContents(const CTTabContents* contents) const {
  int index = 0;
  TabContentsDataVector::const_iterator iter = contents_data_.begin();
  for (; iter != contents_data_.end(); ++iter, ++index) {
    if ((*iter)->contents == contents)
      return index;
  }
  return kNoTab;
}

/*int TabStripModel::GetIndexOfController(
    const NavigationController* controller) const {
  int index = 0;
  TabContentsDataVector::const_iterator iter = contents_data_.begin();
  for (; iter != contents_data_.end(); ++iter, ++index) {
    if (&(*iter)->contents->controller() == controller)
      return index;
  }
  return kNoTab;
}*/

void TabStripModel::UpdateTabContentsStateAt(int index,
                                             TabChangeType change_type) {
  assert(ContainsIndex(index));
  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
      TabChangedAt(GetContentsAt(index), index, change_type));
}

void TabStripModel::CloseAllTabs() {
  // Set state so that observers can adjust their behavior to suit this
  // specific condition when CloseTabContentsAt causes a flurry of
  // Close/Detach/Select notifications to be sent.
  closing_all_ = true;
  std::vector<int> closing_tabs;
  for (int i = count() - 1; i >= 0; --i)
    closing_tabs.push_back(i);
  InternalCloseTabs(closing_tabs, CLOSE_CREATE_HISTORICAL_TAB);
}

bool TabStripModel::CloseTabContentsAt(int index, uint32 close_types) {
  std::vector<int> closing_tabs;
  closing_tabs.push_back(index);
  return InternalCloseTabs(closing_tabs, close_types);
}

bool TabStripModel::TabsAreLoading() const {
  TabContentsDataVector::const_iterator iter = contents_data_.begin();
  for (; iter != contents_data_.end(); ++iter) {
    if ((*iter)->contents.isLoading)
      return true;
  }
  return false;
}

/*NavigationController* TabStripModel::GetOpenerOfTabContentsAt(int index) {
  assert(ContainsIndex(index));
  return contents_data_.at(index)->opener;
}*/

/*int TabStripModel::GetIndexOfNextTabContentsOpenedBy(
    const NavigationController* opener, int start_index, bool use_group) const {
  assert(opener);
  assert(ContainsIndex(start_index));

  // Check tabs after start_index first.
  for (int i = start_index + 1; i < count(); ++i) {
    if (OpenerMatches(contents_data_[i], opener, use_group) &&
        !IsPhantomTab(i)) {
      return i;
    }
  }
  // Then check tabs before start_index, iterating backwards.
  for (int i = start_index - 1; i >= 0; --i) {
    if (OpenerMatches(contents_data_[i], opener, use_group) &&
        !IsPhantomTab(i)) {
      return i;
    }
  }
  return kNoTab;
}*/

/*int TabStripModel::GetIndexOfFirstTabContentsOpenedBy(
    const NavigationController* opener,
    int start_index) const {
  assert(opener);
  assert(ContainsIndex(start_index));

  for (int i = 0; i < start_index; ++i) {
    if (contents_data_[i]->opener == opener && !IsPhantomTab(i))
      return i;
  }
  return kNoTab;
}*/

/*int TabStripModel::GetIndexOfLastTabContentsOpenedBy(
    const NavigationController* opener, int start_index) const {
  assert(opener);
  assert(ContainsIndex(start_index));

  TabContentsDataVector::const_iterator end =
      contents_data_.begin() + start_index;
  TabContentsDataVector::const_iterator iter = contents_data_.end();
  TabContentsDataVector::const_iterator next;
  for (; iter != end; --iter) {
    next = iter - 1;
    if (next == end)
      break;
    if ((*next)->opener == opener &&
        !IsPhantomTab(static_cast<int>(next - contents_data_.begin()))) {
      return static_cast<int>(next - contents_data_.begin());
    }
  }
  return kNoTab;
}*/

void TabStripModel::TabNavigating(CTTabContents* contents,
                                  PageTransition::Type transition) {
  if (ShouldForgetOpenersForTransition(transition)) {
    // Don't forget the openers if this tab is a New Tab page opened at the
    // end of the TabStrip (e.g. by pressing Ctrl+T). Give the user one
    // navigation of one of these transition types before resetting the
    // opener relationships (this allows for the use case of opening a new
    // tab to do a quick look-up of something while viewing a tab earlier in
    // the strip). We can make this heuristic more permissive if need be.
    if (!IsNewTabAtEndOfTabStrip(contents)) {
      // If the user navigates the current tab to another page in any way
      // other than by clicking a link, we want to pro-actively forget all
      // TabStrip opener relationships since we assume they're beginning a
      // different task by reusing the current tab.
      ForgetAllOpeners();
      // In this specific case we also want to reset the group relationship,
      // since it is now technically invalid.
      //ForgetGroup(contents);
    }
  }
}

void TabStripModel::ForgetAllOpeners() {
  // Forget all opener memories so we don't do anything weird with tab
  // re-selection ordering.
  TabContentsDataVector::const_iterator iter = contents_data_.begin();
  for (; iter != contents_data_.end(); ++iter)
    (*iter)->ForgetOpener();
}

/*void TabStripModel::ForgetGroup(CTTabContents* contents) {
  int index = GetIndexOfTabContents(contents);
  assert(ContainsIndex(index));
  contents_data_.at(index)->SetGroup(NULL);
  contents_data_.at(index)->ForgetOpener();
}

bool TabStripModel::ShouldResetGroupOnSelect(CTTabContents* contents) const {
  int index = GetIndexOfTabContents(contents);
  assert(ContainsIndex(index));
  return contents_data_.at(index)->reset_group_on_select;
}*/

void TabStripModel::SetTabBlocked(int index, bool blocked) {
  assert(ContainsIndex(index));
  if (contents_data_[index]->blocked == blocked)
    return;
  contents_data_[index]->blocked = blocked;
  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
      TabBlockedStateChanged(contents_data_[index]->contents,
      index));
}

void TabStripModel::SetTabPinned(int index, bool pinned) {
  assert(ContainsIndex(index));
  if (contents_data_[index]->pinned == pinned)
    return;

  if (IsAppTab(index)) {
    if (!pinned) {
      // App tabs should always be pinned.
      NOTREACHED();
      return;
    }
    // Changing the pinned state of an app tab doesn't effect it's mini-tab
    // status.
    contents_data_[index]->pinned = pinned;
  } else {
    // The tab is not an app tab, it's position may have to change as the
    // mini-tab state is changing.
    int non_mini_tab_index = IndexOfFirstNonMiniTab();
    contents_data_[index]->pinned = pinned;
    if (pinned && index != non_mini_tab_index) {
      MoveTabContentsAtImpl(index, non_mini_tab_index, false);
      return;  // Don't send TabPinnedStateChanged notification.
    } else if (!pinned && index + 1 != non_mini_tab_index) {
      MoveTabContentsAtImpl(index, non_mini_tab_index - 1, false);
      return;  // Don't send TabPinnedStateChanged notification.
    }

    FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
                      TabMiniStateChanged(contents_data_[index]->contents,
                                          index));
  }

  // else: the tab was at the boundary and it's position doesn't need to
  // change.
  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
                    TabPinnedStateChanged(contents_data_[index]->contents,
                                          index));
}

bool TabStripModel::IsTabPinned(int index) const {
  return contents_data_[index]->pinned;
}

bool TabStripModel::IsMiniTab(int index) const {
  return IsTabPinned(index) || IsAppTab(index);
}

bool TabStripModel::IsAppTab(int index) const {
  CTTabContents* contents = GetTabContentsAt(index);
  return contents && contents.isApp;
}

bool TabStripModel::IsPhantomTab(int index) const {
  /*return IsTabPinned(index) &&
         GetTabContentsAt(index)->controller().needs_reload();*/
  return false;
}

bool TabStripModel::IsTabBlocked(int index) const {
  return contents_data_[index]->blocked;
}

int TabStripModel::IndexOfFirstNonMiniTab() const {
  for (size_t i = 0; i < contents_data_.size(); ++i) {
    if (!IsMiniTab(static_cast<int>(i)))
      return static_cast<int>(i);
  }
  // No mini-tabs.
  return count();
}

int TabStripModel::ConstrainInsertionIndex(int index, bool mini_tab) {
  return mini_tab ? std::min(std::max(0, index), IndexOfFirstNonMiniTab()) :
      std::min(count(), std::max(index, IndexOfFirstNonMiniTab()));
}

int TabStripModel::IndexOfFirstNonPhantomTab() const {
  /*for (int i = 0; i < count(); ++i) {
    if (!IsPhantomTab(i))
      return i;
  }*/
  return count() ? 0 : kNoTab;
}

int TabStripModel::GetNonPhantomTabCount() const {
  /*int tabs = 0;
  for (int i = 0; i < count(); ++i) {
    if (!IsPhantomTab(i))
      ++tabs;
  }
  return tabs;*/
  return count();
}

void TabStripModel::AddTabContents(CTTabContents* contents,
                                   int index,
                                   PageTransition::Type transition,
                                   int add_types) {
  // If the newly-opened tab is part of the same task as the parent tab, we want
  // to inherit the parent's "group" attribute, so that if this tab is then
  // closed we'll jump back to the parent tab.
  bool inherit_group = (add_types & ADD_INHERIT_GROUP) == ADD_INHERIT_GROUP;

  if (transition == PageTransition::LINK &&
      (add_types & ADD_FORCE_INDEX) == 0) {
    // We assume tabs opened via link clicks are part of the same task as their
    // parent.  Note that when |force_index| is true (e.g. when the user
    // drag-and-drops a link to the tab strip), callers aren't really handling
    // link clicks, they just want to score the navigation like a link click in
    // the history backend, so we don't inherit the group in this case.
    index = order_controller_->DetermineInsertionIndex(
        contents, transition, add_types & ADD_SELECTED);
    inherit_group = true;
  } else {
    // For all other types, respect what was passed to us, normalizing -1s and
    // values that are too large.
    if (index < 0 || index > count())
      index = order_controller_->DetermineInsertionIndexForAppending();
  }

  if (transition == PageTransition::TYPED && index == count()) {
    // Also, any tab opened at the end of the TabStrip with a "TYPED"
    // transition inherit group as well. This covers the cases where the user
    // creates a New Tab (e.g. Ctrl+T, or clicks the New Tab button), or types
    // in the address bar and presses Alt+Enter. This allows for opening a new
    // Tab to quickly look up something. When this Tab is closed, the old one
    // is re-selected, not the next-adjacent.
    inherit_group = true;
  }
  InsertTabContentsAt(
      index, contents,
      add_types | (inherit_group ? ADD_INHERIT_GROUP : 0));
  // Reset the index, just in case insert ended up moving it on us.
  index = GetIndexOfTabContents(contents);

  /*if (inherit_group && transition == PageTransition::TYPED)
    contents_data_.at(index)->reset_group_on_select = true;*/

  // TODO(sky): figure out why this is here and not in InsertTabContentsAt. When
  // here we seem to get failures in startup perf tests.
  // Ensure that the new TabContentsView begins at the same size as the
  // previous TabContentsView if it existed.  Otherwise, the initial WebKit
  // layout will be performed based on a width of 0 pixels, causing a
  // very long, narrow, inaccurate layout.  Because some scripts on pages (as
  // well as WebKit's anchor link location calculation) are run on the
  // initial layout and not recalculated later, we need to ensure the first
  // layout is performed with sane view dimensions even when we're opening a
  // new background tab.
  /*if (CTTabContents* old_contents = GetSelectedTabContents()) {
    if ((add_types & ADD_SELECTED) == 0) {
      contents->view()->SizeContents(old_contents->view()->GetContainerSize());
      // We need to hide the contents or else we get and execute paints for
      // background tabs. With enough background tabs they will steal the
      // backing store of the visible tab causing flashing. See bug 20831.
      contents->HideContents();
    }
  }*/
}

void TabStripModel::CloseSelectedTab() {
  CloseTabContentsAt(selected_index_, CLOSE_CREATE_HISTORICAL_TAB);
}

void TabStripModel::SelectNextTab() {
  SelectRelativeTab(true);
}

void TabStripModel::SelectPreviousTab() {
  SelectRelativeTab(false);
}

void TabStripModel::SelectLastTab() {
  SelectTabContentsAt(count() - 1, true);
}

void TabStripModel::MoveTabNext() {
  int new_index = std::min(selected_index_ + 1, count() - 1);
  MoveTabContentsAt(selected_index_, new_index, true);
}

void TabStripModel::MoveTabPrevious() {
  int new_index = std::max(selected_index_ - 1, 0);
  MoveTabContentsAt(selected_index_, new_index, true);
}

// Context menu functions.
bool TabStripModel::IsContextMenuCommandEnabled(
    int context_index, ContextMenuCommand command_id) const {
  assert(command_id > CommandFirst && command_id < CommandLast);
  switch (command_id) {
    case CommandNewTab:
    case CommandCloseTab:
      return [delegate_ canCloseTab];
      //return delegate_->CanCloseTab();
    case CommandReload:
      if (CTTabContents* contents = GetTabContentsAt(context_index)) {
        id delegate = contents.delegate;
        if ([delegate respondsToSelector:@selector(canReloadContents:)]) {
          return [delegate canReloadContents:contents];
        } else {
          return false;
        }
        //return contents->delegate()->CanReloadContents(contents);
      } else {
        return false;
      }
    case CommandCloseOtherTabs: {
      int mini_tab_count = IndexOfFirstNonMiniTab();
          int non_mini_tab_count = count() - mini_tab_count;
      // Close other doesn't effect mini-tabs.
      return non_mini_tab_count > 1 ||
          (non_mini_tab_count == 1 && context_index != mini_tab_count);
    }
    case CommandCloseTabsToRight:
      // Close doesn't effect mini-tabs.
      return count() != IndexOfFirstNonMiniTab() &&
          context_index < (count() - 1);
    case CommandDuplicate:
      return [delegate_ canDuplicateContentsAt:context_index];
      //return delegate_->CanDuplicateContentsAt(context_index);
    case CommandRestoreTab:
      return [delegate_ canRestoreTab];
      //return delegate_->CanRestoreTab();
    case CommandTogglePinned:
      return !IsAppTab(context_index);
    //case CommandBookmarkAllTabs:
    //  return delegate_->CanBookmarkAllTabs();
    //case CommandUseVerticalTabs:
    //  return true;
    default:
      NOTREACHED();
  }
  return false;
}

bool TabStripModel::IsContextMenuCommandChecked(
    int context_index,
    ContextMenuCommand command_id) const {
  switch (command_id) {
    //case CommandUseVerticalTabs:
    //  return delegate()->UseVerticalTabs();
    default:
      NOTREACHED();
      break;
  }
  return false;
}

void TabStripModel::ExecuteContextMenuCommand(
    int context_index, ContextMenuCommand command_id) {
  assert(command_id > CommandFirst && command_id < CommandLast);
  switch (command_id) {
    case CommandNewTab:
      [delegate_ addBlankTabAtIndex:context_index+1 inForeground:true];
      //delegate()->AddBlankTabAt(context_index + 1, true);
      break;
    case CommandReload:
      [GetContentsAt(context_index).delegate reload];
      break;
    case CommandDuplicate:
      [delegate_ duplicateContentsAt:context_index];
      //delegate_->DuplicateContentsAt(context_index);
      break;
    case CommandCloseTab:
      CloseTabContentsAt(context_index, CLOSE_CREATE_HISTORICAL_TAB |
                         CLOSE_USER_GESTURE);
      break;
    case CommandCloseOtherTabs: {
      InternalCloseTabs(GetIndicesClosedByCommand(context_index, command_id),
                        CLOSE_CREATE_HISTORICAL_TAB);
      break;
    }
    case CommandCloseTabsToRight: {
      InternalCloseTabs(GetIndicesClosedByCommand(context_index, command_id),
                        CLOSE_CREATE_HISTORICAL_TAB);
      break;
    }
    case CommandRestoreTab: {
      [delegate_ restoreTab];
      //delegate_->RestoreTab();
      break;
    }
    case CommandTogglePinned: {
      if (IsPhantomTab(context_index)) {
        // The tab is a phantom tab, close it.
        CloseTabContentsAt(context_index,
                           CLOSE_USER_GESTURE | CLOSE_CREATE_HISTORICAL_TAB);
      } else {
        SelectTabContentsAt(context_index, true);
        SetTabPinned(context_index, !IsTabPinned(context_index));
      }
      break;
    }

    /*case CommandBookmarkAllTabs: {
      delegate_->BookmarkAllTabs();
      break;
    }*/

    /*case CommandUseVerticalTabs: {
      delegate()->ToggleUseVerticalTabs();
      break;
    }*/
    
    default:
      NOTREACHED();
  }
}


std::vector<int> TabStripModel::GetIndicesClosedByCommand(
    int index,
    ContextMenuCommand id) const {
  assert(ContainsIndex(index));

  // NOTE: some callers assume indices are sorted in reverse order.
  std::vector<int> indices;

  if (id != CommandCloseTabsToRight && id != CommandCloseOtherTabs)
    return indices;

  int start = (id == CommandCloseTabsToRight) ? index + 1 : 0;
  for (int i = count() - 1; i >= start; --i) {
    if (i != index && !IsMiniTab(i))
      indices.push_back(i);
  }
  return indices;
}

///////////////////////////////////////////////////////////////////////////////
// TabStripModel, NotificationObserver implementation:

// TODO replace with NSNotification if possible
// Invoked by CTTabContents when they dealloc
void TabStripModel::TabContentsWasDestroyed(CTTabContents *contents) {
  // Sometimes, on qemu, it seems like a CTTabContents object can be destroyed
  // while we still have a reference to it. We need to break this reference
  // here so we don't crash later.
  int index = GetIndexOfTabContents(contents);
  if (index != TabStripModel::kNoTab) {
    // Note that we only detach the contents here, not close it - it's
    // already been closed. We just want to undo our bookkeeping.
    //if (ShouldMakePhantomOnClose(index)) {
    //  // We don't actually allow pinned tabs to close. Instead they become
    //  // phantom.
    //  MakePhantom(index);
    //} else {
    DetachTabContentsAt(index);
    //}
  }
}

/*void TabStripModel::Observe(NotificationType type,
                            const NotificationSource& source,
                            const NotificationDetails& details) {
  switch (type.value) {
    case NotificationType::TAB_CONTENTS_DESTROYED: {
      // Sometimes, on qemu, it seems like a CTTabContents object can be destroyed
      // while we still have a reference to it. We need to break this reference
      // here so we don't crash later.
      int index = GetIndexOfTabContents(Source<CTTabContents>(source).ptr());
      if (index != TabStripModel::kNoTab) {
        // Note that we only detach the contents here, not close it - it's
        // already been closed. We just want to undo our bookkeeping.
        if (ShouldMakePhantomOnClose(index)) {
          // We don't actually allow pinned tabs to close. Instead they become
          // phantom.
          MakePhantom(index);
        } else {
          DetachTabContentsAt(index);
        }
      }
      break;
    }

    case NotificationType::EXTENSION_UNLOADED: {
      Extension* extension = Details<Extension>(details).ptr();
      // Iterate backwards as we may remove items while iterating.
      for (int i = count() - 1; i >= 0; i--) {
        CTTabContents* contents = GetTabContentsAt(i);
        if (contents->extension_app() == extension) {
          // The extension an app tab was created from has been nuked. Delete
          // the CTTabContents. Deleting a CTTabContents results in a notification
          // of type TAB_CONTENTS_DESTROYED; we do the necessary cleanup in
          // handling that notification.

          InternalCloseTab(contents, i, false);
        }
      }
      break;
    }

    default:
      NOTREACHED();
  }
}*/

///////////////////////////////////////////////////////////////////////////////
// TabStripModel, private:

bool TabStripModel::IsNewTabAtEndOfTabStrip(CTTabContents* contents) const {
  return !contents || contents == GetContentsAt(count() - 1);
  /*return LowerCaseEqualsASCII(contents->GetURL().spec(),
                              chrome::kChromeUINewTabURL) &&
      contents == GetContentsAt(count() - 1) &&
      contents->controller().entry_count() == 1;*/
}

bool TabStripModel::InternalCloseTabs(const std::vector<int>& indices,
                                      uint32 close_types) {
  bool retval = true;

  // We only try the fast shutdown path if the whole browser process is *not*
  // shutting down. Fast shutdown during browser termination is handled in
  // BrowserShutdown.
  /*if (browser_shutdown::GetShutdownType() == browser_shutdown::NOT_VALID) {
    // Construct a map of processes to the number of associated tabs that are
    // closing.
    std::map<RenderProcessHost*, size_t> processes;
    for (size_t i = 0; i < indices.size(); ++i) {
      if (!delegate_->CanCloseContentsAt(indices[i])) {
        retval = false;
        continue;
      }

      CTTabContents* detached_contents = GetContentsAt(indices[i]);
      RenderProcessHost* process = detached_contents->GetRenderProcessHost();
      std::map<RenderProcessHost*, size_t>::iterator iter =
          processes.find(process);
      if (iter == processes.end()) {
        processes[process] = 1;
      } else {
        iter->second++;
      }
    }

    // Try to fast shutdown the tabs that can close.
    for (std::map<RenderProcessHost*, size_t>::iterator iter =
            processes.begin();
        iter != processes.end(); ++iter) {
      iter->first->FastShutdownForPageCount(iter->second);
    }
  }*/

  // We now return to our regularly scheduled shutdown procedure.
  for (size_t i = 0; i < indices.size(); ++i) {
    CTTabContents* detached_contents = GetContentsAt(indices[i]);
    [detached_contents closingOfTabDidStart:this]; // TODO notification

    if (![delegate_ canCloseContentsAt:indices[i]]) {
      retval = false;
      continue;
    }

    // Update the explicitly closed state. If the unload handlers cancel the
    // close the state is reset in CTBrowser. We don't update the explicitly
    // closed state if already marked as explicitly closed as unload handlers
    // call back to this if the close is allowed.
    if (!detached_contents.closedByUserGesture) {
      detached_contents.closedByUserGesture = close_types & CLOSE_USER_GESTURE;
    }

    //if (delegate_->RunUnloadListenerBeforeClosing(detached_contents)) {
    if ([delegate_ runUnloadListenerBeforeClosing:detached_contents]) {
      retval = false;
      continue;
    }

    InternalCloseTab(detached_contents, indices[i],
                     (close_types & CLOSE_CREATE_HISTORICAL_TAB) != 0);
  }

  return retval;
}

void TabStripModel::InternalCloseTab(CTTabContents* contents,
                                     int index,
                                     bool create_historical_tabs) {
  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
                    TabClosingAt(contents, index));

  // Ask the delegate to save an entry for this tab in the historical tab
  // database if applicable.
  if (create_historical_tabs) {
    [delegate_ createHistoricalTab:contents];
    //delegate_->CreateHistoricalTab(contents);
  }

  // Deleting the CTTabContents will call back to us via NotificationObserver
  // and detach it.
  [contents destroy:this];
}

CTTabContents* TabStripModel::GetContentsAt(int index) const {
  assert(ContainsIndex(index));
      //<< "Failed to find: " << index << " in: " << count() << " entries.";
  return contents_data_.at(index)->contents;
}

void TabStripModel::ChangeSelectedContentsFrom(
    CTTabContents* old_contents, int to_index, bool user_gesture) {
  assert(ContainsIndex(to_index));
  CTTabContents* new_contents = GetContentsAt(to_index);
  if (old_contents == new_contents)
    return;

  CTTabContents* last_selected_contents = old_contents;
  if (last_selected_contents) {
    FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
                      TabDeselectedAt(last_selected_contents, selected_index_));
  }

  selected_index_ = to_index;
  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
      TabSelectedAt(last_selected_contents, new_contents, selected_index_,
                    user_gesture));
}

void TabStripModel::SelectRelativeTab(bool next) {
  // This may happen during automated testing or if a user somehow buffers
  // many key accelerators.
  if (contents_data_.empty())
    return;

  // Skip pinned-app-phantom tabs when iterating.
  int index = selected_index_;
  int delta = next ? 1 : -1;
  do {
    index = (index + count() + delta) % count();
  } while (index != selected_index_ && IsPhantomTab(index));
  SelectTabContentsAt(index, true);
}

int TabStripModel::IndexOfNextNonPhantomTab(int index,
                                            int ignore_index) {
  if (index == kNoTab)
    return kNoTab;

  if (empty())
    return index;

  index = std::min(count() - 1, std::max(0, index));
  int start = index;
  do {
    if (index != ignore_index && !IsPhantomTab(index))
      return index;
    index = (index + 1) % count();
  } while (index != start);

  // All phantom tabs.
  return start;
}

const bool kPhantomTabsEnabled = false;

bool TabStripModel::ShouldMakePhantomOnClose(int index) {
  if (kPhantomTabsEnabled && IsTabPinned(index) && !IsPhantomTab(index) &&
      !closing_all_) {
    if (!IsAppTab(index))
      return true;  // Always make non-app tabs go phantom.

    //ExtensionsService* extension_service = profile()->GetExtensionsService();
    //if (!extension_service)
    return false;

    //Extension* extension_app = GetTabContentsAt(index)->extension_app();
    //assert(extension_app);

    // Only allow the tab to be made phantom if the extension still exists.
    //return extension_service->GetExtensionById(extension_app->id(),
    //                                           false) != NULL;
  }
  return false;
}

/*void TabStripModel::MakePhantom(int index) {
  // MakePhantom is called when the CTTabContents is being destroyed so we don't
  // need to do anything with the returned value from ReplaceTabContentsAtImpl.
  ReplaceTabContentsAtImpl(index, GetContentsAt(index)->CloneAndMakePhantom(),
                           REPLACE_MADE_PHANTOM);

  if (selected_index_ == index && HasNonPhantomTabs()) {
    // Change the selection, otherwise we're going to force the phantom tab
    // to become selected.
    // NOTE: we must do this after the call to Replace otherwise browser's
    // TabSelectedAt will send out updates for the old CTTabContents which we've
    // already told observers has been closed (we sent out TabClosing at).
    int new_selected_index =
        order_controller_->DetermineNewSelectedIndex(index, false);
    new_selected_index = IndexOfNextNonPhantomTab(new_selected_index,
                                                  index);
    SelectTabContentsAt(new_selected_index, true);
  }

  if (!HasNonPhantomTabs())
    FOR_EACH_OBSERVER(TabStripModelObserver, observers_, TabStripEmpty());
}*/


void TabStripModel::MoveTabContentsAtImpl(int index, int to_position,
                                          bool select_after_move) {
  TabContentsData* moved_data = contents_data_.at(index);
  contents_data_.erase(contents_data_.begin() + index);
  contents_data_.insert(contents_data_.begin() + to_position, moved_data);

  // if !select_after_move, keep the same tab selected as was selected before.
  if (select_after_move || index == selected_index_) {
    selected_index_ = to_position;
  } else if (index < selected_index_ && to_position >= selected_index_) {
    selected_index_--;
  } else if (index > selected_index_ && to_position <= selected_index_) {
    selected_index_++;
  }

  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
                    TabMoved(moved_data->contents, index, to_position));
}

// static
/*bool TabStripModel::OpenerMatches(const TabContentsData* data,
                                  const NavigationController* opener,
                                  bool use_group) {
  return data->opener == opener || (use_group && data->group == opener);
}*/

CTTabContents* TabStripModel::ReplaceTabContentsAtImpl(
    int index,
    CTTabContents* new_contents,
    TabReplaceType type) {
  // TODO: this should reset group/opener of any tabs that point at
  // old_contents.
  assert(ContainsIndex(index));

  CTTabContents* old_contents = GetContentsAt(index);

  contents_data_[index]->contents = new_contents;

  FOR_EACH_OBSERVER(TabStripModelObserver, observers_,
                    TabReplacedAt(old_contents, new_contents, index, type));
  return old_contents;
}
