#include "Number.h"

#include "c2x-compat.h"

#include <iso646.h>
#include <stdint.h>

enum {
    SF_NUMBER_KIND_SIGNED = 1U,
    SF_NUMBER_KIND_UNSIGNED = 2U,
    SF_NUMBER_KIND_DOUBLE = 3U,
};

static uint64_t sf_number_hash_word(uint64_t hash, uintptr_t word)
{
    for (size_t i = 0U; i < sizeof(word); ++i) {
        unsigned char byte = (unsigned char)((word >> (i * 8U)) & (uintptr_t)0xffU);
        hash ^= (uint64_t)byte;
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

static int sf_number_extract_payload(id obj, uint8_t *kind, long long *signed_value, unsigned long long *unsigned_value,
                                     double *double_value)
{
    Number *number = (Number *)obj;

    if (obj == nullptr or kind == nullptr) {
        return 0;
    }
#if SF_RUNTIME_TAGGED_POINTERS
    if (number.isTaggedPointer) {
        *kind = SF_NUMBER_KIND_UNSIGNED;
        if (signed_value != nullptr) {
            *signed_value = (long long)number.taggedPointerPayload;
        }
        if (unsigned_value != nullptr) {
            *unsigned_value = (unsigned long long)number.taggedPointerPayload;
        }
        if (double_value != nullptr) {
            *double_value = (double)number.taggedPointerPayload;
        }
        return 1;
    }
#endif

    *kind = number->_kind;
    switch (number->_kind) {
        case SF_NUMBER_KIND_SIGNED:
            if (signed_value != nullptr) {
                *signed_value = number->_storage._signed_value;
            }
            if (unsigned_value != nullptr) {
                *unsigned_value = (number->_storage._signed_value >= 0LL)
                                      ? (unsigned long long)number->_storage._signed_value
                                      : 0ULL;
            }
            if (double_value != nullptr) {
                *double_value = (double)number->_storage._signed_value;
            }
            return 1;
        case SF_NUMBER_KIND_UNSIGNED:
            if (signed_value != nullptr) {
                *signed_value = (long long)number->_storage._unsigned_value;
            }
            if (unsigned_value != nullptr) {
                *unsigned_value = number->_storage._unsigned_value;
            }
            if (double_value != nullptr) {
                *double_value = (double)number->_storage._unsigned_value;
            }
            return 1;
        case SF_NUMBER_KIND_DOUBLE:
            if (signed_value != nullptr) {
                *signed_value = (long long)number->_storage._double_value;
            }
            if (unsigned_value != nullptr) {
                *unsigned_value = (number->_storage._double_value >= 0.0)
                                      ? (unsigned long long)number->_storage._double_value
                                      : 0ULL;
            }
            if (double_value != nullptr) {
                *double_value = number->_storage._double_value;
            }
            return 1;
        default:
            return 0;
    }
}

@interface Number ()
- (instancetype _Nullable)initWithSignedLongLong: (long long)value;
- (instancetype _Nullable)initWithUnsignedLongLong: (unsigned long long)value;
- (instancetype _Nullable)initWithDoubleValue: (double)value;
@end

@implementation Number

#if SF_RUNTIME_TAGGED_POINTERS
+ (uintptr_t)taggedPointerSlot
{
    return 1U;
}
#endif

+ (instancetype)numberWithChar: (char)value
{
    return [self numberWithLongLong: (long long)value];
}

+ (instancetype)numberWithUnsignedChar: (unsigned char)value
{
    return [self numberWithUnsignedLongLong: (unsigned long long)value];
}

+ (instancetype)numberWithShort: (short)value
{
    return [self numberWithLongLong: (long long)value];
}

+ (instancetype)numberWithUnsignedShort: (unsigned short)value
{
    return [self numberWithUnsignedLongLong: (unsigned long long)value];
}

+ (instancetype)numberWithInt: (int)value
{
    return [self numberWithLongLong: (long long)value];
}

+ (instancetype)numberWithUnsignedInt: (unsigned int)value
{
    return [self numberWithUnsignedLongLong: (unsigned long long)value];
}

+ (instancetype)numberWithLong: (long)value
{
    return [self numberWithLongLong: (long long)value];
}

+ (instancetype)numberWithUnsignedLong: (unsigned long)value
{
    return [self numberWithUnsignedLongLong: (unsigned long long)value];
}

+ (instancetype)numberWithLongLong: (long long)value
{
#if SF_RUNTIME_TAGGED_POINTERS
    if (value >= 0LL and (unsigned long long)value <= (unsigned long long)(UINTPTR_MAX >> 3U)) {
        Number *tagged = [self taggedPointerWithPayload: (uintptr_t)value];
#if SF_RUNTIME_EXCEPTIONS
        __builtin_assume(tagged != nullptr);
#endif
        return tagged;
    }
#endif
    Number *number = [[self allocWithAllocator: nullptr] initWithSignedLongLong: value];
    return [number autorelease];
}

+ (instancetype)numberWithUnsignedLongLong: (unsigned long long)value
{
#if SF_RUNTIME_TAGGED_POINTERS
    if (value <= (unsigned long long)(UINTPTR_MAX >> 3U)) {
        Number *tagged = [self taggedPointerWithPayload: (uintptr_t)value];
#if SF_RUNTIME_EXCEPTIONS
        __builtin_assume(tagged != nullptr);
#endif
        return tagged;
    }
#endif
    Number *number = [[self allocWithAllocator: nullptr] initWithUnsignedLongLong: value];
    return [number autorelease];
}

+ (instancetype)numberWithDouble: (double)value
{
    Number *number = [[self allocWithAllocator: nullptr] initWithDoubleValue: value];
    return [number autorelease];
}

+ (instancetype)numberWithBool: (bool)value
{
    return [self numberWithUnsignedLongLong: value ? 1ULL : 0ULL];
}

- (instancetype)initWithSignedLongLong: (long long)value
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }
    _kind = SF_NUMBER_KIND_SIGNED;
    _storage._signed_value = value;
    return self;
}

