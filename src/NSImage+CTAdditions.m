#import "NSImage+CTAdditions.h"
#import "CTUtil.h"

@implementation NSImage (CTAdditions)

+(NSImage*)imageWithPath:(NSString *)path {
  return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
}

+(NSImage*)imageInAppOrCTFrameworkNamed:(NSString *)name {
  NSString *path = [CTHostBundle pathForImageResource:name];
  if (!path)
    path = [CTFrameworkBundle pathForImageResource:name];
  return [self imageWithPath:path];
}

+(NSImage*)imageInFrameworkNamed:(NSString *)name {
  return [self imageWithPath:[CTFrameworkBundle pathForImageResource:name]];
}

@end
