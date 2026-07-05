#import "AOTRenderer.h"
#import "AOTBoneManager.h"
#import "Bones.h"

@implementation AOTRenderer

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [self drawBonesInContext:ctx];
}

- (void)drawBonesInContext:(CGContextRef)ctx {
    if (!_bonePoints || _bonePoints.count == 0) return;
    
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetRGBStrokeColor(ctx, 1.0, 1.0, 1.0, 0.6);
    
    // Draw skeleton lines
    for (int i = 0; i < _bonePoints.count - 1; i++) {
        CGPoint p1 = [_bonePoints[i] CGPointValue];
        CGPoint p2 = [_bonePoints[i+1] CGPointValue];
        CGContextMoveToPoint(ctx, p1.x, p1.y);
        CGContextAddLineToPoint(ctx, p2.x, p2.y);
        CGContextStrokePath(ctx);
    }
    
    // Draw bone dots
    for (int i = 0; i < _bonePoints.count; i++) {
        CGPoint p = [_bonePoints[i] CGPointValue];
        BOOL isSelected = (i == (NSInteger)_selectedBone);
        BOOL isPinned = [_pinnedBones containsObject:@(i)];
        CGFloat radius = isSelected ? 12 : 8;
        
        CGContextSetRGBFillColor(ctx, isPinned ? 1.0 : (isSelected ? 0.0 : 1.0), 
                                 isPinned ? 1.0 : (isSelected ? 1.0 : 0.0), 
                                 isPinned ? 0.0 : (isSelected ? 0.0 : 0.0), 1.0);
        CGContextFillEllipseInRect(ctx, CGRectMake(p.x - radius, p.y - radius, radius * 2, radius * 2));
        
        // Glow for selected
        if (isSelected) {
            CGContextSetRGBFillColor(ctx, 0.0, 1.0, 0.0, 0.3);
            CGContextFillEllipseInRect(ctx, CGRectMake(p.x - 18, p.y - 18, 36, 36));
        }
    }
}

@end
