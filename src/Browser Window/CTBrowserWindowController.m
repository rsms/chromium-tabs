#import "CTBrowser.h"
#import "CTBrowserWindow.h"
#import "CTBrowserWindowController.h"
#import "CTPresentationModeController.h"
#import "CTFloatingBarBackingView.h"

#import "CTTabContents.h"
#import "CTTabStripController.h"
#import "CTTabStripModel.h"
#import "CTTabView.h"
#import "CTTabStripView.h"
#import "CTToolbarController.h"
#import "CTUtil.h"
#import "FastResizeView.h"

//#import "scoped_nsdisable_screen_updates.h"

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

@interface CTBrowserWindowController (FullScreen)

- (void)registerForContentViewResizeNotifications;
- (void)deregisterForContentViewResizeNotifications;

// Creates the button used to toggle presentation mode.  Must only be called on
// Lion or later.  Does nothing if the button already exists.
- (void)createAndInstallPresentationModeToggleButton;

// Toggles presentation mode without exiting fullscreen mode.  Should only be
// called by the presentation mode toggle button. 
- (void)togglePresentationModeForLionOrLater:(id)sender;

// Sets presentation mode, creating the PresentationModeController if needed and
// forcing a relayout.  If |forceDropdown| is YES, this method will always
// initially show the floating bar when entering presentation mode, even if the
// floating bar does not have focus.  This method is safe to call on all OS
// versions.
- (void)setPresentationModeInternal:(BOOL)presentationMode
                      forceDropdown:(BOOL)forceDropdown;

// Allows/prevents bar visibility locks and releases from updating the visual
// state. Enabling makes changes instantaneously; disabling cancels any
// timers/animation.
- (void)enableBarVisibilityUpdates;
- (void)disableBarVisibilityUpdates;
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
@synthesize shouldUsePresentationModeWhenEnteringFullscreen = shouldUsePresentationModeWhenEnteringFullscreen_;

+ (CTBrowserWindowController*)browserWindowController {
	return [[self alloc] init];
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
	browser_ = browser;
    NSWindow* window = [self window];
	
    // Lion will attempt to automagically save and restore the UI. This
    // functionality appears to be leaky (or at least interacts badly with our
    // architecture) and thus BrowserWindowController never gets released. This
    // prevents the browser from being able to quit <http://crbug.com/79113>.
    if ([window respondsToSelector:@selector(setRestorable:)])
		[window setRestorable:NO];
	
    // Create the bar visibility lock set; 10 is arbitrary, but should hopefully
    // be big enough to hold all locks that'll ever be needed.
	barVisibilityLocks_ = [NSMutableSet setWithCapacity:10];
	
	// Note: the below statement including [self window] implicitly loads the
	// window and thus initializes IBOutlets, needed later. If [self window] is
	// not called (i.e. code removed), substitute the loading with a call to
	// [self loadWindow]
	
    // Set the window to not have rounded corners, which prevents the resize
    // control from being inset slightly and looking ugly. Only bother to do
    // this on Snow Leopard and earlier; on Lion and later all windows have
    // rounded bottom corners, and this won't work anyway.
	if ([window respondsToSelector:@selector(setBottomCornerRounded:)])
		[window setBottomCornerRounded:NO];
	[[window contentView] setAutoresizesSubviews:YES];
	
    // Lion will attempt to automagically save and restore the UI. This
    // functionality appears to be leaky (or at least interacts badly with our
    // architecture) and thus BrowserWindowController never gets released. This
    // prevents the browser from being able to quit <http://crbug.com/79113>.
    if ([window respondsToSelector:@selector(setRestorable:)])
		[window setRestorable:NO];
	
	// Note: when using the default BrowserWindow.xib, window bounds are saved and
	// restored by Cocoa using NSUserDefaults key "browserWindow".
	
    // Get the windows to swish in on Lion.
    if ([window respondsToSelector:@selector(setAnimationBehavior:)])
		[window setAnimationBehavior:NSWindowAnimationBehaviorDocumentWindow];
	
    // Set the window to participate in Lion Fullscreen mode.  Setting this flag
    // has no effect on Snow Leopard or earlier.  Panels can share a fullscreen
    // space with a tabbed window, but they can not be primary fullscreen
    // windows.
    NSUInteger collectionBehavior = [window collectionBehavior];
    collectionBehavior |= NSWindowCollectionBehaviorFullScreenPrimary;
    [window setCollectionBehavior:collectionBehavior];
	
	// Create a tab strip controller
	tabStripController_ =
	[[CTTabStripController alloc] initWithView:self.tabStripView
                                    switchView:self.tabContentArea
                                       browser:browser_];
	
	// Create a toolbar controller. The browser object might return nil, in which
	// means we do not have a toolbar.
	toolbarController_ = [browser_ createToolbarController];
	if (toolbarController_) {
		[[[self window] contentView] addSubview:[toolbarController_ view]];
	}
	
	// When using NSDocuments
	[self setShouldCloseDocument:YES];
	
    // Allow bar visibility to be changed.
    [self enableBarVisibilityUpdates];
	
	// Observe tabs	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tabDidSelect:) 
												 name:CTTabSelectedNotification 
											   object:browser_.tabStripModel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tabDidInsert:) 
												 name:CTTabInsertedNotification 
											   object:browser_.tabStripModel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tabDidReplace:) 
												 name:CTTabReplacedNotification 
											   object:browser_.tabStripModel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tabDidDetach:) 
												 name:CTTabDetachedNotification 
											   object:browser_.tabStripModel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tabWillClose:) 
												 name:CTTabClosingNotification 
											   object:browser_.tabStripModel];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tabStripDidBecomeEmpty) 
												 name:CTTabStripEmptyNotification
											   object:browser_.tabStripModel];
	
    // Register for application hide/unhide notifications.
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationDidHide:)
												 name:NSApplicationDidHideNotification
											   object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationDidUnhide:)
												 name:NSApplicationDidUnhideNotification
											   object:nil];	
	
    // Force a relayout of all the various bars.
	[self layoutSubviews];
	
	initializing_ = NO;
	if (!_currentMain) {
		//    ct_casid(&_currentMain, self);
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
		//    ct_casid(&_currentMain, nil);
		_currentMain = nil;
	}
	
	// Close all tabs
	//[browser_ closeAllTabs]; // TODO
	
	// Explicitly release |fullscreenController_| here, as it may call back to
	// this BWC in |-dealloc|.  We are required to call |-exitFullscreen| before
	// releasing the controller.
	//[fullscreenController_ exitFullscreen]; // TODO
	//fullscreenController_.reset();
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


