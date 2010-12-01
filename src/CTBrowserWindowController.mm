#import "CTBrowserWindowController.h"
#import "CTTabStripModel.h"
#import "CTTabContents.h"
#import "CTTabStripController.h"
#import "CTTabStripModelObserverBridge.h"
#import "CTTabView.h"
#import "CTTabStripView.h"
#import "CTToolbarController.h"
#import "CTUtil.h"
#import "fast_resize_view.h"

#import "scoped_nsdisable_screen_updates.h"

@interface NSWindow (ThingsThatMightBeImplemented)
- (void)setShouldHideTitle:(BOOL)y;
- (void)setBottomCornerRounded:(BOOL)y;
@end

@interface CTBrowserWindowController (Private)
- (CGFloat)layoutTabStripAtMaxY:(CGFloat)maxY
                          width:(CGFloat)width
                     fullscreen:(BOOL)fullscreen;
- (CGFloat)layoutToolbarAtMinX:(CGFloat)minX
                          maxY:(CGFloat)maxY
                         width:(CGFloat)width;
@end

@implementation NSDocumentController (CTBrowserWindowControllerAdditions)
- (id)openUntitledDocumentWithWindowController:(NSWindowController*)windowController
                                       display:(BOOL)display
                                         error:(NSError **)outError {
  // default implementation
  return [self openUntitledDocumentAndDisplay:display error:outError];
}
@end

static CTBrowserWindowController* _currentMain = nil; // weak

@implementation CTBrowserWindowController

@synthesize tabStripController = tabStripController_;
@synthesize toolbarController = toolbarController_;
@synthesize browser = browser_;


/*- (id)retain {
  self = [super retain];
  NSLog(@"%@  did retain  (retainCount: %u)", self, [self retainCount]);
  NSLog(@"%@", [NSThread callStackSymbols]);
  return self;
}

- (void)release {
  NSLog(@"%@ will release (retainCount: %u)", self, [self retainCount]);
  NSLog(@"%@", [NSThread callStackSymbols]);
  [super release];
}*/

+ (CTBrowserWindowController*)browserWindowController {
  return [[[self alloc] init] autorelease];
}

+ (CTBrowserWindowController*)mainBrowserWindowController {
  return _currentMain;
}

+ (CTBrowserWindowController*)browserWindowControllerForWindow:(NSWindow*)window {
  while (window) {
    id controller = [window windowController];
    if ([controller isKindOfClass:[CTBrowserWindowController class]])
      return (CTBrowserWindowController*)controller;
    window = [window parentWindow];
  }
  return nil;
}

+ (CTBrowserWindowController*)browserWindowControllerForView:(NSView*)view {
  NSWindow* window = [view window];
  return [CTBrowserWindowController browserWindowControllerForWindow:window];
}


// Load the browser window nib and do initialization. Note that the nib also
// sets this controller up as the window's delegate.
- (id)initWithWindowNibPath:(NSString *)windowNibPath
                    browser:(CTBrowser*)browser {
  if (!(self = [super initWithWindowNibPath:windowNibPath owner:self]))
    return nil;

  // Set initialization boolean state so subroutines can act accordingly
  initializing_ = YES;

  // Our browser
  browser_ = [browser retain];
  browser_->windowController_ = self;

  // Observe tabs
  tabStripObserver_ = 
      new CTTabStripModelObserverBridge([browser_ tabStripModel], self);

  // Note: the below statement including [self window] implicitly loads the
  // window and thus initializes IBOutlets, needed later. If [self window] is
  // not called (i.e. code removed), substitute the loading with a call to
  // [self loadWindow]

  // Sets the window to not have rounded corners, which prevents the resize
  // control from being inset slightly and looking ugly.
  NSWindow *window = [self window];
  if ([window respondsToSelector:@selector(setBottomCornerRounded:)])
    [window setBottomCornerRounded:NO];
  [[window contentView] setAutoresizesSubviews:YES];

  // Note: when using the default BrowserWindow.xib, window bounds are saved and
  // restored by Cocoa using NSUserDefaults key "browserWindow".

  // Create a tab strip controller
  tabStripController_ =
      [[CTTabStripController alloc] initWithView:self.tabStripView
                                    switchView:self.tabContentArea
                                       browser:browser_];

  // Create a toolbar controller. The browser object might return nil, in which
  // means we do not have a toolbar.
  toolbarController_ = [[browser_ createToolbarController] retain];
  if (toolbarController_) {
    [[[self window] contentView] addSubview:[toolbarController_ view]];
  }

  // When using NSDocuments
  [self setShouldCloseDocument:YES];

  [self layoutSubviews];

  initializing_ = NO;
  if (!_currentMain) {
    // TODO: synchronization
    _currentMain = self;
  }
  return self;
}


