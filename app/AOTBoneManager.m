#import <UIKit/UIKit.h>
#import "AOTBoneManager.h"
#import "AOTMemoryManager.h"
#import "AOTMatrix4x4.h"
#import "AOTSettingsManager.h"
#import "Bones.h"

// All bone offsets relative to localPlayer
static const uint32_t kAllOffsets[] = {
    BonesHead, BonesNeck, BonesHip,
    BonesLeftShoulder, BonesRightShoulder,
    BonesLeftElbow, BonesRightElbow,
    BonesLeftWrist, BonesRightWrist,
    BonesLeftHand, BonesRightHand,
    BonesLeftAnkle, BonesRightAnkle,
    BonesLeftFoot, BonesRightFoot,
    BonesRoot
};
static const int kBoneCount = (int)(sizeof(kAllOffsets)/sizeof(kAllOffsets[0]));

@implementation AOTBoneManager {
    NSInteger _pinnedBoneIndex; // -1 = none
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _bones         = [NSMutableArray array];
        _bonePositions = [NSMutableArray array];
        _pinnedBoneIndex = -1;
    }
    return self;
}

// ─── Convert world-space Vector3 → screen CGPoint ────────────────────────────
- (CGPoint)worldToScreen:(AOTVector3)world {
    AOTMatrix4x4 *vp = [AOTMatrix4x4 getViewProjectionMatrix];
    AOTVector3 clip  = [vp multiplyVector:world];

    // clip.z = homogeneous w; positive w = in front of camera
    if (clip.z <= 0.0f) return CGPointMake(-1, -1);

    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;

    CGFloat sx = (clip.x / clip.z + 1.0f) * 0.5f * sw;
    CGFloat sy = (1.0f - (clip.y / clip.z + 1.0f) * 0.5f) * sh;

    // Reject off-screen
    if (sx < -50 || sx > sw + 50 || sy < -50 || sy > sh + 50)
        return CGPointMake(-1, -1);

    return CGPointMake(sx, sy);
}

// ─── Update bone screen-positions every frame ─────────────────────────────────
- (void)updateBonePositions {
    [_bonePositions removeAllObjects];

    AOTMemoryManager *mem = [AOTMemoryManager sharedManager];
    if (![mem isGameRunning]) return;

    for (int i = 0; i < kBoneCount; i++) {
        AOTVector3 world = [mem readVector3AtOffset:kAllOffsets[i]];
        CGPoint    screen = [self worldToScreen:world];
        // -1,-1 means behind cam or off-screen → still add a null sentinel so
        // index stays aligned with kAllOffsets
        [_bonePositions addObject:[NSValue valueWithCGPoint:screen]];
    }
}

// ─── Pinned-bone world position (for aimbot) ──────────────────────────────────
- (AOTVector3)pinnedBoneWorldPosition {
    AOTMemoryManager *mem = [AOTMemoryManager sharedManager];
    if (![mem isGameRunning]) return (AOTVector3){0,0,0};
    NSInteger idx = _pinnedBoneIndex;
    if (idx < 0 || idx >= kBoneCount) idx = 0; // default Head
    return [mem readVector3AtOffset:kAllOffsets[idx]];
}

- (void)setPinnedBoneIndex:(NSInteger)index {
    _pinnedBoneIndex = (index >= 0 && index < kBoneCount) ? index : -1;
}

- (NSInteger)pinnedBoneIndex { return _pinnedBoneIndex; }

// ─── Bone count ───────────────────────────────────────────────────────────────
+ (NSInteger)boneCount { return kBoneCount; }
+ (NSString *)boneNameAtIndex:(NSInteger)i {
    static NSArray *names;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        names = @[@"Head", @"Neck", @"Hip",
                  @"L-Shoulder", @"R-Shoulder",
                  @"L-Elbow",    @"R-Elbow",
                  @"L-Wrist",   @"R-Wrist",
                  @"L-Hand",    @"R-Hand",
                  @"L-Ankle",   @"R-Ankle",
                  @"L-Foot",    @"R-Foot",
                  @"Root"];
    });
    return (i >= 0 && i < (NSInteger)names.count) ? names[i] : @"?";
}

@end