-(void)finalize {
	if (_currentMain == self) {
		//    ct_casid(&_currentMain, nil);
		_currentMain = nil;
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super finalize];
}

- (BOOL)hasToolbar {
	return !!toolbarController_;
}


// Updates the toolbar with the states of the specified |contents|.
// If |shouldRestore| is YES, we're switching (back?) to this tab and should
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
	CTTabContents *baseTabContents = browser_.activeTabContents;
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
	[browser_ newWindow];
}

- (IBAction)closeTab:(id)sender {
	[browser_ closeTab];
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

#pragma mark -
#pragma mark Tab Management

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
			[[dragBWC->browser_ tabStripModel] tabContentsAtIndex:index];
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
		BOOL isPinned = [[dragBWC->browser_ tabStripModel] isTabPinnedAtIndex:index];
		
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


- (NSView*)activeTabView {
	return [tabStripController_ activeTabView];
}

// Creates a new window by pulling the given tab out and placing it in
// the new window. Returns the controller for the new window. The size of the
// new window will be the same size as this window.
- (CTTabWindowController*)detachTabToNewWindow:(CTTabView*)tabView {
	// Disable screen updates so that this appears as a single visual change.
	NSDisableScreenUpdates();
	@try {
		// Keep a local ref to the tab strip model object
		CTTabStripModel *tabStripModel = [browser_ tabStripModel];
		
		// Fetch the tab contents for the tab being dragged.
		int index = [tabStripController_ modelIndexForTabView:tabView];
		CTTabContents* contents = [tabStripModel tabContentsAtIndex:index];
		
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
		BOOL isPinned = [tabStripModel isTabPinnedAtIndex:index];
		
		// Detach it from the source window, which just updates the model without
		// deleting the tab contents. This needs to come before creating the new
		// CTBrowser because it clears the CTTabContents' delegate, which gets hooked
		// up during creation of the new window.
		[tabStripModel detachTabContentsAtIndex:index];
		
		// Create the new browser with a single tab in its model, the one being
		// dragged.
		CTBrowser* newBrowser = [browser_ createNewStripWithContents:contents];
		CTBrowserWindowController* controller = [newBrowser windowController];
		
		// Set window frame
		[controller.window setFrame:windowRect display:NO];
		
		// Propagate the tab pinned state of the new tab (which is the only tab in
		// this new window).
		[[newBrowser tabStripModel] setTabAtIndex:0
										   pinned:isPinned];
		
		// Force the added tab to the right size (remove stretching.)
		tabRect.size.height = [CTTabStripController defaultTabHeight];
		
		// And make sure we use the correct frame in the new view.
		[[controller tabStripController] setFrameOfActiveTab:tabRect];
		return controller;
	}
	@finally {
		NSEnableScreenUpdates();
	}
}


- (void)insertPlaceholderForTab:(CTTabView*)tab
                          frame:(NSRect)frame {
	[super insertPlaceholderForTab:tab frame:frame];
	[tabStripController_ insertPlaceholderForTab:tab
										   frame:frame];
}

- (void)removePlaceholder {
	[super removePlaceholder];
	[tabStripController_ insertPlaceholderForTab:nil
										   frame:NSZeroRect];
}

- (BOOL)tabDraggingAllowed {
	return [tabStripController_ tabDraggingAllowed];
}

// Default implementation of the below are both YES. Until we have fullscreen
// support these will always be YES.
- (BOOL)tabTearingAllowed {
	return ![self isFullscreen];
}
- (BOOL)windowMovementAllowed {
	return ![self isFullscreen];
}

- (BOOL)isTabFullyVisible:(CTTabView*)tab {
	return [tabStripController_ isTabFullyVisible:tab];
}

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
	[[browser_ tabStripModel] detachTabContentsAtIndex:index];
}