- (id)initWithBrowser:(CTBrowser *)browser {
  // subclasses could override this to provie a custom nib
  NSString *windowNibPath = [CTUtil pathForResource:@"BrowserWindow"
                                             ofType:@"nib"];
  return [self initWithWindowNibPath:windowNibPath browser:browser];
}


- (id)init {
  // subclasses could override this to provide a custom |CTBrowser|
  return [self initWithBrowser:[CTBrowser browser]];
}


-(void)dealloc {
  DLOG("[ChromiumTabs] dealloc window controller");
  if (_currentMain == self) {
    // TODO: synchronization
    _currentMain = nil;
  }
  delete tabStripObserver_;
  
  // Close all tabs
  //[browser_ closeAllTabs]; // TODO

  // Explicitly release |fullscreenController_| here, as it may call back to
  // this BWC in |-dealloc|.  We are required to call |-exitFullscreen| before
  // releasing the controller.
  //[fullscreenController_ exitFullscreen]; // TODO
  //fullscreenController_.reset();

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [browser_ release];
  [tabStripController_ release];
  [toolbarController_ release];
  [super dealloc];
}


-(void)finalize {
  if (_currentMain == self) {
    // TODO: synchronization
    _currentMain = nil;
  }
  //NSLog(@"%@ will finalize (retainCount: %u)", self, [self retainCount]);
  //NSLog(@"%@", [NSThread callStackSymbols]);
  delete tabStripObserver_;
  [super finalize];
}


- (BOOL)isFullscreen {
  return NO; // TODO
}

- (BOOL)hasToolbar {
  return !!toolbarController_;
}


// Updates the toolbar with the states of the specified |contents|.
// If |shouldRestore| is true, we're switching (back?) to this tab and should
// restore any previous state (such as user editing a text field) as well.
- (void)updateToolbarWithContents:(CTTabContents*)contents
               shouldRestoreState:(BOOL)shouldRestore {
  // safe even if toolbarController_ is nil
  [toolbarController_ updateToolbarWithContents:contents
                             shouldRestoreState:shouldRestore];
}

- (void)synchronizeWindowTitleWithDocumentName {
  // overriding this to not do anything have the effect of not adding a title to
  // our window (the title is in the tab, remember?)
}

#pragma mark -
#pragma mark NSWindow (CTThemed)

- (NSPoint)themePatternPhase {
  // Our patterns want to be drawn from the upper left hand corner of the view.
  // Cocoa wants to do it from the lower left of the window.
  //
  // Rephase our pattern to fit this view. Some other views (Tabs, Toolbar etc.)
  // will phase their patterns relative to this so all the views look right.
  //
  // To line up the background pattern with the pattern in the browser window
  // the background pattern for the tabs needs to be moved left by 5 pixels.
  const CGFloat kPatternHorizontalOffset = -5;
  NSView* tabStripView = [self tabStripView];
  NSRect tabStripViewWindowBounds = [tabStripView bounds];
  NSView* windowChromeView = [[[self window] contentView] superview];
  tabStripViewWindowBounds =
      [tabStripView convertRect:tabStripViewWindowBounds
                         toView:windowChromeView];
  NSPoint phase = NSMakePoint(NSMinX(tabStripViewWindowBounds)
                                  + kPatternHorizontalOffset,
                              NSMinY(tabStripViewWindowBounds)
                                  + [CTTabStripController defaultTabHeight]);
  return phase;
}


#pragma mark -
#pragma mark Actions


- (IBAction)saveAllDocuments:(id)sender {
  [[NSDocumentController sharedDocumentController] saveAllDocuments:sender];
}
- (IBAction)openDocument:(id)sender {
  [[NSDocumentController sharedDocumentController] openDocument:sender];
}

- (IBAction)newDocument:(id)sender {
  NSDocumentController* docController =
      [NSDocumentController sharedDocumentController];
  NSError *error = nil;
  DCHECK(browser_);
  CTTabContents *baseTabContents = browser_.selectedTabContents;
  CTTabContents *tabContents =
      [docController openUntitledDocumentWithWindowController:self
                                                      display:YES
                                                        error:&error];
  if (!tabContents) {
    [NSApp presentError:error];
  } else if (baseTabContents) {
    tabContents.parentOpener = baseTabContents;
  }
}

- (IBAction)newWindow:(id)sender {
  CTBrowserWindowController* windowController =
      [[isa browserWindowController] retain];
  [windowController newDocument:sender];
  [windowController showWindow:self];
}


