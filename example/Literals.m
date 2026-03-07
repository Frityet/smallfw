#include "Literals.h"

#include <limits.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#include "runtime/internal.h"

typedef struct SFWExampleConstantString {
    Class isa;
    int32_t flags;
    int32_t len;
    int32_t size;
    int32_t reserved;
    const char *str;
} SFWExampleConstantString_t;

typedef struct SFDictionaryEntry {
    id key;
    id value;
    unsigned long hash;
} SFDictionaryEntry_t;

static void sfw_initialize_number_cache(void);

#ifndef nil
#define nil ((id)0)
#endif

@interface SFWLiteralException : Object {
@private
    const char *_reason;
}
+ (instancetype)exceptionWithReason:(const char *)reason;
- (const char *)reason;
@end

@implementation SFWLiteralException

+ (instancetype)exceptionWithReason:(const char *)reason {
    SFWLiteralException *exception = [self allocWithAllocator:sf_default_allocator()];
    if (exception == nil) {
        abort();
    }

    exception->_reason = reason != NULL ? reason : "Literal exception";
    return [exception autorelease];
}

- (const char *)reason {
    return _reason != NULL ? _reason : "Literal exception";
}

@end

static void sfw_throw_exception(const char *reason) __attribute__((noreturn));
static void sfw_throw_exception(const char *reason) {
    id exception = [SFWLiteralException exceptionWithReason:reason];
    if (exception == nil) {
        abort();
    }
    @throw exception;
}

static unsigned long sf_hash_bytes_local(const unsigned char *bytes, unsigned long length) {
    unsigned long hash = 5381UL;

    if (bytes == NULL) {
        return 0UL;
    }

    for (unsigned long i = 0UL; i < length; ++i) {
        hash = ((hash << 5U) + hash) ^ (unsigned long)bytes[i];
    }
    return hash;
}

static unsigned long sf_hash_string(const char *text) {
    if (text == NULL) {
        return 0UL;
    }
    return sf_hash_bytes_local((const unsigned char *)text, (unsigned long)strlen(text));
}

static unsigned long sf_obj_hash(id obj) {
    if (obj == nil) {
        return 0UL;
    }
    return (unsigned long)[obj hash];
}

static int sf_obj_equal(Object *lhs, Object *rhs) {
    if (lhs == rhs) {
        return 1;
    }
    if (lhs == nil || rhs == nil) {
        return 0;
    }
    return [lhs isEqual:rhs] ? 1 : 0;
}

static void *sf_alloc_bytes_for_object(Object *obj, size_t size, size_t align) {
    SFAllocator_t *allocator = NULL;

    if (size == 0U) {
        return NULL;
    }

    allocator = obj != nil ? [obj allocator] : sf_default_allocator();
    return allocator->alloc(allocator->ctx, size, align);
}

static void sf_free_bytes_for_object(Object *obj, void *ptr, size_t size, size_t align) {
    SFAllocator_t *allocator = NULL;

    if (ptr == NULL) {
        return;
    }

    allocator = obj != nil ? [obj allocator] : sf_default_allocator();
    allocator->free(allocator->ctx, ptr, size, align);
}

static unsigned long sf_next_pow2(unsigned long value) {
    if (value <= 1UL) {
        return 1UL;
    }

    value -= 1UL;
    value |= (value >> 1U);
    value |= (value >> 2U);
    value |= (value >> 4U);
    value |= (value >> 8U);
    value |= (value >> 16U);
    if (sizeof(unsigned long) > 4U) {
        value |= (value >> 32U);
    }
    return value + 1UL;
}

static unsigned long sf_dictionary_capacity_for_count(unsigned long count) {
    unsigned long target = 0UL;

    if (count == 0UL) {
        return 8UL;
    }

    if (count > (ULONG_MAX / 2UL)) {
        return 0UL;
    }

    target = count + (count / 2UL) + 1UL;
    if (target < 8UL) {
        target = 8UL;
    }

    return sf_next_pow2(target);
}