- (instancetype)initWithUnsignedLongLong: (unsigned long long)value
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }
    _kind = SF_NUMBER_KIND_UNSIGNED;
    _storage._unsigned_value = value;
    return self;
}

- (instancetype)initWithDoubleValue: (double)value
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }
    _kind = SF_NUMBER_KIND_DOUBLE;
    _storage._double_value = value;
    return self;
}

- (char)charValue
{
    return (char)self.longLongValue;
}

- (unsigned char)unsignedCharValue
{
    return (unsigned char)self.unsignedLongLongValue;
}

- (short)shortValue
{
    return (short)self.longLongValue;
}

- (unsigned short)unsignedShortValue
{
    return (unsigned short)self.unsignedLongLongValue;
}

- (int)intValue
{
    return (int)self.longLongValue;
}

- (unsigned int)unsignedIntValue
{
    return (unsigned int)self.unsignedLongLongValue;
}

- (long)longValue
{
    return (long)self.longLongValue;
}

- (unsigned long)unsignedLongValue
{
    return (unsigned long)self.unsignedLongLongValue;
}

- (long long)longLongValue
{
    uint8_t kind = 0U;
    long long signed_value = 0LL;
    unsigned long long unsigned_value = 0ULL;
    double double_value = 0.0;

    if (not sf_number_extract_payload(self, &kind, &signed_value, &unsigned_value, &double_value)) {
        return 0LL;
    }
    switch (kind) {
        case SF_NUMBER_KIND_SIGNED:
            return signed_value;
        case SF_NUMBER_KIND_UNSIGNED:
            return (long long)unsigned_value;
        case SF_NUMBER_KIND_DOUBLE:
            return (long long)double_value;
        default:
            return 0LL;
    }
}

