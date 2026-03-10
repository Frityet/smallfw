#include "runtime/internal.h"

#if !defined(_WIN32)
#include <ffi.h>
#endif
#include <stdarg.h>
#include <stdint.h>
#include <string.h>

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
#pragma clang diagnostic ignored "-Wcast-function-type-strict"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#pragma clang diagnostic ignored "-Wpadded"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#endif

#define SF_C_FALLBACK_MAX_ARGS 4U
#define SF_C_SIG_CACHE_SIZE 32U

#if defined(_WIN32)
#define SF_DISPATCH_C_USE_LIBFFI 0
#else
#define SF_DISPATCH_C_USE_LIBFFI 1
#endif

typedef struct SFCSigCacheEntry {
    SEL sel;
    char codes[SF_C_FALLBACK_MAX_ARGS];
    uint8_t argc;
    uint8_t unsupported;
} SFCSigCacheEntry_t;

typedef enum SFCCallArgKind {
    SFC_CALL_ARG_KIND_CODE = 0,
    SFC_CALL_ARG_KIND_AGGREGATE_WORD = 1,
    SFC_CALL_ARG_KIND_AGGREGATE_POINTER = 2,
    SFC_CALL_ARG_KIND_STRUCT_BYTES = 3,
} SFCCallArgKind_t;

typedef struct SFCCallArgInfo {
    char code;
    uint8_t kind;
    uint16_t size;
} SFCCallArgInfo_t;

typedef struct SFCTypeLayout {
    size_t size;
    size_t align;
    int contains_fp;
    int unsupported;
    const char *end;
} SFCTypeLayout_t;

#if defined(__x86_64__) && !defined(_WIN32)
typedef struct SFCSysVVaList {
    unsigned int gp_offset;
    unsigned int fp_offset;
    void *overflow_arg_area;
    void *reg_save_area;
} SFCSysVVaList_t;
#endif

#if SF_DISPATCH_C_USE_LIBFFI
typedef union SFCWordStorage {
    int8_t s8;
    uint8_t u8;
    int16_t s16;
    uint16_t u16;
    int32_t s32;
    uint32_t u32;
    long sl;
    unsigned long ul;
    long long s64;
    unsigned long long u64;
    void *ptr;
} SFCWordStorage_t;

typedef struct SFCStructFFIType {
    ffi_type type;
    ffi_type *elements[16];
} SFCStructFFIType_t;
#endif

static __thread SFCSigCacheEntry_t g_sig_cache[SF_C_SIG_CACHE_SIZE];

static int is_digit_char(char c) {
    return c >= '0' && c <= '9';
}

static int is_type_qualifier(char c) {
    return c == 'r' || c == 'n' || c == 'N' || c == 'o' || c == 'O' || c == 'R' || c == 'V';
}

static size_t align_up_size(size_t value, size_t align) {
    if (align <= 1U) {
        return value;
    }
    size_t mask = align - 1U;
    return (value + mask) & ~mask;
}

static const char *skip_type_token(const char *p) {
    while (*p && is_type_qualifier(*p)) {
        ++p;
    }

    if (*p == '^') {
        ++p;
        return skip_type_token(p);
    }

    if (*p == '{') {
        int depth = 1;
        ++p;
        while (*p && depth > 0) {
            if (*p == '{') {
                depth += 1;
            } else if (*p == '}') {
                depth -= 1;
            }
            ++p;
        }
        return p;
    }

    if (*p == '(') {
        int depth = 1;
        ++p;
        while (*p && depth > 0) {
            if (*p == '(') {
                depth += 1;
            } else if (*p == ')') {
                depth -= 1;
            }
            ++p;
        }
        return p;
    }

    if (*p == '[') {
        int depth = 1;
        ++p;
        while (*p && depth > 0) {
            if (*p == '[') {
                depth += 1;
            } else if (*p == ']') {
                depth -= 1;
            }
            ++p;
        }
        return p;
    }

    if (*p == '@' && p[1] == '?') {
        return p + 2;
    }

    if (*p != '\0') {
        ++p;
    }
    return p;
}

static char primary_type_code(const char *p) {
    while (*p && is_type_qualifier(*p)) {
        ++p;
    }
    if (*p == '^') {
        return '^';
    }
    return *p;
}

