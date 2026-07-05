#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import "AOTVector3.h"

@interface AOTMemoryManager : NSObject

+ (instancetype)sharedManager;

// Game state
- (BOOL)tryAttachToGame;
- (void)detachFromGame;
- (BOOL)isGameRunning;

// Accessors
- (uint64_t)baseAddress;
- (uint64_t)localPlayer;
- (mach_port_t)taskPort;
- (void)setBaseAddress:(uint64_t)base;

// Read (offset relative to localPlayer for bones)
- (AOTVector3)readVector3AtOffset:(uint32_t)offset;
- (AOTVector3)readVector3AtAddress:(uint64_t)address;
- (uint64_t)readPointerAtOffset:(uint32_t)offset;
- (uint64_t)readPointerAtAddress:(uint64_t)address;
- (float)readFloatAtAddress:(uint64_t)address;
- (uint32_t)readUint32AtAddress:(uint64_t)address;

// Write (aimbot)
- (void)writeFloat:(float)val atAddress:(uint64_t)addr;
- (void)writeInt32:(int32_t)val atAddress:(uint64_t)addr;

@end
