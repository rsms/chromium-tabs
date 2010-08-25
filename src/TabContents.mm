#import "TabContents.h"
#import "chrome/browser/tabs/tab_strip_model.h"

@implementation TabContents

@synthesize isApp = isApp_;
@synthesize isLoading = isLoading_;
@synthesize isWaitingForResponse = isWaitingForResponse_;
@synthesize isCrashed = isCrashed_;
@synthesize delegate = delegate_;
@synthesize closedByUserGesture = closedByUserGesture_;
@synthesize view = view_;
@synthesize title = title_;
@synthesize icon = icon_;

-(id)initWithBaseTabContents:(TabContents*)baseContents {
	if (!(self = [super init])) return nil;
	// subclasses can use baseContents -- the selected TabContents (if any) -- to
	// perform customized initialization (e.g. inheriting title).
	return self;
}

//-(void)dealloc {}

-(void)destroy:(TabStripModel*)sender {
	// TODO: notify "disconnected"
	sender->TabContentsWasDestroyed(self); // TODO: NSNotification
	[self release];
}

-(void)closingOfTabDidStart:(TabStripModel*)closeInitiatedByTabStripModel {
	NSLog(@"TabContents closingOfTabDidStart");
}

-(void)didBecomeSelected {
	NSLog(@"TabContents didBecomeSelected");
}

-(void)didBecomeHidden {
	NSLog(@"TabContents didBecomeHidden");
}

-(void)viewFrameDidChange:(NSRect)newFrame {
	[view_ setFrame:newFrame];
}

@end
