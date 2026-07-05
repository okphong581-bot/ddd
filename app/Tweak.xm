#import <UIKit/UIKit.h>
#import "AOTFloatingMenu.h"

static AOTFloatingMenu *floatingMenu = nil;

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL ret = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!floatingMenu) {
            floatingMenu = [[AOTFloatingMenu alloc] initWithFrame:[UIScreen mainScreen].bounds];
            floatingMenu.userInteractionEnabled = YES;
            floatingMenu.backgroundColor = [UIColor clearColor];
            floatingMenu.layer.zPosition = 99999;
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (keyWindow) {
                [keyWindow addSubview:floatingMenu];
            }
        }
    });
    return ret;
}

%end
