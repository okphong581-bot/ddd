#import "AOTFloatingMenu.h"
#import "AOTSettingsManager.h"
#import "AOTMemoryManager.h"

@implementation AOTFloatingMenu

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        defaultDotColor = [UIColor redColor];
        selectedDotColor = [UIColor greenColor];
        bonePoints = [NSMutableArray array];
        [self setupUI];
        boneManager = [[AOTBoneManager alloc] init];
        renderer = [[AOTRenderer alloc] initWithFrame:frame];
        renderer.backgroundColor = [UIColor clearColor];
        renderer.userInteractionEnabled = NO;
        [self addSubview:renderer];
        
        // CADisplayLink for real-time update
        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateOverlay)];
        [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        
        // Gesture recognizers
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPress];
    }
    return self;
}

- (void)setupUI {
    toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [toggleButton setTitle:@"🔴" forState:UIControlStateNormal];
    toggleButton.frame = CGRectMake(20, 80, 60, 60);
    toggleButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    toggleButton.layer.cornerRadius = 30;
    [toggleButton addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:toggleButton];
    
    boneTableView = [[UITableView alloc] initWithFrame:CGRectMake(100, 80, 220, 500)];
    boneTableView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    boneTableView.alpha = 0.0;
    boneTableView.layer.cornerRadius = 12;
    boneTableView.delegate = (id)self;
    boneTableView.dataSource = (id)self;
    [self addSubview:boneTableView];
    
    sensitivitySlider = [[UISlider alloc] initWithFrame:CGRectMake(100, 600, 220, 30)];
    sensitivitySlider.minimumValue = 0.1;
    sensitivitySlider.maximumValue = 1.0;
    sensitivitySlider.value = 0.5;
    [sensitivitySlider addTarget:self action:@selector(sensitivityChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:sensitivitySlider];
    
    aimbotSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(340, 80, 50, 30)];
    [aimbotSwitch addTarget:self action:@selector(aimbotToggled:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:aimbotSwitch];
}

- (void)toggleMenuVisibility {
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        self->boneTableView.alpha = (self->boneTableView.alpha == 0.0) ? 0.9 : 0.0;
    } completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:self];
        toggleButton.center = CGPointMake(toggleButton.center.x + translation.x, toggleButton.center.y + translation.y);
        [gesture setTranslation:CGPointZero inView:self];
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint point = [gesture locationInView:renderer];
    [self handleTapOnBoneAtPoint:point];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // find nearest bone and pin
        [self pinBone:nil atIndex:0];
    }
}

- (void)handleTapOnBoneAtPoint:(CGPoint)point {
    // bone selection logic
}

- (void)pinBone:(AOTBone *)bone atIndex:(NSUInteger)index {
    // pin logic
}

- (void)sensitivityChanged:(UISlider *)slider {
    [AOTSettingsManager sharedManager].sensitivity = slider.value;
}

- (void)aimbotToggled:(UISwitch *)sender {
    [AOTSettingsManager sharedManager].aimbotEnabled = sender.isOn;
}

- (void)renderSkeletonInContext:(CGContextRef)ctx {
    [renderer drawBonesInContext:ctx];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 16;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"BoneCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
    }
    NSArray *boneNames = @[@"Head", @"Neck", @"Hip", @"L-Shoulder", @"R-Shoulder", @"L-Elbow", @"R-Elbow", @"L-Wrist", @"R-Wrist", @"L-Hand", @"R-Hand", @"L-Ankle", @"R-Ankle", @"L-Foot", @"R-Foot", @"Root"];
    if (indexPath.row < boneNames.count) {
        cell.textLabel.text = boneNames[indexPath.row];
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"Bone %ld", (long)indexPath.row];
    }
    return cell;
}

- (void)updateOverlay {
    if ([[AOTMemoryManager sharedManager] isGameRunning]) {
        [boneManager updateBonePositions];
        renderer.bonePoints = boneManager.bonePositions;
    } else {
        renderer.bonePoints = nil;
    }
    [renderer setNeedsDisplay];
}

@end
