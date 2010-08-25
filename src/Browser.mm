#import "Browser.h"
#import "chrome/browser/tabs/tab_strip_model.h"
#import "chrome/browser/cocoa/tab_strip_controller.h"
#import "chrome/common/page_transition_types.h"
#import "BrowserWindowController.h"
#import "BrowserCommands.h"

@interface Browser (Private)
-(void)createWindowController;
@end;


@implementation Browser

@synthesize windowController = windowController_;
@synthesize tabStripModel = tabStripModel_;


+(Browser*)browser {
	Browser *browser = [[[[self class] alloc] init] autorelease];
	[browser createWindowController];
	// TODO: post notification? BrowserReady(self)
	return browser;
}


+(Browser*)browserWithWindowFrame:(const NSRect)frame {
	Browser* browser = [self browser];
	[browser.window setFrame:frame display:NO];
	return browser;
}


+(Browser*)openEmptyWindow {
	Browser *browser = [Browser browser];
	// reference will live as long as the window lives (until closed)
	[browser addBlankTabInForeground:YES];
	[browser.windowController showWindow:self];
	return browser;
}


-(id)init {
	if (!(self = [super init])) return nil;
	tabStripModel_ = new TabStripModel(self);
	return self;
}


-(void)dealloc {
	logd(@"dealloced browser");
	delete tabStripModel_;
	[windowController_ release];
	[super dealloc];
}


// private
-(void)createWindowController {
	DCHECK(!windowController_);
	windowController_ =
			[[BrowserWindowController alloc] initWithWindowNibName:@"BrowserWindow" 
																										 browser:self];
}


#pragma mark -
#pragma mark Accessors

-(NSWindow*)window {
	return [windowController_ window];
}

// TabStripModel convenience helpers

-(int)tabCount {
	return tabStripModel_->count();
}
-(int)selectedTabIndex {
	return tabStripModel_->selected_index();
}
-(TabContents*)selectedTabContents {
	return tabStripModel_->GetSelectedTabContents();
}
-(TabContents*)tabContentsAtIndex:(int)index {
	return tabStripModel_->GetTabContentsAt(index);
}
-(void)selectTabContentsAtIndex:(int)index userGesture:(BOOL)userGesture {
	tabStripModel_->SelectTabContentsAt(index, userGesture);
}
-(void)closeAllTabs {
	tabStripModel_->CloseAllTabs();
}

#pragma mark -
#pragma mark Callbacks

-(void)loadingStateDidChange:(TabContents*)contents {
	logd(@"TODO %s", __func__);
	loge(contents);
}

-(void)windowDidBeginToClose {
	tabStripModel_->CloseAllTabs();
	// NOTE: in the future the following call could be deferred (i.e. after all
	// tabs have finalized). But for now we'll just call it again.
	//[self closeWindow];
}


#pragma mark -
#pragma mark Commands

-(void)newWindow {
	[Browser openEmptyWindow];
}

-(void)closeWindow {
	logd(@"closeWindow");
	loge(self.window);
	[self.window orderOut:self];
	[self.window performClose:self];  // Autoreleases the controller.
}

-(TabContents*)addTabContents:(TabContents*)contents
											atIndex:(int)index
								 inForeground:(BOOL)foreground {
	//tabStripModel_->AppendTabContents(contents, foreground);
	int addTypes = foreground ? TabStripModel::ADD_SELECTED :
															TabStripModel::ADD_NONE;
	tabStripModel_->AddTabContents(contents, index, PageTransition::TYPED,
	                               addTypes);
	// By default, content believes it is not hidden.  When adding contents
	// in the background, tell it that it's hidden.
	if ((addTypes & TabStripModel::ADD_SELECTED) == 0) {
		// TabStripModel::AddTabContents invokes HideContents if not foreground.
		[contents didBecomeHidden];
	}
	return contents;
}

