#import <Cocoa/Cocoa.h>

@interface NSImage (ChromiumTabsAdditions)
+(NSImage*)imageWithPath:(NSString *)path;
+(NSImage*)imageInAppOrFrameworkNamed:(NSString*)name;
+(NSImage*)imageInFrameworkNamed:(NSString*)name;
@end