// Called when the user picks a menu or toolbar item when this window is key.
// Calls through to the browser object to execute the command. This assumes that
// the command is supported and doesn't check, otherwise it would have been
// disabled in the UI in validateUserInterfaceItem:.
- (void)commandDispatch:(id)sender {
  assert(sender);
  // Identify the actual BWC to which the command should be dispatched. It might
  // belong to a background window, yet this controller gets it because it is
  // the foreground window's controller and thus in the responder chain. Some
  // senders don't have this problem (for example, menus only operate on the
  // foreground window), so this is only an issue for senders that are part of
  // windows.
  CTBrowserWindowController* targetController = self;
  if ([sender respondsToSelector:@selector(window)])
    targetController = [[sender window] windowController];
  assert([targetController isKindOfClass:[CTBrowserWindowController class]]);
  [targetController.browser executeCommand:[sender tag]];
}


-(IBAction)closeTab:(id)sender {
  CTTabStripModel *tabStripModel = browser_.tabStripModel;
  //tabStripModel->CloseAllTabs();
  tabStripModel->CloseTabContentsAt(tabStripModel->selected_index(),
                                    CTTabStripModel::CLOSE_CREATE_HISTORICAL_TAB);
}


#pragma mark -
#pragma mark CTTabWindowController implementation

// Accept tabs from a CTBrowserWindowController with the same Profile.
- (BOOL)canReceiveFrom:(CTTabWindowController*)source {
  if (![source isKindOfClass:[isa class]]) {
    return NO;
  }

  // here we could for instance check (and deny) dragging a tab from a normal
  // window into a special window (e.g. pop-up or similar)

  return YES;
}


// Move a given tab view to the location of the current placeholder. If there is
// no placeholder, it will go at the end. |controller| is the window controller
// of a tab being dropped from a different window. It will be nil if the drag is
// within the window, otherwise the tab is removed from that window before being
// placed into this one.
//
// The implementation will call |-removePlaceholder| since the drag is now
// complete. This also calls |-layoutTabs| internally so clients do not need to
// call it again.
- (void)moveTabView:(NSView*)view
     fromController:(CTTabWindowController*)dragController {
  if (dragController) {
    // Moving between windows. Figure out the CTTabContents to drop into our tab
    // model from the source window's model.
    BOOL isBrowser =
        [dragController isKindOfClass:[CTBrowserWindowController class]];
    assert(isBrowser);
    if (!isBrowser) return;
    CTBrowserWindowController* dragBWC = (CTBrowserWindowController*)dragController;
    int index = [dragBWC->tabStripController_ modelIndexForTabView:view];
    CTTabContents* contents =
        [dragBWC->browser_ tabStripModel]->GetTabContentsAt(index);
    // The tab contents may have gone away if given a window.close() while it
    // is being dragged. If so, bail, we've got nothing to drop.
    if (!contents)
      return;

    // Convert |view|'s frame (which starts in the source tab strip's coordinate
    // system) to the coordinate system of the destination tab strip. This needs
    // to be done before being detached so the window transforms can be
    // performed.
    NSRect destinationFrame = [view frame];
    NSPoint tabOrigin = destinationFrame.origin;
    tabOrigin = [[dragController tabStripView] convertPoint:tabOrigin
                                                     toView:nil];
    tabOrigin = [[view window] convertBaseToScreen:tabOrigin];
    tabOrigin = [[self window] convertScreenToBase:tabOrigin];
    tabOrigin = [[self tabStripView] convertPoint:tabOrigin fromView:nil];
    destinationFrame.origin = tabOrigin;

    // Before the tab is detached from its originating tab strip, store the
    // pinned state so that it can be maintained between the windows.
    bool isPinned = [dragBWC->browser_ tabStripModel]->IsTabPinned(index);

    // Now that we have enough information about the tab, we can remove it from
    // the dragging window. We need to do this *before* we add it to the new
    // window as this will remove the CTTabContents' delegate.
    [dragController detachTabView:view];

    // Deposit it into our model at the appropriate location (it already knows
    // where it should go from tracking the drag). Doing this sets the tab's
    // delegate to be the CTBrowser.
    [tabStripController_ dropTabContents:contents
                               withFrame:destinationFrame
                             asPinnedTab:isPinned];
  } else {
    // Moving within a window.
    int index = [tabStripController_ modelIndexForTabView:view];
    [tabStripController_ moveTabFromIndex:index];
  }

  // Remove the placeholder since the drag is now complete.
  [self removePlaceholder];
}


- (NSView*)selectedTabView {
  return [tabStripController_ selectedTabView];
}


- (void)layoutTabs {
  [tabStripController_ layoutTabs];
}


