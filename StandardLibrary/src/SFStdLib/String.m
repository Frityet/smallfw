@import SFRuntime;

#include "String.h"

#include <iso646.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if SF_RUNTIME_EXCEPTIONS
    @interface InvalidArgumentException (SmallFWInternal)
    + (instancetype)exception;
    @end
#endif

#pragma clang assume_nonnull begin

@interface SFUTF8String : String {
  @private
    size_t _length;
    size_t _byte_count;
    const char *nonnil _bytes;
    bool _owns_bytes;
}
- (instancetype nillable)initWithUTF8Storage:(const char *nonnil)bytes
                                       length:(size_t)length
                                    unitCount:(size_t)unit_count
                                    copyBytes:(bool)copy_bytes;
@end

static thread_local char g_tagged_string_buffers[4][9];
static thread_local size_t g_tagged_string_buffer_index;
static thread_local char *g_unicode_utf8_buffer;
static thread_local size_t g_unicode_utf8_capacity;

static bool sf_string_ascii_is_taggable(const char *nonnil bytes, size_t length)
{
    sf_nonnil_check(bytes != nullptr);
#if SF_RUNTIME_TAGGED_POINTERS
        if (length > 8U) {
            return 0;
        }
        for (size_t i = 0U; i < length; ++i) {
            if (((unsigned char)bytes[i]) > 0x7fU) {
                return 0;
            }
        }
        return 1;
#else
        (void)bytes;
        (void)length;
        return 0;
#endif
}

static uintptr_t sf_string_tagged_payload(const char *nonnil bytes, size_t length)
{
    sf_nonnil_check(bytes != nullptr);
    uintptr_t payload = (uintptr_t)length;
    for (size_t i = 0U; i < length; ++i) {
        payload |= ((uintptr_t)((unsigned char)bytes[i] & 0x7fU)) << (54U - (i * 7U));
    }
    return payload;
}

static size_t sf_string_tagged_length(String *nonnil string)
{
    sf_nonnil_check(string != nullptr);
    return (size_t)((((uintptr_t)string) >> 3U) & (uintptr_t)0xfU);
}

static unsigned short sf_string_tagged_character_at(String *nonnil string, size_t idx)
{
    sf_nonnil_check(string != nullptr);
    if (idx >= sf_string_tagged_length(string)) {
        return 0U;
    }
    return (unsigned short)((((uintptr_t)string) >> (57U - (idx * 7U))) & (uintptr_t)0x7fU);
}

static const char *nonnil sf_string_tagged_utf8(String *nonnil string)
{
    sf_nonnil_check(string != nullptr);
    size_t length = sf_string_tagged_length(string);
    size_t slot = g_tagged_string_buffer_index++ & 3U;
    char *buffer = g_tagged_string_buffers[slot];

    for (size_t i = 0U; i < length; ++i) {
        buffer[i] = (char)sf_string_tagged_character_at(string, i);
    }
    buffer[length] = '\0';
    return buffer;
}

static bool sf_string_utf8_decode_one(const unsigned char *nonnil bytes, size_t length, size_t *nonnil offset_io, uint32_t *nonnil codepoint)
{
    sf_nonnil_check(bytes != nullptr and offset_io != nullptr and codepoint != nullptr);
    size_t offset = 0U;
    unsigned char c0 = 0U;
    uint32_t value = 0U;

    offset = *offset_io;
    if (offset >= length) {
        return 0;
    }

    c0 = bytes[offset];
    if (c0 < 0x80U) {
        *codepoint = c0;
        *offset_io = offset + 1U;
        return 1;
    }
    if ((c0 & 0xe0U) == 0xc0U) {
        if (offset + 1U >= length) {
            return 0;
        }
        unsigned char c1 = bytes[offset + 1U];
        if ((c1 & 0xc0U) != 0x80U) {
            return 0;
        }
        value = ((uint32_t)(c0 & 0x1fU) << 6U) | (uint32_t)(c1 & 0x3fU);
        if (value < 0x80U) {
            return 0;
        }
        *codepoint = value;
        *offset_io = offset + 2U;
        return 1;
    }
    if ((c0 & 0xf0U) == 0xe0U) {
        if (offset + 2U >= length) {
            return 0;
        }
        unsigned char c1 = bytes[offset + 1U];
        unsigned char c2 = bytes[offset + 2U];
        if ((c1 & 0xc0U) != 0x80U or (c2 & 0xc0U) != 0x80U) {
            return 0;
        }
        value = ((uint32_t)(c0 & 0x0fU) << 12U) | ((uint32_t)(c1 & 0x3fU) << 6U) | (uint32_t)(c2 & 0x3fU);
        if (value < 0x800U or (value >= 0xd800U and value <= 0xdfffU)) {
            return 0;
        }
        *codepoint = value;
        *offset_io = offset + 3U;
        return 1;
    }
    if ((c0 & 0xf8U) == 0xf0U) {
        if (offset + 3U >= length) {
            return 0;
        }
        unsigned char c1 = bytes[offset + 1U];
        unsigned char c2 = bytes[offset + 2U];
        unsigned char c3 = bytes[offset + 3U];
        if ((c1 & 0xc0U) != 0x80U or (c2 & 0xc0U) != 0x80U or (c3 & 0xc0U) != 0x80U) {
            return 0;
        }
        value = ((uint32_t)(c0 & 0x07U) << 18U) | ((uint32_t)(c1 & 0x3fU) << 12U) |
                ((uint32_t)(c2 & 0x3fU) << 6U) | (uint32_t)(c3 & 0x3fU);
        if (value < 0x10000U or value > 0x10ffffU) {
            return 0;
        }
        *codepoint = value;
        *offset_io = offset + 4U;
        return 1;
    }
    return 0;
}