@implementation String

- (const char *)UTF8String {
    return "";
}

- (unsigned long)length {
    const char *s = [self UTF8String];
    return s != NULL ? (unsigned long)strlen(s) : 0UL;
}

- (instancetype)copy {
    return [self retain];
}

- (unsigned long)hash {
    return sf_hash_string([self UTF8String]);
}

- (int)isEqual:(Object *)other {
    const char *lhs = NULL;
    const char *rhs = NULL;
    unsigned long lhs_len = 0UL;
    unsigned long rhs_len = 0UL;

    if (self == other) {
        return 1;
    }
    if (other == nil) {
        return 0;
    }

    lhs = [self UTF8String];
    rhs = [(String *)other UTF8String];
    if (lhs == NULL || rhs == NULL) {
        return 0;
    }

    lhs_len = [self length];
    rhs_len = [(String *)other length];
    if (lhs_len != rhs_len) {
        return 0;
    }

    if (lhs_len == 0UL) {
        return 1;
    }

    return memcmp(lhs, rhs, lhs_len) == 0 ? 1 : 0;
}

@end

@implementation ConstantString

- (const char *)UTF8String {
    SFWExampleConstantString_t *literal = (SFWExampleConstantString_t *)self;
    return literal->str != NULL ? literal->str : "";
}

- (unsigned long)length {
    SFWExampleConstantString_t *literal = (SFWExampleConstantString_t *)self;

    if (literal->len >= 0) {
        return (unsigned long)literal->len;
    }

    return (unsigned long)strlen([self UTF8String]);
}

@end

@interface Number () {
@private
    long long _value;
    int _isCached;
}
- (instancetype)initWithLongLong:(long long)value cached:(int)is_cached;
@end

@implementation Number

enum {
    SFWNumberCacheMin = -16,
    SFWNumberCacheMax = 255,
    SFWNumberCacheCount = (SFWNumberCacheMax - SFWNumberCacheMin + 1)
};

static pthread_once_t g_number_cache_once = PTHREAD_ONCE_INIT;
static Number *g_number_cache[SFWNumberCacheCount];

+ (void)initializeNumberCache {
    for (long long value = SFWNumberCacheMin; value <= SFWNumberCacheMax; ++value) {
        unsigned long index = (unsigned long)(value - SFWNumberCacheMin);
        Number *number = [[self allocWithAllocator:sf_default_allocator()] initWithLongLong:value cached:1];
        g_number_cache[index] = number;
    }
}

+ (Number *)cachedNumberForValue:(long long)value {
    unsigned long index = 0UL;

    if (value < SFWNumberCacheMin || value > SFWNumberCacheMax) {
        return nil;
    }

    (void)pthread_once(&g_number_cache_once, &sfw_initialize_number_cache);
    index = (unsigned long)(value - SFWNumberCacheMin);
    return g_number_cache[index];
}

static void sfw_initialize_number_cache(void) {
    [Number initializeNumberCache];
}

- (instancetype)initWithLongLong:(long long)value cached:(int)is_cached {
    self = [super init];
    if (self == nil) {
        sfw_throw_exception("Number initialization failed");
    }

    _value = value;
    _isCached = is_cached;
    return self;
}

+ (instancetype)numberWithInt:(int)value {
    return [self numberWithLongLong:(long long)value];
}

+ (instancetype)numberWithLongLong:(long long)value {
    Number *cached = [self cachedNumberForValue:value];
    Number *number = nil;

    if (cached != nil) {
        return cached;
    }

    number = [[self allocWithAllocator:sf_default_allocator()] initWithLongLong:value cached:0];
    if (number == nil) {
        sfw_throw_exception("Failed to allocate Number");
    }

    return [number autorelease];
}

- (instancetype)retain {
    if (_isCached) {
        return self;
    }

    return (id)objc_retain(self);
}

