#import "AOTPlayerStructure.h"

@implementation AOTPlayerStructure

- (instancetype)init {
    self = [super init];
    if (self) {
        _address = 0;
        _health = 100.0;
        _maxHealth = 100.0;
        _teamId = 0;
        _isAlive = YES;
        _isVisible = NO;
    }
    return self;
}

@end
