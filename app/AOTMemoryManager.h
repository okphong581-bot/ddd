#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import "AOTVector3.h"

@interface AOTMemoryManager : NSObject

+ (instancetype)sharedManager;

// ─── Game attach / detach ──────────────────────────────────────
- (BOOL)tryAttachToGame;
- (void)detachFromGame;
- (BOOL)isGameRunning;

// ─── Accessors ────────────────────────────────────────────────
- (uint64_t)baseAddress;
- (mach_port_t)taskPort;

// ─── Primitive reads ──────────────────────────────────────────
- (void)setBaseAddress:(uint64_t)base;
- (AOTVector3)readVector3AtOffset:(uint32_t)offset;
- (AOTVector3)readVector3AtAddress:(uint64_t)address;

// ─── Pointer reads ────────────────────────────────────────────
- (uint64_t)readPointerAtOffset:(uint32_t)offset;
- (uint64_t)readPointerAtAddress:(uint64_t)address;

// ─── Scalar reads ─────────────────────────────────────────────
- (float)readFloatAtAddress:(uint64_t)address;
- (uint32_t)readUint32AtAddress:(uint64_t)address;

@end
