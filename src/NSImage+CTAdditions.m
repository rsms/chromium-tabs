#import "NSImage+CTAdditions.h"
#import "CTUtil.h"

@implementation NSImage (CTAdditions)

+(NSImage*)imageWithPath:(NSString *)path {
	return [[NSImage alloc] initWithContentsOfFile:path];
}

+(NSImage*)imageInAppOrCTFrameworkNamed:(NSString *)name {
	NSBundle *bundle = CTHostBundle;
	if (bundle == nil) bundle = [NSBundle mainBundle];
	NSString *path = [bundle pathForImageResource:name];
	if (!path) {
		NSBundle *bundle = CTFrameworkBundle;
		if (bundle == nil) bundle = [NSBundle bundleForClass:self];
		path = [bundle pathForImageResource:name];
	}
	return [self imageWithPath:path];
}

+(NSImage*)imageInFrameworkNamed:(NSString *)name {
	return [self imageWithPath:[CTFrameworkBundle pathForImageResource:name]];
}

@end
