#import "AOTSettingsManager.h"

@implementation AOTSettingsManager

+ (instancetype)sharedManager {
    static AOTSettingsManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance loadSettings];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sensitivity = 0.5;
        _aimbotEnabled = YES;
        _showSkeleton = YES;
        _showDots = YES;
        _dotColor = [UIColor redColor];
        _lineColor = [UIColor whiteColor];
    }
    return self;
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:_sensitivity forKey:@"sensitivity"];
    [defaults setBool:_aimbotEnabled forKey:@"aimbotEnabled"];
    [defaults setBool:_showSkeleton forKey:@"showSkeleton"];
    [defaults setBool:_showDots forKey:@"showDots"];
    [defaults synchronize];
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _sensitivity = [defaults floatForKey:@"sensitivity"] ?: 0.5;
    _aimbotEnabled = [defaults boolForKey:@"aimbotEnabled"];
    _showSkeleton = [defaults boolForKey:@"showSkeleton"] ?: YES;
    _showDots = [defaults boolForKey:@"showDots"] ?: YES;
}

@end
