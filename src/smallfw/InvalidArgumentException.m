#include "smallfw/Object.h"

#include <stdlib.h>

#include "runtime/abi.h"
#include "runtime/internal.h"

typedef struct SFStaticInvalidArgumentException {
    SFObjHeader_t hdr;
    Class isa;
} SFStaticInvalidArgumentException_t;

@interface InvalidArgumentException (SmallFWInternal)
+ (instancetype)invalidArgumentException;
@end

@implementation InvalidArgumentException

+ (instancetype)invalidArgumentException
{
    static thread_local SFStaticInvalidArgumentException_t fallback;

    id exc = sf_alloc_object((Class)self, sf_default_allocator());
    if (exc != nullptr) {
        return [(InvalidArgumentException *)exc init];
    }

    exc = [self allocInPlace:&fallback size:sizeof(fallback)];
    if (exc != nullptr) {
        return [(InvalidArgumentException *)exc init];
    }
    return nullptr;
}

@end
