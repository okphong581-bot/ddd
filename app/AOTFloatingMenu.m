#import "AOTFloatingMenu.h"
#import "AOTSettingsManager.h"
#import "AOTMemoryManager.h"
#import "AOTBoneManager.h"

// ─── Constants ───────────────────────────────────────────────
#define kIconSize     56.0
#define kMenuWidth   280.0
#define kMenuHeight  440.0
#define kCorner       16.0

// ─── Private ivar extension ──────────────────────────────────
@interface AOTFloatingMenu () {
    /* floating gear icon */
    UIButton        *_iconBtn;
    BOOL             _menuOpen;

    /* menu panel */
    UIView          *_panel;

    /* panel children */
    UILabel         *_titleLbl;
    UISwitch        *_espSwitch;
    UISwitch        *_aimbotSwitch;
    UISwitch        *_dotsSwitch;
    UISlider        *_sensitivitySlider;
    UILabel         *_sensitivityLbl;
    UIButton        *_redBtn;
    UIButton        *_greenBtn;
    UIButton        *_blueBtn;
    UIButton        *_yellowBtn;
    UILabel         *_statusLbl;
    UITableView     *_boneTV;        // bone selection list
    UILabel         *_pinnedLbl;     // shows which bone is pinned
}
@end

@implementation AOTFloatingMenu

// ─── Init ────────────────────────────────────────────────────
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.userInteractionEnabled  = YES;
    self.backgroundColor         = [UIColor clearColor];

    defaultDotColor  = [UIColor redColor];
    selectedDotColor = [UIColor greenColor];
    bonePoints       = [NSMutableArray array];

    /* renderer (ESP draw layer) */
    renderer = [[AOTRenderer alloc] initWithFrame:frame];
    renderer.backgroundColor       = [UIColor clearColor];
    renderer.userInteractionEnabled = NO;
    [self addSubview:renderer];

    /* bone manager */
    boneManager = [[AOTBoneManager alloc] init];

    [self setupUI];

    /* CADisplayLink – bone update loop */
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateOverlay)];
    [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    [[AOTSettingsManager sharedManager] loadSettings];

    return self;
}

// ─── Touch pass-through ──────────────────────────────────────
// Only consume touches that land on the gear icon OR the open panel.
// Everything else passes through to the game underneath.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (!_iconBtn.hidden && CGRectContainsPoint(_iconBtn.frame, point)) return YES;
    if (!_panel.hidden  && CGRectContainsPoint(_panel.frame,   point)) return YES;
    return NO;
}

