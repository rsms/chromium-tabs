#pragma once
#import <Cocoa/Cocoa.h>

class CTTabStripModel; // Note: C++ class

@interface CTTabContents : NSObject {
  BOOL isApp_;
  BOOL isLoading_;
  BOOL isWaitingForResponse_;
  BOOL isCrashed_;
  id delegate_;
  unsigned int closedByUserGesture_; // TabStripModel::CloseTypes
  NSView *view_; // the actual content
  NSString *title_; // title of this tab
  NSImage *icon_; // tab icon (nil means no or default icon)
}

@property(assign, nonatomic) BOOL isApp;
@property(assign, nonatomic) BOOL isLoading;
@property(assign, nonatomic) BOOL isCrashed;
@property(assign, nonatomic) BOOL isWaitingForResponse;
@property(retain, nonatomic) id delegate;
@property(assign, nonatomic) unsigned int closedByUserGesture;
@property(retain, nonatomic) NSView *view;
@property(retain, nonatomic) NSString *title;
@property(retain, nonatomic) NSImage *icon;

// If this returns true, special icons like throbbers and "crashed" is
// displayed, even if |icon| is nil. By default this returns true.
@property(readonly, nonatomic) BOOL hasIcon;

// Initialize a new CTTabContents object.
// The default implementation does nothing with |baseContents| but subclasses
// can use |baseContents| (the selected CTTabContents, if any) to perform
// customized initialization.
-(id)initWithBaseTabContents:(CTTabContents*)baseContents;

// Invoked when the tab should be destroyed (involves some finalization).
-(void)destroy:(CTTabStripModel*)sender;

// Invoked when this tab is closing.
-(void)closingOfTabDidStart:(CTTabStripModel*)closeInitiatedByTabStripModel;

// Invoked when the tab contents becomes selected. If you override, be sure
// and invoke super's implementation.
-(void)didBecomeSelected;

// Invoked when the tab contents becomes hidden.
// NOTE: If you override this, call the superclass version too!
-(void)didBecomeHidden;

// Invoked when the frame has changed, normally due to the window being resized.
-(void)viewFrameDidChange:(NSRect)newFrame;

@end

@protocol TabContentsDelegate
-(BOOL)canReloadContents:(CTTabContents*)contents;
-(BOOL)reload; // should set contents->isLoading_ = YES
@end