static SFCTypeLayout_t parse_type_layout(const char *p) {
    SFCTypeLayout_t layout = {0U, 1U, 0, 0, p};
    while (*layout.end && is_type_qualifier(*layout.end)) {
        ++layout.end;
    }

    switch (*layout.end) {
        case '\0':
            return layout;
        case 'v':
            layout.end += 1;
            return layout;
        case 'c':
        case 'C':
        case 'B':
            layout.size = 1U;
            layout.align = 1U;
            layout.end += 1;
            return layout;
        case 's':
        case 'S':
            layout.size = 2U;
            layout.align = 2U;
            layout.end += 1;
            return layout;
        case 'i':
        case 'I':
            layout.size = 4U;
            layout.align = 4U;
            layout.end += 1;
            return layout;
        case 'f':
            layout.size = 4U;
            layout.align = 4U;
            layout.contains_fp = 1;
            layout.end += 1;
            return layout;
        case 'l':
        case 'L':
            layout.size = sizeof(long);
            layout.align = sizeof(long);
            layout.end += 1;
            return layout;
        case 'q':
        case 'Q':
            layout.size = 8U;
            layout.align = 8U;
            layout.end += 1;
            return layout;
        case 'd':
        case 'D':
            layout.size = 8U;
            layout.align = 8U;
            layout.contains_fp = 1;
            layout.end += 1;
            return layout;
        case '*':
        case ':':
        case '@':
        case '#':
            layout.size = sizeof(void *);
            layout.align = sizeof(void *);
            if (layout.end[0] == '@' && layout.end[1] == '?') {
                layout.end += 2;
            } else {
                layout.end += 1;
            }
            return layout;
        case '^':
            layout.size = sizeof(void *);
            layout.align = sizeof(void *);
            layout.end += 1;
            (void)parse_type_layout(layout.end);
            layout.end = skip_type_token(layout.end);
            return layout;
        case '[': {
            size_t count = 0U;
            layout.end += 1;
            while (is_digit_char(*layout.end)) {
                count = (count * 10U) + (size_t)(*layout.end - '0');
                ++layout.end;
            }
            SFCTypeLayout_t elem = parse_type_layout(layout.end);
            layout.size = count * elem.size;
            layout.align = elem.align;
            layout.contains_fp = elem.contains_fp;
            layout.unsupported = elem.unsupported;
            layout.end = elem.end;
            if (*layout.end == ']') {
                ++layout.end;
            } else {
                layout.unsupported = 1;
            }
            return layout;
        }
        case '{': {
            size_t size = 0U;
            size_t align = 1U;
            int contains_fp = 0;
            int unsupported = 0;
            layout.end += 1;
            while (*layout.end && *layout.end != '=' && *layout.end != '}') {
                ++layout.end;
            }
            if (*layout.end == '}') {
                ++layout.end;
                layout.unsupported = 1;
                return layout;
            }
            if (*layout.end != '=') {
                layout.unsupported = 1;
                return layout;
            }
            ++layout.end;
            while (*layout.end && *layout.end != '}') {
                SFCTypeLayout_t field = parse_type_layout(layout.end);
                size = align_up_size(size, field.align);
                size += field.size;
                if (field.align > align) {
                    align = field.align;
                }
                contains_fp |= field.contains_fp;
                unsupported |= field.unsupported;
                layout.end = field.end;
            }
            if (*layout.end == '}') {
                ++layout.end;
            } else {
                unsupported = 1;
            }
            layout.size = align_up_size(size, align);
            layout.align = align;
            layout.contains_fp = contains_fp;
            layout.unsupported = unsupported;
            return layout;
        }
        case '(': {
            size_t size = 0U;
            size_t align = 1U;
            int contains_fp = 0;
            int unsupported = 0;
            layout.end += 1;
            while (*layout.end && *layout.end != '=' && *layout.end != ')') {
                ++layout.end;
            }
            if (*layout.end == ')') {
                ++layout.end;
                layout.unsupported = 1;
                return layout;
            }
            if (*layout.end != '=') {
                layout.unsupported = 1;
                return layout;
            }
            ++layout.end;
            while (*layout.end && *layout.end != ')') {
                SFCTypeLayout_t field = parse_type_layout(layout.end);
                if (field.size > size) {
                    size = field.size;
                }
                if (field.align > align) {
                    align = field.align;
                }
                contains_fp |= field.contains_fp;
                unsupported |= field.unsupported;
                layout.end = field.end;
            }
            if (*layout.end == ')') {
                ++layout.end;
            } else {
                unsupported = 1;
            }
            layout.size = align_up_size(size, align);
            layout.align = align;
            layout.contains_fp = contains_fp;
            layout.unsupported = unsupported;
            return layout;
        }
        default:
            layout.size = sizeof(void *);
            layout.align = sizeof(void *);
            layout.unsupported = 1;
            layout.end = skip_type_token(layout.end);
            return layout;
    }
}

