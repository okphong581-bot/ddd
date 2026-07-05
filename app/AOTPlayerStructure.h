#import <Foundation/Foundation.h>

@interface AOTPlayerStructure : NSObject

@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) float health;
@property (nonatomic, assign) float maxHealth;
@property (nonatomic, assign) int teamId;
@property (nonatomic, assign) BOOL isAlive;
@property (nonatomic, assign) BOOL isVisible;

@end
