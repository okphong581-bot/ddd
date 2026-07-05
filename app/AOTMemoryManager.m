#import "AOTMemoryManager.h"
#import <dlfcn.h>

@implementation AOTMemoryManager {
    uint64_t _baseAddress;
    mach_port_t _task;
}

+ (instancetype)sharedManager {
    static AOTMemoryManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance->_task = mach_task_self();
    });
    return instance;
}

- (AOTVector3)readVector3AtOffset:(uint32_t)offset {
    AOTVector3 vec = {0, 0, 0};
    if (_baseAddress == 0) return vec;
    
    uint64_t address = _baseAddress + offset;
    size_t size = sizeof(AOTVector3);
    kern_return_t kr = vm_read_overwrite(_task, address, size, (vm_address_t)&vec, &size);
    
    if (kr != KERN_SUCCESS) {
        // fallback: return zero
    }
    return vec;
}

- (void)setBaseAddress:(uint64_t)base {
    _baseAddress = base;
}

- (BOOL)isGameRunning {
    return _baseAddress != 0;
}

@end