// Creates a new window by pulling the given tab out and placing it in
// the new window. Returns the controller for the new window. The size of the
// new window will be the same size as this window.
- (CTTabWindowController*)detachTabToNewWindow:(CTTabView*)tabView {
  // Disable screen updates so that this appears as a single visual change.
  base::ScopedNSDisableScreenUpdates disabler;

  // Keep a local ref to the tab strip model object
  CTTabStripModel *tabStripModel = [browser_ tabStripModel];

  // Fetch the tab contents for the tab being dragged.
  int index = [tabStripController_ modelIndexForTabView:tabView];
  CTTabContents* contents = tabStripModel->GetTabContentsAt(index);

  // Set the window size. Need to do this before we detach the tab so it's
  // still in the window. We have to flip the coordinates as that's what
  // is expected by the CTBrowser code.
  NSWindow* sourceWindow = [tabView window];
  NSRect windowRect = [sourceWindow frame];
  NSScreen* screen = [sourceWindow screen];
  windowRect.origin.y =
      [screen frame].size.height - windowRect.size.height - windowRect.origin.y;
  
  //gfx::Rect browserRect(windowRect.origin.x, windowRect.origin.y,
  //                      windowRect.size.width, windowRect.size.height);

  NSRect tabRect = [tabView frame];

  // Before detaching the tab, store the pinned state.
  bool isPinned = tabStripModel->IsTabPinned(index);

  // Detach it from the source window, which just updates the model without
  // deleting the tab contents. This needs to come before creating the new
  // CTBrowser because it clears the CTTabContents' delegate, which gets hooked
  // up during creation of the new window.
  tabStripModel->DetachTabContentsAt(index);

  // Create the new browser with a single tab in its model, the one being
  // dragged. Note that we do not retain the (autoreleased) reference since the
  // new browser will be owned by a window controller (created later)
  //--oldimpl--
  //CTBrowser* newBrowser =
  //    [tabStripModel->delegate() createNewStripWithContents:contents];

  // New browser
  CTBrowser* newBrowser = [[browser_ class] browser];

  // Create a new window controller with the browser.
  CTBrowserWindowController* controller =
      [[[self class] alloc] initWithBrowser:newBrowser];
  
  // Add the tab to the browser (we do it here after creating the window
  // controller so that notifications are properly delegated)
  newBrowser.tabStripModel->AppendTabContents(contents, true);
  [newBrowser loadingStateDidChange:contents];

  // Set window frame
  [controller.window setFrame:windowRect display:NO];

  // Propagate the tab pinned state of the new tab (which is the only tab in
  // this new window).
  [newBrowser tabStripModel]->SetTabPinned(0, isPinned);

  // Force the added tab to the right size (remove stretching.)
  tabRect.size.height = [CTTabStripController defaultTabHeight];

  // And make sure we use the correct frame in the new view.
  [[controller tabStripController] setFrameOfSelectedTab:tabRect];
  return controller;
}


- (void)insertPlaceholderForTab:(CTTabView*)tab
                          frame:(NSRect)frame
                      yStretchiness:(CGFloat)yStretchiness {
  [super insertPlaceholderForTab:tab frame:frame yStretchiness:yStretchiness];
  [tabStripController_ insertPlaceholderForTab:tab
                                         frame:frame
                                 yStretchiness:yStretchiness];
}

- (void)removePlaceholder {
  [super removePlaceholder];
  [tabStripController_ insertPlaceholderForTab:nil
                                         frame:NSZeroRect
                                 yStretchiness:0];
}

- (BOOL)tabDraggingAllowed {
  return [tabStripController_ tabDraggingAllowed];
}

// Default implementation of the below are both YES. Until we have fullscreen
// support these will always be true.
/*- (BOOL)tabTearingAllowed {
  return ![self isFullscreen];
}
- (BOOL)windowMovementAllowed {
  return ![self isFullscreen];
}*/


// impl. CTTabWindowController requirements
- (void)setShowsNewTabButton:(BOOL)show {
  tabStripController_.showsNewTabButton = show;
}

- (BOOL)showsNewTabButton {
  return tabStripController_.showsNewTabButton;
}


// Tells the tab strip to forget about this tab in preparation for it being
// put into a different tab strip, such as during a drop on another window.
- (void)detachTabView:(NSView*)view {
  int index = [tabStripController_ modelIndexForTabView:view];
  [browser_ tabStripModel]->DetachTabContentsAt(index);
}


- (NSInteger)numberOfTabs {
  // count() includes pinned tabs (both live and phantom).
  return [browser_ tabStripModel]->count();
}


- (BOOL)hasLiveTabs {
  return [browser_ tabStripModel]->HasNonPhantomTabs();
}


- (int)selectedTabIndex {
  return [browser_ tabStripModel]->selected_index();
}