- (oneway void)release {
    if (_isCached) {
        return;
    }

    objc_release(self);
}

- (instancetype)autorelease {
    if (_isCached) {
        return self;
    }

    return (id)sf_autorelease(self);
}

- (instancetype)copy {
    return [self retain];
}

- (int)intValue {
    return (int)_value;
}

- (long long)longLongValue {
    return _value;
}

- (unsigned long)hash {
    uint64_t bits = (uint64_t)_value;
    bits ^= (bits >> 33U);
    bits *= UINT64_C(0xff51afd7ed558ccd);
    bits ^= (bits >> 33U);
    bits *= UINT64_C(0xc4ceb9fe1a85ec53);
    bits ^= (bits >> 33U);
    return (unsigned long)bits;
}

- (int)isEqual:(Object *)other {
    if (self == other) {
        return 1;
    }

    if (other == nil || sf_object_class(other) != sf_object_class(self)) {
        return 0;
    }

    return _value == ((Number *)other)->_value ? 1 : 0;
}

@end

@interface Array () {
@private
    unsigned long _count;
    id *_items;
    size_t _storageSize;
}
- (instancetype)initWithObjects:(const id * _Nonnull)objects count:(unsigned long)count;
@end

@implementation Array

+ (instancetype)arrayWithObjects:(const id * _Nonnull)objects count:(unsigned long)count {
    Array *array = [[self allocWithAllocator:sf_default_allocator()] initWithObjects:objects count:count];
    if (array == nil) {
        sfw_throw_exception("Failed to allocate Array");
    }

    return [array autorelease];
}

- (instancetype)initWithObjects:(const id * _Nonnull)objects count:(unsigned long)count {
    self = [super init];
    if (self == nil) {
        sfw_throw_exception("Array initialization failed");
    }

    _count = 0UL;
    _items = NULL;
    _storageSize = 0U;

    if (count == 0UL) {
        return self;
    }

    if (objects == NULL || count > (ULONG_MAX / (unsigned long)sizeof(id))) {
        [self release];
        sfw_throw_exception("Invalid Array constructor arguments");
    }

    _storageSize = (size_t)(count * (unsigned long)sizeof(id));
    _items = (id *)sf_alloc_bytes_for_object(self, _storageSize, sizeof(void *));
    if (_items == NULL) {
        [self release];
        sfw_throw_exception("Failed to allocate Array storage");
    }

    memset(_items, 0, _storageSize);
    _count = count;
    for (unsigned long i = 0UL; i < _count; ++i) {
        _items[i] = objc_retain(objects[i]);
    }

    return self;
}

- (instancetype)copy {
    return [self retain];
}

- (unsigned long)count {
    return _count;
}

- (id)objectAtIndex:(unsigned long)index {
    if (index >= _count) {
        sfw_throw_exception("Array index out of bounds");
    }
    return _items[index];
}

- (id)objectAtIndexedSubscript:(unsigned long)index {
    return [self objectAtIndex:index];
}

- (void)dealloc {
    for (unsigned long i = 0UL; i < _count; ++i) {
        objc_release(_items[i]);
    }

    sf_free_bytes_for_object(self, _items, _storageSize, sizeof(void *));
    [super dealloc];
}

@end

@interface Dictionary () {
@private
    unsigned long _count;
    unsigned long _capacity;
    SFDictionaryEntry_t *_entries;
    size_t _storageSize;
}
- (instancetype)initWithObjects:(const id * _Nonnull)objects
                        forKeys:(const id * _Nonnull)keys
                          count:(unsigned long)count;
@end

@implementation Dictionary

+ (instancetype)dictionaryWithObjects:(const id * _Nonnull)objects
                              forKeys:(const id * _Nonnull)keys
                                count:(unsigned long)count {
    Dictionary *dict = [[self allocWithAllocator:sf_default_allocator()] initWithObjects:objects
                                                                                  forKeys:keys
                                                                                    count:count];
    if (dict == nil) {
        sfw_throw_exception("Failed to allocate Dictionary");
    }

    return [dict autorelease];
}

