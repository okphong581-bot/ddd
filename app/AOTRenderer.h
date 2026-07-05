#import <UIKit/UIKit.h>

@class AOTBone;

@interface AOTRenderer : UIView
@property (nonatomic, strong) NSArray *bonePoints;
@property (nonatomic, assign) NSInteger selectedBone;
@property (nonatomic, strong) NSArray *pinnedBones;
- (void)drawBonesInContext:(CGContextRef)ctx;
@end