- (NSInteger)numberOfTabs {
	// count includes pinned tabs.
	return [[browser_ tabStripModel] count];
}


- (BOOL)hasLiveTabs {
	return [self numberOfTabs] > 0;
}


- (int)activeTabIndex {
	return [browser_ tabStripModel].activeIndex;
}


- (CTTabContents*)activeTabContents {
	return [[browser_ tabStripModel] activeTabContents];
}


- (NSString*)activeTabTitle {
	CTTabContents* contents = [self activeTabContents];
	return contents ? contents.title : nil;
}


- (BOOL)hasTabStrip {
	return YES;
}


-(void)willStartTearingTab {
	CTTabContents* contents = [browser_ activeTabContents];
	if (contents) {
		contents.isTeared = YES;
	}
}

-(void)willEndTearingTab {
	CTTabContents* contents = [browser_ activeTabContents];
	if (contents) {
		contents.isTeared = NO;
	}
}

-(void)didEndTearingTab {
	CTTabContents* contents = [browser_ activeTabContents];
	if (contents) {
		[contents tabDidResignTeared];
	}
}

- (void)focusTabContents {
	CTTabContents* contents = [browser_ activeTabContents];
	if (contents) {
		[[self window] makeFirstResponder:contents.view];
	}
}

#pragma mark -
#pragma mark Layout

// Find the total height of the floating bar (in presentation mode). Safe to
// call even when not in presentation mode.
- (CGFloat)floatingBarHeight {
	if (![self inPresentationMode])
		return 0;
	
	CGFloat totalHeight = [presentationModeController_ floatingBarVerticalOffset];
	
	if ([self hasTabStrip])
		totalHeight += NSHeight([[self tabStripView] frame]);
	
	if ([self hasToolbar]) {
		totalHeight += NSHeight([[toolbarController_ view] frame]);
	}
	
	return totalHeight;
}

// Lay out the view which draws the background for the floating bar when in
// presentation mode, with the given frame and presentation-mode-status. Should
// be called even when not in presentation mode to hide the backing view.
- (void)layoutFloatingBarBackingView:(NSRect)frame
                    presentationMode:(BOOL)presentationMode {
	// Only display when in presentation mode.
	if (presentationMode) {
		// For certain window types such as app windows (e.g., the dev tools
		// window), there's no actual overlay. (Displaying one would result in an
		// overly sliding in only under the menu, which gives an ugly effect.)
		if (floatingBarBackingView_) {
//			BOOL aboveBookmarkBar = [self placeBookmarkBarBelowInfoBar];
//			
//			// Insert it into the view hierarchy if necessary.
			if (![floatingBarBackingView_ superview]) {
				NSView* contentView = [[self window] contentView];
				// z-order gets messed up unless we explicitly remove the floatingbar
				// view and re-add it.
				[floatingBarBackingView_ removeFromSuperview];
				[contentView addSubview:floatingBarBackingView_
							 positioned:NSWindowBelow
							 relativeTo:[toolbarController_ view]];
//				floatingBarAboveBookmarkBar_ = aboveBookmarkBar;
			}
			
			// Set its frame.
			[floatingBarBackingView_ setFrame:frame];
		}
		
		// But we want the logic to work as usual (for show/hide/etc. purposes).
		[presentationModeController_ overlayFrameChanged:frame];
	} else {
		// Okay to call even if |floatingBarBackingView_| is nil.
		if ([floatingBarBackingView_ superview])
			[floatingBarBackingView_ removeFromSuperview];
	}
}

