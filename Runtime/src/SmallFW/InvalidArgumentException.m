#include "SmallFW/Object.h"

#include <stdlib.h>

#include "abi.h"
#include "internal.h"

#pragma clang assume_nonnull begin

typedef struct SFStaticInvalidArgumentException {
    SFObjHeader_t hdr;
    Class isa;
} SFStaticInvalidArgumentException_t;

@implementation InvalidArgumentException

+ (instancetype)exception
{
    static thread_local SFStaticInvalidArgumentException_t fallback;

    auto exc = sf_alloc_object((Class)self, sf_default_allocator());
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
#pragma clang assume_nonnull end
