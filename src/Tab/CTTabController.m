// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabController.h"
#import "CTTabControllerTarget.h"
#import "CTTabView.h"
#import "CTUtil.h"
#import "HoverCloseButton.h"

static NSString* const kBrowserThemeDidChangeNotification =
@"BrowserThemeDidChangeNotification";

@implementation CTTabController {
@private
	IBOutlet NSView* iconView_;
	IBOutlet NSTextField* titleView_;
	IBOutlet HoverCloseButton* closeButton_;
	
	NSRect originalIconFrame_;  // frame of iconView_ as loaded from nib
	BOOL isIconShowing_;  // last state of iconView_ in updateVisibility
	
	BOOL isApp_;
	BOOL isMini_;
	BOOL isPinned_;
	BOOL isActive_;
	CTTabLoadingState loadingState_;
	CGFloat iconTitleXOffset_;  // between left edges of icon and title
	CGFloat titleCloseWidthOffset_;  // between right edges of icon and close btn.
	id<CTTabControllerTarget> target_;  // weak, where actions are sent
	SEL action_;  // selector sent when tab is selected by clicking
}

@synthesize action = action_;
@synthesize isApp = isApp_;
@synthesize loadingState = loadingState_;
@synthesize isMini = isMini_;
@synthesize isPinned = isPinned_;
@synthesize target = target_;
@synthesize isActive = isActive_;

// The min widths match the windows values and are sums of left + right
// padding, of which we have no comparable constants (we draw using paths, not
// images). The active tab width includes the close button width.
+ (CGFloat)minTabWidth { return 31; }
+ (CGFloat)minActiveTabWidth { return 46; }
+ (CGFloat)maxTabWidth { return 220; }
+ (CGFloat)miniTabWidth { return 53; }
+ (CGFloat)appTabWidth { return 66; }

- (CTTabView*)tabView {
	return (CTTabView*)[self view];
}

- (id)init {
	NSBundle *bundle = [CTUtil bundleForResource:@"TabView" ofType:@"nib"];
	return [self initWithNibName:@"TabView" bundle:bundle];
}

- (id)initWithNibName:(NSString*)nibName bundle:(NSBundle*)bundle {
	self = [super initWithNibName:nibName bundle:bundle];
	assert(self);
	if (self != nil) {
		isIconShowing_ = YES;
		NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];
		[defaultCenter addObserver:self
						  selector:@selector(viewResized:)
							  name:NSViewFrameDidChangeNotification
							object:[self view]];
		[defaultCenter addObserver:self
						  selector:@selector(themeChangedNotification:)
							  name:kBrowserThemeDidChangeNotification
							object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[self tabView] setController:nil];
	//  [super dealloc];
}

// The internals of |-setActive:| but doesn't check if we're already set
// to |active|. Pass the selection change to the subviews that need it and
// mark ourselves as needing a redraw.
- (void)internalSetActive:(BOOL)active {
	isActive_ = active;
	CTTabView* tabView = (CTTabView*)[self view];
	assert([tabView isKindOfClass:[CTTabView class]]);
	[tabView setState:active];
	[tabView cancelAlert];
	[self updateVisibility];
	[self updateTitleColor];
}

// Called when the tab's nib is done loading and all outlets are hooked up.
- (void)awakeFromNib {
	// Remember the icon's frame, so that if the icon is ever removed, a new
	// one can later replace it in the proper location.
	originalIconFrame_ = [iconView_ frame];
	
	// When the icon is removed, the title expands to the left to fill the space
	// left by the icon.  When the close button is removed, the title expands to
	// the right to fill its space.  These are the amounts to expand and contract
	// titleView_ under those conditions.
	NSRect titleFrame = [titleView_ frame];
	iconTitleXOffset_ = NSMinX(titleFrame) - NSMinX(originalIconFrame_);
	titleCloseWidthOffset_ = NSMaxX([closeButton_ frame]) - NSMaxX(titleFrame);
	
	[self internalSetActive:isActive_];
}

// Called when Cocoa wants to display the context menu. Lazily instantiate
// the menu based off of the cross-platform model. Re-create the menu and
// model every time to get the correct labels and enabling.
- (NSMenu*)menu {
	/*contextMenuDelegate_.reset(
	 new TabControllerInternal::MenuDelegate(target_, self));
	 contextMenuModel_.reset(new TabMenuModel(contextMenuDelegate_.get(),
	 [self pinned]));
	 contextMenuController_.reset(
	 [[MenuController alloc] initWithModel:contextMenuModel_.get()
	 useWithPopUpButtonCell:NO]);
	 return [contextMenuController_ menu];*/
	return nil;
}

- (IBAction)closeTab:(id)sender {
	if ([[self target] respondsToSelector:@selector(closeTab:)]) {
		[[self target] performSelector:@selector(closeTab:)
							withObject:[self view]];
	}
}

- (void)setTitle:(NSString*)title {
	[[self view] setToolTip:title];
	if ([self isMini] && ![self isActive]) {
		CTTabView* tabView = (CTTabView*)[self view];
		assert([tabView isKindOfClass:[CTTabView class]]);
		[tabView startAlert];
	}
	[super setTitle:title];
}

