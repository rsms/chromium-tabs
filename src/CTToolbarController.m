#import "CTToolbarController.h"
#import "CTBrowser.h"
#import "CTToolbarView.h"
#import "CTTabContents.h"
#import "BackgroundGradientView.h"

@interface CTToolbarController (Private)
- (BackgroundGradientView*)backgroundGradientView;
- (void)toolbarFrameChanged;
@end

@implementation CTToolbarController {
	CTBrowser* browser_;  // weak, one per window
}

@synthesize browser = browser_;

- (id)initWithNibName:(NSString*)nibName
               bundle:(NSBundle*)bundle
              browser:(CTBrowser*)browser {
	self = [self initWithNibName:nibName bundle:bundle];
	assert(self);
	browser_ = browser; // weak
	return self;
}


- (void)updateToolbarWithContents:(CTTabContents*)contents
               shouldRestoreState:(BOOL)shouldRestore {
	// subclasses should implement this
}


- (void)setDividerOpacity:(CGFloat)opacity {
	BackgroundGradientView* view = [self backgroundGradientView];
	[view setShowsDivider:(opacity > 0 ? YES : NO)];
	if ([view isKindOfClass:[CTToolbarView class]]) {
		CTToolbarView* toolbarView = (CTToolbarView*)view;
		[toolbarView setDividerOpacity:opacity];
	}
}


// Called after the view is done loading and the outlets have been hooked up.
- (void)awakeFromNib {
}

#pragma mark -
#pragma mark URLDropTargetController protocol impl

- (void)dropURLs:(NSArray*)urls inView:(NSView*)view at:(NSPoint)point {
	// subclasses should implement this
	NOTIMPLEMENTED();
}


- (void)indicateDropURLsInView:(NSView*)view at:(NSPoint)point {
	// Do nothing.
}


- (void)hideDropURLsIndicatorInView:(NSView*)view {
	// Do nothing.
}


- (id)customFieldEditorForObject:(id)obj {
	return nil;
}


#pragma mark -
#pragma mark Private

// (Private) Returns the backdrop to the toolbar.
- (BackgroundGradientView*)backgroundGradientView {
	// We really do mean |[super view]| see our override of |-view|.
	assert([[super view] isKindOfClass:[BackgroundGradientView class]]);
	return (BackgroundGradientView*)[super view];
}


@end
