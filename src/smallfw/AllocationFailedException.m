#include "smallfw/Object.h"

#include <stdlib.h>

#include "runtime/abi.h"
#include "runtime/internal.h"

typedef struct SFStaticAllocationFailedException {
    SFObjHeader_t hdr;
    Class isa;
} SFStaticAllocationFailedException_t;

@interface AllocationFailedException (SmallFWInternal)
+ (void)raiseForAllocationFailure __attribute__((noreturn));
@end

@implementation AllocationFailedException

+ (instancetype)allocationFailedException
{
    static __thread SFStaticAllocationFailedException_t fallback;

    id exc = sf_alloc_object((Class)self, sf_default_allocator());
    if (exc != NULL) {
        return [(AllocationFailedException *)exc init];
    }

    exc = [self allocInPlace:&fallback size:sizeof(fallback)];
    if (exc != NULL) {
        return [(AllocationFailedException *)exc init];
    }
    return NULL;
}

+ (void)raiseForAllocationFailure
{
#if SF_RUNTIME_EXCEPTIONS
    objc_exception_throw([self allocationFailedException]);
    __builtin_unreachable();
#else
    abort();
#endif
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