// ─── Build UI ────────────────────────────────────────────────
- (void)setupUI {

    /* ── Floating gear icon ── */
    _iconBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _iconBtn.frame = CGRectMake(20, 100, kIconSize, kIconSize);
    _iconBtn.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.12 alpha:0.90];
    _iconBtn.layer.cornerRadius  = kIconSize / 2.0;
    _iconBtn.layer.borderWidth   = 2.0;
    _iconBtn.layer.borderColor   = [UIColor colorWithRed:0.40 green:0.80 blue:1.0 alpha:0.9].CGColor;
    _iconBtn.layer.shadowColor   = [UIColor colorWithRed:0.40 green:0.80 blue:1.0 alpha:1.0].CGColor;
    _iconBtn.layer.shadowOffset  = CGSizeZero;
    _iconBtn.layer.shadowRadius  = 8;
    _iconBtn.layer.shadowOpacity = 0.8;
    [_iconBtn setTitle:@"⚙️" forState:UIControlStateNormal];
    _iconBtn.titleLabel.font = [UIFont systemFontOfSize:28];
    [_iconBtn addTarget:self action:@selector(iconTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_iconBtn];

    /* Drag icon */
    UIPanGestureRecognizer *iconDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragIcon:)];
    [_iconBtn addGestureRecognizer:iconDrag];

    /* ── Menu panel ── */
    _panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kMenuWidth, kMenuHeight)];
    _panel.hidden = YES;
    _panel.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.10 alpha:0.96];
    _panel.layer.cornerRadius = kCorner;
    _panel.layer.borderWidth  = 1.0;
    _panel.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.08].CGColor;
    _panel.layer.shadowColor  = UIColor.blackColor.CGColor;
    _panel.layer.shadowOffset = CGSizeMake(0, 8);
    _panel.layer.shadowRadius = 20;
    _panel.layer.shadowOpacity = 0.5;
    [self addSubview:_panel];

    CGFloat y  = 0;
    CGFloat pw = kMenuWidth;

    /* Header bar */
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, 48)];
    header.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.20 alpha:1.0];
    UIBezierPath *headerMask = [UIBezierPath bezierPathWithRoundedRect:header.bounds byRoundingCorners:UIRectCornerTopLeft|UIRectCornerTopRight cornerRadii:CGSizeMake(kCorner,kCorner)];
    CAShapeLayer *ml = [CAShapeLayer layer]; ml.path = headerMask.CGPath; header.layer.mask = ml;
    [_panel addSubview:header];

    _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, pw - 40, 48)];
    _titleLbl.text = @"🎯 HoangHa Menu";
    _titleLbl.textColor = [UIColor colorWithRed:0.45 green:0.85 blue:1.0 alpha:1.0];
    _titleLbl.font = [UIFont boldSystemFontOfSize:15];
    [header addSubview:_titleLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(pw - 40, 8, 32, 32);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.6 alpha:1] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    y = 60;

    /* ── Toggle rows ── */
    _espSwitch    = [self addRowInPanel:_panel y:&y label:@"👁  ESP Skeleton"];
    _aimbotSwitch = [self addRowInPanel:_panel y:&y label:@"🎯  Aimbot"];
    _dotsSwitch   = [self addRowInPanel:_panel y:&y label:@"•  Show Dots"];

    [_espSwitch    addTarget:self action:@selector(espToggled:)    forControlEvents:UIControlEventValueChanged];
    [_aimbotSwitch addTarget:self action:@selector(aimbotToggled:) forControlEvents:UIControlEventValueChanged];
    [_dotsSwitch   addTarget:self action:@selector(dotsToggled:)   forControlEvents:UIControlEventValueChanged];

    /* Sync switch states */
    AOTSettingsManager *s = [AOTSettingsManager sharedManager];
    _espSwitch.on    = s.showSkeleton;
    _aimbotSwitch.on = s.aimbotEnabled;
    _dotsSwitch.on   = s.showDots;

    /* Divider */
    y += 4;
    UIView *div1 = [[UIView alloc] initWithFrame:CGRectMake(16, y, pw - 32, 1)];
    div1.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    [_panel addSubview:div1];
    y += 12;

    /* ── Sensitivity slider ── */
    UILabel *sensTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, y, pw - 32, 18)];
    sensTitle.text = @"SENSITIVITY";
    sensTitle.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    sensTitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    [_panel addSubview:sensTitle]; y += 22;

    _sensitivityLbl = [[UILabel alloc] initWithFrame:CGRectMake(pw - 54, y, 40, 22)];
    _sensitivityLbl.textColor = [UIColor colorWithRed:0.45 green:0.85 blue:1.0 alpha:1.0];
    _sensitivityLbl.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    _sensitivityLbl.textAlignment = NSTextAlignmentRight;
    [_panel addSubview:_sensitivityLbl];

    _sensitivitySlider = [[UISlider alloc] initWithFrame:CGRectMake(16, y, pw - 80, 30)];
    _sensitivitySlider.minimumValue = 0.0;
    _sensitivitySlider.maximumValue = 1.0;
    _sensitivitySlider.value = s.sensitivity;
    _sensitivitySlider.minimumTrackTintColor = [UIColor colorWithRed:0.30 green:0.70 blue:1.0 alpha:1.0];
    [_sensitivitySlider addTarget:self action:@selector(sensitivityChanged:) forControlEvents:UIControlEventValueChanged];
    [_panel addSubview:_sensitivitySlider];
    [self updateSensLabel:s.sensitivity];
    y += 38;

    /* Divider */
    UIView *div2 = [[UIView alloc] initWithFrame:CGRectMake(16, y, pw - 32, 1)];
    div2.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    [_panel addSubview:div2];
    y += 12;

    /* ── Dot colour picker ── */
    UILabel *colorTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, y, pw - 32, 18)];
    colorTitle.text = @"DOT COLOUR";
    colorTitle.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    colorTitle.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    [_panel addSubview:colorTitle]; y += 26;

    NSArray<UIColor *> *colors = @[[UIColor colorWithRed:1 green:0.25 blue:0.25 alpha:1],
                                    [UIColor colorWithRed:0.25 green:0.90 blue:0.45 alpha:1],
                                    [UIColor colorWithRed:0.30 green:0.70 blue:1.0 alpha:1],
                                    [UIColor colorWithRed:1 green:0.85 blue:0.15 alpha:1]];
    NSArray<UIButton *> *colorBtns = [self addColorRowInPanel:_panel y:y colors:colors];
    _redBtn    = colorBtns[0];
    _greenBtn  = colorBtns[1];
    _blueBtn   = colorBtns[2];
    _yellowBtn = colorBtns[3];
    y += 46;

    /* Divider */
    UIView *div3 = [[UIView alloc] initWithFrame:CGRectMake(16, y, pw - 32, 1)];
    div3.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    [_panel addSubview:div3];
    y += 12;

    /* ── Status label ── */
    _statusLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, y, pw - 32, 24)];
    _statusLbl.text = @"⚙️ Init...";
    _statusLbl.textColor = [UIColor colorWithWhite:0.55 alpha:1];
    _statusLbl.font = [UIFont systemFontOfSize:11];
    [_panel addSubview:_statusLbl];
    y += 28;

    /* ── Pinned bone label ── */
    _pinnedLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, y, pw - 32, 20)];
    _pinnedLbl.text = @"📌 Pinned: Head";
    _pinnedLbl.textColor = [UIColor colorWithRed:1.0 green:0.9 blue:0.0 alpha:1];
    _pinnedLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    [_panel addSubview:_pinnedLbl];
    y += 26;

    /* ── Bone list table ── */
    _boneTV = [[UITableView alloc] initWithFrame:CGRectMake(16, y, pw - 32, 160)];
    _boneTV.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    _boneTV.layer.cornerRadius = 8;
    _boneTV.separatorColor = [UIColor colorWithWhite:1 alpha:0.06];
    _boneTV.delegate   = (id)self;
    _boneTV.dataSource = (id)self;
    [_panel addSubview:_boneTV];
    y += 168;

    // Resize panel to fit
    CGRect pf = _panel.frame;
    pf.size.height = y + 12;
    _panel.frame = pf;

    /* Drag panel */
    UIPanGestureRecognizer *panelDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPanel:)];
    [_panel addGestureRecognizer:panelDrag];
}