- (CTTabContents*)selectedTabContents {
  return [browser_ tabStripModel]->GetSelectedTabContents();
}


- (NSString*)selectedTabTitle {
  CTTabContents* contents = [self selectedTabContents];
  return contents ? contents.title : nil;
}


- (BOOL)hasTabStrip {
  return YES;
}


- (BOOL)useVerticalTabs {
  return NO;
}


// Called when the size of the window content area has changed.
// Position specific views.
- (void)layoutSubviews {
  // With the exception of the top tab strip, the subviews which we lay out are
  // subviews of the content view, so we mainly work in the content view's
  // coordinate system. Note, however, that the content view's coordinate system
  // and the window's base coordinate system should coincide.
  NSWindow* window = [self window];
  NSView* contentView = [window contentView];
  NSRect contentBounds = [contentView bounds];
  CGFloat minX = NSMinX(contentBounds);
  CGFloat minY = NSMinY(contentBounds);
  CGFloat width = NSWidth(contentBounds);

  // Suppress title drawing (the title is in the tab, baby)
  if ([window respondsToSelector:@selector(setShouldHideTitle:)])
    [window setShouldHideTitle:YES];

  BOOL isFullscreen = [self isFullscreen];
  //CGFloat floatingBarHeight = [self floatingBarHeight];
  // In fullscreen mode, |yOffset| accounts for the sliding position of the
  // floating bar and the extra offset needed to dodge the menu bar.
  CGFloat yOffset = 0;
  //CGFloat yOffset = isFullscreen ?
  //    (floor((1 - floatingBarShownFraction_) * floatingBarHeight) -
  //        [fullscreenController_ floatingBarVerticalOffset]) : 0;
  CGFloat maxY = NSMaxY(contentBounds) + yOffset;
  CGFloat startMaxY = maxY;

  if ([self hasTabStrip] && ![self useVerticalTabs]) {
    // If we need to lay out the top tab strip, replace |maxY| and |startMaxY|
    // with higher values, and then lay out the tab strip.
    NSRect windowFrame = [contentView convertRect:[window frame] fromView:nil];
    startMaxY = maxY = NSHeight(windowFrame) + yOffset;
    maxY = [self layoutTabStripAtMaxY:maxY width:width fullscreen:isFullscreen];
  }

  // Sanity-check |maxY|.
  DCHECK_GE(maxY, minY);
  DCHECK_LE(maxY, NSMaxY(contentBounds) + yOffset);

  // The base class already positions the side tab strip on the left side
  // of the window's content area and sizes it to take the entire vertical
  // height. All that's needed here is to push everything over to the right,
  // if necessary.
  //if ([self useVerticalTabs]) {
  //  const CGFloat sideTabWidth = [[self tabStripView] bounds].size.width;
  //  minX += sideTabWidth;
  //  width -= sideTabWidth;
  //}

  // Place the toolbar at the top of the reserved area.
  if ([self hasToolbar])
    maxY = [self layoutToolbarAtMinX:minX maxY:maxY width:width];

  // If we're not displaying the bookmark bar below the infobar, then it goes
  // immediately below the toolbar.
  //BOOL placeBookmarkBarBelowInfoBar = [self placeBookmarkBarBelowInfoBar];
  //if (!placeBookmarkBarBelowInfoBar)
  //  maxY = [self layoutBookmarkBarAtMinX:minX maxY:maxY width:width];

  // The floating bar backing view doesn't actually add any height.
  //NSRect floatingBarBackingRect =
  //    NSMakeRect(minX, maxY, width, floatingBarHeight);
  //[self layoutFloatingBarBackingView:floatingBarBackingRect
  //                        fullscreen:isFullscreen];

  // Place the find bar immediately below the toolbar/attached bookmark bar. In
  // fullscreen mode, it hangs off the top of the screen when the bar is hidden.
  // The find bar is unaffected by the side tab positioning.
  //[findBarCocoaController_ positionFindBarViewAtMaxY:maxY maxWidth:width];

  // If in fullscreen mode, reset |maxY| to top of screen, so that the floating
  // bar slides over the things which appear to be in the content area.
  if (isFullscreen)
    maxY = NSMaxY(contentBounds);

  // Also place the infobar container immediate below the toolbar, except in
  // fullscreen mode in which case it's at the top of the visual content area.
  //maxY = [self layoutInfoBarAtMinX:minX maxY:maxY width:width];

  // If the bookmark bar is detached, place it next in the visual content area.
  //if (placeBookmarkBarBelowInfoBar)
  //  maxY = [self layoutBookmarkBarAtMinX:minX maxY:maxY width:width];

  // Place the download shelf, if any, at the bottom of the view.
  //minY = [self layoutDownloadShelfAtMinX:minX minY:minY width:width];

  // Finally, the content area takes up all of the remaining space.
  NSRect contentAreaRect = NSMakeRect(minX, minY, width, maxY - minY);
  [self layoutTabContentArea:contentAreaRect];

  // Place the status bubble at the bottom of the content area.
  //verticalOffsetForStatusBubble_ = minY;

  // Normally, we don't need to tell the toolbar whether or not to show the
  // divider, but things break down during animation.
  if (toolbarController_) {
    [toolbarController_ setDividerOpacity:0.4];
  }
}


