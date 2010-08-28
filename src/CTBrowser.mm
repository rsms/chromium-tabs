#import "CTBrowser.h"
#import "CTTabStripModel.h"
#import "CTTabStripController.h"
#import "CTPageTransition.h"
#import "CTBrowserWindowController.h"
#import "CTTabContentsController.h"
#import "util.h"

@interface CTBrowser (Private)
-(void)createWindowControllerInstance;
@end


@implementation CTBrowser

@synthesize windowController = windowController_;
@synthesize tabStripModel = tabStripModel_;


+(CTBrowser*)browser {
  CTBrowser *browser = [[[self alloc] init] autorelease];
  [browser createWindowControllerInstance];
  // TODO: post notification browserReady:self ?
  return browser;
}


+(CTBrowser*)browserWithWindowFrame:(const NSRect)frame {
  CTBrowser* browser = [self browser];
  [browser.window setFrame:frame display:NO];
  return browser;
}


+(CTBrowser*)openEmptyWindow {
  CTBrowser *browser = [self browser];
  // reference will live as long as the window lives (until closed)
  [browser addBlankTabInForeground:YES];
  [browser.windowController showWindow:self];
  return browser;
}


-(id)init {
  if (!(self = [super init])) return nil;
  tabStripModel_ = new CTTabStripModel(self);
  return self;
}


-(void)dealloc {
  DLOG("deallocing browser %@", self);
  delete tabStripModel_;
  [windowController_ release];
  [super dealloc];
}


// private
-(void)createWindowControllerInstance {
  assert(!windowController_);
  windowController_ = [self createWindowController];
  assert(windowController_);
}


-(CTBrowserWindowController *)createWindowController {
  // subclasses could override this
  NSString *windowNibPath = [util pathForResource:@"BrowserWindow"
                                           ofType:@"nib"];
  return [[CTBrowserWindowController alloc] initWithWindowNibPath:windowNibPath 
                                                        browser:self];
}


