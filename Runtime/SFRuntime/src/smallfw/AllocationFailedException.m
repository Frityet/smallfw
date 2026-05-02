#include "smallfw/Object.h"

#include <stdlib.h>

#include "runtime/abi.h"
#include "runtime/internal.h"

typedef struct SFStaticAllocationFailedException {
    SFObjHeader_t hdr;
    Class isa;
} SFStaticAllocationFailedException_t;

@interface AllocationFailedException (SmallFWInternal)
+ (instancetype)allocationFailedException;
@end

@implementation AllocationFailedException

+ (instancetype)allocationFailedException
{
    static thread_local SFStaticAllocationFailedException_t fallback;

    id exc = sf_alloc_object((Class)self, sf_default_allocator());
    if (exc != nullptr) {
        return [(AllocationFailedException *)exc init];
    }

    exc = [self allocInPlace:&fallback size:sizeof(fallback)];
    if (exc != nullptr) {
        return [(AllocationFailedException *)exc init];
    }
    return nullptr;
}

- (size_t)exceptionBacktraceCount
{
    return sf_exception_backtrace_count(self);
}

- (const void *)exceptionBacktraceFrameAtIndex:(size_t)index
{
    return sf_exception_backtrace_frame(self, index);
}

@end