// implementation conforms to TabStripModelDelegate
-(TabContents*)addBlankTabAtIndex:(int)index inForeground:(BOOL)foreground {
	TabContents* baseContents = tabStripModel_->GetSelectedTabContents();
	TabContents* contents =
			[[TabContents alloc] initWithBaseTabContents:baseContents];
	contents.title = @"New tab";
	contents.view = [[NSView alloc] initWithFrame:NSZeroRect];
	return [self addTabContents:contents atIndex:index inForeground:foreground];
}

// implementation conforms to TabStripModelDelegate
-(TabContents*)addBlankTabInForeground:(BOOL)foreground {
	return [self addBlankTabAtIndex:-1 inForeground:foreground];
}

-(TabContents*)addBlankTab {
	return [self addBlankTabInForeground:YES];
}

-(void)closeTab {
  if ([self canCloseTab]) {
    tabStripModel_->CloseTabContentsAt(
        tabStripModel_->selected_index(),
        TabStripModel::CLOSE_USER_GESTURE |
        TabStripModel::CLOSE_CREATE_HISTORICAL_TAB);
  }
}

-(void)selectNextTab {
  tabStripModel_->SelectNextTab();
}

-(void)selectPreviousTab {
  tabStripModel_->SelectPreviousTab();
}


-(void)executeCommand:(int)cmd
			withDisposition:(WindowOpenDisposition)disposition {
	loge(cmd);
  // No commands are enabled if there is not yet any selected tab.
  // TODO(pkasting): It seems like we should not need this, because either
  // most/all commands should not have been enabled yet anyway or the ones that
  // are enabled should be global, or safe themselves against having no selected
  // tab.  However, Ben says he tried removing this before and got lots of
  // crashes, e.g. from Windows sending WM_COMMANDs at random times during
  // window construction.  This probably could use closer examination someday.
  if (![self selectedTabContents])
    return;

  // If command execution is blocked then just record the command and return.
  /*if (block_command_execution_) {
    // We actually only allow no more than one blocked command, otherwise some
    // commands maybe lost.
    DCHECK_EQ(last_blocked_command_id_, -1);
    last_blocked_command_id_ = id;
    last_blocked_command_disposition_ = disposition;
    return;
  }*/

  // The order of commands in this switch statement must match the function
  // declaration order in BrowserCommands.h
  switch (cmd) {
		// Window management commands
    case IDC_NEW_WINDOW:						[self newWindow]; break;
    //case IDC_NEW_INCOGNITO_WINDOW: break;
    case IDC_CLOSE_WINDOW:          [self closeWindow]; break;
		//case IDC_ALWAYS_ON_TOP: break;
    case IDC_NEW_TAB:               [self addBlankTab]; break;
    case IDC_CLOSE_TAB:             [self closeTab]; break;
    case IDC_SELECT_NEXT_TAB:       [self selectNextTab]; break;
    case IDC_SELECT_PREVIOUS_TAB:   [self selectPreviousTab]; break;
    case IDC_SELECT_TAB_0:
    case IDC_SELECT_TAB_1:
    case IDC_SELECT_TAB_2:
    case IDC_SELECT_TAB_3:
    case IDC_SELECT_TAB_4:
    case IDC_SELECT_TAB_5:
    case IDC_SELECT_TAB_6:
    case IDC_SELECT_TAB_7:          logd(@"TODO SelectNumberedTab(id - IDC_SELECT_TAB_0);"); break;
    case IDC_SELECT_LAST_TAB:       logd(@"TODO SelectLastTab();");                  break;
    case IDC_DUPLICATE_TAB:         logd(@"TODO DuplicateTab();");                   break;
    case IDC_RESTORE_TAB:           logd(@"TODO RestoreTab();");                     break;
    case IDC_SHOW_AS_TAB:           logd(@"TODO ConvertPopupToTabbedBrowser();");    break;
    case IDC_FULLSCREEN:            logd(@"TODO ToggleFullscreenMode();");           break;
    case IDC_EXIT:                  [NSApp terminate:self];                           break;
    case IDC_MOVE_TAB_NEXT:         logd(@"TODO MoveTabNext();");                    break;
    case IDC_MOVE_TAB_PREVIOUS:     logd(@"TODO MoveTabPrevious();");                break;
	}
}

