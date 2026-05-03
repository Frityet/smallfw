#include "encoding.h"

#include "internal.h"

#include <stdlib.h>
#include <string.h>

enum { SF_ENCODING_CACHE_CAPACITY = 8192U };

static inline struct SFEncodingText sf_encoding_text(const char *bytes, size_t length)
{
    return (struct SFEncodingText){.bytes = bytes, .length = length};
}

static inline struct SFEncoding sf_invalid_encoding(void)
{
    return (struct SFEncoding){.type = {.kind = SF_ENCODING_KIND_INVALID}};
}

static inline struct SFMethodEncoding sf_invalid_method_encoding(void)
{
    return (struct SFMethodEncoding){0};
}

static inline struct SFPropertyEncoding sf_invalid_property_encoding(void)
{
    return (struct SFPropertyEncoding){0};
}

struct SFTypeEncodingCacheEntry {
    char *nillable source;
    uint64_t hash;
    struct SFEncoding encoding;
};

struct SFMethodEncodingCacheEntry {
    char *nillable source;
    uint64_t hash;
    struct SFMethodEncoding encoding;
};

struct SFPropertyEncodingCacheEntry {
    char *nillable source;
    uint64_t hash;
    struct SFPropertyEncoding encoding;
};

static SFRuntimeRwlock_t g_encoding_cache_lock = SF_RUNTIME_RWLOCK_INITIALIZER;
static struct SFTypeEncodingCacheEntry g_type_encoding_cache[SF_ENCODING_CACHE_CAPACITY];
static struct SFMethodEncodingCacheEntry g_method_encoding_cache[SF_ENCODING_CACHE_CAPACITY];
static struct SFPropertyEncodingCacheEntry g_property_encoding_cache[SF_ENCODING_CACHE_CAPACITY];

static uint64_t sf_encoding_hash_cstr(const char *bytes)
{
    uint64_t hash = UINT64_C(1469598103934665603);
    while (*bytes != '\0') {
        hash ^= (uint8_t)*bytes;
        hash *= UINT64_C(1099511628211);
        ++bytes;
    }
    return hash != 0U ? hash : 1U;
}

static char *nillable sf_encoding_copy_cstr(const char *bytes)
{
    size_t length = strlen(bytes) + 1U;
    auto copy = (char *)sf_runtime_test_malloc(length);
    if (copy == nullptr) {
        return nullptr;
    }
    memcpy(copy, bytes, length);
    return copy;
}

static inline size_t sf_encoding_cache_index(uint64_t hash, size_t step)
{
    return (size_t)((hash + step) & (SF_ENCODING_CACHE_CAPACITY - 1U));
}

static inline bool sf_encoding_is_digit(char c)
{
    return c >= '0' && c <= '9';
}

static inline uint32_t sf_encoding_qualifier_for_code(char code)
{
    switch (code) {
        case 'r':
            return SF_ENCODING_QUALIFIER_CONST;
        case 'n':
            return SF_ENCODING_QUALIFIER_IN;
        case 'N':
            return SF_ENCODING_QUALIFIER_INOUT;
        case 'o':
            return SF_ENCODING_QUALIFIER_OUT;
        case 'O':
            return SF_ENCODING_QUALIFIER_BYCOPY;
        case 'R':
            return SF_ENCODING_QUALIFIER_BYREF;
        case 'V':
            return SF_ENCODING_QUALIFIER_ONEWAY;
        case 'A':
            return SF_ENCODING_QUALIFIER_ATOMIC;
        default:
            return 0U;
    }
}

static uint64_t sf_encoding_parse_unsigned(const char **cursor)
{
    auto p = *cursor;
    uint64_t value = 0U;
    while (sf_encoding_is_digit(*p)) {
        value = (value * 10U) + (uint64_t)(*p - '0');
        ++p;
    }
    *cursor = p;
    return value;
}

static int32_t sf_encoding_parse_signed(const char **cursor)
{
    auto p = *cursor;
    bool negative = false;
    int64_t value = 0;
    if (*p == '-') {
        negative = true;
        ++p;
    }
    while (sf_encoding_is_digit(*p)) {
        value = (value * 10) + (int64_t)(*p - '0');
        if (value > INT32_MAX) {
            value = INT32_MAX;
        }
        ++p;
    }
    *cursor = p;
    return negative ? (int32_t)-value : (int32_t)value;
}