static bool sf_string_utf8_measure_units(const char *nonnil bytes, size_t length, size_t *nillable units_out, bool *nillable ascii_only_out)
{
    sf_nonnil_check(bytes != nullptr);
    size_t offset = 0U;
    size_t units = 0U;
    bool ascii_only = true;

    if (length == 0U) {
        if (units_out != nullptr) {
            *units_out = 0U;
        }
        if (ascii_only_out != nullptr) {
            *ascii_only_out = 1;
        }
        return 1;
    }
    while (offset < length) {
        uint32_t codepoint = 0U;
        if (not sf_string_utf8_decode_one((const unsigned char *)bytes, length, &offset, &codepoint)) {
            return 0;
        }
        if (codepoint > 0x7fU) {
            ascii_only = 0;
        }
        units += (codepoint <= 0xffffU) ? 1U : 2U;
    }

    if (units_out != nullptr) {
        *units_out = units;
    }
    if (ascii_only_out != nullptr) {
        *ascii_only_out = ascii_only;
    }
    return 1;
}

static size_t sf_string_utf16_utf8_size(const uint16_t *nonnil units, size_t length)
{
    sf_nonnil_check(units != nullptr);
    size_t size = 0U;
    size_t i = 0U;
    while (i < length) {
        uint32_t codepoint = units[i++];
        if (codepoint >= 0xd800U and codepoint <= 0xdbffU and i < length) {
            uint32_t low = units[i];
            if (low >= 0xdc00U and low <= 0xdfffU) {
                ++i;
                codepoint = (((codepoint - 0xd800U) << 10U) | (low - 0xdc00U)) + 0x10000U;
            }
        }

        if (codepoint <= 0x7fU) {
            size += 1U;
        } else if (codepoint <= 0x7ffU) {
            size += 2U;
        } else if (codepoint <= 0xffffU) {
            size += 3U;
        } else {
            size += 4U;
        }
    }
    return size;
}

static size_t sf_string_append_utf8(char *nonnil buffer, size_t offset, uint32_t codepoint)
{
    sf_nonnil_check(buffer != nullptr);
    if (codepoint <= 0x7fU) {
        buffer[offset++] = (char)codepoint;
    } else if (codepoint <= 0x7ffU) {
        buffer[offset++] = (char)(0xc0U | (codepoint >> 6U));
        buffer[offset++] = (char)(0x80U | (codepoint & 0x3fU));
    } else if (codepoint <= 0xffffU) {
        buffer[offset++] = (char)(0xe0U | (codepoint >> 12U));
        buffer[offset++] = (char)(0x80U | ((codepoint >> 6U) & 0x3fU));
        buffer[offset++] = (char)(0x80U | (codepoint & 0x3fU));
    } else {
        buffer[offset++] = (char)(0xf0U | (codepoint >> 18U));
        buffer[offset++] = (char)(0x80U | ((codepoint >> 12U) & 0x3fU));
        buffer[offset++] = (char)(0x80U | ((codepoint >> 6U) & 0x3fU));
        buffer[offset++] = (char)(0x80U | (codepoint & 0x3fU));
    }
    return offset;
}