- (void)layoutTabContentArea:(NSRect)newFrame {
	NSView* tabContentView = self.tabContentArea;
	NSRect tabContentFrame = tabContentView.frame;
	BOOL contentShifted =
		NSMaxY(tabContentFrame) != NSMaxY(newFrame) ||
		NSMinX(tabContentFrame) != NSMinX(newFrame);
	tabContentFrame = newFrame;
	[tabContentView setFrame:tabContentFrame];
	// If the relayout shifts the content area up or down, let the renderer know.
	if (contentShifted) {
		CTTabContents* contents = [browser_ activeTabContents];
		if (contents) {
			[contents viewFrameDidChange:newFrame];
		}
	}
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
	
	BOOL inPresentationMode = [self inPresentationMode];
	CGFloat floatingBarHeight = [self floatingBarHeight];
	// In presentation mode, |yOffset| accounts for the sliding position of the
	// floating bar and the extra offset needed to dodge the menu bar.
	CGFloat yOffset = inPresentationMode ?
		(floor((1 - floatingBarShownFraction_) * floatingBarHeight) -
		 [presentationModeController_ floatingBarVerticalOffset]) : 0;
	CGFloat maxY = NSMaxY(contentBounds) + yOffset;
	
	CGFloat overlayMaxY = NSMaxY([window frame]) + floor((1 - floatingBarShownFraction_) * floatingBarHeight);
	[self layoutPresentationModeToggleAtOverlayMaxX:NSMaxX([window frame])
										overlayMaxY:overlayMaxY];
	
	if ([self hasTabStrip]) {
		// If we need to lay out the top tab strip, replace |maxY| and |startMaxY|
		// with higher values, and then lay out the tab strip.
		NSRect windowFrame = [contentView convertRect:[window frame] fromView:nil];
		maxY = NSHeight(windowFrame) + yOffset;
		maxY = [self layoutTabStripAtMaxY:maxY 
									width:width 
							   fullscreen:[self isFullscreen]];
	}
	
	// Sanity-check |maxY|.
	DCHECK_GE(maxY, minY);
	DCHECK_LE(maxY, NSMaxY(contentBounds) + yOffset);
	
	// Place the toolbar at the top of the reserved area.
	if ([self hasToolbar])
		maxY = [self layoutToolbarAtMinX:minX maxY:maxY width:width];
	
	// The floating bar backing view doesn't actually add any height.
	NSRect floatingBarBackingRect =	NSMakeRect(minX, maxY, width, floatingBarHeight);
	[self layoutFloatingBarBackingView:floatingBarBackingRect
					  presentationMode:inPresentationMode];
	
	// If in presentation mode, reset |maxY| to top of screen, so that the
	// floating bar slides over the things which appear to be in the content area.
	if (inPresentationMode)
		maxY = NSMaxY(contentBounds);
	
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
	// TODO: check this	
//	[toolbarController_
//	 setDividerOpacity:[bookmarkBarController_ toolbarDividerOpacity]];
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

- (void)layoutTabs {
	[tabStripController_ layoutTabs];
}

- (void)layoutPresentationModeToggleAtOverlayMaxX:(CGFloat)maxX
                                      overlayMaxY:(CGFloat)maxY {
	// Lay out the presentation mode toggle button at the very top of the
	// tab strip.
	if ([self shouldShowPresentationModeToggle]) {
		[self createAndInstallPresentationModeToggleButton];
		
		NSPoint origin =
        NSMakePoint(maxX - NSWidth([presentationModeToggleButton_ frame]),
                    maxY - NSHeight([presentationModeToggleButton_ frame]));
		[presentationModeToggleButton_ setFrameOrigin:origin];
	} else {
		[presentationModeToggleButton_ removeFromSuperview];
		presentationModeToggleButton_ = nil;
	}
}

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
	
	[tabStripController_ layoutTabsWithoutAnimation];
	
	return maxY;
}

#pragma mark -
#pragma mark NSWindowController impl