static const char *sf_encoding_skip_quoted(const char *cursor)
{
    if (*cursor != '"') {
        return nullptr;
    }
    ++cursor;
    while (*cursor != '\0' && *cursor != '"') {
        ++cursor;
    }
    return *cursor == '"' ? cursor + 1 : nullptr;
}

static const char *sf_parse_encoding_type(const char *start, struct SFEncoding *out);

static const char *sf_parse_encoding_aggregate(const char *cursor, char close, struct SFEncoding *out)
{
    auto name_start = cursor;
    while (*cursor != '\0' && *cursor != '=' && *cursor != close) {
        ++cursor;
    }
    out->name = sf_encoding_text(name_start, (size_t)(cursor - name_start));
    if (*cursor == close) {
        return cursor + 1;
    }
    if (*cursor != '=') {
        return nullptr;
    }
    ++cursor;
    auto fields_start = cursor;
    while (*cursor != '\0' && *cursor != close) {
        while (*cursor == '"') {
            auto quoted_end = sf_encoding_skip_quoted(cursor);
            if (quoted_end == nullptr) {
                return nullptr;
            }
            cursor = quoted_end;
        }
        if (*cursor == close) {
            break;
        }
        struct SFEncoding field = sf_invalid_encoding();
        auto field_end = sf_parse_encoding_type(cursor, &field);
        if (field_end == nullptr) {
            return nullptr;
        }
        cursor = field_end;
    }
    if (*cursor != close) {
        return nullptr;
    }
    out->fields = sf_encoding_text(fields_start, (size_t)(cursor - fields_start));
    return cursor + 1;
}

static void sf_encoding_set_simple_kind(struct SFEncoding *out, char code)
{
    switch (code) {
        case 'v':
            out->type.kind = SF_ENCODING_KIND_VOID;
            break;
        case 'B':
            out->type.kind = SF_ENCODING_KIND_BOOL;
            break;
        case 'c':
            out->type.kind = SF_ENCODING_KIND_CHAR;
            break;
        case 'C':
            out->type.kind = SF_ENCODING_KIND_UNSIGNED_CHAR;
            break;
        case 's':
            out->type.kind = SF_ENCODING_KIND_SHORT;
            break;
        case 'S':
            out->type.kind = SF_ENCODING_KIND_UNSIGNED_SHORT;
            break;
        case 'i':
            out->type.kind = SF_ENCODING_KIND_INT;
            break;
        case 'I':
            out->type.kind = SF_ENCODING_KIND_UNSIGNED_INT;
            break;
        case 'l':
            out->type.kind = SF_ENCODING_KIND_LONG;
            break;
        case 'L':
            out->type.kind = SF_ENCODING_KIND_UNSIGNED_LONG;
            break;
        case 'q':
            out->type.kind = SF_ENCODING_KIND_LONG_LONG;
            break;
        case 'Q':
            out->type.kind = SF_ENCODING_KIND_UNSIGNED_LONG_LONG;
            break;
        case 'f':
            out->type.kind = SF_ENCODING_KIND_FLOAT;
            break;
        case 'd':
            out->type.kind = SF_ENCODING_KIND_DOUBLE;
            break;
        case 'D':
            out->type.kind = SF_ENCODING_KIND_LONG_DOUBLE;
            break;
        case '*':
            out->type.kind = SF_ENCODING_KIND_CHAR_POINTER;
            break;
        case '#':
            out->type.kind = SF_ENCODING_KIND_CLASS;
            break;
        case ':':
            out->type.kind = SF_ENCODING_KIND_SELECTOR;
            break;
        case '?':
            out->type.kind = SF_ENCODING_KIND_UNKNOWN;
            break;
        default:
            out->type.kind = SF_ENCODING_KIND_INVALID;
            break;
    }
}

