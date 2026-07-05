#import <UIKit/UIKit.h>
#import "AOTFloatingMenu.h"

static AOTFloatingMenu *gMenu = nil;

static void injectMenu(void) {
    if (gMenu) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;

        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) { keyWindow = w; break; }
                    }
                    if (keyWindow) break;
                }
            }
        }

        if (!keyWindow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            keyWindow = [[UIApplication sharedApplication] keyWindow];
#pragma clang diagnostic pop
        }

        if (!keyWindow) return;

        CGRect screen = keyWindow.bounds;
        gMenu = [[AOTFloatingMenu alloc] initWithFrame:screen];
        gMenu.userInteractionEnabled = YES;

        // Sit on top but pass through touches that miss our controls
        [keyWindow addSubview:gMenu];
    });
}

// ─── Hook: inject as soon as the application becomes active ──────────────────
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ injectMenu(); });
}
%end
