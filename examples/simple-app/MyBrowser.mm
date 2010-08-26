#import "MyBrowser.h"

@implementation MyBrowser

// This method is called when a new tab is being created. We need to return a
// new CTTabContents object which will represent the contents of the new tab.
-(CTTabContents*)createBlankTabBasedOn:(CTTabContents*)baseContents {
  // Ask super to create a standard CTTabContents for us as we don't need our
  // own type
  CTTabContents *contents = [super createBlankTabBasedOn:baseContents];

  // Retrieve the window frame
  NSRect frame = [self.windowController.window frame];
  frame.origin.x  = frame.origin.y = 0.0;

  // Create a simple NSTextView
  NSTextView* tv = [[NSTextView alloc] initWithFrame:frame];
  [tv setFont:[NSFont userFixedPitchFontOfSize:13.0]];
  [tv setAutoresizingMask:                  NSViewMaxYMargin|
                          NSViewMinXMargin|NSViewWidthSizable|NSViewMaxXMargin|
                                           NSViewHeightSizable|
                                           NSViewMinYMargin];

  // Create a NSScrollView to which we add the NSTextView
  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:frame];
  [sv setDocumentView:tv];
  [sv setHasVerticalScroller:YES];

  // Set the NSScrollView as the content view
  contents.view = sv;

  return contents;
}

@end