static const char *sf_parse_encoding_type(const char *start, struct SFEncoding *out)
{
    auto cursor = start;
    *out = sf_invalid_encoding();
    while (*cursor != '\0') {
        uint32_t qualifier = sf_encoding_qualifier_for_code(*cursor);
        if (qualifier == 0U) {
            break;
        }
        out->type.qualifiers |= qualifier;
        ++cursor;
    }
    if (*cursor == '\0') {
        return nullptr;
    }
    out->type.code = *cursor;
    ++cursor;
    switch (out->type.code) {
        case 'v':
        case 'B':
        case 'c':
        case 'C':
        case 's':
        case 'S':
        case 'i':
        case 'I':
        case 'l':
        case 'L':
        case 'q':
        case 'Q':
        case 'f':
        case 'd':
        case 'D':
        case '*':
        case '#':
        case ':':
        case '?':
            sf_encoding_set_simple_kind(out, out->type.code);
            break;
        case '@':
            if (*cursor == '?') {
                out->type.kind = SF_ENCODING_KIND_BLOCK;
                ++cursor;
            } else {
                out->type.kind = SF_ENCODING_KIND_OBJECT;
                if (*cursor == '"') {
                    auto name_start = cursor + 1;
                    auto quote_end = sf_encoding_skip_quoted(cursor);
                    if (quote_end == nullptr) {
                        return nullptr;
                    }
                    out->name = sf_encoding_text(name_start, (size_t)(quote_end - name_start - 1));
                    cursor = quote_end;
                }
            }
            break;
        case '^': {
            out->type.kind = SF_ENCODING_KIND_POINTER;
            out->type.pointerDepth = 1U;
            while (*cursor == '^') {
                ++out->type.pointerDepth;
                ++cursor;
            }
            struct SFEncoding element = sf_invalid_encoding();
            auto element_end = sf_parse_encoding_type(cursor, &element);
            if (element_end == nullptr) {
                return nullptr;
            }
            out->element = element.source;
            cursor = element_end;
            break;
        }
        case '[': {
            out->type.kind = SF_ENCODING_KIND_ARRAY;
            out->type.arrayCount = sf_encoding_parse_unsigned(&cursor);
            struct SFEncoding element = sf_invalid_encoding();
            auto element_end = sf_parse_encoding_type(cursor, &element);
            if (element_end == nullptr || *element_end != ']') {
                return nullptr;
            }
            out->element = element.source;
            cursor = element_end + 1;
            break;
        }
        case '{':
            out->type.kind = SF_ENCODING_KIND_STRUCT;
            cursor = sf_parse_encoding_aggregate(cursor, '}', out);
            if (cursor == nullptr) {
                return nullptr;
            }
            break;
        case '(':
            out->type.kind = SF_ENCODING_KIND_UNION;
            cursor = sf_parse_encoding_aggregate(cursor, ')', out);
            if (cursor == nullptr) {
                return nullptr;
            }
            break;
        case 'b':
            out->type.kind = SF_ENCODING_KIND_BIT_FIELD;
            out->type.bitSize = sf_encoding_parse_unsigned(&cursor);
            break;
        case 'j': {
            out->type.kind = SF_ENCODING_KIND_COMPLEX;
            struct SFEncoding element = sf_invalid_encoding();
            auto element_end = sf_parse_encoding_type(cursor, &element);
            if (element_end == nullptr) {
                return nullptr;
            }
            out->element = element.source;
            cursor = element_end;
            break;
        }
        case '!': {
            out->type.kind = SF_ENCODING_KIND_VECTOR;
            if (*cursor == '[') {
                struct SFEncoding element = sf_invalid_encoding();
                auto element_end = sf_parse_encoding_type(cursor, &element);
                if (element_end == nullptr) {
                    return nullptr;
                }
                out->element = element.source;
                cursor = element_end;
            }
            break;
        }
        default:
            return nullptr;
    }
    if (out->type.kind == SF_ENCODING_KIND_INVALID) {
        return nullptr;
    }
    out->type.valid = true;
    out->source = sf_encoding_text(start, (size_t)(cursor - start));
    return cursor;
}