- (BOOL)windowShouldClose:(id)sender {
	// Disable updates while closing all tabs to avoid flickering.
	NSDisableScreenUpdates();
	@try {
		// NOTE: when using the default BrowserWindow.xib, window bounds are saved and
		//       restored by Cocoa using NSUserDefaults key "browserWindow".
		
		// NOTE: orderOut: ends up activating another window, so if we save window
		//       bounds in a custom manner we have to do it here, before we call
		//       orderOut:
		
		if ([browser_.tabStripModel count] > 0) {
			// Tab strip isn't empty.  Hide the frame (so it appears to have closed
			// immediately) and close all the tabs, allowing them to shut down. When the
			// tab strip is empty we'll be called back again.
			[[self window] orderOut:self];
			[browser_ windowDidBeginToClose];
			if (_currentMain == self) {
				//      ct_casid(&_currentMain, nil);
				_currentMain = nil;
			}
			return NO;
		}
		
		// the tab strip is empty, it's ok to close the window
		return YES;
	}
	@finally {
		NSEnableScreenUpdates();
	}
}


- (void)windowWillClose:(NSNotification *)notification {
	//  [self autorelease];
}


// Called right after our window became the main window.
- (void)windowDidBecomeMain:(NSNotification*)notification {
	// NOTE: if you use custom window bounds saving/restoring, you should probably
	//       save the window bounds here.

	_currentMain = self;
	
	// TODO(dmaclach): Instead of redrawing the whole window, views that care
	// about the active window state should be registering for notifications.
	[[self window] setViewsNeedDisplay:YES];
	
	// TODO(viettrungluu): For some reason, the above doesn't suffice.
	if ([self isFullscreen])
		[floatingBarBackingView_ setNeedsDisplay:YES];  // Okay even if nil.
}

- (void)windowDidResignMain:(NSNotification*)notification {
	if (_currentMain == self) {
		_currentMain = nil;
	}
	
	// TODO(dmaclach): Instead of redrawing the whole window, views that care
	// about the active window state should be registering for notifications.
	[[self window] setViewsNeedDisplay:YES];
	
	// TODO(viettrungluu): For some reason, the above doesn't suffice.
	if ([self isFullscreen])
		[floatingBarBackingView_ setNeedsDisplay:YES];  // Okay even if nil.
}

