#import <Foundation/Foundation.h>
#import "AOTVector3.h"

@interface AOTMatrix4x4 : NSObject

+ (instancetype)identity;
+ (AOTMatrix4x4 *)getViewProjectionMatrix;
- (AOTVector3)multiplyVector:(AOTVector3)v;

@end
