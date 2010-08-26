#import "util.h"

NSBundle *kFrameworkBundle = nil;
NSBundle *kHostBundle = nil;

@implementation util

+(void)initialize {
  kFrameworkBundle = [NSBundle bundleForClass:self];
  assert(kFrameworkBundle);
  kHostBundle = [NSBundle mainBundle];
  assert(kHostBundle);
}

+(NSBundle *)bundleForResource:(NSString *)name {
  return [self bundleForResource:name ofType:nil];
}

+(NSBundle *)bundleForResource:(NSString *)name ofType:(NSString *)ext {
  if ([kHostBundle pathForResource:name ofType:ext])
    return kHostBundle;
  assert([kFrameworkBundle pathForResource:name ofType:ext]);
  return kFrameworkBundle;
}

+(NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext {
  NSString *path = [kHostBundle pathForResource:name ofType:ext];
  if (path)
    return path;
  return [kFrameworkBundle pathForResource:name ofType:ext];
}

@end
