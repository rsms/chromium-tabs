#import "TabContents.h"
#import "base/logging.h"

@implementation TabContents

@synthesize isApp = isApp_;
@synthesize isLoading = isLoading_;
@synthesize delegate = delegate_;
@synthesize closedByUserGesture = closedByUserGesture_;
@synthesize view = view_;

-(void)closingOfTabDidStart:(TabStripModel*)closeInitiatedByTabStripModel {
	DLOG(INFO) << "closingOfTabDidStart called";
}

@end
