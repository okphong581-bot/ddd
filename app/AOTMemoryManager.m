#import "AOTMemoryManager.h"
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <string.h>

// ─── Find base address of the main executable in the CURRENT process ─────────
// Since the tweak is injected by Substrate INTO Free Fire, we are already
// running inside the game process. We just walk our own dyld image list.
static uint64_t find_own_base_address(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        // The main executable will contain "freefire", "ffios" or similar.
        // If none match, fall back to image index 0 (always the main exe).
        if (i == 0 ||
            strcasestr(name, "freefire") != NULL ||
            strcasestr(name, "ffios")    != NULL) {
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            // The load address = slide (ASLR offset) + compile-time text base.
            // For the main binary this equals the actual load address directly.
            const struct mach_header *mh = _dyld_get_image_header(i);
            return (uint64_t)(uintptr_t)mh + (uint64_t)(uintptr_t)slide;
        }
    }
    // Absolute fallback – just return the slide of image 0
    return (uint64_t)(uintptr_t)_dyld_get_image_header(0);
}

@implementation AOTMemoryManager {
    uint64_t    _baseAddress;
    mach_port_t _task;
}

+ (instancetype)sharedManager {
    static AOTMemoryManager *inst = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        inst = [[AOTMemoryManager alloc] init];
        // We are already inside the game process – use mach_task_self()
        inst->_task        = mach_task_self();
        inst->_baseAddress = find_own_base_address();
    });
    return inst;
}

// ─── Attach (no-op for injected tweak – always attached) ─────────────────────
- (BOOL)tryAttachToGame {
    if (_baseAddress == 0) {
        _baseAddress = find_own_base_address();
    }
    return _baseAddress != 0;
}

- (void)detachFromGame {
    // Never detach – we live inside the game process.
    // Only reset base if explicitly needed.
}

// ─── isGameRunning: since we are injected, always YES ────────────────────────
- (BOOL)isGameRunning {
    return _baseAddress != 0;
}

// ─── Accessors ───────────────────────────────────────────────────────────────
- (uint64_t)baseAddress    { return _baseAddress; }
- (mach_port_t)taskPort    { return _task; }
- (void)setBaseAddress:(uint64_t)base { _baseAddress = base; }

// ─── Low-level read helper ───────────────────────────────────────────────────
- (BOOL)_read:(uint64_t)addr into:(void *)buf size:(size_t)size {
    if (addr == 0) return NO;
    // Inside the same process – just memcpy directly (no vm_read needed)
    @try {
        memcpy(buf, (const void *)(uintptr_t)addr, size);
        return YES;
    } @catch (...) {
        return NO;
    }
}

// ─── AOTVector3 ──────────────────────────────────────────────────────────────
- (AOTVector3)readVector3AtOffset:(uint32_t)offset {
    return [self readVector3AtAddress:_baseAddress + offset];
}

- (AOTVector3)readVector3AtAddress:(uint64_t)addr {
    AOTVector3 v = {0, 0, 0};
    [self _read:addr into:&v size:sizeof(v)];
    return v;
}

// ─── Pointer reads ───────────────────────────────────────────────────────────
- (uint64_t)readPointerAtOffset:(uint32_t)offset {
    return [self readPointerAtAddress:_baseAddress + offset];
}

- (uint64_t)readPointerAtAddress:(uint64_t)addr {
    uint64_t v = 0;
    [self _read:addr into:&v size:sizeof(v)];
    return v;
}

// ─── Scalar reads ────────────────────────────────────────────────────────────
- (float)readFloatAtAddress:(uint64_t)addr {
    float v = 0;
    [self _read:addr into:&v size:sizeof(v)];
    return v;
}

- (uint32_t)readUint32AtAddress:(uint64_t)addr {
    uint32_t v = 0;
    [self _read:addr into:&v size:sizeof(v)];
    return v;
}

@end
