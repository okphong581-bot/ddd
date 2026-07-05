#import "AOTRenderer.h"
#import "AOTBoneManager.h"
#import "AOTSettingsManager.h"

// Skeleton connection pairs: [from, to] by index into kAllOffsets order:
// 0=Head 1=Neck 2=Hip 3=L-Shldr 4=R-Shldr 5=L-Elbow 6=R-Elbow
// 7=L-Wrist 8=R-Wrist 9=L-Hand 10=R-Hand 11=L-Ankle 12=R-Ankle
// 13=L-Foot 14=R-Foot 15=Root
static const int kBoneLines[][2] = {
    {0, 1},   // Head → Neck
    {1, 2},   // Neck → Hip
    {2, 15},  // Hip  → Root
    {1, 3},   // Neck → L-Shoulder
    {1, 4},   // Neck → R-Shoulder
    {3, 5},   // L-Shoulder → L-Elbow
    {4, 6},   // R-Shoulder → R-Elbow
    {5, 7},   // L-Elbow → L-Wrist
    {6, 8},   // R-Elbow → R-Wrist
    {7, 9},   // L-Wrist → L-Hand
    {8,10},   // R-Wrist → R-Hand
    {15,11},  // Root → L-Ankle
    {15,12},  // Root → R-Ankle
    {11,13},  // L-Ankle → L-Foot
    {12,14},  // R-Ankle → R-Foot
};
static const int kBoneLineCount = (int)(sizeof(kBoneLines)/sizeof(kBoneLines[0]));

@implementation AOTRenderer

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [self drawBonesInContext:ctx];
}

- (void)drawBonesInContext:(CGContextRef)ctx {
    if (!_bonePoints || _bonePoints.count == 0) return;
    if (!ctx) return;

    AOTSettingsManager *s = [AOTSettingsManager sharedManager];

    // ── Skeleton lines ────────────────────────────────────────
    if (s.showSkeleton) {
        CGContextSaveGState(ctx);
        CGContextSetLineWidth(ctx, 1.5);
        // White semi-transparent lines
        CGFloat r,g,b,a;
        [[UIColor colorWithRed:0.3 green:1.0 blue:0.4 alpha:0.7] getRed:&r green:&g blue:&b alpha:&a];
        CGContextSetRGBStrokeColor(ctx, r, g, b, a);

        for (int i = 0; i < kBoneLineCount; i++) {
            int ai = kBoneLines[i][0];
            int bi = kBoneLines[i][1];
            if (ai >= (int)_bonePoints.count || bi >= (int)_bonePoints.count) continue;

            CGPoint pa = [_bonePoints[ai] CGPointValue];
            CGPoint pb = [_bonePoints[bi] CGPointValue];
            // Skip invalid (off-screen / behind camera) points
            if (pa.x < 0 || pb.x < 0) continue;

            CGContextMoveToPoint(ctx, pa.x, pa.y);
            CGContextAddLineToPoint(ctx, pb.x, pb.y);
            CGContextStrokePath(ctx);
        }
        CGContextRestoreGState(ctx);
    }

    // ── Bone dots ─────────────────────────────────────────────
    if (s.showDots) {
        UIColor *dotColor = s.dotColor ?: [UIColor redColor];
        CGFloat dr, dg, db, da;
        [dotColor getRed:&dr green:&dg blue:&db alpha:&da];

        for (int i = 0; i < (int)_bonePoints.count; i++) {
            CGPoint p = [_bonePoints[i] CGPointValue];
            if (p.x < 0) continue; // behind camera

            BOOL isPinned   = (i == (int)_selectedBone);
            CGFloat radius  = isPinned ? 7.0 : 4.5;

            CGContextSaveGState(ctx);
            if (isPinned) {
                // Pinned bone → bright yellow glow
                CGContextSetRGBFillColor(ctx, 1.0, 0.9, 0.0, 0.3);
                CGContextFillEllipseInRect(ctx, CGRectMake(p.x-14, p.y-14, 28, 28));
                CGContextSetRGBFillColor(ctx, 1.0, 0.9, 0.0, 1.0);
            } else {
                CGContextSetRGBFillColor(ctx, dr, dg, db, 0.9);
            }
            CGContextFillEllipseInRect(ctx, CGRectMake(p.x-radius, p.y-radius, radius*2, radius*2));
            CGContextRestoreGState(ctx);
        }
    }
}

@end
