@import SFRuntime;

#include "Array.h"

#include <iso646.h>
#include <stdint.h>

#if SF_RUNTIME_EXCEPTIONS
    @interface InvalidArgumentException (SmallFWInternal)
    + (instancetype)exception;
    @end
#endif

#pragma clang assume_nonnull begin

static uint64_t sf_array_hash_word(uint64_t hash, uintptr_t word)
{
    for (size_t i = 0U; i < sizeof(word); ++i) {
        unsigned char byte = (unsigned char)((word >> (i * 8U)) & (uintptr_t)0xffU);
        hash ^= (uint64_t)byte;
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

@implementation Array

@synthesize count = _count;

+ (SF_ERRORABLE(instancetype))arrayWithObjects:(const id nonnil *nillable)objects count:(size_t)count
{
    auto array = [[self allocWithAllocator:nullptr] initWithObjects:objects count:count];
    return [array autorelease];
}

- (SF_ERRORABLE(instancetype))initWithObjects:(const id nonnil *nillable)objects count:(size_t)count
{
    if (count > 0U and objects == nullptr) {
        [self release];
        SF_THROW([InvalidArgumentException exception]);
    }

    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    _count = count;
    if (count == 0U) {
        _items = nullptr;
        return self;
    }

    auto tmp = (id *)[self allocateMemoryWithSize:sizeof(id) * count alignment:alignof(id *)];
    if (tmp == nullptr) {
        [self release];
        return nullptr;
    }

    for (size_t i = 0U; i < count; ++i) {
        auto item = (Object *)objects[i];
        if (item != nullptr) {
            tmp[i] = [item retain];
        } else {
            tmp[i] = nullptr;
        }
    }

    _items = tmp;
    return self;
}

- (SF_ERRORABLE(id))objectAtIndex:(size_t)idx
{
    if (idx >= _count or _items == nullptr) {
#if SF_RUNTIME_EXCEPTIONS
            @throw [InvalidArgumentException exception];
#else
            return nullptr;
#endif
    }
    return (id)_items[idx];
}

- (SF_ERRORABLE(id))objectAtIndexedSubscript:(size_t)idx
{
    return [self objectAtIndex:idx];
}

- (bool)isEqual:(Object *nillable)other
{
    if ((id)self == (id)other) {
        return true;
    }
    if (not[other isKindOfClass:Array.class]) {
        return false;
    }

    auto rhs = (Array *)other;
    if (_count != rhs.count) {
        return false;
    }

    for (size_t i = 0U; i < _count; ++i) {
        auto lhs_obj = _items[i];
        auto rhs_obj = rhs[i];
        if (lhs_obj == rhs_obj) {
            continue;
        }
        if (lhs_obj == nullptr or rhs_obj == nullptr or not[lhs_obj isEqual:rhs_obj]) {
            return false;
        }
    }
    return 1;
}

- (unsigned long)hash
{
    uint64_t hash = UINT64_C(1469598103934665603);
    hash = sf_array_hash_word(hash, (uintptr_t)_count);
    for (size_t i = 0U; i < _count; ++i) {
        hash = sf_array_hash_word(hash, (uintptr_t)[(Object *)_items[i] hash]);
    }
    return (unsigned long)hash;
}

- (void)dealloc
{
    for (size_t i = 0U; i < _count; ++i) {
        if (_items[i] != nullptr) {
            [(Object *)_items[i] release];
        }
    }
    if (_items != nullptr) {
        auto allocator = self.allocator;
        if (allocator != nullptr) {
            allocator->free(allocator->ctx, _items, sizeof(id) * _count, alignof(id));
        }
    }
    [super dealloc];
}

@end
#pragma clang assume_nonnull end
