#import "AOTBoneManager.h"
#import "AOTMemoryManager.h"
#import "AOTMatrix4x4.h"

@implementation AOTBoneManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _bones = [NSMutableArray array];
        _bonePositions = [NSMutableArray array];
    }
    return self;
}

- (void)updateBonePositions {
    [_bonePositions removeAllObjects];
    AOTMemoryManager *mem = [AOTMemoryManager sharedManager];
    uint32_t offsets[] = {BonesHead, BonesNeck, BonesHip, 
                          BonesLeftShoulder, BonesRightShoulder,
                          BonesLeftElbow, BonesRightElbow,
                          BonesLeftWrist, BonesRightWrist,
                          BonesLeftHand, BonesRightHand,
                          BonesLeftAnkle, BonesRightAnkle,
                          BonesLeftFoot, BonesRightFoot,
                          BonesRoot};
    int count = sizeof(offsets)/sizeof(uint32_t);
    
    for (int i = 0; i < count; i++) {
        AOTVector3 pos = [mem readVector3AtOffset:offsets[i]];
        CGPoint screen = [self worldToScreen:pos];
        if (screen.x > 0 && screen.y > 0) {
            [_bonePositions addObject:[NSValue valueWithCGPoint:screen]];
        }
    }
}

- (CGPoint)worldToScreen:(AOTVector3)worldPos {
    AOTMatrix4x4 viewProj = [AOTMatrix4x4 getViewProjectionMatrix];
    AOTVector3 screen = [viewProj multiplyVector:worldPos];
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    screen.x = (screen.x / screen.z + 1.0) * 0.5 * screenW;
    screen.y = (1.0 - (screen.y / screen.z + 1.0) * 0.5) * screenH;
    return CGPointMake(screen.x, screen.y);
}

@end
