#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "AOTPlayerStructure.h"
#import "Bones.h"
#import "AOTVector3.h"

@interface AOTBoneManager : NSObject

@property (nonatomic, strong) NSMutableArray *bones;
@property (nonatomic, strong) NSMutableArray *bonePositions; // NSValue CGPoint, -1,-1 = off-screen/behind cam

- (void)updateBonePositions;
- (CGPoint)worldToScreen:(AOTVector3)worldPos;

// Pin support for aimbot
- (void)setPinnedBoneIndex:(NSInteger)index;   // -1 = none
- (NSInteger)pinnedBoneIndex;
- (AOTVector3)pinnedBoneWorldPosition;

// Metadata
+ (NSInteger)boneCount;
+ (NSString *)boneNameAtIndex:(NSInteger)i;

@end