static int classify_aggregate_token(const char *token, SFCCallArgInfo_t *out_info) {
    SFCTypeLayout_t layout = parse_type_layout(token);
    char code = primary_type_code(token);
    if (layout.unsupported || layout.contains_fp) {
        return 0;
    }
    out_info->size = (uint16_t)layout.size;
    if (layout.size <= sizeof(uint64_t)) {
        out_info->code = 'Q';
        out_info->kind = (uint8_t)SFC_CALL_ARG_KIND_AGGREGATE_WORD;
        return 1;
    }
    if (code == '{' && layout.size > (2U * sizeof(uint64_t))) {
        out_info->code = '{';
        out_info->kind = (uint8_t)SFC_CALL_ARG_KIND_STRUCT_BYTES;
        return 1;
    }
    out_info->code = '^';
    out_info->kind = (uint8_t)SFC_CALL_ARG_KIND_AGGREGATE_POINTER;
    return 1;
}

static int classify_type_token(const char *token, SFCCallArgInfo_t *out_info) {
    char code = primary_type_code(token);
    out_info->code = code;
    out_info->kind = (uint8_t)SFC_CALL_ARG_KIND_CODE;
    out_info->size = 0U;
    if (code == '{' || code == '(' || code == '[') {
        return classify_aggregate_token(token, out_info);
    }
    return !(code == 'f' || code == 'd' || code == 'D');
}

static int collect_return_info(SEL op, SFCCallArgInfo_t *out_info) {
    const char *types = op ? op->types : NULL;
    if (types == NULL || types[0] == '\0') {
        out_info->code = '@';
        out_info->kind = (uint8_t)SFC_CALL_ARG_KIND_CODE;
        return 1;
    }
    return classify_type_token(types, out_info);
}

static size_t collect_explicit_arg_infos(SEL op,
                                         SFCCallArgInfo_t out_infos[SF_C_FALLBACK_MAX_ARGS],
                                         int *unsupported_sig) {
    if (unsupported_sig != NULL) {
        *unsupported_sig = 0;
    }
    if (op == NULL || op->types == NULL || op->types[0] == '\0') {
        return 0;
    }

    const char *p = op->types;
    p = skip_type_token(p);
    while (is_digit_char(*p)) {
        ++p;
    }

    size_t explicit_count = 0U;
    int arg_index = 0;
    while (*p != '\0') {
        const char *token = p;
        p = skip_type_token(p);
        while (*p == '-' || is_digit_char(*p)) {
            ++p;
        }

        if (arg_index >= 2) {
            if (explicit_count >= SF_C_FALLBACK_MAX_ARGS ||
                !classify_type_token(token, &out_infos[explicit_count])) {
                if (unsupported_sig != NULL) {
                    *unsupported_sig = 1;
                }
                return explicit_count;
            }
            explicit_count += 1U;
        }
        arg_index += 1;
    }

    return explicit_count;
}

#if SF_DISPATCH_C_USE_LIBFFI
static ffi_type *ffi_type_for_code(char code) {
    switch (code) {
        case 'v':
            return &ffi_type_void;
        case 'c':
            return &ffi_type_sint8;
        case 'C':
        case 'B':
            return &ffi_type_uint8;
        case 's':
            return &ffi_type_sint16;
        case 'S':
            return &ffi_type_uint16;
        case 'i':
            return &ffi_type_sint32;
        case 'I':
            return &ffi_type_uint32;
        case 'l':
            return &ffi_type_slong;
        case 'L':
            return &ffi_type_ulong;
        case 'q':
            return &ffi_type_sint64;
        case 'Q':
            return &ffi_type_uint64;
        case '*':
        case ':':
        case '@':
        case '#':
        case '^':
        case '[':
        case '(':
        case '{':
            return &ffi_type_pointer;
        default:
            return NULL;
    }
}