static const char *nonnil sf_string_thread_utf8_buffer(const uint16_t *nonnil units, size_t length)
{
    sf_nonnil_check(units != nullptr);
    size_t needed = sf_string_utf16_utf8_size(units, length) + 1U;
    char *next = nullptr;
    size_t offset = 0U;
    size_t i = 0U;

    if (needed > g_unicode_utf8_capacity) {
        next = (char *)realloc(g_unicode_utf8_buffer, needed);
        if (next == nullptr) {
            return "";
        }
        g_unicode_utf8_buffer = next;
        g_unicode_utf8_capacity = needed;
    }

    while (i < length) {
        uint32_t codepoint = units[i++];
        if (codepoint >= 0xd800U and codepoint <= 0xdbffU and i < length) {
            uint32_t low = units[i];
            if (low >= 0xdc00U and low <= 0xdfffU) {
                ++i;
                codepoint = (((codepoint - 0xd800U) << 10U) | (low - 0xdc00U)) + 0x10000U;
            }
        }
        offset = sf_string_append_utf8(g_unicode_utf8_buffer, offset, codepoint);
    }
    g_unicode_utf8_buffer[offset] = '\0';
    return g_unicode_utf8_buffer;
}

static size_t sf_string_utf8_unit_length(const char *nonnil bytes, size_t length)
{
    sf_nonnil_check(bytes != nullptr);
    size_t offset = 0U;
    size_t units = 0U;
    while (offset < length) {
        uint32_t codepoint = 0U;
        if (not sf_string_utf8_decode_one((const unsigned char *)bytes, length, &offset, &codepoint)) {
            return 0U;
        }
        units += (codepoint <= 0xffffU) ? 1U : 2U;
    }
    return units;
}

static unsigned short sf_string_utf8_character_at(const char *nonnil bytes, size_t length, size_t idx)
{
    sf_nonnil_check(bytes != nullptr);
    size_t offset = 0U;
    size_t units = 0U;

    while (offset < length) {
        uint32_t codepoint = 0U;
        if (not sf_string_utf8_decode_one((const unsigned char *)bytes, length, &offset, &codepoint)) {
            return 0U;
        }
        if (codepoint <= 0xffffU) {
            if (units == idx) {
                return (unsigned short)codepoint;
            }
            ++units;
            continue;
        }

        uint32_t value = codepoint - 0x10000U;
        unsigned short high = (unsigned short)(0xd800U + (value >> 10U));
        unsigned short low = (unsigned short)(0xdc00U + (value & 0x3ffU));
        if (units == idx) {
            return high;
        }
        ++units;
        if (units == idx) {
            return low;
        }
        ++units;
    }
    return 0U;
}

static SF_ERRORABLE(String *) sf_string_fail_init(String *nonnil self)
{
    sf_nonnil_check(self != nullptr);
    [self release];
    SF_THROW([InvalidArgumentException exception]);
}

static SFUTF8String *nillable sf_string_storage_receiver(String *nonnil self)
{
    sf_nonnil_check(self != nullptr);
    SFAllocator_t *allocator = nullptr;
    Object *parent = nullptr;

    if (self.class == SFUTF8String.class) {
        return (SFUTF8String *)self;
    }

    allocator = self.allocator;
    parent = self.parent;
    [self release];

    if (parent != nullptr) {
        return [SFUTF8String allocWithParent:parent];
    }
    return [SFUTF8String allocWithAllocator:allocator];
}

@implementation String

#if SF_RUNTIME_TAGGED_POINTERS
    + (uintptr_t)taggedPointerSlot
    {
        return 4U;
    }
#endif

- (SF_ERRORABLE(instancetype))initWithUTF8String:(const char *nillable)bytes
{
    if (bytes == nullptr) {
        return sf_string_fail_init(self);
    }
    return [self initWithBytes:bytes length:strlen(bytes)];
}

- (SF_ERRORABLE(instancetype))initWithBytes:(const char *nillable)bytes length:(size_t)length
{
    size_t utf16_length = 0U;
    const char *nonnil nonnull_bytes = (const char *nonnil)((bytes != nullptr) ? bytes : "");
    SFUTF8String *storage = nullptr;

    if (bytes == nullptr and length > 0U) {
        return sf_string_fail_init(self);
    }
#if SF_RUNTIME_TAGGED_POINTERS
        if (sf_string_ascii_is_taggable(nonnull_bytes, length)) {
            id tagged = [String taggedPointerWithPayload:sf_string_tagged_payload(nonnull_bytes, length)];
            if (tagged != nullptr) {
                [self release];
                return tagged;
            }
        }
#endif
    if (not sf_string_utf8_measure_units(nonnull_bytes, length, &utf16_length, nullptr)) {
        return sf_string_fail_init(self);
    }

    storage = sf_string_storage_receiver(self);
    if (storage == nullptr) {
        return nullptr;
    }

    return [storage initWithUTF8Storage:nonnull_bytes length:length unitCount:utf16_length copyBytes:1];
}

