#import <Foundation/Foundation.h>

@interface AOTSettingsManager : NSObject

@property (nonatomic, assign) float sensitivity;
@property (nonatomic, assign) BOOL aimbotEnabled;
@property (nonatomic, assign) BOOL showSkeleton;
@property (nonatomic, assign) BOOL showDots;
@property (nonatomic, strong) UIColor *dotColor;
@property (nonatomic, strong) UIColor *lineColor;

+ (instancetype)sharedManager;
- (void)saveSettings;
- (void)loadSettings;

@end