// Called when we are activated (when we gain focus).
- (void)windowDidBecomeKey:(NSNotification*)notification {
	if (![[self window] isMiniaturized]) {
		CTTabContents* contents = [browser_ activeTabContents];
		if (contents) {
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
}

// Called when we have been minimized.
- (void)windowDidMiniaturize:(NSNotification *)notification {
	CTTabContents* contents = [browser_ activeTabContents];
	if (contents) {
		contents.isVisible = NO;
	}
}

// Called when we have been unminimized.
- (void)windowDidDeminiaturize:(NSNotification *)notification {
	CTTabContents* contents = [browser_ activeTabContents];
	if (contents) {
		contents.isVisible = YES;
	}
}

// Called when the application has been hidden.
- (void)applicationDidHide:(NSNotification *)notification {
	// Let the active tab know (unless we are minimized, in which case nothing
	// has really changed).
	if (![[self window] isMiniaturized]) {
		CTTabContents* contents = [browser_ activeTabContents];
		if (contents) {
			contents.isVisible = NO;
		}
	}
}

// Called when the application has been unhidden.
- (void)applicationDidUnhide:(NSNotification *)notification {
	// Let the active tab know
	// (unless we are minimized, in which case nothing has really changed).
	if (![[self window] isMiniaturized]) {
		CTTabContents* contents = [browser_ activeTabContents];
		if (contents) {
			contents.isVisible = YES;
		}
	}
}

#pragma mark -
#pragma mark Etc (need sorting out)

- (void)activate {
	[[self window] makeKeyAndOrderFront:self];
}


#pragma mark -
#pragma mark CTTabStripModel Observer

// Note: the following are called by the CTTabStripModel and thus indicate
// the model's state rather than the UI state. This means that when for instance
// tabSelectedWithContents:... is called, the view is not yet on screen, so
// doing things like restoring focus is not possible.

// Note: this is called _before_ the view is on screen
- (void)tabDidSelect:(NSNotification *)notification {
	NSDictionary *userInfo = notification.userInfo;
	CTTabContents *newContents = [userInfo valueForKey:CTTabNewContentsUserInfoKey];
	CTTabContents *oldContents = [userInfo valueForKey:CTTabContentsUserInfoKey];
	assert(newContents != oldContents);
	[self updateToolbarWithContents:newContents
				 shouldRestoreState:!!oldContents];
}

- (void)tabWillClose:(NSNotification *)notification {
	NSDictionary *userInfo = notification.userInfo;
	CTTabContents *contents = [userInfo valueForKey:CTTabContentsUserInfoKey];
	NSInteger index = [[userInfo valueForKey:CTTabIndexUserInfoKey] intValue];
	[contents tabWillCloseInBrowser:browser_ atIndex:index];
	if (contents.isActive)
		[self updateToolbarWithContents:nil shouldRestoreState:NO];
}

- (void)tabDidInsert:(NSNotification *)notification {
	NSDictionary *userInfo = notification.userInfo;
	CTTabContents *contents = [userInfo valueForKey:CTTabContentsUserInfoKey];
	NSInteger index = [[userInfo valueForKey:CTTabIndexUserInfoKey] intValue];
	BOOL isInForeground = [[userInfo valueForKey:CTTabOptionsUserInfoKey] boolValue];
	[contents tabDidInsertIntoBrowser:browser_
							  atIndex:index
						 inForeground:isInForeground];
}

- (void)tabDidReplace:(NSNotification *)notification {
	NSDictionary *userInfo = notification.userInfo;
	CTTabContents *newContents = [userInfo valueForKey:CTTabNewContentsUserInfoKey];
	CTTabContents *oldContents = [userInfo valueForKey:CTTabContentsUserInfoKey];
	NSInteger index = [[userInfo valueForKey:CTTabIndexUserInfoKey] intValue];
	[newContents tabReplaced:oldContents inBrowser:browser_ atIndex:index];
	if ([self activeTabIndex] == index) {
		[self updateToolbarWithContents:newContents
					 shouldRestoreState:!!oldContents];
	}
}

- (void)tabDidDetach:(NSNotification *)notification {
	NSDictionary *userInfo = notification.userInfo;
	CTTabContents *contents = [userInfo valueForKey:CTTabContentsUserInfoKey];
	NSInteger index = [[userInfo valueForKey:CTTabIndexUserInfoKey] intValue];
	[contents tabDidDetachFromBrowser:browser_ atIndex:index];
	if (contents.isActive)
		[self updateToolbarWithContents:nil shouldRestoreState:NO];
}

- (void)tabStripDidBecomeEmpty {
	[self close];
}
@end

#pragma mark -

@implementation CTBrowserWindowController (FullScreen)
#pragma mark Full Screen Mode
- (void)contentViewDidResize:(NSNotification*)notification {
	[self layoutSubviews];
}

// Register or deregister for content view resize notifications.  These
// notifications are used while transitioning to fullscreen mode in Lion or
// later.  This method is safe to call on all OS versions.
- (void)registerForContentViewResizeNotifications {
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contentViewDidResize:)
												 name:NSViewFrameDidChangeNotification
											   object:[[self window] contentView]];
}

- (void)deregisterForContentViewResizeNotifications {
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:NSViewFrameDidChangeNotification
												  object:[[self window] contentView]];
}

// On Lion, this method is called by either the Lion fullscreen button or the
// "Enter Full Screen" menu item.  On Snow Leopard, this function is never
// called by the UI directly, but it provides the implementation for
// |-setPresentationMode:|.
- (void)setFullscreen:(BOOL)fullscreen {
	if (fullscreen == [self isFullscreen])
		return;
	
	enteredPresentationModeFromFullscreen_ = YES;
	[self.window toggleFullScreen:nil];
}

- (BOOL)isFullscreen {
	return ([[self window] styleMask] & NSFullScreenWindowMask) || enteringFullscreen_;
}


- (void)windowWillEnterFullScreen:(NSNotification*)notification {
	[self registerForContentViewResizeNotifications];
	
//	NSWindow* window = [self window];
//	savedRegularWindowFrame_ = [window frame];
	BOOL mode = [self shouldUsePresentationModeWhenEnteringFullscreen];
//	mode = mode || browser_->IsFullscreenForTabOrPending();
	enteringFullscreen_ = YES;
	[self setPresentationModeInternal:mode forceDropdown:NO];
}

- (void)windowDidEnterFullScreen:(NSNotification*)notification {
	[self deregisterForContentViewResizeNotifications];
	enteringFullscreen_ = NO;
}

- (void)windowWillExitFullScreen:(NSNotification*)notification {
	[self registerForContentViewResizeNotifications];
	[self setPresentationModeInternal:NO forceDropdown:NO];
}