- (unsigned long long)unsignedLongLongValue
{
    uint8_t kind = 0U;
    long long signed_value = 0LL;
    unsigned long long unsigned_value = 0ULL;
    double double_value = 0.0;

    if (not sf_number_extract_payload(self, &kind, &signed_value, &unsigned_value, &double_value)) {
        return 0ULL;
    }
    switch (kind) {
        case SF_NUMBER_KIND_SIGNED:
            return (signed_value >= 0LL) ? (unsigned long long)signed_value : 0ULL;
        case SF_NUMBER_KIND_UNSIGNED:
            return unsigned_value;
        case SF_NUMBER_KIND_DOUBLE:
            return (double_value >= 0.0) ? (unsigned long long)double_value : 0ULL;
        default:
            return 0ULL;
    }
}

- (double)doubleValue
{
    uint8_t kind = 0U;
    long long signed_value = 0LL;
    unsigned long long unsigned_value = 0ULL;
    double double_value = 0.0;

    if (not sf_number_extract_payload(self, &kind, &signed_value, &unsigned_value, &double_value)) {
        return 0.0;
    }
    switch (kind) {
        case SF_NUMBER_KIND_SIGNED:
            return (double)signed_value;
        case SF_NUMBER_KIND_UNSIGNED:
            return (double)unsigned_value;
        case SF_NUMBER_KIND_DOUBLE:
            return double_value;
        default:
            return 0.0;
    }
}

- (bool)boolValue
{
    return self.doubleValue != 0.0;
}

- (int)isEqual: (Object *)other
{
    uint8_t lhs_kind = 0U;
    uint8_t rhs_kind = 0U;
    long long lhs_signed = 0LL;
    long long rhs_signed = 0LL;
    unsigned long long lhs_unsigned = 0ULL;
    unsigned long long rhs_unsigned = 0ULL;
    double lhs_double = 0.0;
    double rhs_double = 0.0;

    if ((id)self == (id)other) {
        return 1;
    }
    if ([(Object *)other isKindOfClass: Number.class] == 0) {
        return 0;
    }
    if (not sf_number_extract_payload(self, &lhs_kind, &lhs_signed, &lhs_unsigned, &lhs_double) or
        not sf_number_extract_payload(other, &rhs_kind, &rhs_signed, &rhs_unsigned, &rhs_double)) {
        return 0;
    }

    if (lhs_kind == SF_NUMBER_KIND_DOUBLE or rhs_kind == SF_NUMBER_KIND_DOUBLE) {
        return (lhs_double <= rhs_double) and (lhs_double >= rhs_double);
    }
    if (lhs_kind == SF_NUMBER_KIND_SIGNED and rhs_kind == SF_NUMBER_KIND_SIGNED) {
        return lhs_signed == rhs_signed;
    }
    if (lhs_kind == SF_NUMBER_KIND_UNSIGNED and rhs_kind == SF_NUMBER_KIND_UNSIGNED) {
        return lhs_unsigned == rhs_unsigned;
    }
    if (lhs_kind == SF_NUMBER_KIND_SIGNED) {
        return lhs_signed >= 0LL and (unsigned long long)lhs_signed == rhs_unsigned;
    }
    return rhs_signed >= 0LL and lhs_unsigned == (unsigned long long)rhs_signed;
}

- (unsigned long)hash
{
    uint64_t hash = UINT64_C(1469598103934665603);
    uint8_t kind = 0U;
    long long signed_value = 0LL;
    unsigned long long unsigned_value = 0ULL;
    double double_value = 0.0;

    if (not sf_number_extract_payload(self, &kind, &signed_value, &unsigned_value, &double_value)) {
        return [super hash];
    }
    hash = sf_number_hash_word(hash, (uintptr_t)kind);
    if (kind == SF_NUMBER_KIND_DOUBLE) {
        union {
            double value;
            uint64_t bits;
        } bits = {.value = double_value};
        hash = sf_number_hash_word(hash, (uintptr_t)bits.bits);
    } else if (kind == SF_NUMBER_KIND_SIGNED and signed_value < 0LL) {
        hash = sf_number_hash_word(hash, (uintptr_t)(uint64_t)signed_value);
    } else {
        hash = sf_number_hash_word(hash, (uintptr_t)unsigned_value);
    }
    return (unsigned long)hash;
}

@end
