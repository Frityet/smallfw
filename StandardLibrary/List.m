#include "List.h"

#import "c2x-compat.h"

#include <stdint.h>
#include <string.h>

#if SF_RUNTIME_EXCEPTIONS
@interface AllocationFailedException (SmallFWInternal)
+ (instancetype)allocationFailedException;
@end

@interface InvalidArgumentException (SmallFWInternal)
+ (instancetype)exception;
@end
#endif

#pragma clang assume_nonnull begin

static uint64_t sf_list_hash_word(uint64_t hash, uintptr_t word)
{
    for (size_t i = 0U; i < sizeof(word); ++i) {
        unsigned char byte = (unsigned char)((word >> (i * 8U)) & (uintptr_t)0xffU);
        hash ^= (uint64_t)byte;
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

static int sf_list_capacity_bytes(size_t capacity, size_t *bytes_out)
{
    if (bytes_out == nullptr) {
        return 0;
    }
    if (capacity > (SIZE_MAX / sizeof(id))) {
        return 0;
    }
    *bytes_out = capacity * sizeof(id);
    return 1;
}

@implementation List

@synthesize count = _count;

- (instancetype)init
{
    return [self initWithCapacity: 0U];
}

- (SF_ERRORABLE(instancetype))initWithCapacity: (size_t)capacity
{
    size_t bytes = 0U;

    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    _count = 0U;
    _capacity = 0U;
    _items = nullptr;
    if (capacity == 0U) {
        return self;
    }

    if (not sf_list_capacity_bytes(capacity, &bytes)) {
        [self release];
#if SF_RUNTIME_EXCEPTIONS
        @throw [AllocationFailedException allocationFailedException];
#endif
        return nullptr;
    }

    id *tmp = (id *)self.allocator->alloc(self.allocator->ctx, bytes, alignof(id));
    if (tmp == nullptr) {
        [self release];
#if SF_RUNTIME_EXCEPTIONS
        @throw [AllocationFailedException allocationFailedException];
#endif
        return nullptr;
    }

    memset(tmp, 0, bytes);
    _items = tmp;
    _capacity = capacity;
    return self;
}

- (bool)growToFit: (size_t)min_capacity
{
    size_t new_capacity = 0U;
    size_t bytes = 0U;
    id *tmp = nullptr;

    if (min_capacity <= _capacity) {
        return true;
    }

    new_capacity = (_capacity == 0U) ? 4U : _capacity;
    while (new_capacity < min_capacity) {
        if (new_capacity > (SIZE_MAX / 2U)) {
            new_capacity = min_capacity;
            break;
        }
        new_capacity *= 2U;
    }
    if (new_capacity < min_capacity or not sf_list_capacity_bytes(new_capacity, &bytes)) {
#if SF_RUNTIME_EXCEPTIONS
        @throw [AllocationFailedException allocationFailedException];
#endif
        return false;
    }

    tmp = (id *)self.allocator->alloc(self.allocator->ctx, bytes, alignof(id));
    if (tmp == nullptr) {
#if SF_RUNTIME_EXCEPTIONS
        @throw [AllocationFailedException allocationFailedException];
#endif
        return false;
    }

    memset(tmp, 0, bytes);
    for (size_t i = 0U; i < _count; ++i) {
        tmp[i] = _items[i];
    }

    SFAllocator_t *allocator = self.allocator;
    if (allocator != nullptr and _items != nullptr) {
        allocator->free(allocator->ctx, _items, sizeof(id) * _capacity, alignof(id));
    }

    _items = tmp;
    _capacity = new_capacity;
    return true;
}

#if SF_RUNTIME_EXCEPTIONS
- (void)addObject: (id)object
#else
- (bool)addObject: (id)object
#endif
{
    if (object == nullptr) {
#if SF_RUNTIME_EXCEPTIONS
        @throw [InvalidArgumentException exception];
#else
        return false;
#endif
    }
#if SF_RUNTIME_GENERIC_METADATA
    if ([object class] != (Class)self.genericTypeClass) {
#if SF_RUNTIME_EXCEPTIONS
        @throw [InvalidArgumentException exception];
#else
        return false;
#endif
    }
#endif

    if (not [self growToFit: _count + 1U]) {
#if SF_RUNTIME_EXCEPTIONS
        __builtin_unreachable();
#else
        return false;
#endif
    }

    _items[_count] = [(Object *)object retain];
    ++_count;
#if not SF_RUNTIME_EXCEPTIONS
    return true;
#endif
}

- (SF_ERRORABLE(id))objectAtIndex: (size_t)idx
{
    if (idx >= _count or _items == nullptr) {
#if SF_RUNTIME_EXCEPTIONS
        @throw [IndexOutOfBoundsException indexOutOfBoundsException];
#else
        return nullptr;
#endif
    }
    return _items[idx];
}

- (SF_ERRORABLE(id))objectAtIndexedSubscript: (size_t)idx
{
    return [self objectAtIndex: idx];
}

- (bool)isEqual: (Object *_Nullable)other
{
    if ((id)self == (id)other) {
        return true;
    }
    if (not [other isKindOfClass: List.class]) {
        return false;
    }

    List<Object *> *rhs = (List *)other;
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
    return true;
}

- (unsigned long)hash
{
    uint64_t hash = UINT64_C(1469598103934665603);

    hash = sf_list_hash_word(hash, (uintptr_t)_count);
    for (size_t i = 0U; i < _count; ++i) {
        hash = sf_list_hash_word(hash, (uintptr_t)[(Object *)_items[i] hash]);
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
            allocator->free(allocator->ctx, _items, sizeof(id) * _capacity, alignof(id));
        }
    }
    [super dealloc];
}

@end

#pragma clang assume_nonnull end