- (size_t)length
{
#if SF_RUNTIME_TAGGED_POINTERS
        if (self.isTaggedPointer) {
            return sf_string_tagged_length(self);
        }
#endif
    return 0U;
}

- (unsigned short)characterAtIndex:(size_t)idx
{
#if SF_RUNTIME_TAGGED_POINTERS
        if (self.isTaggedPointer) {
            return sf_string_tagged_character_at(self, idx);
        }
#endif
    return 0U;
}

- (const char *)UTF8String
{
#if SF_RUNTIME_TAGGED_POINTERS
        if (self.isTaggedPointer) {
            return sf_string_tagged_utf8(self);
        }
#endif
    return "";
}

- (bool)isEqual:(Object *nillable)other
{
    if ((id)self == (id)other) {
        return true;
    }
    if (not[(Object *)other isKindOfClass:String.class]) {
        return false;
    }

    size_t length = self.length;
    if (length != ((String *)other).length) {
        return false;
    }
    for (size_t i = 0U; i < length; ++i) {
        if ([self characterAtIndex:i] != [(String *)other characterAtIndex:i]) {
            return false;
        }
    }
    return true;
}

- (unsigned long)hash
{
    uint64_t hash = UINT64_C(1469598103934665603);
    size_t length = self.length;
    for (size_t i = 0U; i < length; ++i) {
        unsigned short value = [self characterAtIndex:i];
        hash ^= (uint64_t)(value & 0xffU);
        hash *= UINT64_C(1099511628211);
        hash ^= (uint64_t)((value >> 8U) & 0xffU);
        hash *= UINT64_C(1099511628211);
    }
    return (unsigned long)hash;
}

@end

@implementation SFUTF8String

- (instancetype nillable)initWithUTF8Storage:(const char *nonnil)bytes
	                             length:(size_t)length
	                          unitCount:(size_t)unit_count
	                          copyBytes:(bool)copy_bytes
{
    sf_nonnil_check(bytes != nullptr);
    char *owned_bytes = nullptr;

    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    _length = unit_count;
    _byte_count = length;
    _bytes = "";
    _owns_bytes = false;

    if (copy_bytes == 0) {
        _bytes = bytes;
        return self;
    }

    owned_bytes = (char *)[self allocateMemoryWithSize:length + 1U alignment:alignof(char)];
    if (owned_bytes == nullptr) {
        [self release];
        return nullptr;
    }
    if (length > 0U) {
        memcpy(owned_bytes, bytes, length);
    }
    owned_bytes[length] = '\0';
    _bytes = owned_bytes;
    _owns_bytes = true;
    return self;
}

- (size_t)length
{
    return _length;
}

- (unsigned short)characterAtIndex:(size_t)idx
{
    return sf_string_utf8_character_at(_bytes, _byte_count, idx);
}

- (const char *)UTF8String
{
    return (const char *)(const void *)_bytes;
}

- (void)dealloc
{
    if (_owns_bytes) {
        auto allocator = self.allocator;
        if (allocator != nullptr) {
            allocator->free(allocator->ctx, (void *)(uintptr_t)_bytes, _byte_count + 1U, alignof(char));
        }
    }
    [super dealloc];
}

@end

@implementation ConstantString

- (size_t)length
{
    return (size_t)_length;
}

- (unsigned short)characterAtIndex:(size_t)idx
{
    if (idx >= (size_t)_length or _data == nullptr) {
        return 0U;
    }
    if (_flags == 2U) {
        return ((const uint16_t *)_data)[idx];
    }
    return (unsigned short)((const unsigned char *)_data)[idx];
}

- (const char *)UTF8String
{
    if (_data == nullptr) {
        return "";
    }
    if (_flags == 2U) {
        return sf_string_thread_utf8_buffer((const uint16_t *)_data, (size_t)_length);
    }
    return (const char *)_data;
}

@end

@implementation NSConstantString
@end

@implementation NXConstantString
@end
#pragma clang assume_nonnull end