static const struct SFEncoding *nillable sf_type_encoding_cache_lookup_or_insert(const char *encoding)
{
    if (encoding == nullptr || *encoding == '\0') {
        return nullptr;
    }
    uint64_t hash = sf_encoding_hash_cstr(encoding);
    sf_runtime_rwlock_wrlock(&g_encoding_cache_lock);
    for (size_t i = 0; i < SF_ENCODING_CACHE_CAPACITY; ++i) {
        auto slot = &g_type_encoding_cache[sf_encoding_cache_index(hash, i)];
        if (slot->source == nullptr) {
            auto copy = sf_encoding_copy_cstr(encoding);
            struct SFEncoding parsed = sf_invalid_encoding();
            if (copy == nullptr || sf_parse_encoding_type(copy, &parsed) == nullptr) {
                free(copy);
                sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
                return nullptr;
            }
            slot->source = copy;
            slot->hash = hash;
            slot->encoding = parsed;
            sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
            return &slot->encoding;
        }
        if (slot->hash == hash && strcmp(slot->source, encoding) == 0) {
            auto parsed = &slot->encoding;
            sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
            return parsed;
        }
    }
    sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
    return nullptr;
}

const struct SFEncoding *sf_encoding_parse(const char *encoding)
{
    return sf_type_encoding_cache_lookup_or_insert(encoding);
}

const struct SFEncoding *sf_encoding_for_class(Class cls)
{
    return sf_class_cached_encoding(cls);
}

static bool sf_method_encoding_parse_uncached(const char *encoding, struct SFMethodEncoding *out)
{
    if (encoding == nullptr || *encoding == '\0') {
        *out = sf_invalid_method_encoding();
        return false;
    }
    struct SFMethodEncoding method = sf_invalid_method_encoding();
    auto cursor = encoding;
    auto return_end = sf_parse_encoding_type(cursor, &method.signature.returnType);
    if (return_end == nullptr) {
        *out = sf_invalid_method_encoding();
        return false;
    }
    cursor = return_end;
    if (*cursor == '-' || sf_encoding_is_digit(*cursor)) {
        method.signature.frameSize = sf_encoding_parse_signed(&cursor);
    }
    while (*cursor != '\0') {
        auto argument_start = cursor;
        struct SFMethodArgumentEncoding argument = {0};
        auto argument_type_end = sf_parse_encoding_type(cursor, &argument.value.type);
        if (argument_type_end == nullptr) {
            *out = sf_invalid_method_encoding();
            return false;
        }
        cursor = argument_type_end;
        if (*cursor == '-' || sf_encoding_is_digit(*cursor)) {
            argument.value.offset = sf_encoding_parse_signed(&cursor);
        }
        argument.source = sf_encoding_text(argument_start, (size_t)(cursor - argument_start));
        if (method.signature.argumentCount < SF_METHOD_ENCODING_MAX_ARGUMENTS) {
            method.signature.arguments[method.signature.argumentCount] = argument;
        } else {
            method.state.argumentsTruncated = true;
        }
        ++method.signature.argumentCount;
    }
    method.state.valid = true;
    method.source = sf_encoding_text(encoding, (size_t)(cursor - encoding));
    *out = method;
    return true;
}

const struct SFMethodEncoding *sf_method_encoding_parse(const char *encoding)
{
    if (encoding == nullptr || *encoding == '\0') {
        return nullptr;
    }
    uint64_t hash = sf_encoding_hash_cstr(encoding);
    sf_runtime_rwlock_wrlock(&g_encoding_cache_lock);
    for (size_t i = 0; i < SF_ENCODING_CACHE_CAPACITY; ++i) {
        auto slot = &g_method_encoding_cache[sf_encoding_cache_index(hash, i)];
        if (slot->source == nullptr) {
            auto copy = sf_encoding_copy_cstr(encoding);
            struct SFMethodEncoding parsed = sf_invalid_method_encoding();
            if (copy == nullptr || !sf_method_encoding_parse_uncached(copy, &parsed)) {
                free(copy);
                sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
                return nullptr;
            }
            slot->source = copy;
            slot->hash = hash;
            slot->encoding = parsed;
            sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
            return &slot->encoding;
        }
        if (slot->hash == hash && strcmp(slot->source, encoding) == 0) {
            auto parsed = &slot->encoding;
            sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
            return parsed;
        }
    }
    sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
    return nullptr;
}

