#import <Foundation/Foundation.h>
#import "AOTPlayerStructure.h"
#import "Bones.h"
#import "AOTVector3.h"

@interface AOTBoneManager : NSObject

@property (nonatomic, strong) NSMutableArray *bones;
@property (nonatomic, strong) NSMutableArray *bonePositions;

- (void)updateBonePositions;
- (CGPoint)worldToScreen:(AOTVector3)worldPos;

@end