-(void)executeCommand:(int)cmd {
	[self executeCommand:cmd withDisposition:CURRENT_TAB];
}


#pragma mark -
#pragma mark TabStripModelDelegate protocol implementation


-(Browser*)createNewStripWithContents:(TabContents*)contents
												 windowBounds:(const NSRect)windowBounds
														 maximize:(BOOL)maximize {
  //DCHECK(CanSupportWindowFeature(FEATURE_TABSTRIP));

  //gfx::Rect new_window_bounds = window_bounds;
  //if (dock_info.GetNewWindowBounds(&new_window_bounds, &maximize))
  //  dock_info.AdjustOtherWindowBounds();

  // Create an empty new browser window the same size as the old one.
  Browser* browser = [Browser browserWithWindowFrame:windowBounds];
	browser.tabStripModel->AppendTabContents(contents, true);
	[browser loadingStateDidChange:contents];
	[browser.windowController showWindow:self];

	// Orig impl:
  //browser->set_override_bounds(new_window_bounds);
  //browser->set_maximized_state(
  //    maximize ? MAXIMIZED_STATE_MAXIMIZED : MAXIMIZED_STATE_UNMAXIMIZED);
  //browser->CreateBrowserWindow();
  //browser->tabstrip_model()->AppendTabContents(contents, true);

  // Make sure the loading state is updated correctly, otherwise the throbber
  // won't start if the page is loading.
  //browser->LoadingStateChanged(contents);

  return browser;
}

// Creates a new Browser object and window containing the specified
// |contents|, and continues a drag operation that began within the source
// window's tab strip. |window_bounds| are the bounds of the source window in
// screen coordinates, used to place the new window, and |tab_bounds| are the
// bounds of the dragged Tab view in the source window, in screen coordinates,
// used to place the new Tab in the new window.
-(void)continueDraggingDetachedTab:(TabContents*)contents
											windowBounds:(const NSRect)windowBounds
											   tabBounds:(const NSRect)tabBounds {
	NOTIMPLEMENTED();
}


// Returns whether some contents can be duplicated.
-(BOOL)canDuplicateContentsAt:(int)index {
	DLOG(INFO) << "BrowserWindowController canDuplicateContentsAt" << index;
	return false;
}

// Duplicates the contents at the provided index and places it into its own
// window.
-(void)duplicateContentsAt:(int)index {
	DLOG(INFO) << "BrowserWindowController duplicateContentsAt" << index;
}

// Called when a drag session has completed and the frame that initiated the
// the session should be closed.
-(void)closeFrameAfterDragSession {
	DLOG(INFO) << "BrowserWindowController closeFrameAfterDragSession";
}

// Creates an entry in the historical tab database for the specified
// TabContents.
-(void)createHistoricalTab:(TabContents*)contents {
	DLOG(INFO) << "BrowserWindowController createHistoricalTab" << contents;
}

// Runs any unload listeners associated with the specified TabContents before
// it is closed. If there are unload listeners that need to be run, this
// function returns true and the TabStripModel will wait before closing the
// TabContents. If it returns false, there are no unload listeners and the
// TabStripModel can close the TabContents immediately.
-(BOOL)runUnloadListenerBeforeClosing:(TabContents*)contents {
	//DLOG(INFO) << "BrowserWindowController runUnloadListenerBeforeClosing" << contents;
	return false;
}

// Returns true if a tab can be restored.
-(BOOL)canRestoreTab {
	DLOG(INFO) << "BrowserWindowController canRestoreTab";
	return false;
}

// Restores the last closed tab if CanRestoreTab would return true.
-(void)restoreTab {
	DLOG(INFO) << "BrowserWindowController restoreTab";
}

// Returns whether some contents can be closed.
-(BOOL)canCloseContentsAt:(int)index {
	DLOG(INFO) << "BrowserWindowController canCloseContentsAt" << index;
	return true;
}

// Returns true if any of the tabs can be closed.
-(BOOL)canCloseTab {
	DLOG(INFO) << "BrowserWindowController canCloseTab";
	return true;
}


@end
