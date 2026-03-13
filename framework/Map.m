#include "Map.h"
#include "runtime/c2x-compat.h"

#include <iso646.h>
#include <stdint.h>

#if SF_RUNTIME_EXCEPTIONS
@interface InvalidArgumentException (SmallFWInternal)
+ (instancetype)invalidArgumentException;
@end
#endif

static uint64_t sf_map_hash_word(uint64_t hash, uintptr_t word)
{
    for (size_t i = 0U; i < sizeof(word); ++i) {
        unsigned char byte = (unsigned char)((word >> (i * 8U)) & (uintptr_t)0xffU);
        hash ^= (uint64_t)byte;
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

static int sf_map_keys_equal(id lhs, id rhs)
{
    if (lhs == rhs) {
        return 1;
    }
    if (lhs == nullptr or rhs == nullptr) {
        return 0;
    }
    return [(Object *)lhs isEqual: rhs];
}

@implementation Map

@synthesize count = _count;

+ (instancetype)dictionaryWithObjects: (const id _Nonnull * _Nullable)objects
                              forKeys: (const id _Nonnull * _Nullable)keys
                                count: (size_t)count
{
    Map *map = [[self allocWithAllocator: nullptr] initWithObjects: objects forKeys: keys count: count];
    return [map autorelease];
}

- (instancetype)initWithObjects: (const id _Nonnull * _Nullable)objects
                        forKeys: (const id _Nonnull * _Nullable)keys
                          count: (size_t)count
{
    if (count > 0U and (objects == nullptr or keys == nullptr)) {
        [self release];
#if SF_RUNTIME_EXCEPTIONS
        @throw [InvalidArgumentException invalidArgumentException];
#endif
        return nullptr;
    }

    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    if (count == 0U) {
        _count = 0U;
        _keys = nullptr;
        _values = nullptr;
        return self;
    }

    id *tmp_keys = (id *)[self allocateMemoryWithSize: sizeof(id) * count alignment: alignof(id)];
    id *tmp_values = (id *)[self allocateMemoryWithSize: sizeof(id) * count alignment: alignof(id)];
    size_t used = 0U;

    if (tmp_keys == nullptr or tmp_values == nullptr) {
        SFAllocator_t *allocator = self.allocator;
        if (allocator != nullptr) {
            if (tmp_keys != nullptr) {
                allocator->free(allocator->ctx, tmp_keys, sizeof(id) * count, alignof(id));
            }
            if (tmp_values != nullptr) {
                allocator->free(allocator->ctx, tmp_values, sizeof(id) * count, alignof(id));
            }
        }
        [self release];
        return nullptr;
    }

    for (size_t i = 0U; i < count; ++i) {
        id key = keys[i];
        id value = objects[i];
        size_t replace_index = used;

        if (key == nullptr or value == nullptr) {
            continue;
        }

        for (size_t existing = 0U; existing < used; ++existing) {
            if (sf_map_keys_equal(tmp_keys[existing], key)) {
                replace_index = existing;
                break;
            }
        }

        if (replace_index == used) {
            tmp_keys[used] = [(Object *)key retain];
            tmp_values[used] = [(Object *)value retain];
            ++used;
            continue;
        }

        [(Object *)tmp_keys[replace_index] release];
        [(Object *)tmp_values[replace_index] release];
        tmp_keys[replace_index] = [(Object *)key retain];
        tmp_values[replace_index] = [(Object *)value retain];
    }

    _count = used;
    _keys = tmp_keys;
    _values = tmp_values;
    return self;
}

- (id)objectForKey: (id)key
{
    if (key == nullptr) {
        return nullptr;
    }
    for (size_t i = 0U; i < _count; ++i) {
        if (sf_map_keys_equal(_keys[i], key)) {
            return _values[i];
        }
    }
    return nullptr;
}

- (id)objectForKeyedSubscript: (id)key
{
    return [self objectForKey: key];
}

- (int)isEqual: (Object *)other
{
    if ((id)self == (id)other) {
        return 1;
    }
    if ([(Object *)other isKindOfClass: Map.class] == 0) {
        return 0;
    }

    Map *rhs = (Map *)other;
    if (_count != rhs.count) {
        return 0;
    }

    for (size_t i = 0U; i < _count; ++i) {
        id lhs_value = _values[i];
        id rhs_value = [rhs objectForKey: _keys[i]];

        if (rhs_value == nullptr) {
            return 0;
        }
        if (lhs_value == rhs_value) {
            continue;
        }
        if (lhs_value == nullptr or [(Object *)lhs_value isEqual: rhs_value] == 0) {
            return 0;
        }
    }
    return 1;
}

- (unsigned long)hash
{
    uint64_t hash = UINT64_C(1469598103934665603);
    hash = sf_map_hash_word(hash, (uintptr_t)_count);
    for (size_t i = 0U; i < _count; ++i) {
        hash = sf_map_hash_word(hash, (uintptr_t)[(Object *)_keys[i] hash]);
        hash = sf_map_hash_word(hash, (uintptr_t)[(Object *)_values[i] hash]);
    }
    return (unsigned long)hash;
}

- (void)dealloc
{
    for (size_t i = 0U; i < _count; ++i) {
        if (_keys[i] != nullptr) {
            [(Object *)_keys[i] release];
        }
        if (_values[i] != nullptr) {
            [(Object *)_values[i] release];
        }
    }
    if (_keys != nullptr) {
        SFAllocator_t *allocator = self.allocator;
        if (allocator != nullptr) {
            allocator->free(allocator->ctx, _keys, sizeof(id) * _count, alignof(id));
        }
    }
    if (_values != nullptr) {
        SFAllocator_t *allocator = self.allocator;
        if (allocator != nullptr) {
            allocator->free(allocator->ctx, _values, sizeof(id) * _count, alignof(id));
        }
    }
    [super dealloc];
}

@end