- (CGFloat)layoutToolbarAtMinX:(CGFloat)minX
                          maxY:(CGFloat)maxY
                         width:(CGFloat)width {
  assert([self hasToolbar]);
  NSView* toolbarView = [toolbarController_ view];
  NSRect toolbarFrame = [toolbarView frame];
  assert(![toolbarView isHidden]);
  toolbarFrame.origin.x = minX;
  toolbarFrame.origin.y = maxY - NSHeight(toolbarFrame);
  toolbarFrame.size.width = width;
  maxY -= NSHeight(toolbarFrame);
  [toolbarView setFrame:toolbarFrame];
  return maxY;
}


-(void)willStartTearingTab {
  if (CTTabContents* contents = [browser_ selectedTabContents]) {
    contents.isTeared = YES;
  }
}

-(void)willEndTearingTab {
  if (CTTabContents* contents = [browser_ selectedTabContents]) {
    contents.isTeared = NO;
  }
}

-(void)didEndTearingTab {
  if (CTTabContents* contents = [browser_ selectedTabContents]) {
    [contents tabDidResignTeared];
  }
}


#pragma mark -
#pragma mark Layout


- (void)layoutTabContentArea:(NSRect)newFrame {
  FastResizeView* tabContentView = self.tabContentArea;
  NSRect tabContentFrame = tabContentView.frame;
  BOOL contentShifted =
      NSMaxY(tabContentFrame) != NSMaxY(newFrame) ||
      NSMinX(tabContentFrame) != NSMinX(newFrame);
  tabContentFrame.size.height = newFrame.size.height;
  [tabContentView setFrame:tabContentFrame];
  // If the relayout shifts the content area up or down, let the renderer know.
  if (contentShifted) {
    if (CTTabContents* contents = [browser_ selectedTabContents]) {
      [contents viewFrameDidChange:newFrame];
    }
  }
}


#pragma mark -
#pragma mark Private


- (CGFloat)layoutTabStripAtMaxY:(CGFloat)maxY
                          width:(CGFloat)width
                     fullscreen:(BOOL)fullscreen {
  // Nothing to do if no tab strip.
  if (![self hasTabStrip])
    return maxY;

  NSView* tabStripView = [self tabStripView];
  CGFloat tabStripHeight = NSHeight([tabStripView frame]);
  maxY -= tabStripHeight;
  [tabStripView setFrame:NSMakeRect(0, maxY, width, tabStripHeight)];

  // Set indentation.
  [tabStripController_ setIndentForControls:(fullscreen ? 0 :
      [[tabStripController_ class] defaultIndentForControls])];

  // TODO(viettrungluu): Seems kind of bad -- shouldn't |-layoutSubviews| do
  // this? Moreover, |-layoutTabs| will try to animate....
  [tabStripController_ layoutTabs];

  // Now lay out incognito badge together with the tab strip.
  //if (incognitoBadge_.get()) {
  //  // Actually place the badge *above* |maxY|.
  //  NSPoint origin = NSMakePoint(width - NSWidth([incognitoBadge_ frame]) -
  //                                   kIncognitoBadgeOffset, maxY);
  //  [incognitoBadge_ setFrameOrigin:origin];
  //  [incognitoBadge_ setHidden:NO];  // Make sure it's shown.
  //}

  return maxY;
}


#pragma mark -
#pragma mark NSWindowController impl

- (BOOL)windowShouldClose:(id)sender {
  // Disable updates while closing all tabs to avoid flickering.
  base::ScopedNSDisableScreenUpdates disabler;

  // NOTE: when using the default BrowserWindow.xib, window bounds are saved and
  //       restored by Cocoa using NSUserDefaults key "browserWindow".

  // NOTE: orderOut: ends up activating another window, so if we save window
  //       bounds in a custom manner we have to do it here, before we call
  //       orderOut:

  if (browser_.tabStripModel->HasNonPhantomTabs()) {
    // Tab strip isn't empty.  Hide the frame (so it appears to have closed
    // immediately) and close all the tabs, allowing them to shut down. When the
    // tab strip is empty we'll be called back again.
    [[self window] orderOut:self];
    [browser_ windowDidBeginToClose];
    if (_currentMain == self)
      _currentMain = nil;
    return NO;
  }

  // the tab strip is empty, it's ok to close the window
  return YES;
}


