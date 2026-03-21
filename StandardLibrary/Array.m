#include "Array.h"
#include "runtime/c2x-compat.h"

#include <iso646.h>
#include <stdint.h>

#if SF_RUNTIME_EXCEPTIONS
@interface InvalidArgumentException (SmallFWInternal)
+ (instancetype)exception;
@end
#endif

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

+ (instancetype)arrayWithObjects: (const id _Nonnull * _Nullable)objects count: (size_t)count
{
    Array *array = [[self allocWithAllocator: nullptr] initWithObjects: objects count: count];
    return [array autorelease];
}

- (instancetype)initWithObjects: (const id _Nonnull * _Nullable)objects count: (size_t)count
{
    if (count > 0U and objects == nullptr) {
        [self release];
#if SF_RUNTIME_EXCEPTIONS
        @throw [InvalidArgumentException exception];
#endif
        return nullptr;
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

    id *tmp = (id *)[self allocateMemoryWithSize: sizeof(id) * count alignment: alignof(id *)];
    if (tmp == nullptr) {
        [self release];
        return nullptr;
    }

    for (size_t i = 0U; i < count; ++i) {
        Object *item = (Object *)objects[i];
        if (item != nullptr) {
            tmp[i] = [item retain];
        } else {
            tmp[i] = nullptr;
        }
    }

    _items = tmp;
    return self;
}

- (id)objectAtIndex: (size_t)idx
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

- (id)objectAtIndexedSubscript: (size_t)idx
{
    return [self objectAtIndex: idx];
}

- (bool)isEqual: (Object *)other
{
    if ((id)self == (id)other) {
        return true;
    }
    if (not [other isKindOfClass: Array.class]) {
        return false;
    }

    Array<Object *> *rhs = (Array *)other;
    if (_count != rhs.count) {
        return false;
    }

    for (size_t i = 0U; i < _count; ++i) {
        Object *lhs_obj = _items[i];
        Object *rhs_obj = rhs[i];
        if (lhs_obj == rhs_obj) {
            continue;
        }
        if (lhs_obj == nullptr or rhs_obj == nullptr or not [lhs_obj isEqual: rhs_obj]) {
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
        SFAllocator_t *allocator = self.allocator;
        if (allocator != nullptr) {
            allocator->free(allocator->ctx, _items, sizeof(id) * _count, alignof(id));
        }
    }
    [super dealloc];
}

@end
