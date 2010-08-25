#import "Browser.h"
#import "chrome/browser/tabs/tab_strip_model.h"
#import "chrome/browser/cocoa/tab_strip_controller.h"
#import "BrowserWindowController.h"

@interface Browser (Private)
-(void)createWindowController;
@end;

static NSMutableSet *browsers_;

@implementation Browser

@synthesize windowController = windowController_;
@synthesize tabStripModel = tabStripModel_;


+(void)initialize {
	browsers_ = [[NSMutableSet alloc] init]; 
}


+(NSSet*)browsers {
	return browsers_;
}


+(Browser*)browser {
	Browser *browser = [[[self class] alloc] init];
	[browser createWindowController];
	[browsers_ addObject:browser];
	// TODO: post notification? BrowserReady(self)
	return browser;
}


+(Browser*)browserWithWindowFrame:(const NSRect)frame {
	Browser* browser = [self browser];
	[browser.window setFrame:frame display:NO];
	return browser;
}


-(id)init {
	if (!(self = [super init]))
		return nil;

	// Setup tab strip
	tabStripModel_ = new TabStripModel(self);

	// Note: Don't add |self| to browsers_ here. Do it at a higher level.

	return self;
}


-(void)dealloc {
	delete tabStripModel_;
	[windowController_ release];
	[browsers_ removeObject:self];
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
	NSLog(@"TODO %s", __func__);
}


#pragma mark -
#pragma mark Creating tabs


-(TabContents*)appendNewEmptyTab {
	TabContents* contents = [[TabContents alloc] init];
	contents.title = @"New tab";
	contents.view = [[NSView alloc] initWithFrame:NSZeroRect];
	tabStripModel_->AppendTabContents(contents, true);
	return contents;
}


#pragma mark -
#pragma mark Command execution


// WIP -- porting command execution from browser.cc

-(void)executeCommand:(int)cmd
			withDisposition:(WindowOpenDisposition)disposition {
	/*
  // No commands are enabled if there is not yet any selected tab.
  // TODO(pkasting): It seems like we should not need this, because either
  // most/all commands should not have been enabled yet anyway or the ones that
  // are enabled should be global, or safe themselves against having no selected
  // tab.  However, Ben says he tried removing this before and got lots of
  // crashes, e.g. from Windows sending WM_COMMANDs at random times during
  // window construction.  This probably could use closer examination someday.
  if (!GetSelectedTabContents())
    return;

  DCHECK(command_updater_.IsCommandEnabled(id)) << "Invalid/disabled command";

  // If command execution is blocked then just record the command and return.
  if (block_command_execution_) {
    // We actually only allow no more than one blocked command, otherwise some
    // commands maybe lost.
    DCHECK_EQ(last_blocked_command_id_, -1);
    last_blocked_command_id_ = id;
    last_blocked_command_disposition_ = disposition;
    return;
  }

  // The order of commands in this switch statement must match the function
  // declaration order in browser.h!
  switch (id) {
    // Navigation commands
    case IDC_BACK:                  GoBack(disposition);              break;
    case IDC_FORWARD:               GoForward(disposition);           break;
    case IDC_RELOAD:                Reload(disposition);              break;
    case IDC_RELOAD_IGNORING_CACHE: ReloadIgnoringCache(disposition); break;
    case IDC_HOME:                  Home(disposition);                break;
    case IDC_OPEN_CURRENT_URL:      OpenCurrentURL();                 break;
    case IDC_STOP:                  Stop();                           break;

     // Window management commands
    case IDC_NEW_WINDOW:            NewWindow();                      break;
    case IDC_NEW_INCOGNITO_WINDOW:  NewIncognitoWindow();             break;
    case IDC_CLOSE_WINDOW:          CloseWindow();                    break;
    case IDC_NEW_TAB:               NewTab();                         break;
    case IDC_CLOSE_TAB:             CloseTab();                       break;
    case IDC_SELECT_NEXT_TAB:       SelectNextTab();                  break;
    case IDC_SELECT_PREVIOUS_TAB:   SelectPreviousTab();              break;
    case IDC_TABPOSE:               OpenTabpose();                    break;
    case IDC_MOVE_TAB_NEXT:         MoveTabNext();                    break;
    case IDC_MOVE_TAB_PREVIOUS:     MoveTabPrevious();                break;
    case IDC_SELECT_TAB_0:
    case IDC_SELECT_TAB_1:
    case IDC_SELECT_TAB_2:
    case IDC_SELECT_TAB_3:
    case IDC_SELECT_TAB_4:
    case IDC_SELECT_TAB_5:
    case IDC_SELECT_TAB_6:
    case IDC_SELECT_TAB_7:          SelectNumberedTab(id - IDC_SELECT_TAB_0);
                                                                      break;
    case IDC_SELECT_LAST_TAB:       SelectLastTab();                  break;
    case IDC_DUPLICATE_TAB:         DuplicateTab();                   break;
    case IDC_RESTORE_TAB:           RestoreTab();                     break;
    case IDC_COPY_URL:              WriteCurrentURLToClipboard();     break;
    case IDC_SHOW_AS_TAB:           ConvertPopupToTabbedBrowser();    break;
    case IDC_FULLSCREEN:            ToggleFullscreenMode();           break;
    case IDC_EXIT:                  Exit();                           break;
	}*/
}

-(void)executeCommand:(int)cmd {
	[self executeCommand:cmd withDisposition:CURRENT_TAB];
}


#pragma mark -
#pragma mark TabStripModelDelegate protocol implementation


// Adds what the delegate considers to be a blank tab to the model.
-(TabContents*)addBlankTab:(BOOL)foreground {
	DLOG(INFO) << "BrowserWindowController addBlankTab" << foreground;
	return NULL; // TODO
}


-(TabContents*)addBlankTabAt:(int)index foreground:(BOOL)foreground {
	DLOG(INFO) << "BrowserWindowController addBlankTabAt" << index << foreground;
	return NULL; // TODO
}


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
	DLOG(INFO) << "BrowserWindowController runUnloadListenerBeforeClosing" << contents;
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
