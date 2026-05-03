#pragma once

#include "objc-runtime-exports.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#    define SF_ENCODING_EXPORT
#else
#    define SF_ENCODING_EXPORT __attribute__((visibility("default")))
#endif

#define SF_METHOD_ENCODING_MAX_ARGUMENTS 32U

#ifdef __cplusplus
    extern "C" {
#endif

#pragma clang assume_nonnull begin

enum SFEncodingKind {
    SF_ENCODING_KIND_INVALID = 0,
    SF_ENCODING_KIND_UNKNOWN,
    SF_ENCODING_KIND_VOID,
    SF_ENCODING_KIND_BOOL,
    SF_ENCODING_KIND_CHAR,
    SF_ENCODING_KIND_UNSIGNED_CHAR,
    SF_ENCODING_KIND_SHORT,
    SF_ENCODING_KIND_UNSIGNED_SHORT,
    SF_ENCODING_KIND_INT,
    SF_ENCODING_KIND_UNSIGNED_INT,
    SF_ENCODING_KIND_LONG,
    SF_ENCODING_KIND_UNSIGNED_LONG,
    SF_ENCODING_KIND_LONG_LONG,
    SF_ENCODING_KIND_UNSIGNED_LONG_LONG,
    SF_ENCODING_KIND_FLOAT,
    SF_ENCODING_KIND_DOUBLE,
    SF_ENCODING_KIND_LONG_DOUBLE,
    SF_ENCODING_KIND_CHAR_POINTER,
    SF_ENCODING_KIND_OBJECT,
    SF_ENCODING_KIND_BLOCK,
    SF_ENCODING_KIND_CLASS,
    SF_ENCODING_KIND_SELECTOR,
    SF_ENCODING_KIND_POINTER,
    SF_ENCODING_KIND_ARRAY,
    SF_ENCODING_KIND_STRUCT,
    SF_ENCODING_KIND_UNION,
    SF_ENCODING_KIND_BIT_FIELD,
    SF_ENCODING_KIND_COMPLEX,
    SF_ENCODING_KIND_VECTOR
};

enum SFEncodingQualifier {
    SF_ENCODING_QUALIFIER_CONST = 1U << 0U,
    SF_ENCODING_QUALIFIER_IN = 1U << 1U,
    SF_ENCODING_QUALIFIER_INOUT = 1U << 2U,
    SF_ENCODING_QUALIFIER_OUT = 1U << 3U,
    SF_ENCODING_QUALIFIER_BYCOPY = 1U << 4U,
    SF_ENCODING_QUALIFIER_BYREF = 1U << 5U,
    SF_ENCODING_QUALIFIER_ONEWAY = 1U << 6U,
    SF_ENCODING_QUALIFIER_ATOMIC = 1U << 7U
};

enum SFPropertyEncodingOwnership {
    SF_PROPERTY_ENCODING_OWNERSHIP_ASSIGN = 0,
    SF_PROPERTY_ENCODING_OWNERSHIP_COPY,
    SF_PROPERTY_ENCODING_OWNERSHIP_STRONG,
    SF_PROPERTY_ENCODING_OWNERSHIP_WEAK
};

struct SFEncodingText {
    const char *nillable bytes;
    size_t length;
};

struct SFEncoding {
    struct {
        bool valid;
        enum SFEncodingKind kind;
        uint32_t qualifiers, pointerDepth;
        uint64_t arrayCount, bitSize;
        char code;
    } type;
    struct SFEncodingText source, name, element, fields;
};

struct SFMethodEncoding {
    struct {
        bool valid, argumentsTruncated;
    } state;
    struct SFEncodingText source;
    struct {
        struct SFEncoding returnType;
        int32_t frameSize;
        uint32_t argumentCount;
        struct SFMethodArgumentEncoding {
            struct {
                struct SFEncoding type;
                int32_t offset;
            } value;
            struct SFEncodingText source;
        } arguments[SF_METHOD_ENCODING_MAX_ARGUMENTS];
    } signature;
};

struct SFPropertyEncoding {
    struct {
        bool valid, readonly, nonatomic, dynamic, weak, eligibleForGarbageCollection, oldStyleTypeEncoding;
    } state;
    struct SFEncodingText source, getterName, setterName, ivarName;
    struct {
        struct SFEncoding type;
        enum SFPropertyEncodingOwnership ownership;
    } value;
};

SF_ENCODING_EXPORT const struct SFEncoding *nillable sf_encoding_parse(const char *nillable encoding);
SF_ENCODING_EXPORT const struct SFEncoding *nillable sf_encoding_for_class(Class nillable cls);
SF_ENCODING_EXPORT const struct SFMethodEncoding *nillable sf_method_encoding_parse(const char *nillable encoding);
SF_ENCODING_EXPORT const struct SFPropertyEncoding *nillable sf_property_encoding_parse(const char *nillable encoding);
SF_ENCODING_EXPORT bool sf_encoding_text_equal_cstr(struct SFEncodingText text, const char *nillable bytes);

#pragma clang assume_nonnull end

#ifdef __cplusplus
    }
#endif

#undef SF_ENCODING_EXPORT
