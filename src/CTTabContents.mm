#import "CTTabContents.h"
#import "tab_strip_model.h"

@implementation CTTabContents

@synthesize isApp = isApp_;
@synthesize isLoading = isLoading_;
@synthesize isWaitingForResponse = isWaitingForResponse_;
@synthesize isCrashed = isCrashed_;
@synthesize delegate = delegate_;
@synthesize closedByUserGesture = closedByUserGesture_;
@synthesize view = view_;
@synthesize title = title_;
@synthesize icon = icon_;

-(id)initWithBaseTabContents:(CTTabContents*)baseContents {
  if (!(self = [super init])) return nil;
  // Example icon:
  //icon_ = [NSImage imageNamed:NSImageNameBluetoothTemplate];
  return self;
}

-(void)dealloc {
  [super dealloc];
}

-(void)destroy:(CTTabStripModel*)sender {
  // TODO: notify "disconnected"
  sender->TabContentsWasDestroyed(self); // TODO: NSNotification
  [self release];
}

-(BOOL)hasIcon {
  return YES;
}

-(void)closingOfTabDidStart:(CTTabStripModel*)closeInitiatedByTabStripModel {
  // subclasses can implement this
  //NSLog(@"CTTabContents closingOfTabDidStart");
}

-(void)didBecomeSelected {
  // subclasses can implement this
  //NSLog(@"CTTabContents didBecomeSelected");
}

-(void)didBecomeHidden {
  // subclasses can implement this
  //NSLog(@"CTTabContents didBecomeHidden");
}

-(void)viewFrameDidChange:(NSRect)newFrame {
  [view_ setFrame:newFrame];
}

@end