// ─── Helper: toggle row ──────────────────────────────────────
- (UISwitch *)addRowInPanel:(UIView *)panel y:(CGFloat *)y label:(NSString *)label {
    CGFloat pw = kMenuWidth;
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, *y, pw - 80, 36)];
    lbl.text = label;
    lbl.textColor = [UIColor colorWithWhite:0.90 alpha:1];
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    [panel addSubview:lbl];

    UISwitch *sw = [[UISwitch alloc] init];
    sw.center = CGPointMake(pw - 44, *y + 18);
    sw.onTintColor = [UIColor colorWithRed:0.30 green:0.70 blue:1.0 alpha:1.0];
    sw.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [panel addSubview:sw];

    *y += 40;
    return sw;
}

// ─── Helper: colour row ──────────────────────────────────────
- (NSArray<UIButton *> *)addColorRowInPanel:(UIView *)panel y:(CGFloat)y colors:(NSArray<UIColor *> *)colors {
    NSMutableArray *btns = [NSMutableArray array];
    CGFloat size  = 32;
    CGFloat gap   = (kMenuWidth - 32 - size * colors.count) / (colors.count - 1);
    CGFloat xOff  = 16;
    for (UIColor *c in colors) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(xOff, y, size, size);
        b.backgroundColor = c;
        b.layer.cornerRadius = size / 2;
        b.layer.borderWidth  = 2;
        b.layer.borderColor  = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
        [b addTarget:self action:@selector(colorPicked:) forControlEvents:UIControlEventTouchUpInside];
        [panel addSubview:b];
        [btns addObject:b];
        xOff += size + gap;
    }
    return [btns copy];
}