static void store_word_arg(SFCWordStorage_t *storage, char code, uintptr_t raw) {
    switch (code) {
        case 'c':
            storage->s8 = (int8_t)(intptr_t)raw;
            break;
        case 'C':
        case 'B':
            storage->u8 = (uint8_t)raw;
            break;
        case 's':
            storage->s16 = (int16_t)(intptr_t)raw;
            break;
        case 'S':
            storage->u16 = (uint16_t)raw;
            break;
        case 'i':
            storage->s32 = (int32_t)(intptr_t)raw;
            break;
        case 'I':
            storage->u32 = (uint32_t)raw;
            break;
        case 'l':
            storage->sl = (long)(intptr_t)raw;
            break;
        case 'L':
            storage->ul = (unsigned long)raw;
            break;
        case 'q':
            storage->s64 = (long long)(intptr_t)raw;
            break;
        case 'Q':
            storage->u64 = (unsigned long long)raw;
            break;
        default:
            storage->ptr = (void *)raw;
            break;
    }
}

static id return_word_as_id(const SFCWordStorage_t *storage, char code) {
    switch (code) {
        case 'v':
            return (id)0;
        case 'c':
            return (id)(uintptr_t)(intptr_t)storage->s8;
        case 'C':
        case 'B':
            return (id)(uintptr_t)storage->u8;
        case 's':
            return (id)(uintptr_t)(intptr_t)storage->s16;
        case 'S':
            return (id)(uintptr_t)storage->u16;
        case 'i':
            return (id)(uintptr_t)(intptr_t)storage->s32;
        case 'I':
            return (id)(uintptr_t)storage->u32;
        case 'l':
            return (id)(uintptr_t)(intptr_t)storage->sl;
        case 'L':
            return (id)(uintptr_t)storage->ul;
        case 'q':
            return (id)(uintptr_t)(intptr_t)storage->s64;
        case 'Q':
            return (id)(uintptr_t)storage->u64;
        default:
            return (id)storage->ptr;
    }
}
#endif

static size_t collect_explicit_arg_codes(SEL op, char out_codes[SF_C_FALLBACK_MAX_ARGS], int *unsupported_sig) {
    if (unsupported_sig != NULL) {
        *unsupported_sig = 0;
    }

    if (op == NULL || op->types == NULL || op->types[0] == '\0') {
        return 0;
    }

    const char *p = op->types;

    p = skip_type_token(p);
    while (is_digit_char(*p)) {
        ++p;
    }

    size_t explicit_count = 0;
    int arg_index = 0;
    while (*p != '\0') {
        char code = primary_type_code(p);
        p = skip_type_token(p);
        while (*p == '-' || is_digit_char(*p)) {
            ++p;
        }

        if (arg_index >= 2) {
            if (code == 'f' || code == 'd' || code == 'D') {
                if (unsupported_sig != NULL) {
                    *unsupported_sig = 1;
                }
                return explicit_count;
            }
            if (explicit_count >= SF_C_FALLBACK_MAX_ARGS) {
                if (unsupported_sig != NULL) {
                    *unsupported_sig = 1;
                }
                return explicit_count;
            }
            out_codes[explicit_count++] = code;
        }
        arg_index += 1;
    }

    return explicit_count;
}

static inline size_t sig_cache_index(SEL op) {
    uintptr_t v = (uintptr_t)op;
    uintptr_t mix = (v >> 4U) ^ (v >> 11U);
    return (size_t)(mix & (SF_C_SIG_CACHE_SIZE - 1U));
}

static size_t collect_explicit_arg_codes_cached(SEL op,
                                                char out_codes[SF_C_FALLBACK_MAX_ARGS],
                                                int *unsupported_sig) {
    if (unsupported_sig != NULL) {
        *unsupported_sig = 0;
    }
    if (op == NULL) {
        return 0;
    }

    SFCSigCacheEntry_t *entry = &g_sig_cache[sig_cache_index(op)];
    if (entry->sel == op) {
        size_t argc = (size_t)entry->argc;
        if (argc > SF_C_FALLBACK_MAX_ARGS) {
            argc = SF_C_FALLBACK_MAX_ARGS;
        }
        if (argc > 0) {
            memcpy(out_codes, entry->codes, argc);
        }
        if (unsupported_sig != NULL) {
            *unsupported_sig = (int)entry->unsupported;
        }
        return argc;
    }

    int unsupported = 0;
    size_t argc = collect_explicit_arg_codes(op, out_codes, &unsupported);

    entry->sel = op;
    entry->argc = (uint8_t)argc;
    entry->unsupported = (uint8_t)(unsupported != 0);
    if (argc > 0) {
        memcpy(entry->codes, out_codes, argc);
    }

    if (unsupported_sig != NULL) {
        *unsupported_sig = unsupported;
    }
    return argc;
}