- (void)windowDidExitFullScreen:(NSNotification*)notification {
	[self deregisterForContentViewResizeNotifications];
}

- (void)windowDidFailToEnterFullScreen:(NSWindow*)window {
	[self deregisterForContentViewResizeNotifications];
	enteringFullscreen_ = NO;
	[self setPresentationModeInternal:NO forceDropdown:NO];
	
	// Force a relayout to try and get the window back into a reasonable state.
	[self layoutSubviews];
}

- (void)windowDidFailToExitFullScreen:(NSWindow*)window {
	[self deregisterForContentViewResizeNotifications];
	
	// Force a relayout to try and get the window back into a reasonable state.
	[self layoutSubviews];
}

#pragma mark -
#pragma mark Presentation Mode
- (BOOL)shouldShowPresentationModeToggle {
	return [self isFullscreen];
}

- (void)createAndInstallPresentationModeToggleButton {
	if (presentationModeToggleButton_)
		return;
	
	// TODO(rohitrao): Make this button prettier.
	presentationModeToggleButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 25, 25)];
	[presentationModeToggleButton_ setButtonType:NSMomentaryLightButton];
	[presentationModeToggleButton_ setBezelStyle:NSRegularSquareBezelStyle];
	[presentationModeToggleButton_ setBordered:NO];
	[[presentationModeToggleButton_ cell] setHighlightsBy:NSContentsCellMask];
	[[presentationModeToggleButton_ cell] setShowsStateBy:NSContentsCellMask];
	[presentationModeToggleButton_ setImage:[NSImage imageNamed:NSImageNameIChatTheaterTemplate]];
	[presentationModeToggleButton_ setTarget:self];
	[presentationModeToggleButton_ setAction:@selector(togglePresentationModeForLionOrLater:)];
	[[[[self window] contentView] superview] addSubview:presentationModeToggleButton_];
}

- (void)togglePresentationModeForLionOrLater:(id)sender {
	// Called only by the presentation mode toggle button.
	enteredPresentationModeFromFullscreen_ = YES;
//	browser_->ExecuteCommand(IDC_PRESENTATION_MODE);

	if ([self inPresentationMode])
		[self exitPresentationMode];
	else
		[self enterPresentationMode];
//	TODO: Post notification on WindowFullscreenStateChanged
}

// Adjust the UI when entering or leaving presentation mode.  This method is
// safe to call on all OS versions.
- (void)adjustUIForPresentationMode:(BOOL)fullscreen {
	// Create the floating bar backing view if necessary.
	if (fullscreen && !floatingBarBackingView_ &&
		([self hasTabStrip] || [self hasToolbar])) {
		floatingBarBackingView_ = [[CTFloatingBarBackingView alloc] initWithFrame:NSZeroRect];
		[floatingBarBackingView_ setAutoresizingMask:(NSViewWidthSizable |
													  NSViewMinYMargin)];
	}
}

- (BOOL)isBarVisibilityLockedForOwner:(id)owner {
	DCHECK(owner);
	DCHECK(barVisibilityLocks_);
	return [barVisibilityLocks_ containsObject:owner];
}

- (void)enableBarVisibilityUpdates {
	// Early escape if there's nothing to do.
	if (barVisibilityUpdatesEnabled_)
		return;
	
	barVisibilityUpdatesEnabled_ = YES;
	
	if ([barVisibilityLocks_ count])
		[presentationModeController_ ensureOverlayShownWithAnimation:NO delay:NO];
	else
		[presentationModeController_ ensureOverlayHiddenWithAnimation:NO delay:NO];
}

- (void)disableBarVisibilityUpdates {
	// Early escape if there's nothing to do.
	if (!barVisibilityUpdatesEnabled_)
		return;
	
	barVisibilityUpdatesEnabled_ = NO;
	[presentationModeController_ cancelAnimationAndTimers];
}

- (void)lockBarVisibilityForOwner:(id)owner
                    withAnimation:(BOOL)animate
                            delay:(BOOL)delay {
	if (![self isBarVisibilityLockedForOwner:owner]) {
		[barVisibilityLocks_ addObject:owner];
		
		// If enabled, show the overlay if necessary (and if in presentation mode).
		if (barVisibilityUpdatesEnabled_) {
			[presentationModeController_ ensureOverlayShownWithAnimation:animate
																   delay:delay];
		}
	}
}

