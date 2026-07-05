#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import "AOTVector3.h"

@interface AOTMemoryManager : NSObject

+ (instancetype)sharedManager;
- (AOTVector3)readVector3AtOffset:(uint32_t)offset;
- (void)setBaseAddress:(uint64_t)base;
- (BOOL)isGameRunning;

- (BOOL)tryAttachToGame;
- (void)detachFromGame;
- (uint64_t)baseAddress;
- (mach_port_t)taskPort;

@end