static struct SFEncodingText sf_property_attribute_value(const char *start)
{
    auto end = start;
    while (*end != '\0' && *end != ',') {
        ++end;
    }
    return sf_encoding_text(start, (size_t)(end - start));
}

static bool sf_property_encoding_parse_uncached(const char *encoding, struct SFPropertyEncoding *out)
{
    if (encoding == nullptr || *encoding == '\0') {
        *out = sf_invalid_property_encoding();
        return false;
    }
    struct SFPropertyEncoding property = {.value = {.ownership = SF_PROPERTY_ENCODING_OWNERSHIP_ASSIGN}};
    auto cursor = encoding;
    while (*cursor != '\0') {
        auto attribute = *cursor;
        ++cursor;
        switch (attribute) {
            case 'T':
            case 't': {
                struct SFEncoding type = sf_invalid_encoding();
                auto type_end = sf_parse_encoding_type(cursor, &type);
                if (type_end == nullptr) {
                    *out = sf_invalid_property_encoding();
                    return false;
                }
                property.value.type = type;
                property.state.oldStyleTypeEncoding = property.state.oldStyleTypeEncoding || attribute == 't';
                cursor = type_end;
                break;
            }
            case 'V':
                property.ivarName = sf_property_attribute_value(cursor);
                cursor += property.ivarName.length;
                break;
            case 'G':
                property.getterName = sf_property_attribute_value(cursor);
                cursor += property.getterName.length;
                break;
            case 'S':
                property.setterName = sf_property_attribute_value(cursor);
                cursor += property.setterName.length;
                break;
            case 'R':
                property.state.readonly = true;
                break;
            case 'C':
                property.value.ownership = SF_PROPERTY_ENCODING_OWNERSHIP_COPY;
                break;
            case '&':
                property.value.ownership = SF_PROPERTY_ENCODING_OWNERSHIP_STRONG;
                break;
            case 'W':
                property.value.ownership = SF_PROPERTY_ENCODING_OWNERSHIP_WEAK;
                property.state.weak = true;
                break;
            case 'N':
                property.state.nonatomic = true;
                break;
            case 'D':
                property.state.dynamic = true;
                break;
            case 'P':
                property.state.eligibleForGarbageCollection = true;
                break;
            default: {
                auto value = sf_property_attribute_value(cursor);
                cursor += value.length;
                break;
            }
        }
        if (*cursor == ',') {
            ++cursor;
        }
    }
    if (!property.value.type.type.valid) {
        *out = sf_invalid_property_encoding();
        return false;
    }
    property.state.valid = true;
    property.source = sf_encoding_text(encoding, (size_t)(cursor - encoding));
    *out = property;
    return true;
}

const struct SFPropertyEncoding *sf_property_encoding_parse(const char *encoding)
{
    if (encoding == nullptr || *encoding == '\0') {
        return nullptr;
    }
    uint64_t hash = sf_encoding_hash_cstr(encoding);
    sf_runtime_rwlock_wrlock(&g_encoding_cache_lock);
    for (size_t i = 0; i < SF_ENCODING_CACHE_CAPACITY; ++i) {
        auto slot = &g_property_encoding_cache[sf_encoding_cache_index(hash, i)];
        if (slot->source == nullptr) {
            auto copy = sf_encoding_copy_cstr(encoding);
            struct SFPropertyEncoding parsed = sf_invalid_property_encoding();
            if (copy == nullptr || !sf_property_encoding_parse_uncached(copy, &parsed)) {
                free(copy);
                sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
                return nullptr;
            }
            slot->source = copy;
            slot->hash = hash;
            slot->encoding = parsed;
            sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
            return &slot->encoding;
        }
        if (slot->hash == hash && strcmp(slot->source, encoding) == 0) {
            auto parsed = &slot->encoding;
            sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
            return parsed;
        }
    }
    sf_runtime_rwlock_unlock(&g_encoding_cache_lock);
    return nullptr;
}

bool sf_encoding_text_equal_cstr(struct SFEncodingText text, const char *bytes)
{
    if (text.bytes == nullptr || bytes == nullptr) {
        return text.bytes == bytes;
    }
    auto length = strlen(bytes);
    return text.length == length && memcmp(text.bytes, bytes, length) == 0;
}
