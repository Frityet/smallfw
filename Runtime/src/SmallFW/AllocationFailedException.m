#include "SmallFW/Object.h"

#include <stdlib.h>

#include "abi.h"
#include "internal.h"

#pragma clang assume_nonnull begin

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

    auto exc = sf_alloc_object((Class)self, sf_default_allocator());
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

- (const void *nillable)exceptionBacktraceFrameAtIndex:(size_t)index
{
    return sf_exception_backtrace_frame(self, index);
}

@end
#pragma clang assume_nonnull end