- (instancetype)initWithObjects:(const id * _Nonnull)objects forKeys:(const id * _Nonnull)keys count:(unsigned long)count {
    self = [super init];
    if (self == nil) {
        sfw_throw_exception("Dictionary initialization failed");
    }

    _count = 0UL;
    _capacity = 0UL;
    _entries = NULL;
    _storageSize = 0U;

    if (count == 0UL) {
        return self;
    }

    if (objects == NULL || keys == NULL) {
        [self release];
        sfw_throw_exception("Invalid Dictionary constructor arguments");
    }

    _capacity = sf_dictionary_capacity_for_count(count);
    if (_capacity == 0UL || _capacity > (ULONG_MAX / (unsigned long)sizeof(SFDictionaryEntry_t))) {
        [self release];
        sfw_throw_exception("Dictionary capacity overflow");
    }

    _storageSize = (size_t)(_capacity * (unsigned long)sizeof(SFDictionaryEntry_t));
    _entries = (SFDictionaryEntry_t *)sf_alloc_bytes_for_object(self, _storageSize, sizeof(void *));
    if (_entries == NULL) {
        [self release];
        sfw_throw_exception("Failed to allocate Dictionary storage");
    }

    memset(_entries, 0, _storageSize);

    unsigned long mask = _capacity - 1UL;
    for (unsigned long i = 0UL; i < count; ++i) {
        id key = keys[i];
        id value = objects[i];
        unsigned long hash = sf_obj_hash(key);
        unsigned long idx = hash & mask;

        if (key == nil || value == nil) {
            [self release];
            sfw_throw_exception("Dictionary cannot contain nil keys or values");
        }

        for (;;) {
            SFDictionaryEntry_t *entry = &_entries[idx];
            if (entry->key == nil) {
                entry->hash = hash;
                entry->key = objc_retain(key);
                entry->value = objc_retain(value);
                _count += 1UL;
                break;
            }

            if (entry->hash == hash && sf_obj_equal((Object *)entry->key, (Object *)key)) {
                if (entry->value != nil) {
                    objc_release(entry->value);
                }
                entry->value = objc_retain(value);
                break;
            }

            idx = (idx + 1UL) & mask;
        }
    }

    return self;
}

- (instancetype)copy {
    return [self retain];
}

- (unsigned long)count {
    return _count;
}

- (id)objectForKey:(id)key {
    unsigned long mask = 0UL;
    unsigned long hash = 0UL;
    unsigned long idx = 0UL;

    if (key == nil) {
        sfw_throw_exception("Dictionary key cannot be nil");
    }

    if (_capacity == 0UL || _entries == NULL) {
        sfw_throw_exception("Dictionary key not found");
    }

    mask = _capacity - 1UL;
    hash = sf_obj_hash(key);
    idx = hash & mask;

    for (unsigned long n = 0UL; n < _capacity; ++n) {
        SFDictionaryEntry_t *entry = &_entries[idx];

        if (entry->key == nil) {
            sfw_throw_exception("Dictionary key not found");
        }

        if (entry->hash == hash && sf_obj_equal((Object *)entry->key, (Object *)key)) {
            return entry->value;
        }

        idx = (idx + 1UL) & mask;
    }

    sfw_throw_exception("Dictionary key not found");
}

- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

- (void)dealloc {
    for (unsigned long i = 0UL; i < _capacity; ++i) {
        if (_entries[i].key != nil) {
            objc_release(_entries[i].key);
        }
        if (_entries[i].value != nil) {
            objc_release(_entries[i].value);
        }
    }

    sf_free_bytes_for_object(self, _entries, _storageSize, sizeof(void *));
    [super dealloc];
}

@end
