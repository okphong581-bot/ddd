#import "AOTMatrix4x4.h"
#import "AOTMemoryManager.h"
#import <string.h>
#import <mach/mach.h>

// ─── Unity Camera VP-matrix offsets ──────────────────────────────────────────
// In Free Fire (Unity il2cpp) the Camera object keeps the VP matrix at
// GfxDevice + 0x38 → ViewMatrix block, or via the Camera component chain.
// A reliable cross-version trick is to scan for the magic "BGFX" string and
// walk backwards; but the simplest that works for most builds is the
// ComponentArray pointer chain shown below.
//
// Chain (arm64, OA 64-bit):
//   baseAddr + OFFSET_GOBJ_MGR  → GObjectManager*
//   [0x8]                       → first Camera GameObject
//   [0x10]                      → CameraComponent*
//   [OFFSET_VP_MATRIX]          → float[16] ViewProjection matrix
//
// If the VP matrix reads all-zero the offsets need refreshing with IDA/Frida.
#define OFFSET_GOBJ_MGR   0xC8F3A58ULL   // GObjectManager (update if needed)
#define OFFSET_VP_MATRIX  0x2B4          // VP matrix within CameraComponent

@implementation AOTMatrix4x4 {
    float m[4][4];
}

// ─── Shared mutable instance updated every frame ──────────────────────────────
+ (AOTMatrix4x4 *)getViewProjectionMatrix {
    static AOTMatrix4x4 *shared = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ shared = [[AOTMatrix4x4 alloc] init]; });

    AOTMemoryManager *mem = [AOTMemoryManager sharedManager];
    if (![mem isGameRunning]) return shared;

    // ── Walk pointer chain to camera VP matrix ──
    uint64_t gobjMgr  = [mem readPointerAtOffset:(uint32_t)OFFSET_GOBJ_MGR];
    if (!gobjMgr) return shared;

    uint64_t cameraGO  = [mem readPointerAtAddress:gobjMgr + 0x8];
    if (!cameraGO)  return shared;

    uint64_t cameraCmp = [mem readPointerAtAddress:cameraGO + 0x10];
    if (!cameraCmp) return shared;

    uint64_t matrixAddr = cameraCmp + OFFSET_VP_MATRIX;

    float raw[16];
    vm_size_t sz = sizeof(raw);
    kern_return_t kr = vm_read_overwrite([mem taskPort],
                                         (vm_address_t)matrixAddr,
                                         sz,
                                         (vm_address_t)raw,
                                         &sz);
    if (kr == KERN_SUCCESS && sz == sizeof(raw)) {
        // row-major → our m[row][col]
        memcpy(shared->m, raw, sizeof(raw));
    }
    return shared;
}

// ─── Identity matrix constructor ──────────────────────────────────────────────
+ (instancetype)identity {
    AOTMatrix4x4 *mat = [[AOTMatrix4x4 alloc] init];
    memset(mat->m, 0, sizeof(mat->m));
    mat->m[0][0] = mat->m[1][1] = mat->m[2][2] = mat->m[3][3] = 1.0f;
    return mat;
}

// ─── Homogeneous multiply (returns clip-space coords) ─────────────────────────
- (AOTVector3)multiplyVector:(AOTVector3)v {
    float x = v.x * m[0][0] + v.y * m[0][1] + v.z * m[0][2] + m[0][3];
    float y = v.x * m[1][0] + v.y * m[1][1] + v.z * m[1][2] + m[1][3];
    float w = v.x * m[3][0] + v.y * m[3][1] + v.z * m[3][2] + m[3][3];
    // perspective divide; z carries the w for screen-space division in BoneManager
    AOTVector3 r;
    r.x = x;
    r.y = y;
    r.z = (w == 0.0f) ? 0.001f : w;   // avoid division by zero
    return r;
}

@end
