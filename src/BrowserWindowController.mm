#import "BrowserWindowController.h"

#import "chrome/browser/tabs/tab_strip_model.h"

#import "chrome/browser/cocoa/tab_strip_controller.h"
#import "chrome/browser/cocoa/tab_strip_model_observer_bridge.h"
#import "chrome/browser/cocoa/tab_view.h"
#import "chrome/browser/cocoa/tab_strip_view.h"
#import "chrome/browser/cocoa/fast_resize_view.h"

#import "base/scoped_nsdisable_screen_updates.h"


@interface NSWindow (ThingsThatMightBeImplemented)
-(void)setShouldHideTitle:(BOOL)y;
-(void)setBottomCornerRounded:(BOOL)y;
@end

@interface BrowserWindowController (Private)
- (CGFloat)layoutTabStripAtMaxY:(CGFloat)maxY
                          width:(CGFloat)width
                     fullscreen:(BOOL)fullscreen;
@end

@implementation BrowserWindowController

@synthesize tabStripController = tabStripController_;
@synthesize browser = browser_;


// Load the browser window nib and do initialization. Note that the nib also
// sets this controller up as the window's delegate.
- (id)initWithWindowNibPath:(NSString *)windowNibPath
                    browser:(CTBrowser*)browser {
  if (!(self = [super initWithWindowNibPath:windowNibPath owner:self]))
    return nil;

  // Set initialization boolean state so subroutines can act accordingly
  initializing_ = YES;

  // Keep a reference to the browser
  browser_ = [browser retain];

  // Observe tabs
  tabStripObserver_ = 
      new TabStripModelObserverBridge([browser_ tabStripModel], self);

  // Note: the below statement including [self window] implicitly loads the
  // window and thus initializes IBOutlets, needed later. If [self window] is
  // not called (i.e. code removed), substitute the loading with a call to
  // [self loadWindow]

  // Sets the window to not have rounded corners, which prevents the resize
  // control from being inset slightly and looking ugly.
  NSWindow *window = [self window];
  if ([window respondsToSelector:@selector(setBottomCornerRounded:)]) {
    [window setBottomCornerRounded:NO];
  }
  [[window contentView] setAutoresizesSubviews:YES];

  // Create a tab strip controller
  tabStripController_ =
      [[TabStripController alloc] initWithView:self.tabStripView
                                    switchView:self.tabContentArea
                                       browser:browser_];

  initializing_ = NO;
  return self;
}


-(void)dealloc {
  DLOG("dealloc window controller");
  // Close all tabs
  //[browser_ closeAllTabs]; // TODO

  // Explicitly release |fullscreenController_| here, as it may call back to
  // this BWC in |-dealloc|.  We are required to call |-exitFullscreen| before
  // releasing the controller.
  //[fullscreenController_ exitFullscreen]; // TODO
  //fullscreenController_.reset();

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [browser_ release];
  delete tabStripObserver_;
  [super dealloc];
}


- (BOOL)isFullscreen {
  return NO; // TODO fullscreen capabilities
}


#pragma mark -
#pragma mark Actions


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
  BrowserWindowController* targetController = self;
  if ([sender respondsToSelector:@selector(window)])
    targetController = [[sender window] windowController];
  assert([targetController isKindOfClass:[BrowserWindowController class]]);
  [targetController.browser executeCommand:[sender tag]];
}


-(IBAction)closeTab:(id)sender {
  TabStripModel *tabStripModel = browser_.tabStripModel;
  //tabStripModel->CloseAllTabs();
  tabStripModel->CloseTabContentsAt(tabStripModel->selected_index(),
                                    TabStripModel::CLOSE_CREATE_HISTORICAL_TAB);
}


#pragma mark -
#pragma mark TabWindowController implementation