- (void)releaseBarVisibilityForOwner:(id)owner
                       withAnimation:(BOOL)animate
                               delay:(BOOL)delay {
	if ([self isBarVisibilityLockedForOwner:owner]) {
		[barVisibilityLocks_ removeObject:owner];
		
		// If enabled, hide the overlay if necessary (and if in presentation mode).
		if (barVisibilityUpdatesEnabled_ &&
			![barVisibilityLocks_ count]) {
			[presentationModeController_ ensureOverlayHiddenWithAnimation:animate
																	delay:delay];
		}
	}
}

// On Lion, this function is called by either the presentation mode toggle
// button or the "Enter Presentation Mode" menu item.  In the latter case, this
// function also triggers the Lion machinery to enter fullscreen mode as well as
// set presentation mode.  On Snow Leopard, this function is called by the
// "Enter Presentation Mode" menu item, and triggering presentation mode always
// moves the user into fullscreen mode.
- (void)setPresentationMode:(BOOL)presentationMode {
	if (presentationMode) {
		BOOL fullscreen = [self isFullscreen];
		
		[self setShouldUsePresentationModeWhenEnteringFullscreen:YES];
		enteredPresentationModeFromFullscreen_ = fullscreen;
		
		if (fullscreen) {
			// If already in fullscreen mode, just toggle the presentation mode
			// setting.  Go through an elaborate dance to force the overlay to show,
			// then animate out once the mouse moves away.  This helps draw attention
			// to the fact that the UI is in an overlay.  Focus the tab contents
			// because the omnibox is the most likely source of bar visibility locks,
			// and taking focus away from the omnibox releases its lock.
			[self lockBarVisibilityForOwner:self withAnimation:NO delay:NO];
			[self focusTabContents];
			[self setPresentationModeInternal:YES forceDropdown:YES];
			[self releaseBarVisibilityForOwner:self withAnimation:YES delay:YES];
		} else {
			// If not in fullscreen mode, trigger the Lion fullscreen mode machinery.
			// Presentation mode will automatically be enabled in
			// |-windowWillEnterFullScreen:|.
//			NSWindow* window = [self window];
//			if ([window isKindOfClass:[CTBrowser class]])
//				[static_cast<FramedBrowserWindow*>(window) toggleSystemFullScreen];
			[[self window] toggleFullScreen:nil];
		}
	} else {
		if (enteredPresentationModeFromFullscreen_) {
			// The window is currently in fullscreen mode, but the user is choosing to
			// turn presentation mode off (choosing to always show the UI).  Set the
			// preference to ensure that presentation mode will stay off for the next
			// window that goes fullscreen.
			[self setShouldUsePresentationModeWhenEnteringFullscreen:NO];
			[self setPresentationModeInternal:NO forceDropdown:NO];
		} else {
			// The user entered presentation mode directly from non-fullscreen mode
			// using the "Enter Presentation Mode" menu item and is using that same
			// menu item to exit presentation mode.  In this case, exit fullscreen
			// mode as well (using the Lion machinery).
//			NSWindow* window = [self window];
//			if ([window isKindOfClass:[FramedBrowserWindow class]])
//				[static_cast<FramedBrowserWindow*>(window) toggleSystemFullScreen];
			[[self window] toggleFullScreen:nil];
		}
	}
}

- (void)setPresentationModeInternal:(BOOL)presentationMode
                      forceDropdown:(BOOL)forceDropdown {
	if (presentationMode == [self inPresentationMode])
		return;
	
	if (presentationMode) {
//		BOOL showDropdown = forceDropdown || [self floatingBarHasFocus];
		BOOL showDropdown = forceDropdown;
		NSView* contentView = [[self window] contentView];
		presentationModeController_ = [[CTPresentationModeController alloc] 
									   initWithBrowserController:self];
		[presentationModeController_ enterPresentationModeForContentView:contentView
															showDropdown:showDropdown];
	} else {
		[presentationModeController_ exitPresentationMode];
		presentationModeController_ = nil;
	}
	
	[self adjustUIForPresentationMode:presentationMode];
	[self layoutSubviews];
}

- (void)enterPresentationMode {
	[self setPresentationMode:YES];
}

- (void)exitPresentationMode {
	[self setPresentationMode:NO];
}

- (BOOL)inPresentationMode {
	return presentationModeController_ && [presentationModeController_ inPresentationMode];
}

- (CGFloat)floatingBarShownFraction {
	return floatingBarShownFraction_;
}

- (void)setFloatingBarShownFraction:(CGFloat)fraction {
	floatingBarShownFraction_ = fraction;
	[self layoutSubviews];
}
@end