- (void)windowWillClose:(NSNotification *)notification {
  [self autorelease];
}


// Called right after our window became the main window.
- (void)windowDidBecomeMain:(NSNotification*)notification {
  // NOTE: if you use custom window bounds saving/restoring, you should probably
  //       save the window bounds here.

  assert([NSThread isMainThread]); // since we don't lock
  _currentMain = self;

  // TODO(dmaclach): Instead of redrawing the whole window, views that care
  // about the active window state should be registering for notifications.
  [[self window] setViewsNeedDisplay:YES];

  // TODO(viettrungluu): For some reason, the above doesn't suffice.
  //if ([self isFullscreen])
  //  [floatingBarBackingView_ setNeedsDisplay:YES];  // Okay even if nil.
}

- (void)windowDidResignMain:(NSNotification*)notification {
  if (_currentMain == self) {
    assert([NSThread isMainThread]); // since we don't lock
    _currentMain = nil;
  }

  // TODO(dmaclach): Instead of redrawing the whole window, views that care
  // about the active window state should be registering for notifications.
  [[self window] setViewsNeedDisplay:YES];

  // TODO(viettrungluu): For some reason, the above doesn't suffice.
  //if ([self isFullscreen])
  //  [floatingBarBackingView_ setNeedsDisplay:YES];  // Okay even if nil.
}

// Called when we are activated (when we gain focus).
- (void)windowDidBecomeKey:(NSNotification*)notification {
  if (![[self window] isMiniaturized]) {
    if (CTTabContents* contents = [browser_ selectedTabContents]) {
      contents.isVisible = YES;
    }
  }
}

// Called when we are deactivated (when we lose focus).
- (void)windowDidResignKey:(NSNotification*)notification {
  // If our app is still active and we're still the key window, ignore this
  // message, since it just means that a menu extra (on the "system status bar")
  // was activated; we'll get another |-windowDidResignKey| if we ever really
  // lose key window status.
  if ([NSApp isActive] && ([NSApp keyWindow] == [self window]))
    return;

  // We need to deactivate the controls (in the "WebView"). To do this, get the
  // selected TabContents's RenderWidgetHostView and tell it to deactivate.
  /*if (CTTabContents* contents = [browser_ selectedTabContents]) {
    contents.isKey = NO;
  }*/
}

// Called when we have been minimized.
- (void)windowDidMiniaturize:(NSNotification *)notification {
  if (CTTabContents* contents = [browser_ selectedTabContents]) {
    contents.isVisible = NO;
  }
}

// Called when we have been unminimized.
- (void)windowDidDeminiaturize:(NSNotification *)notification {
  if (CTTabContents* contents = [browser_ selectedTabContents]) {
    contents.isVisible = YES;
  }
}

// Called when the application has been hidden.
- (void)applicationDidHide:(NSNotification *)notification {
  // Let the selected tab know (unless we are minimized, in which case nothing
  // has really changed).
  if (![[self window] isMiniaturized]) {
    if (CTTabContents* contents = [browser_ selectedTabContents]) {
      contents.isVisible = NO;
    }
  }
}

// Called when the application has been unhidden.
- (void)applicationDidUnhide:(NSNotification *)notification {
  // Let the selected tab know
  // (unless we are minimized, in which case nothing has really changed).
  if (![[self window] isMiniaturized]) {
    if (CTTabContents* contents = [browser_ selectedTabContents]) {
      contents.isVisible = YES;
    }
  }
}

