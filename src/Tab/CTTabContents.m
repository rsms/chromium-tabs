#import "CTTabContents.h"
#import "CTTabStripModel.h"
#import "CTBrowser.h"
//#import "KVOChangeScope.hh"

NSString *const CTTabContentsDidCloseNotification = @"CTTabContentsDidCloseNotification";

@implementation CTTabContents

// Custom @synthesize which invokes [browser_ updateTabStateForContent:self]
// when setting values.
#define _synthRetain(T, setname, getname) \
- (T)getname { return getname##_; } \
- (void)set##setname :(T)v { \
  getname##_ = v; \
  if (browser_) [browser_ updateTabStateForContent:self]; \
}
#define _synthAssign(T, setname, getname) \
- (T)getname { return getname##_; } \
- (void)set##setname :(T)v { \
  getname##_ = v; \
  if (browser_) [browser_ updateTabStateForContent:self]; \
}

// changing any of these implies [browser_ updateTabStateForContent:self]

_synthAssign(BOOL, IsLoading, isLoading);
_synthAssign(BOOL, IsWaitingForResponse, isWaitingForResponse);
_synthAssign(BOOL, IsCrashed, isCrashed);

_synthRetain(NSString*, Title, title);
_synthRetain(NSImage*, Icon, icon);

//@synthesize isLoading = isLoading_;
//@synthesize isWaitingForResponse = isWaitingForResponse_;
//@synthesize isCrashed = isCrashed_;
//@synthesize title = title_;
//@synthesize icon = icon_;

@synthesize delegate = delegate_;
@synthesize closedByUserGesture = closedByUserGesture_;
@synthesize view = view_;
@synthesize browser = browser_;
@synthesize isApp = isApp_;
@synthesize isActive = isActive_;
@synthesize isTeared = isTeared_;
@synthesize isVisible = isVisible_;

#undef _synth


// KVO support
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString*)key {
  if ([key isEqualToString:@"isLoading"] ||
      [key isEqualToString:@"isWaitingForResponse"] ||
      [key isEqualToString:@"isCrashed"] ||
      [key isEqualToString:@"isVisible"] ||
      [key isEqualToString:@"title"] ||
      [key isEqualToString:@"icon"] ||
      [key isEqualToString:@"parentOpener"] ||
      [key isEqualToString:@"isActive"] ||
      [key isEqualToString:@"isTeared"]) {
    return YES;
  }
  return [super automaticallyNotifiesObserversForKey:key];
}


-(id)initWithBaseTabContents:(CTTabContents*)baseContents {
  // subclasses should probably override this
  self.parentOpener = baseContents;
  return [super init];
}

#pragma mark Properties impl.

-(BOOL)hasIcon {
  return YES;
}

- (CTTabContents*)parentOpener {
  return parentOpener_;
}

- (void)setParentOpener:(CTTabContents*)parentOpener {
  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  if (parentOpener_) {
    [nc removeObserver:self
                  name:CTTabContentsDidCloseNotification
                object:parentOpener_];
  }
    [self willChangeValueForKey:@"parentOpener"];
    parentOpener_ = parentOpener;
    [self didChangeValueForKey:@"parentOpener"];
  if (parentOpener_) {
    [nc addObserver:self
           selector:@selector(tabContentsDidClose:)
               name:CTTabContentsDidCloseNotification
             object:parentOpener_];
  }
}

- (void)tabContentsDidClose:(NSNotification*)notification {
  // detach (NULLify) our parentOpener_ when it closes
  CTTabContents* tabContents = [notification object];
  if (tabContents == parentOpener_) {
    parentOpener_ = nil;
  }
}

- (void)setVisible:(BOOL)visible {
  if (isVisible_ != visible && !isTeared_) {
    isVisible_ = visible;
    if (isVisible_) {
      [self tabDidBecomeVisible];
    } else {
      [self tabDidResignVisible];
    }
  }
}

- (void)setActive:(BOOL)active {
  if (isActive_ != active && !isTeared_) {
    isActive_ = active;
    if (isActive_) {
      [self tabDidBecomeActive];
    } else {
      [self tabDidResignActive];
    }
  }
}

- (void)setTeared:(BOOL)teared {
  if (isTeared_ != teared) {
    isTeared_ = teared;
    if (isTeared_) {
      [self tabWillBecomeTeared];
    } else {
      [self tabWillResignTeared];
      [self tabDidBecomeActive];
    }
  }
}

#pragma mark Actions

- (void)makeKeyAndOrderFront:(id)sender {
  if (browser_) {
    NSWindow *window = browser_.window;
    if (window)
      [window makeKeyAndOrderFront:sender];
    int index = [browser_ indexOfTabContents:self];
    assert(index > -1); // we should exist in browser
    [browser_ selectTabAtIndex:index];
  }
}


- (BOOL)becomeFirstResponder {
  if (isVisible_) {
    return [[view_ window] makeFirstResponder:view_];
  }
  return NO;
}


#pragma mark Callbacks

-(void)closingOfTabDidStart:(CTTabStripModel *)closeInitiatedByTabStripModel {
  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:CTTabContentsDidCloseNotification object:self];
}

// Called when this tab was inserted into a browser
- (void)tabDidInsertIntoBrowser:(CTBrowser*)browser
                        atIndex:(NSInteger)index
                   inForeground:(BOOL)foreground {
  self.browser = browser;
}

// Called when this tab replaced another tab
- (void)tabReplaced:(CTTabContents*)oldContents
          inBrowser:(CTBrowser*)browser
            atIndex:(NSInteger)index {
  self.browser = browser;
}

// Called when this tab is about to close
- (void)tabWillCloseInBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  self.browser = nil;
}

// Called when this tab was removed from a browser. Will be followed by a
// |tabDidInsertIntoBrowser:atIndex:inForeground:|.
- (void)tabDidDetachFromBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  self.browser = nil;
}

-(void)tabWillBecomeActive {}
-(void)tabWillResignActive {}

-(void)tabDidBecomeActive {
  [self becomeFirstResponder];
}

-(void)tabDidResignActive {}
-(void)tabDidBecomeVisible {}
-(void)tabDidResignVisible {}

-(void)tabWillBecomeTeared {
  // Teared tabs should always be visible and active since tearing is invoked
  // by the user selecting the tab on screen.
  assert(isVisible_);
  assert(isActive_);
}

-(void)tabWillResignTeared {
  assert(isVisible_);
  assert(isActive_);
}

// Unlike the above callbacks, this one is explicitly called by
// CTBrowserWindowController
-(void)tabDidResignTeared {
  [[view_ window] makeFirstResponder:view_];
}

-(void)viewFrameDidChange:(NSRect)newFrame {
  [view_ setFrame:newFrame];
}

@end
