#import "AOTMemoryManager.h"
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <stdlib.h>
#import <string.h>

static bool match_game_name(const char *name) {
    if (!name || !*name) return false;
    if (strcasestr(name, "freefire")) return true;
    if (strcasestr(name, "ffios")) return true;
    return false;
}

static pid_t find_game_pid(void) {
    int mib[3] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL};
    size_t size = 0;
    if (sysctl(mib, 3, NULL, &size, NULL, 0) != 0) return -1;
    struct kinfo_proc *procs = (struct kinfo_proc*)malloc(size);
    if (!procs) return -1;
    memset(procs, 0, size);
    if (sysctl(mib, 3, procs, &size, NULL, 0) != 0) { free(procs); return -1; }

    pid_t found = -1;
    pid_t my_pid = getpid();
    int count = (int)(size / sizeof(struct kinfo_proc));
    for (int i = 0; i < count; i++) {
        pid_t pid = procs[i].kp_proc.p_pid;
        if (pid == 0 || pid == my_pid) continue;
        if (match_game_name(procs[i].kp_proc.p_comm)) { found = pid; break; }
    }
    free(procs);
    return found;
}

static uint64_t find_base_address(task_t task) {
    struct task_dyld_info dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    if (task_info(task, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count) != KERN_SUCCESS)
        return 0;

    uint64_t header[3];
    vm_size_t outSize = 24;
    if (vm_read_overwrite(task, (vm_address_t)dyld_info.all_image_info_addr,
            24, (vm_address_t)header, &outSize) != KERN_SUCCESS)
        return 0;

    uint32_t imgCount = (uint32_t)(header[0] >> 32);
    uint64_t infoArrayPtr = header[1];
    if (imgCount == 0 || infoArrayPtr == 0) return 0;

    size_t imgSize = imgCount * 24;
    uint64_t *imgData = (uint64_t*)malloc(imgSize);
    if (!imgData) return 0;

    vm_size_t readSize = (vm_size_t)imgSize;
    kern_return_t ret = vm_read_overwrite(task, (vm_address_t)infoArrayPtr,
                           (vm_size_t)imgSize, (vm_address_t)imgData, &readSize);
    uint64_t base = 0;
    uint64_t fallbackBase = 0;
    if (ret == KERN_SUCCESS) {
        int nImg = (int)(readSize / 24);
        for (int i = 0; i < nImg; i++) {
            uint64_t loadAddr = imgData[i * 3];
            uint64_t filePath = imgData[i * 3 + 1];
            if (filePath == 0) continue;
            char nameBuf[256];
            memset(nameBuf, 0, sizeof(nameBuf));
            vm_size_t ns = sizeof(nameBuf) - 1;
            if (vm_read_overwrite(task, (vm_address_t)filePath,
                    ns, (vm_address_t)nameBuf, &ns) == KERN_SUCCESS) {
                nameBuf[ns] = '\0';
                if (i == 0) {
                    fallbackBase = loadAddr;
                }
                if (strcasestr(nameBuf, "libil2cpp") ||
                    strcasestr(nameBuf, "unityframework") ||
                    strcasestr(nameBuf, "ffios") ||
                    strcasestr(nameBuf, "freefire")) {
                    base = loadAddr;
                    break;
                }
            }
        }
    }
    free(imgData);
    if (base == 0) {
        base = fallbackBase;
    }
    return base;
}

@implementation AOTMemoryManager {
    uint64_t _baseAddress;
    mach_port_t _task;
    pid_t _pid;
}

+ (instancetype)sharedManager {
    static AOTMemoryManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance->_task = TASK_NULL;
        instance->_baseAddress = 0;
        instance->_pid = -1;
    });
    return instance;
}

- (AOTVector3)readVector3AtOffset:(uint32_t)offset {
    AOTVector3 vec = {0, 0, 0};
    if (_task == TASK_NULL || _baseAddress == 0) return vec;
    
    uint64_t address = _baseAddress + offset;
    size_t size = sizeof(AOTVector3);
    kern_return_t kr = vm_read_overwrite(_task, address, size, (vm_address_t)&vec, &size);
    
    if (kr != KERN_SUCCESS) {
        // fallback
    }
    return vec;
}

- (void)setBaseAddress:(uint64_t)base {
    _baseAddress = base;
}

- (BOOL)isGameRunning {
    if (_task == TASK_NULL || _baseAddress == 0) return NO;
    // Probe memory to see if task is still valid
    int probe = 0;
    vm_size_t size = sizeof(probe);
    kern_return_t kr = vm_read_overwrite(_task, _baseAddress, size, (vm_address_t)&probe, &size);
    if (kr != KERN_SUCCESS) {
        [self detachFromGame];
        return NO;
    }
    return YES;
}

- (BOOL)tryAttachToGame {
    if ([self isGameRunning]) return YES;
    
    pid_t pid = find_game_pid();
    if (pid <= 0) return NO;
    
    task_t task;
    kern_return_t ret = task_for_pid(mach_task_self(), pid, &task);
    if (ret != KERN_SUCCESS) return NO;
    
    uint64_t base = find_base_address(task);
    if (base == 0) {
        mach_port_deallocate(mach_task_self(), task);
        return NO;
    }
    
    _task = task;
    _baseAddress = base;
    _pid = pid;
    return YES;
}

- (void)detachFromGame {
    if (_task != TASK_NULL) {
        mach_port_deallocate(mach_task_self(), _task);
        _task = TASK_NULL;
    }
    _baseAddress = 0;
    _pid = -1;
}

- (uint64_t)baseAddress { return _baseAddress; }
- (mach_port_t)taskPort { return _task; }

@end