static uintptr_t read_word_arg(va_list *ap, char code) {
    switch (code) {
        case 'c':
        case 's':
        case 'i':
        case 'B':
            return (uintptr_t)(intptr_t)va_arg(*ap, int);
        case 'C':
        case 'S':
        case 'I':
            return (uintptr_t)va_arg(*ap, unsigned int);
        case 'l':
            return (uintptr_t)(intptr_t)va_arg(*ap, long);
        case 'L':
            return (uintptr_t)va_arg(*ap, unsigned long);
        case 'q':
            return (uintptr_t)(intptr_t)va_arg(*ap, long long);
        case 'Q':
            return (uintptr_t)va_arg(*ap, unsigned long long);
        case '*':
        case ':':
        case '@':
        case '#':
        case '^':
        case '[':
        case '(':
        case '{':
            return (uintptr_t)va_arg(*ap, void *);
        default:
            return (uintptr_t)va_arg(*ap, void *);
    }
}

static uintptr_t read_struct_bytes_arg(va_list *ap, size_t size) {
#if defined(__x86_64__) && !defined(_WIN32)
    SFCSysVVaList_t *sysv = (SFCSysVVaList_t *)(void *)ap;
    void *ptr = sysv->overflow_arg_area;
    size_t rounded = align_up_size(size, sizeof(uint64_t));
    sysv->overflow_arg_area = (void *)((char *)sysv->overflow_arg_area + rounded);
    return (uintptr_t)ptr;
#else
    (void)size;
    return (uintptr_t)va_arg(*ap, void *);
#endif
}

static uintptr_t read_call_arg(va_list *ap, const SFCCallArgInfo_t *info) {
    if (info->kind == (uint8_t)SFC_CALL_ARG_KIND_AGGREGATE_WORD) {
        return (uintptr_t)va_arg(*ap, unsigned long long);
    }
    if (info->kind == (uint8_t)SFC_CALL_ARG_KIND_STRUCT_BYTES) {
        return read_struct_bytes_arg(ap, info->size);
    }
    if (info->kind == (uint8_t)SFC_CALL_ARG_KIND_AGGREGATE_POINTER) {
        return (uintptr_t)va_arg(*ap, void *);
    }
    return read_word_arg(ap, info->code);
}

#if SF_DISPATCH_C_USE_LIBFFI
static int build_struct_ffi_type(const char *token, SFCStructFFIType_t *out_type) {
    const char *p = token;
    size_t count = 0U;

    while (*p && is_type_qualifier(*p)) {
        ++p;
    }
    if (*p != '{') {
        return 0;
    }
    ++p;
    while (*p && *p != '=' && *p != '}') {
        ++p;
    }
    if (*p != '=') {
        return 0;
    }
    ++p;

    while (*p && *p != '}') {
        ffi_type *field_type = ffi_type_for_code(primary_type_code(p));
        if (field_type == NULL) {
            return 0;
        }
        if (count + 1U >= sizeof(out_type->elements) / sizeof(out_type->elements[0])) {
            return 0;
        }
        if (primary_type_code(p) == '{' || primary_type_code(p) == '(' || primary_type_code(p) == '[') {
            return 0;
        }
        out_type->elements[count++] = field_type;
        p = skip_type_token(p);
    }
    if (*p != '}') {
        return 0;
    }

    out_type->elements[count] = NULL;
    out_type->type.size = 0U;
    out_type->type.alignment = 0U;
    out_type->type.type = FFI_TYPE_STRUCT;
    out_type->type.elements = out_type->elements;
    return 1;
}

static ffi_type *ffi_type_for_call_info(const SFCCallArgInfo_t *info) {
    if (info->kind == (uint8_t)SFC_CALL_ARG_KIND_AGGREGATE_WORD) {
        return &ffi_type_uint64;
    }
    if (info->kind == (uint8_t)SFC_CALL_ARG_KIND_AGGREGATE_POINTER) {
        return &ffi_type_pointer;
    }
    return ffi_type_for_code(info->code);
}
#endif