// Called when the user clicks the zoom button (or selects it from the Window
// menu) to determine the "standard size" of the window, based on the content
// and other factors. If the current size/location differs nontrivally from the
// standard size, Cocoa resizes the window to the standard size, and saves the
// current size as the "user size". If the current size/location is the same (up
// to a fudge factor) as the standard size, Cocoa resizes the window to the
// saved user size. (It is possible for the two to coincide.) In this way, the
// zoom button acts as a toggle. We determine the standard size based on the
// content, but enforce a minimum width (calculated using the dimensions of the
// screen) to ensure websites with small intrinsic width (such as google.com)
// don't end up with a wee window. Moreover, we always declare the standard
// width to be at least as big as the current width, i.e., we never want zooming
// to the standard width to shrink the window. This is consistent with other
// browsers' behaviour, and is desirable in multi-tab situations. Note, however,
// that the "toggle" behaviour means that the window can still be "unzoomed" to
// the user size.
/*- (NSRect)windowWillUseStandardFrame:(NSWindow*)window
                        defaultFrame:(NSRect)frame {
  // Forget that we grew the window up (if we in fact did).
  [self resetWindowGrowthState];

  // |frame| already fills the current screen. Never touch y and height since we
  // always want to fill vertically.

  // If the shift key is down, maximize. Hopefully this should make the
  // "switchers" happy.
  if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) {
    return frame;
  }

  // To prevent strange results on portrait displays, the basic minimum zoomed
  // width is the larger of: 60% of available width, 60% of available height
  // (bounded by available width).
  const CGFloat kProportion = 0.6;
  CGFloat zoomedWidth =
      std::max(kProportion * frame.size.width,
               std::min(kProportion * frame.size.height, frame.size.width));

  TabContents* contents = browser_.tabStripModel->GetSelectedTabContents();
  if (contents) {
    // If the intrinsic width is bigger, then make it the zoomed width.
    const int kScrollbarWidth = 16;  // TODO(viettrungluu): ugh.
    TabContentsViewMac* tab_contents_view =
        static_cast<TabContentsViewMac*>(contents->view());
    CGFloat intrinsicWidth = static_cast<CGFloat>(
        tab_contents_view->preferred_width() + kScrollbarWidth);
    zoomedWidth = std::max(zoomedWidth,
                           std::min(intrinsicWidth, frame.size.width));
  }

  // Never shrink from the current size on zoom (see above).
  NSRect currentFrame = [[self window] frame];
  zoomedWidth = std::max(zoomedWidth, currentFrame.size.width);

  // |frame| determines our maximum extents. We need to set the origin of the
  // frame -- and only move it left if necessary.
  if (currentFrame.origin.x + zoomedWidth > frame.origin.x + frame.size.width)
    frame.origin.x = frame.origin.x + frame.size.width - zoomedWidth;
  else
    frame.origin.x = currentFrame.origin.x;

  // Set the width. Don't touch y or height.
  frame.size.width = zoomedWidth;

  return frame;
}*/

#pragma mark -
#pragma mark Etc (need sorting out)

- (void)activate {
  [[self window] makeKeyAndOrderFront:self];
}

- (void)focusTabContents {
  if (CTTabContents* contents = [browser_ selectedTabContents]) {
    [[self window] makeFirstResponder:contents.view];
  }
}


#pragma mark -
#pragma mark CTTabStripModelObserverBridge impl.

// Note: the following are called by the CTTabStripModel and thus indicate
// the model's state rather than the UI state. This means that when for instance
// tabSelectedWithContents:... is called, the view is not yet on screen, so
// doing things like restoring focus is not possible.

// Note: this is called _before_ the view is on screen
- (void)tabSelectedWithContents:(CTTabContents*)newContents
               previousContents:(CTTabContents*)oldContents
                        atIndex:(NSInteger)index
                    userGesture:(bool)wasUserGesture {
  assert(newContents != oldContents);
  [self updateToolbarWithContents:newContents
               shouldRestoreState:!!oldContents];
}


- (void)tabClosingWithContents:(CTTabContents*)contents
                       atIndex:(NSInteger)index {
  [contents tabWillCloseInBrowser:browser_ atIndex:index];
}


- (void)tabInsertedWithContents:(CTTabContents*)contents
                      atIndex:(NSInteger)index
                 inForeground:(bool)foreground {
  [contents tabDidInsertIntoBrowser:browser_
                            atIndex:index
                       inForeground:foreground];
}


- (void)tabReplacedWithContents:(CTTabContents*)contents
                    oldContents:(CTTabContents*)oldContents
                        atIndex:(NSInteger)index {
  [contents tabReplaced:oldContents inBrowser:browser_ atIndex:index];
  if ([self selectedTabIndex] == index) {
    [self updateToolbarWithContents:contents
                 shouldRestoreState:!!oldContents];
  }
}


- (void)tabDetachedWithContents:(CTTabContents*)contents
                        atIndex:(NSInteger)index {
  [contents tabDidDetachFromBrowser:browser_ atIndex:index];
}

/*
- (void)tabMovedWithContents:(CTTabContents*)contents
                    fromIndex:(NSInteger)from
                      toIndex:(NSInteger)to {
  DLOG_TRACE();
}
- (void)tabChangedWithContents:(CTTabContents*)contents
                       atIndex:(NSInteger)index
                    changeType:(CTTabChangeType)change {
  DLOG_TRACE();
}
- (void)tabMiniStateChangedWithContents:(CTTabContents*)contents
                                atIndex:(NSInteger)index {
  DLOG_TRACE();
}
//*/

- (void)tabStripEmpty {
  [self close];
}


@end
