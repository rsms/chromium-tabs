#import "NSImage+CTAdditions.h"
#import "util.h"

@implementation NSImage (CTAdditions)

+(NSImage*)imageWithPath:(NSString *)path {
  return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
}

+(NSImage*)imageInAppOrFrameworkNamed:(NSString *)name {
  NSString *path = [kHostBundle pathForImageResource:name];
  if (!path)
    path = [kFrameworkBundle pathForImageResource:name];
  return [self imageWithPath:path];
}

+(NSImage*)imageInFrameworkNamed:(NSString *)name {
  return [self imageWithPath:[kFrameworkBundle pathForImageResource:name]];
}

@end