int sf_runtime_test_dispatch_is_digit_char(char c) {
    return is_digit_char(c);
}

int sf_runtime_test_dispatch_is_type_qualifier(char c) {
    return is_type_qualifier(c);
}

const char *sf_runtime_test_dispatch_skip_type_token(const char *p) {
    return skip_type_token(p);
}

char sf_runtime_test_dispatch_primary_type_code(const char *p) {
    return primary_type_code(p);
}

size_t sf_runtime_test_dispatch_collect_explicit_arg_codes(SEL op, char *out_codes,
                                                           int *unsupported_sig) {
    return collect_explicit_arg_codes(op, out_codes, unsupported_sig);
}

size_t sf_runtime_test_dispatch_collect_explicit_arg_codes_cached(SEL op, char *out_codes,
                                                                  int *unsupported_sig) {
    return collect_explicit_arg_codes_cached(op, out_codes, unsupported_sig);
}

uintptr_t sf_runtime_test_dispatch_read_word_arg(int code, ...) {
    va_list ap;
    uintptr_t value = 0;
    va_start(ap, code);
    value = read_word_arg(&ap, (char)code);
    va_end(ap);
    return value;
}

void objc_msgSend_stret(void *out, id receiver, SEL op, ...) {
    id dispatch_receiver = receiver;
    SEL dispatch_op = op;
#if SF_RUNTIME_FORWARDING
    IMP imp = sf_resolve_message_dispatch(&dispatch_receiver, &dispatch_op);
#else
    IMP imp = sf_lookup_imp(receiver, op);
#endif
    SFCCallArgInfo_t arg_infos[SF_C_FALLBACK_MAX_ARGS] = {0};
    int unsupported_sig = 0;
    size_t argc = collect_explicit_arg_infos(dispatch_op, arg_infos, &unsupported_sig);
    if (out == NULL || unsupported_sig || imp == NULL || sf_dispatch_imp_is_nil(imp)) {
        return;
    }

    uintptr_t args[SF_C_FALLBACK_MAX_ARGS] = {0, 0, 0, 0};
    va_list ap;
    va_start(ap, op);
    for (size_t i = 0; i < argc; ++i) {
        args[i] = read_call_arg(&ap, &arg_infos[i]);
    }
    va_end(ap);

    switch (argc) {
        case 0:
            ((void (*)(void *, id, SEL))imp)(out, dispatch_receiver, dispatch_op);
            return;
        case 1:
            ((void (*)(void *, id, SEL, uintptr_t))imp)(out, dispatch_receiver, dispatch_op, args[0]);
            return;
        case 2:
            ((void (*)(void *, id, SEL, uintptr_t, uintptr_t))imp)(out, dispatch_receiver, dispatch_op, args[0],
                                                                    args[1]);
            return;
        case 3:
            ((void (*)(void *, id, SEL, uintptr_t, uintptr_t, uintptr_t))imp)(out, dispatch_receiver, dispatch_op,
                                                                               args[0], args[1], args[2]);
            return;
        case 4:
            ((void (*)(void *, id, SEL, uintptr_t, uintptr_t, uintptr_t, uintptr_t))imp)(out, dispatch_receiver,
                                                                                           dispatch_op, args[0],
                                                                                           args[1], args[2], args[3]);
            return;
        default:
            return;
    }
}