// Accept tabs from a BrowserWindowController with the same Profile.
- (BOOL)canReceiveFrom:(TabWindowController*)source {
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
     fromController:(TabWindowController*)dragController {
  if (dragController) {
    // Moving between windows. Figure out the TabContents to drop into our tab
    // model from the source window's model.
    BOOL isBrowser =
        [dragController isKindOfClass:[BrowserWindowController class]];
    assert(isBrowser);
    if (!isBrowser) return;
    BrowserWindowController* dragBWC = (BrowserWindowController*)dragController;
    int index = [dragBWC->tabStripController_ modelIndexForTabView:view];
    TabContents* contents =
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
    // window as this will remove the TabContents' delegate.
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
- (TabWindowController*)detachTabToNewWindow:(TabView*)tabView {
  // Disable screen updates so that this appears as a single visual change.
  base::ScopedNSDisableScreenUpdates disabler;

  // Keep a local ref to the tab strip model object
  TabStripModel *tabStripModel = [browser_ tabStripModel];

  // Fetch the tab contents for the tab being dragged.
  int index = [tabStripController_ modelIndexForTabView:tabView];
  TabContents* contents = tabStripModel->GetTabContentsAt(index);

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
  // CTBrowser because it clears the TabContents' delegate, which gets hooked
  // up during creation of the new window.
  tabStripModel->DetachTabContentsAt(index);

  // Create the new window with a single tab in its model, the one being
  // dragged.
  //DockInfo dockInfo;
  CTBrowser* newBrowser =
      [tabStripModel->delegate() createNewStripWithContents:contents
                                               windowBounds:windowRect
                                                   maximize:false];
  //CreateNewStripWithContents(contents, windowRect, dockInfo, false);

  // Propagate the tab pinned state of the new tab (which is the only tab in
  // this new window).
  [newBrowser tabStripModel]->SetTabPinned(0, isPinned);

  // Get the new controller by asking the new window for its delegate.
  BrowserWindowController* controller =
      reinterpret_cast<BrowserWindowController*>([newBrowser.window delegate]);
  assert(controller && [controller isKindOfClass:[TabWindowController class]]);

  // Force the added tab to the right size (remove stretching.)
  tabRect.size.height = [TabStripController defaultTabHeight];

  // And make sure we use the correct frame in the new view.
  [[controller tabStripController] setFrameOfSelectedTab:tabRect];
  return controller;
}


- (void)insertPlaceholderForTab:(TabView*)tab
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


- (void)showNewTabButton:(BOOL)show {
  [tabStripController_ showNewTabButton:show];
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


- (NSString*)selectedTabTitle {
  TabContents* contents = [browser_ tabStripModel]->GetSelectedTabContents();
  return contents.title;
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
  //maxY = [self layoutToolbarAtMinX:minX maxY:maxY width:width];

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
  //[toolbarController_
  //    setDividerOpacity:[bookmarkBarController_ toolbarDividerOpacity]];
}


#pragma mark -
#pragma mark Layout


- (void)layoutTabContentArea:(NSRect)newFrame {
  NSView* tabContentView = [self tabContentArea];
  NSRect tabContentFrame = [tabContentView frame];

  bool contentShifted =
      NSMaxY(tabContentFrame) != NSMaxY(newFrame) ||
      NSMinX(tabContentFrame) != NSMinX(newFrame);

  tabContentFrame = newFrame;
  [tabContentView setFrame:tabContentFrame];

  // If the relayout shifts the content area up or down, let the renderer know.
  if (contentShifted) {
    if (TabContents* contents = [browser_ selectedTabContents]) {
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

  if (browser_.tabStripModel->HasNonPhantomTabs()) {
    // Tab strip isn't empty.  Hide the frame (so it appears to have closed
    // immediately) and close all the tabs, allowing them to shut down. When the
    // tab strip is empty we'll be called back again.
    [[self window] orderOut:self];
    [browser_ windowDidBeginToClose];
    return NO;
  }

  // the tab strip is empty, it's ok to close the window
  return YES;
}


#pragma mark -
#pragma mark Etc (need sorting out)

- (void)focusTabContents {
  [[self window] makeFirstResponder:[tabStripController_ selectedTabView]];
}


#pragma mark -
#pragma mark TabStripModelObserverBridge impl.


/*- (void)insertTabWithContents:(TabContents*)contents
                      atIndex:(NSInteger)index
                 inForeground:(bool)inForeground;
- (void)tabClosingWithContents:(TabContents*)contents
                       atIndex:(NSInteger)index;
- (void)tabDetachedWithContents:(TabContents*)contents
                        atIndex:(NSInteger)index;
- (void)selectTabWithContents:(TabContents*)newContents
             previousContents:(TabContents*)oldContents
                      atIndex:(NSInteger)index
                  userGesture:(bool)wasUserGesture;
- (void)tabMovedWithContents:(TabContents*)contents
                    fromIndex:(NSInteger)from
                      toIndex:(NSInteger)to;
- (void)tabChangedWithContents:(TabContents*)contents
                       atIndex:(NSInteger)index
                    changeType:(TabChangeType)change;
- (void)tabMiniStateChangedWithContents:(TabContents*)contents
                                atIndex:(NSInteger)index;*/

- (void)tabStripEmpty {
  [browser_ closeWindow];
}


@end
