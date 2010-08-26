#import <Cocoa/Cocoa.h>

// Framework-local utilities

extern NSBundle *kFrameworkBundle;
extern NSBundle *kHostBundle; // main bundle -- the hosts' bundle

inline NSString *L10n(NSString *key) {
  assert(kFrameworkBundle);
  return [kFrameworkBundle localizedStringForKey:key value:nil table:nil];
}

@interface util : NSObject {
}

+(NSBundle *)bundleForResource:(NSString *)name ofType:(NSString *)ext;
+(NSBundle *)bundleForResource:(NSString *)name; // ofType:nil
+(NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext;

@end
