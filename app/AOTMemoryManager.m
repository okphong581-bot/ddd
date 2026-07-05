#import "AOTMemoryManager.h"
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <stdlib.h>
#import <string.h>

// ─── Helpers ─────────────────────────────────────────────────────────────────
static bool name_is_game(const char *name) {
    if (!name || !*name) return false;
    return (strcasestr(name, "freefire")   != NULL ||
            strcasestr(name, "ffios")      != NULL ||
            strcasestr(name, "freefireth") != NULL);
}

static pid_t find_game_pid(void) {
    int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
    size_t sz = 0;
    if (sysctl(mib, 3, NULL, &sz, NULL, 0) != 0 || sz == 0) return -1;

    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(sz);
    if (!procs) return -1;
    memset(procs, 0, sz);
    if (sysctl(mib, 3, procs, &sz, NULL, 0) != 0) { free(procs); return -1; }

    pid_t found = -1;
    pid_t me = getpid();
    int n = (int)(sz / sizeof(struct kinfo_proc));
    for (int i = 0; i < n; i++) {
        pid_t pid = procs[i].kp_proc.p_pid;
        if (pid <= 0 || pid == me) continue;
        if (name_is_game(procs[i].kp_proc.p_comm)) { found = pid; break; }
    }
    free(procs);
    return found;
}

// Walk dyld image list to find the main executable base address.
static uint64_t read_base_address(task_t task) {
    // Method 1: TASK_DYLD_INFO
    struct task_dyld_info di;
    mach_msg_type_number_t cnt = TASK_DYLD_INFO_COUNT;
    if (task_info(task, TASK_DYLD_INFO, (task_info_t)&di, &cnt) != KERN_SUCCESS) return 0;

    // all_image_infos struct: [version(4), infoArrayCount(4), infoArray(8), ...]
    uint64_t header[4] = {0};
    vm_size_t outSz = sizeof(header);
    if (vm_read_overwrite(task, (vm_address_t)di.all_image_info_addr,
                          sizeof(header), (vm_address_t)header, &outSz) != KERN_SUCCESS)
        return 0;

    uint32_t count      = (uint32_t)(header[0] >> 32);
    uint64_t infoArray  = header[1];
    if (count == 0 || infoArray == 0) return 0;

    // Each dyld_image_info: imageLoadAddress(8), imageFilePath(8), imageFileModDate(8)
    uint64_t entry[3] = {0};
    outSz = sizeof(entry);
    if (vm_read_overwrite(task, (vm_address_t)infoArray,
                          sizeof(entry), (vm_address_t)entry, &outSz) != KERN_SUCCESS)
        return 0;

    return entry[0]; // first image = main executable
}

// ─── Implementation ──────────────────────────────────────────────────────────
@implementation AOTMemoryManager {
    uint64_t    _baseAddress;
    mach_port_t _task;
    pid_t       _pid;
}

+ (instancetype)sharedManager {
    static AOTMemoryManager *inst = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        inst = [[AOTMemoryManager alloc] init];
        inst->_task        = TASK_NULL;
        inst->_baseAddress = 0;
        inst->_pid         = -1;
    });
    return inst;
}

// ─── Attach ──────────────────────────────────────────────────────────────────
- (BOOL)tryAttachToGame {
    if ([self isGameRunning]) return YES;

    pid_t pid = find_game_pid();
    if (pid <= 0) return NO;

    task_t t;
    if (task_for_pid(mach_task_self(), pid, &t) != KERN_SUCCESS) return NO;

    uint64_t base = read_base_address(t);
    if (base == 0) { mach_port_deallocate(mach_task_self(), t); return NO; }

    _task        = t;
    _baseAddress = base;
    _pid         = pid;
    return YES;
}

- (void)detachFromGame {
    if (_task != TASK_NULL) {
        mach_port_deallocate(mach_task_self(), _task);
        _task = TASK_NULL;
    }
    _baseAddress = 0;
    _pid         = -1;
}

- (BOOL)isGameRunning {
    if (_task == TASK_NULL || _baseAddress == 0) return NO;
    // Probe one byte to verify task is still alive
    uint8_t probe = 0;
    vm_size_t sz  = 1;
    kern_return_t kr = vm_read_overwrite(_task, (vm_address_t)_baseAddress, 1,
                                         (vm_address_t)&probe, &sz);
    if (kr != KERN_SUCCESS) {
        [self detachFromGame];
        return NO;
    }
    return YES;
}

// ─── Accessors ───────────────────────────────────────────────────────────────
- (uint64_t)baseAddress    { return _baseAddress; }
- (mach_port_t)taskPort    { return _task; }
- (void)setBaseAddress:(uint64_t)base { _baseAddress = base; }

// ─── Low-level read helper ───────────────────────────────────────────────────
- (BOOL)_read:(uint64_t)addr into:(void *)buf size:(size_t)size {
    if (_task == TASK_NULL) return NO;
    vm_size_t outSz = (vm_size_t)size;
    return vm_read_overwrite(_task, (vm_address_t)addr,
                             (vm_size_t)size, (vm_address_t)buf, &outSz) == KERN_SUCCESS
           && outSz == size;
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