// ─── Toggles ─────────────────────────────────────────────────
- (void)iconTapped {
    if (_menuOpen) {
        [self closePanel];
    } else {
        _panel.hidden = NO;
        /* position panel next to icon */
        CGRect ic = _iconBtn.frame;
        CGFloat px = ic.origin.x + kIconSize + 8;
        if (px + kMenuWidth > self.bounds.size.width - 8)
            px = ic.origin.x - kMenuWidth - 8;
        CGFloat py = ic.origin.y;
        if (py + kMenuHeight > self.bounds.size.height - 20)
            py = self.bounds.size.height - kMenuHeight - 20;
        _panel.frame = CGRectMake(px, py, kMenuWidth, kMenuHeight);
        _panel.alpha = 0; _panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
        [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.4 options:0 animations:^{
            self->_panel.alpha = 1; self->_panel.transform = CGAffineTransformIdentity;
        } completion:nil];
        _menuOpen = YES;
    }
}

- (void)closePanel {
    [UIView animateWithDuration:0.2 animations:^{
        self->_panel.alpha = 0; self->_panel.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:^(BOOL f){ self->_panel.hidden = YES; self->_panel.transform = CGAffineTransformIdentity; }];
    _menuOpen = NO;
}

- (void)toggleMenuVisibility { [self iconTapped]; }

// ─── Drag ────────────────────────────────────────────────────
- (void)dragIcon:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self];
    CGPoint c = _iconBtn.center;
    c.x += t.x; c.y += t.y;
    c.x = MAX(kIconSize/2, MIN(self.bounds.size.width  - kIconSize/2, c.x));
    c.y = MAX(kIconSize/2, MIN(self.bounds.size.height - kIconSize/2, c.y));
    _iconBtn.center = c;
    [g setTranslation:CGPointZero inView:self];
    if (_menuOpen) [self closePanel];
}

- (void)dragPanel:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self];
    _panel.center = CGPointMake(_panel.center.x + t.x, _panel.center.y + t.y);
    [g setTranslation:CGPointZero inView:self];
}

// ─── Actions ─────────────────────────────────────────────────
- (void)espToggled:(UISwitch *)s    { [AOTSettingsManager sharedManager].showSkeleton = s.on; [[AOTSettingsManager sharedManager] saveSettings]; }
- (void)aimbotToggled:(UISwitch *)s { [AOTSettingsManager sharedManager].aimbotEnabled = s.on; [[AOTSettingsManager sharedManager] saveSettings]; }
- (void)dotsToggled:(UISwitch *)s   { [AOTSettingsManager sharedManager].showDots = s.on; [[AOTSettingsManager sharedManager] saveSettings]; }

- (void)sensitivityChanged:(UISlider *)s {
    [self updateSensLabel:s.value];
    [AOTSettingsManager sharedManager].sensitivity = s.value;
    [[AOTSettingsManager sharedManager] saveSettings];
}
- (void)updateSensLabel:(float)v { _sensitivityLbl.text = [NSString stringWithFormat:@"%.2f", v]; }

- (void)colorPicked:(UIButton *)b {
    UIColor *c = b.backgroundColor;
    [AOTSettingsManager sharedManager].dotColor = c;
    [[AOTSettingsManager sharedManager] saveSettings];
    /* border highlight */
    for (UIButton *btn in @[_redBtn, _greenBtn, _blueBtn, _yellowBtn]) {
        btn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
        btn.transform = CGAffineTransformIdentity;
    }
    b.layer.borderColor = [UIColor whiteColor].CGColor;
    b.transform = CGAffineTransformMakeScale(1.15, 1.15);
}