- (void)setActive:(BOOL)active {
	if (isActive_ != active)
		[self internalSetActive:active];
}

- (void)setIconView:(NSView*)iconView {
	[iconView_ removeFromSuperview];
	iconView_ = iconView;
	if ([self isApp]) {
		NSRect appIconFrame = [iconView frame];
		appIconFrame.origin = originalIconFrame_.origin;
		// Center the icon.
		appIconFrame.origin.x = ([CTTabController appTabWidth] -
								 NSWidth(appIconFrame)) / 2.0;
		[iconView setFrame:appIconFrame];
	} else {
		[iconView_ setFrame:originalIconFrame_];
	}
	// Ensure that the icon is suppressed if no icon is set or if the tab is too
	// narrow to display one.
	[self updateVisibility];
	
	if (iconView_)
		[[self view] addSubview:iconView_];
}

- (NSView*)iconView {
	return iconView_;
}

- (NSString*)toolTip {
	return [[self view] toolTip];
}

// Return a rough approximation of the number of icons we could fit in the
// tab. We never actually do this, but it's a helpful guide for determining
// how much space we have available.
- (CGFloat)iconCapacity {
	CGFloat width = NSMaxX([closeButton_ frame]) - NSMinX(originalIconFrame_);
	CGFloat iconWidth = NSWidth(originalIconFrame_);
	
	return width / iconWidth;
}

// Returns YES if we should show the icon. When tabs get too small, we clip
// the favicon before the close button for active tabs, and prefer the
// favicon for inactive tabs.  The icon can also be suppressed more directly
// by clearing iconView_.
- (BOOL)shouldShowIcon {
	if (!iconView_)
		return NO;
	
	if ([self isMini])
		return YES;
	
	CGFloat iconCapacity = [self iconCapacity];
	if ([self isActive])
		return iconCapacity >= 2.0;
	return iconCapacity >= 1.0;
}

// Returns YES if we should be showing the close button. The active tab
// always shows the close button.
- (BOOL)shouldShowCloseButton {
	if ([self isMini])
		return NO;
	return ([self isActive] || [self iconCapacity] >= 3.0);
}

- (void)updateVisibility {
	// iconView_ may have been replaced or it may be nil, so [iconView_ isHidden]
	// won't work.  Instead, the state of the icon is tracked separately in
	// isIconShowing_.
	BOOL oldShowIcon = isIconShowing_ ? YES : NO;
	BOOL newShowIcon = [self shouldShowIcon] ? YES : NO;
	
	[iconView_ setHidden:newShowIcon ? NO : YES];
	isIconShowing_ = newShowIcon;
	
	// If the tab is a mini-tab, hide the title.
	[titleView_ setHidden:[self isMini]];
	
	BOOL oldShowCloseButton = [closeButton_ isHidden] ? NO : YES;
	BOOL newShowCloseButton = [self shouldShowCloseButton] ? YES : NO;
	
	[closeButton_ setHidden:newShowCloseButton ? NO : YES];
	
	// Adjust the title view based on changes to the icon's and close button's
	// visibility.
	NSRect titleFrame = [titleView_ frame];
	
	if (oldShowIcon != newShowIcon) {
		// Adjust the left edge of the title view according to the presence or
		// absence of the icon view.
		
		if (newShowIcon) {
			titleFrame.origin.x += iconTitleXOffset_;
			titleFrame.size.width -= iconTitleXOffset_;
		} else {
			titleFrame.origin.x -= iconTitleXOffset_;
			titleFrame.size.width += iconTitleXOffset_;
		}
	}
	
	if (oldShowCloseButton != newShowCloseButton) {
		// Adjust the right edge of the title view according to the presence or
		// absence of the close button.
		if (newShowCloseButton)
			titleFrame.size.width -= titleCloseWidthOffset_;
		else
			titleFrame.size.width += titleCloseWidthOffset_;
	}
	
	[titleView_ setFrame:titleFrame];
}

- (void)updateTitleColor {
	NSColor* titleColor = [self isActive] ? [NSColor blackColor] :
	[NSColor darkGrayColor];
	[titleView_ setTextColor:titleColor];
}

// Called when our view is resized. If it gets too small, start by hiding
// the close button and only show it if tab is active. Eventually, hide the
// icon as well. We know that this is for our view because we only registered
// for notifications from our specific view.
- (void)viewResized:(NSNotification*)info {
	[self updateVisibility];
}

- (void)themeChangedNotification:(NSNotification*)notification {
	[self updateTitleColor];
}

// Called by the tabs to determine whether we are in rapid (tab) closure mode.
- (BOOL)inRapidClosureMode {
	if ([[self target] respondsToSelector:@selector(inRapidClosureMode)]) {
		return [[self target] performSelector:@selector(inRapidClosureMode)] ?
        YES : NO;
	}
	return NO;
}

// The following methods are invoked from the TabView and are forwarded to the
// TabStripDragController.
- (BOOL)tabCanBeDragged:(CTTabController*)controller {
	return [[target_ dragController] tabCanBeDragged:controller];
}

- (void)maybeStartDrag:(NSEvent*)event forTab:(CTTabController*)tab {
	[[target_ dragController] maybeStartDrag:event forTab:tab];
}

@end
