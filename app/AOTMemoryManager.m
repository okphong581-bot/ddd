#import "AOTMemoryManager.h"
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <string.h>
#import <stdlib.h>

// ─── Offsets (from AutoScanner.c in FFESP) ───────────────────────────────────
// Chain: il2cppBase + INIT_BASE_OFF → [+SC_OFF] → [+MATCH_OFF] → [+LP_OFF] = localPlayer
#define INIT_BASE_OFF  0xA986B7CUL   // il2cpp offset to InitBase pointer
#define SC_OFF         0x5C          // InitBase → StaticClass
#define MATCH_OFF      0x50          // StaticClass → CurrentMatch
#define LP_OFF         0x94          // CurrentMatch → LocalPlayer

// Bone offsets are relative to localPlayer
// World position of player: localPlayer + 0x78
#define PLAYER_POS_OFF 0x78

// ─── Find il2cpp base from dyld image list ───────────────────────────────────
static uint64_t find_il2cpp_base(void) {
    uint32_t count = _dyld_image_count();
    uint64_t mainBase = 0;
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (i == 0) {
            mainBase = (uint64_t)(uintptr_t)_dyld_get_image_header(i);
        }
        if (name) {
            if (strcasestr(name, "libil2cpp") != NULL ||
                strcasestr(name, "unityframework") != NULL ||
                strcasestr(name, "ffios") != NULL ||
                strcasestr(name, "freefire") != NULL) {
                return (uint64_t)(uintptr_t)_dyld_get_image_header(i);
            }
        }
    }
    // If no match, use main binary
    return mainBase;
}

// ─── Safe in-process memcpy with guard ───────────────────────────────────────
static BOOL safe_read(uint64_t addr, void *buf, size_t size) {
    if (addr < 0x10000ULL || addr > 0x1000000000000ULL) return NO;
    @try {
        memcpy(buf, (const void *)(uintptr_t)addr, size);
        return YES;
    } @catch (...) {
        return NO;
    }
}

static uint64_t read_ptr(uint64_t addr) {
    uint64_t v = 0;
    safe_read(addr, &v, sizeof(v));
    return v;
}

@implementation AOTMemoryManager {
    uint64_t    _baseAddress;      // il2cpp / main binary base
    uint64_t    _localPlayer;      // pointer to LocalPlayer object
    mach_port_t _task;
}

+ (instancetype)sharedManager {
    static AOTMemoryManager *inst = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        inst = [[AOTMemoryManager alloc] init];
        inst->_task        = mach_task_self();
        inst->_baseAddress = 0;
        inst->_localPlayer = 0;
    });
    return inst;
}

// ─── Attach: walk pointer chain to find localPlayer ──────────────────────────
- (BOOL)tryAttachToGame {
    if (_baseAddress == 0) {
        _baseAddress = find_il2cpp_base();
    }
    if (_baseAddress == 0) return NO;

    // Walk: base + INIT_BASE_OFF → initPtr
    uint64_t initPtr = read_ptr(_baseAddress + INIT_BASE_OFF);
    if (initPtr < 0x10000ULL) { _localPlayer = 0; return NO; }

    // initPtr + SC_OFF → staticClass
    uint64_t sc = read_ptr(initPtr + SC_OFF);
    if (sc < 0x10000ULL) { _localPlayer = 0; return NO; }

    // staticClass + MATCH_OFF → currentMatch
    uint64_t match = read_ptr(sc + MATCH_OFF);
    if (match < 0x10000ULL) { _localPlayer = 0; return NO; }

    // currentMatch + LP_OFF → localPlayer
    uint64_t lp = read_ptr(match + LP_OFF);
    if (lp < 0x10000ULL) { _localPlayer = 0; return NO; }

    // Validate: player world pos must be non-zero and within bounds
    float x = 0, z = 0;
    safe_read(lp + PLAYER_POS_OFF,     &x, 4);
    safe_read(lp + PLAYER_POS_OFF + 8, &z, 4);
    if (x == 0.0f && z == 0.0f) { _localPlayer = 0; return NO; }
    if (fabsf(x) > 1000000.0f || fabsf(z) > 1000000.0f) { _localPlayer = 0; return NO; }

    _localPlayer = lp;
    return YES;
}

- (void)detachFromGame {
    _localPlayer = 0;
    // Keep _baseAddress for reattach
}

- (BOOL)isGameRunning {
    return _localPlayer != 0;
}

// ─── Accessors ───────────────────────────────────────────────────────────────
- (uint64_t)baseAddress     { return _baseAddress; }
- (uint64_t)localPlayer     { return _localPlayer; }
- (mach_port_t)taskPort     { return _task; }
- (void)setBaseAddress:(uint64_t)base { _baseAddress = base; }

// ─── Read helpers ─────────────────────────────────────────────────────────────

// Reads Vector3 at (localPlayer + offset)
- (AOTVector3)readVector3AtOffset:(uint32_t)offset {
    return [self readVector3AtAddress:_localPlayer + offset];
}

- (AOTVector3)readVector3AtAddress:(uint64_t)addr {
    AOTVector3 v = {0, 0, 0};
    safe_read(addr, &v, sizeof(v));
    return v;
}

- (uint64_t)readPointerAtOffset:(uint32_t)offset {
    return read_ptr(_baseAddress + offset);
}

- (uint64_t)readPointerAtAddress:(uint64_t)addr {
    return read_ptr(addr);
}

- (float)readFloatAtAddress:(uint64_t)addr {
    float v = 0;
    safe_read(addr, &v, sizeof(v));
    return v;
}

- (uint32_t)readUint32AtAddress:(uint64_t)addr {
    uint32_t v = 0;
    safe_read(addr, &v, sizeof(v));
    return v;
}

// ─── Write helpers (for aimbot) ───────────────────────────────────────────────
- (void)writeFloat:(float)val atAddress:(uint64_t)addr {
    if (addr < 0x100000000ULL) return;
    @try { *(float *)(uintptr_t)addr = val; } @catch (...) {}
}

- (void)writeInt32:(int32_t)val atAddress:(uint64_t)addr {
    if (addr < 0x100000000ULL) return;
    @try { *(int32_t *)(uintptr_t)addr = val; } @catch (...) {}
}

@end