// ─── CADisplayLink update ────────────────────────────────────
- (void)updateOverlay {
    AOTMemoryManager *mem = [AOTMemoryManager sharedManager];

    if (![mem isGameRunning]) {
        [mem tryAttachToGame];
    }

    if ([mem isGameRunning]) {
        [boneManager updateBonePositions];
        renderer.bonePoints = boneManager.bonePositions;

        _statusLbl.text = [NSString stringWithFormat:@"🟢 lp: 0x%llX",
                           (unsigned long long)[mem localPlayer]];
        _statusLbl.textColor = [UIColor colorWithRed:0.30 green:0.90 blue:0.50 alpha:1];

        // ── Aimbot: write aim direction to localPlayer ──────────
        AOTSettingsManager *s = [AOTSettingsManager sharedManager];
        if (s.aimbotEnabled && [boneManager pinnedBoneIndex] >= 0) {
            AOTVector3 target = [boneManager pinnedBoneWorldPosition];
            // localPlayer world pos
            AOTVector3 myPos = [mem readVector3AtOffset:0x78];

            float dx = target.x - myPos.x;
            float dy = target.y - myPos.y;
            float dz = target.z - myPos.z;
            float len = sqrtf(dx*dx + dy*dy + dz*dz);
            if (len > 0.001f) {
                dx /= len; dy /= len; dz /= len;
                uint64_t lp = [mem localPlayer];
                [mem writeFloat:dx atAddress:lp + 0x4A0];
                [mem writeFloat:dy atAddress:lp + 0x4A4];
                [mem writeFloat:dz atAddress:lp + 0x4A8];
                [mem writeInt32:1  atAddress:lp + 0x48C]; // silentShoot = ON
            }
        } else if (![AOTSettingsManager sharedManager].aimbotEnabled) {
            // Release aim lock when aimbot off
            uint64_t lp = [mem localPlayer];
            if (lp) [mem writeInt32:0 atAddress:lp + 0x48C];
        }
    } else {
        renderer.bonePoints = nil;
        _statusLbl.text = @"⚠️ Scanning...";
        _statusLbl.textColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.0 alpha:1];
    }
    [renderer setNeedsDisplay];
}

// ─── Protocol stubs ───────────────────────────────────────────
- (void)renderSkeletonInContext:(CGContextRef)ctx { [renderer drawBonesInContext:ctx]; }
- (void)handleTapOnBoneAtPoint:(CGPoint)point {}
- (void)pinBone:(AOTBone *)bone atIndex:(NSUInteger)index {}

// ─── UITableViewDataSource – bone list ───────────────────────
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return [AOTBoneManager boneCount];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"BoneCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor colorWithWhite:0.88 alpha:1];
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSInteger idx = ip.row;
    NSString *name = [AOTBoneManager boneNameAtIndex:idx];
    BOOL isPinned = ([boneManager pinnedBoneIndex] == idx);
    cell.textLabel.text = isPinned
        ? [NSString stringWithFormat:@"📌 %@  ← PINNED", name]
        : name;
    cell.textLabel.textColor = isPinned
        ? [UIColor colorWithRed:1 green:0.9 blue:0 alpha:1]
        : [UIColor colorWithWhite:0.88 alpha:1];
    return cell;
}

// ─── UITableViewDelegate – tap to pin bone ───────────────────
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSInteger idx = ip.row;
    if ([boneManager pinnedBoneIndex] == idx) {
        // Tap again to unpin
        [boneManager setPinnedBoneIndex:-1];
        _pinnedLbl.text = @"📌 Pinned: none";
        renderer.selectedBone = -1;
    } else {
        [boneManager setPinnedBoneIndex:idx];
        NSString *name = [AOTBoneManager boneNameAtIndex:idx];
        _pinnedLbl.text = [NSString stringWithFormat:@"📌 Pinned: %@", name];
        renderer.selectedBone = idx;
    }
    [tv reloadData];
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    return 32;
}

@end
