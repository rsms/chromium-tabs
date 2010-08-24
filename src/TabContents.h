#import <Cocoa/Cocoa.h>

class TabStripModel; // Note: C++ class

@interface TabContents : NSObject {
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
@property(assign, nonatomic) id delegate;
@property(assign, nonatomic) unsigned int closedByUserGesture;
@property(assign, nonatomic) NSView *view;
@property(assign, nonatomic) NSString *title;
@property(assign, nonatomic) NSImage *icon;

-(void)closingOfTabDidStart:(TabStripModel*)closeInitiatedByTabStripModel;

// Invoked when the tab contents becomes selected. If you override, be sure
// and invoke super's implementation.
-(void)didBecomeSelected;

// Invoked when the tab contents becomes hidden.
// NOTE: If you override this, call the superclass version too!
-(void)didBecomeHidden;

@end

@protocol TabContentsDelegate
-(BOOL)canReloadContents:(TabContents*)contents;
-(BOOL)reload; // should set contents->isLoading_ = YES
@end