-(CTTabContentsController*)createTabContentsControllerWithContents:
    (CTTabContents*)contents {
  // subclasses could override this
  return [[[CTTabContentsController alloc] initWithContents:contents] autorelease];
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
-(CTTabContents*)selectedTabContents {
  return tabStripModel_->GetSelectedTabContents();
}
-(CTTabContents*)tabContentsAtIndex:(int)index {
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

-(void)loadingStateDidChange:(CTTabContents*)contents {
  // TODO: Make sure the loading state is updated correctly
}

-(void)windowDidBeginToClose {
  tabStripModel_->CloseAllTabs();
}


#pragma mark -
#pragma mark UI state


/*-(NSRect)savedWindowBounds {
  gfx::Rect restored_bounds = override_bounds_;
  bool maximized;
  WindowSizer::GetBrowserWindowBounds(app_name_, restored_bounds, NULL,
                                      &restored_bounds, &maximized);
  return restored_bounds;
}*/


#pragma mark -
#pragma mark Commands

-(void)newWindow {
  [isa openEmptyWindow];
}

-(void)closeWindow {
  [self.window orderOut:self];
  [self.window performClose:self];  // Autoreleases the controller.
}

-(CTTabContents*)addTabContents:(CTTabContents*)contents
                      atIndex:(int)index
                 inForeground:(BOOL)foreground {
  //tabStripModel_->AppendTabContents(contents, foreground);
  int addTypes = foreground ? CTTabStripModel::ADD_SELECTED :
                              CTTabStripModel::ADD_NONE;
  tabStripModel_->AddTabContents(contents, index, CTPageTransitionTyped,
                                 addTypes);
  if ((addTypes & CTTabStripModel::ADD_SELECTED) == 0) {
    // TabStripModel::AddTabContents invokes HideContents if not foreground.
    contents.isVisible = NO;
  }
  return contents;
}


-(CTTabContents*)createBlankTabBasedOn:(CTTabContents*)baseContents {
  // subclasses should override this to provide a custom CTTabContents type
  // and/or initialization
  return [[CTTabContents alloc] initWithBaseTabContents:baseContents];
}


// implementation conforms to CTTabStripModelDelegate
-(CTTabContents*)addBlankTabAtIndex:(int)index inForeground:(BOOL)foreground {
  // Retrieve the window frame which we pass on to 
  //NSRect frame = [self.windowController.window frame];
  //frame.origin.x  = frame.origin.y = 0.0;
  
  CTTabContents* baseContents = tabStripModel_->GetSelectedTabContents();
  CTTabContents* contents = [self createBlankTabBasedOn:baseContents];
  return [self addTabContents:contents atIndex:index inForeground:foreground];
}

// implementation conforms to CTTabStripModelDelegate
-(CTTabContents*)addBlankTabInForeground:(BOOL)foreground {
  return [self addBlankTabAtIndex:-1 inForeground:foreground];
}

-(CTTabContents*)addBlankTab {
  return [self addBlankTabInForeground:YES];
}

-(void)closeTab {
  if ([self canCloseTab]) {
    tabStripModel_->CloseTabContentsAt(
        tabStripModel_->selected_index(),
        CTTabStripModel::CLOSE_USER_GESTURE |
        CTTabStripModel::CLOSE_CREATE_HISTORICAL_TAB);
  }
}

-(void)selectNextTab {
  tabStripModel_->SelectNextTab();
}

-(void)selectPreviousTab {
  tabStripModel_->SelectPreviousTab();
}

-(void)moveTabNext {
  tabStripModel_->MoveTabNext();
}

-(void)moveTabPrevious {
  tabStripModel_->MoveTabPrevious();
}

-(void)selectTabAtIndex:(int)index {
  if (index < tabStripModel_->count()) {
    tabStripModel_->SelectTabContentsAt(index, true);
  }
}

-(void)selectLastTab {
  tabStripModel_->SelectLastTab();
}

-(void)duplicateTab {
  //[self duplicateContentsAt:tabStripModel_->selected_index()];
  // can't do this currently
}


-(void)executeCommand:(int)cmd
      withDisposition:(CTWindowOpenDisposition)disposition {
  //DLOG_EXPR(cmd); //< useful to debug incoming |cmd| values
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
    case CTBrowserCommandNewWindow:            [self newWindow]; break;
    //case CTBrowserCommandNewIncognitoWindow: break;
    case CTBrowserCommandCloseWindow:          [self closeWindow]; break;
    //case CTBrowserCommandAlwaysOnTop: break;
    case CTBrowserCommandNewTab:               [self addBlankTab]; break;
    case CTBrowserCommandCloseTab:             [self closeTab]; break;
    case CTBrowserCommandSelectNextTab:       [self selectNextTab]; break;
    case CTBrowserCommandSelectPreviousTab:   [self selectPreviousTab]; break;
    case CTBrowserCommandSelectTab0:
    case CTBrowserCommandSelectTab1:
    case CTBrowserCommandSelectTab2:
    case CTBrowserCommandSelectTab3:
    case CTBrowserCommandSelectTab4:
    case CTBrowserCommandSelectTab5:
    case CTBrowserCommandSelectTab6:
    case CTBrowserCommandSelectTab7: {
      [self selectTabAtIndex:cmd - CTBrowserCommandSelectTab0];
      break;
    }
    case CTBrowserCommandSelectLastTab:    [self selectLastTab]; break;
    case CTBrowserCommandDuplicateTab:     [self duplicateTab]; break;
    //case CTBrowserCommandRestoreTab:     break;
    //case CTBrowserCommandShowAsTab:      break;
    //case CTBrowserCommandFullscreen:     DLOG("TODO ToggleFullscreenMode();"); break;
    case CTBrowserCommandExit:             [NSApp terminate:self]; break;
    case CTBrowserCommandMoveTabNext:      [self moveTabNext]; break;
    case CTBrowserCommandMoveTabPrevious:  [self moveTabPrevious]; break;
  }
}

-(void)executeCommand:(int)cmd {
  [self executeCommand:cmd withDisposition:CTWindowOpenDispositionCurrentTab];
}

+(void)executeCommand:(int)cmd {
  switch (cmd) {
    case CTBrowserCommandNewWindow:
    case CTBrowserCommandNewTab:    [self openEmptyWindow];  break;
    case CTBrowserCommandExit:      [NSApp terminate:self]; break;
  }
}


#pragma mark -
#pragma mark CTTabStripModelDelegate protocol implementation


-(CTBrowser*)createNewStripWithContents:(CTTabContents*)contents
                         windowBounds:(const NSRect)windowBounds
                             maximize:(BOOL)maximize {
  //assert(CanSupportWindowFeature(FEATURE_TABSTRIP));

  //gfx::Rect new_window_bounds = window_bounds;
  //if (dock_info.GetNewWindowBounds(&new_window_bounds, &maximize))
  //  dock_info.AdjustOtherWindowBounds();

  // Create an empty new browser window the same size as the old one.
  CTBrowser* browser = [isa browserWithWindowFrame:windowBounds];
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

// Creates a new CTBrowser object and window containing the specified
// |contents|, and continues a drag operation that began within the source
// window's tab strip. |window_bounds| are the bounds of the source window in
// screen coordinates, used to place the new window, and |tab_bounds| are the
// bounds of the dragged Tab view in the source window, in screen coordinates,
// used to place the new Tab in the new window.
-(void)continueDraggingDetachedTab:(CTTabContents*)contents
                      windowBounds:(const NSRect)windowBounds
                         tabBounds:(const NSRect)tabBounds {
  NOTIMPLEMENTED();
}


// Returns whether some contents can be duplicated.
-(BOOL)canDuplicateContentsAt:(int)index {
  return false;
}

// Duplicates the contents at the provided index and places it into its own
// window.
-(void)duplicateContentsAt:(int)index {
}

// Called when a drag session has completed and the frame that initiated the
// the session should be closed.
-(void)closeFrameAfterDragSession {
  DLOG("closeFrameAfterDragSession");
}

// Creates an entry in the historical tab database for the specified
// CTTabContents.
-(void)createHistoricalTab:(CTTabContents*)contents {
  DLOG("TODO createHistoricalTab %@", contents);
}

// Runs any unload listeners associated with the specified CTTabContents before
// it is closed. If there are unload listeners that need to be run, this
// function returns true and the TabStripModel will wait before closing the
// CTTabContents. If it returns false, there are no unload listeners and the
// TabStripModel can close the CTTabContents immediately.
-(BOOL)runUnloadListenerBeforeClosing:(CTTabContents*)contents {
  return false;
}

// Returns true if a tab can be restored.
-(BOOL)canRestoreTab {
  return false;
}

// Restores the last closed tab if CanRestoreTab would return true.
-(void)restoreTab {
}

// Returns whether some contents can be closed.
-(BOOL)canCloseContentsAt:(int)index {
  return true;
}

// Returns true if any of the tabs can be closed.
-(BOOL)canCloseTab {
  return true;
}


@end
