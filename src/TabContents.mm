#import "TabContents.h"
#import "base/logging.h"

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

-(void)closingOfTabDidStart:(TabStripModel*)closeInitiatedByTabStripModel {
	DLOG(INFO) << "TabContents closingOfTabDidStart";
}

-(void)didBecomeSelected {
	DLOG(INFO) << "TabContents didBecomeSelected";
}

-(void)didBecomeHidden {
	DLOG(INFO) << "TabContents didBecomeHidden";
}

@end
