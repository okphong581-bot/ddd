#import "AppDelegate.h"
#import "AOTFloatingMenu.h"
#import "AOTMemoryManager.h"
#import <AVFoundation/AVFoundation.h>

@interface OverlayWindow : UIWindow
@end

@implementation OverlayWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *subview in self.subviews) {
        CGPoint subPoint = [self convertPoint:point toView:subview];
        UIView *hitView = [subview hitTest:subPoint withEvent:event];
        if (hitView && hitView != subview && hitView != self.rootViewController.view) {
            return YES;
        }
    }
    return NO;
}
@end

@interface MainViewController : UIViewController
@property (nonatomic, strong) UISwitch *activateSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.10 alpha:1.0];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 40)];
    titleLabel.text = @"HOANGHA AIMBOT";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:28];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
    
    UILabel *subTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, 140, self.view.bounds.size.width - 40, 30)];
    subTitle.text = @"System-wide Overlay Loader";
    subTitle.textColor = [UIColor lightGrayColor];
    subTitle.font = [UIFont systemFontOfSize:16];
    subTitle.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:subTitle];
    
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 220, self.view.bounds.size.width - 40, 30)];
    _statusLabel.text = @"Trạng thái: Chưa kích hoạt";
    _statusLabel.textColor = [UIColor orangeColor];
    _statusLabel.font = [UIFont systemFontOfSize:18];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_statusLabel];
    
    _activateSwitch = [[UISwitch alloc] init];
    _activateSwitch.center = CGPointMake(self.view.bounds.size.width / 2, 300);
    [_activateSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_activateSwitch];
    
    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 340, self.view.bounds.size.width - 40, 30)];
    switchLabel.text = @"Bật để Kích hoạt Overlay & Auto-scan";
    switchLabel.textColor = [UIColor grayColor];
    switchLabel.font = [UIFont systemFontOfSize:14];
    switchLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:switchLabel];
    
    [self setupBackgroundAudio];
}

- (void)setupBackgroundAudio {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)switchChanged:(UISwitch *)sender {
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if (sender.isOn) {
        _statusLabel.text = @"Trạng thái: Đang dò tìm Free Fire...";
        _statusLabel.textColor = [UIColor yellowColor];
        [appDelegate startScanLoop];
    } else {
        _statusLabel.text = @"Trạng thái: Chưa kích hoạt";
        _statusLabel.textColor = [UIColor orangeColor];
        [appDelegate stopScanLoop];
    }
}

@end


@implementation AppDelegate {
    NSTimer *_scanTimer;
    AOTFloatingMenu *_floatingMenu;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[MainViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)startScanLoop {
    if (_scanTimer) return;
    _scanTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(scanTick) userInfo:nil repeats:YES];
}

- (void)stopScanLoop {
    [_scanTimer invalidate];
    _scanTimer = nil;
    [self hideOverlay];
    [[AOTMemoryManager sharedManager] detachFromGame];
}

- (void)scanTick {
    AOTMemoryManager *mem = [AOTMemoryManager sharedManager];
    MainViewController *mainVC = (MainViewController *)self.window.rootViewController;
    
    if ([mem tryAttachToGame]) {
        mainVC.statusLabel.text = [NSString stringWithFormat:@"✅ Đã kết nối Free Fire | Base: 0x%llX", (unsigned long long)[mem baseAddress]];
        mainVC.statusLabel.textColor = [UIColor greenColor];
        [self showOverlay];
    } else {
        mainVC.statusLabel.text = @"🔍 Đang quét tiến trình Free Fire...";
        mainVC.statusLabel.textColor = [UIColor yellowColor];
        [self hideOverlay];
    }
}

- (void)showOverlay {
    if (self.overlayWindow) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.overlayWindow = [[OverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.windowLevel = 1000000000; // accessibility overlay level
        
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        
        self->_floatingMenu = [[AOTFloatingMenu alloc] initWithFrame:rootVC.view.bounds];
        self->_floatingMenu.backgroundColor = [UIColor clearColor];
        [rootVC.view addSubview:self->_floatingMenu];
        
        self.overlayWindow.rootViewController = rootVC;
        self.overlayWindow.hidden = NO;
    });
}

- (void)hideOverlay {
    if (!self.overlayWindow) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.overlayWindow.hidden = YES;
        self.overlayWindow = nil;
        self->_floatingMenu = nil;
    });
}

@end