id objc_msgSend(id receiver, SEL op, ...) {
    id dispatch_receiver = receiver;
    SEL dispatch_op = op;
#if SF_RUNTIME_FORWARDING
    IMP imp = sf_resolve_message_dispatch(&dispatch_receiver, &dispatch_op);
#else
    IMP imp = sf_lookup_imp(receiver, op);
#endif
#if SF_DISPATCH_C_USE_LIBFFI
    if (imp == NULL || sf_dispatch_imp_is_nil(imp)) {
        return (id)0;
    }

    SFCCallArgInfo_t ret_info = {0};
    SFCCallArgInfo_t arg_infos[SF_C_FALLBACK_MAX_ARGS] = {0};
    int unsupported_sig = 0;
    size_t argc = collect_explicit_arg_infos(dispatch_op, arg_infos, &unsupported_sig);
    if (unsupported_sig || !collect_return_info(dispatch_op, &ret_info)) {
        return (id)0;
    }
    ffi_type *ret_type = ffi_type_for_call_info(&ret_info);
    if (ret_type == NULL) {
        return (id)0;
    }

    uintptr_t args[SF_C_FALLBACK_MAX_ARGS] = {0, 0, 0, 0};
    va_list ap;
    va_start(ap, op);
    for (size_t i = 0; i < argc; ++i) {
        args[i] = read_call_arg(&ap, &arg_infos[i]);
    }
    va_end(ap);

    ffi_type *arg_types[2 + SF_C_FALLBACK_MAX_ARGS] = {&ffi_type_pointer, &ffi_type_pointer, NULL, NULL, NULL, NULL};
    void *arg_values[2 + SF_C_FALLBACK_MAX_ARGS] = {&dispatch_receiver, &dispatch_op, NULL, NULL, NULL, NULL};
    SFCWordStorage_t arg_storage[SF_C_FALLBACK_MAX_ARGS];
    SFCStructFFIType_t struct_arg_types[SF_C_FALLBACK_MAX_ARGS];
    memset(arg_storage, 0, sizeof(arg_storage));
    memset(struct_arg_types, 0, sizeof(struct_arg_types));
    for (size_t i = 0; i < argc; ++i) {
        if (arg_infos[i].kind == (uint8_t)SFC_CALL_ARG_KIND_STRUCT_BYTES) {
            const char *types = dispatch_op != NULL ? dispatch_op->types : NULL;
            const char *p = types;
            int arg_index = 0;
            if (p == NULL) {
                return (id)0;
            }
            p = skip_type_token(p);
            while (is_digit_char(*p)) {
                ++p;
            }
            while (*p != '\0') {
                const char *token = p;
                p = skip_type_token(p);
                while (*p == '-' || is_digit_char(*p)) {
                    ++p;
                }
                if (arg_index >= 2 && (size_t)(arg_index - 2) == i) {
                    if (!build_struct_ffi_type(token, &struct_arg_types[i])) {
                        return (id)0;
                    }
                    arg_types[i + 2] = &struct_arg_types[i].type;
                    arg_values[i + 2] = (void *)(uintptr_t)args[i];
                    break;
                }
                arg_index += 1;
            }
            if (arg_types[i + 2] == NULL) {
                return (id)0;
            }
            continue;
        }
        arg_types[i + 2] = ffi_type_for_call_info(&arg_infos[i]);
        if (arg_types[i + 2] == NULL) {
            return (id)0;
        }
        store_word_arg(&arg_storage[i], arg_infos[i].code, args[i]);
        arg_values[i + 2] = &arg_storage[i];
    }

    ffi_cif cif;
    if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)(argc + 2U), ret_type, arg_types) != FFI_OK) {
        return (id)0;
    }

    SFCWordStorage_t result;
    memset(&result, 0, sizeof(result));
    ffi_call(&cif, FFI_FN(imp), &result, arg_values);
    return return_word_as_id(&result, ret_info.code);
#else
    char arg_codes[SF_C_FALLBACK_MAX_ARGS] = {0};
    int unsupported_sig = 0;
    size_t argc = collect_explicit_arg_codes_cached(dispatch_op, arg_codes, &unsupported_sig);
    if (unsupported_sig || imp == NULL) {
        return (id)0;
    }

    uintptr_t args[SF_C_FALLBACK_MAX_ARGS] = {0, 0, 0, 0};
    va_list ap;
    va_start(ap, op);
    for (size_t i = 0; i < argc; ++i) {
        args[i] = read_word_arg(&ap, arg_codes[i]);
    }
    va_end(ap);

    switch (argc) {
        case 0:
            return ((id (*)(id, SEL))imp)(dispatch_receiver, dispatch_op);
        case 1:
            return ((id (*)(id, SEL, uintptr_t))imp)(dispatch_receiver, dispatch_op, args[0]);
        case 2:
            return ((id (*)(id, SEL, uintptr_t, uintptr_t))imp)(dispatch_receiver, dispatch_op, args[0], args[1]);
        case 3:
            return ((id (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t))imp)(dispatch_receiver, dispatch_op,
                                                                              args[0], args[1], args[2]);
        case 4:
            return ((id (*)(id, SEL, uintptr_t, uintptr_t, uintptr_t, uintptr_t))imp)(dispatch_receiver, dispatch_op,
                                                                                        args[0], args[1],
                                                                                        args[2], args[3]);
        default:
            return (id)0;
    }
#endif
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
