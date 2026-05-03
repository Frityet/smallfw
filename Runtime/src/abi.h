#pragma once

#include "c2x-compat.h"

#include <stddef.h>
#include <stdint.h>
#include <stdatomic.h>
#include <iso646.h>

#include "locking.h"
#include "objc-runtime-exports.h"
#include "sf-allocator.h"

#pragma clang assume_nonnull begin

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sf_objc_method {
    IMP imp;
    SEL nillable selector;
    const char *nillable types;
} SFObjCMethod_t;

typedef struct SFObjCMethodList {
    struct SFObjCMethodList *nillable next;
    int32_t count;
    int64_t size;
    SFObjCMethod_t methods[];
} SFObjCMethodList_t;

typedef struct sf_objc_class {
    struct sf_objc_class *nillable isa;
    struct sf_objc_class *nillable superclass;
    const char *nillable name;
    long version;
    unsigned long info;
    long instance_size;
    void *nillable ivars;
    SFObjCMethodList_t *nillable methods;
    void *nillable dtable;
    void *nillable subclass_list;
    void *nillable sibling_class;
    void *nillable protocols;
    void *nillable gc_object_type;
    unsigned long abi_version;
#if !defined(_WIN32)
    void *nillable ivar_offsets;
    unsigned long flags;
#endif
    void *nillable properties;
} SFObjCClass_t;

typedef struct sf_objc_ivar {
    const char *nillable name;
    const char *nillable type;
    int32_t *nillable offset;
    uint32_t size;
    uint32_t flags;
} SFObjCIvar_t;

typedef struct SFObjCIvarList {
    uintptr_t count;
    uintptr_t item_size;
    SFObjCIvar_t ivars[];
} SFObjCIvarList_t;

typedef struct SFObjCInit {
    uint64_t version;
    void *nillable selectors_start;
    void *nillable selectors_stop;
    void *nillable classes_start;
    void *nillable classes_stop;
    void *nillable class_refs_start;
    void *nillable class_refs_stop;
    void *nillable cats_start;
    void *nillable cats_stop;
    void *nillable protocols_start;
    void *nillable protocols_stop;
    void *nillable protocol_refs_start;
    void *nillable protocol_refs_stop;
    void *nillable aliases_start;
    void *nillable aliases_stop;
    void *nillable const_strings_start;
    void *nillable const_strings_stop;
} SFObjCInit_t;

typedef struct SFObjCSelectorFields {
    const char *nillable name;
    const char *nillable types;
} SFObjCSelectorFields_t;

static inline const SFObjCSelectorFields_t *nillable sf_selector_fields(SEL nillable sel)
{
    return (const SFObjCSelectorFields_t *)(const void *)sel;
}

static inline const char *nillable sf_selector_name(SEL nillable sel)
{
    const SFObjCSelectorFields_t *fields = sf_selector_fields(sel);
    return fields != nullptr ? fields->name : nullptr;
}

static inline const char *nillable sf_selector_types(SEL nillable sel)
{
    const SFObjCSelectorFields_t *fields = sf_selector_fields(sel);
    return fields != nullptr ? fields->types : nullptr;
}

static inline SEL nillable sf_method_selector_ptr(SFObjCMethod_t *nillable method)
{
    return method != nullptr ? method->selector : nullptr;
}

static inline const char *nillable sf_method_types(SFObjCMethod_t *nillable method)
{
    return method != nullptr ? method->types : nullptr;
}

static inline void sf_method_assign_selector(SFObjCMethod_t *nonnil method, SEL nillable selector,
                                             const char *nillable types)
{
    method->selector = selector;
    method->types = (types != nullptr) ? types : sf_selector_types(selector);
}

typedef uint32_t SFObjRefcount_t;
typedef struct SFObjColdState SFObjColdState_t;

typedef struct SFGroupState {
    struct SFObjHeader *nillable root, *nillable head;
    size_t group_live_count;
    uint32_t dead, reserved;
    SFRuntimeMutex_t group_lock;
} SFGroupState_t;

enum SFObjFlags {
    SF_OBJ_FLAG_NONE = 0U,
    SF_OBJ_FLAG_IMMORTAL = 1U << 0U,
    SF_OBJ_FLAG_EMBEDDED = 1U << 1U,
    SF_OBJ_FLAG_HAS_COLD = 1U << 2U,
    SF_OBJ_FLAG_INLINE_VALUE = 1U << 3U,
};

enum SFObjClassFlags {
    SF_OBJ_CLASS_FLAG_NONE = 0U,
    SF_OBJ_CLASS_FLAG_TRIVIAL_RELEASE = 1U << 0U,
    SF_OBJ_CLASS_FLAG_HAS_OBJECT_IVARS = 1U << 1U,
    SF_OBJ_CLASS_FLAG_HAS_CXX_DESTRUCT = 1U << 2U,
    SF_OBJ_CLASS_FLAG_VALUE_OBJECT = 1U << 3U,
    SF_OBJ_CLASS_FLAG_INLINE_VALUE_ELIGIBLE = 1U << 4U,
};

enum SFObjAuxFlags {
    SF_OBJ_AUX_FLAG_NONE = 0U,
    SF_OBJ_AUX_FLAG_HAS_EXCEPTION_METADATA = 1U << 0U,
    SF_OBJ_AUX_FLAG_GROUP_DEAD = 1U << 1U,
};

enum {
    SF_OBJ_FLAG_PACKED_MASK = 0x000000FFU,
    SF_OBJ_AUX_FLAGS_SHIFT = 8U,
    SF_OBJ_AUX_FLAGS_MASK = 0x0000FF00U,
    SF_OBJ_COOKIE_SHIFT = 16U,
    SF_OBJ_COOKIE_MASK = 0x00FF0000U,
    SF_OBJ_CLASS_FLAGS_SHIFT = 24U,
    SF_OBJ_CLASS_FLAGS_MASK = 0xFF000000U,
    SF_OBJ_HEADER_COOKIE_LIVE = 0xA5U,
};

#if SF_RUNTIME_COMPACT_HEADERS
typedef struct SFInlineValueHeader {
#if SF_RUNTIME_VALIDATION
    uint64_t magic;
#endif
    SFObjRefcount_t refcount;
    uint32_t state, flags, alloc_size, reserved, class_flags;
    uintptr_t tagged_parent;
#if SF_RUNTIME_GENERIC_METADATA
    Class nillable generic_type_class;
#endif
} SFInlineValueHeader_t;

struct SFObjColdState {
#if SF_RUNTIME_VALIDATION
    struct SFObjHeader *nillable live_next;
#endif
    SFAllocator_t *nillable allocator;
    id nillable parent;
#if SF_RUNTIME_GENERIC_METADATA
    Class nillable generic_type_class;
#endif
    struct SFObjHeader *nillable group_root;
    struct SFObjHeader *nillable group_next;
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *nillable group;
#else
    struct SFObjHeader *nillable inline_group_head;
    size_t inline_group_live_count;
    uint32_t inline_group_dead;
    uint32_t inline_group_reserved;
#endif
};

typedef struct SFObjHeader {
#if SF_RUNTIME_VALIDATION
    uint64_t magic;
#endif
    SFObjRefcount_t refcount;
    uint32_t state, flags, alloc_size, reserved, class_flags, aux_flags;
    SFObjColdState_t *nillable cold;
} SFObjHeader_t;
#else
typedef struct SFObjHeader {
#if SF_RUNTIME_VALIDATION
    uint64_t magic;
    struct SFObjHeader *nillable live_next;
#endif
    SFObjRefcount_t refcount;
    uint32_t state, flags, alloc_size, reserved;
    SFAllocator_t *nillable allocator;
#if SF_RUNTIME_GENERIC_METADATA
    Class nillable generic_type_class;
#endif
    id nillable parent;
    SFGroupState_t *nillable group;
    struct SFObjHeader *nillable group_next;
} SFObjHeader_t;
#endif

static inline uint32_t sf_header_aux_flags(SFObjHeader_t *nillable hdr)
{
    if (hdr == nullptr) {
        return 0U;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return hdr->aux_flags;
#else
    return (hdr->flags & SF_OBJ_AUX_FLAGS_MASK) >> SF_OBJ_AUX_FLAGS_SHIFT;
#endif
}

static inline void sf_header_set_aux_flags(SFObjHeader_t *nillable hdr, uint32_t aux_flags)
{
    if (hdr == nullptr) {
        return;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    hdr->aux_flags = aux_flags;
#else
    hdr->flags =
        (hdr->flags & ~SF_OBJ_AUX_FLAGS_MASK) | ((aux_flags << SF_OBJ_AUX_FLAGS_SHIFT) & SF_OBJ_AUX_FLAGS_MASK);
#endif
}

static inline void sf_header_or_aux_flags(SFObjHeader_t *nillable hdr, uint32_t aux_flags)
{
    sf_header_set_aux_flags(hdr, sf_header_aux_flags(hdr) | aux_flags);
}

static inline void sf_header_clear_aux_flags(SFObjHeader_t *nillable hdr, uint32_t aux_flags)
{
    sf_header_set_aux_flags(hdr, sf_header_aux_flags(hdr) & ~aux_flags);
}

static inline int sf_header_has_aux_flag(SFObjHeader_t *nillable hdr, uint32_t aux_flag)
{
    return (sf_header_aux_flags(hdr) & aux_flag) != 0U;
}

static inline void sf_header_set_live_cookie(SFObjHeader_t *nillable hdr)
{
    if (hdr == nullptr) {
        return;
    }
    hdr->flags =
        (hdr->flags & ~SF_OBJ_COOKIE_MASK) | ((uint32_t)SF_OBJ_HEADER_COOKIE_LIVE << SF_OBJ_COOKIE_SHIFT);
}

static inline void sf_header_clear_live_cookie(SFObjHeader_t *nillable hdr)
{
    if (hdr == nullptr) {
        return;
    }
    hdr->flags &= ~SF_OBJ_COOKIE_MASK;
}

static inline int sf_header_has_live_cookie(SFObjHeader_t *nillable hdr)
{
    return hdr != nullptr and
           ((hdr->flags & SF_OBJ_COOKIE_MASK) >> SF_OBJ_COOKIE_SHIFT) == (uint32_t)SF_OBJ_HEADER_COOKIE_LIVE;
}

static inline uint32_t sf_header_class_flags(SFObjHeader_t *nillable hdr)
{
    if (hdr == nullptr) {
        return 0U;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return hdr->class_flags;
#else
    return (hdr->flags & SF_OBJ_CLASS_FLAGS_MASK) >> SF_OBJ_CLASS_FLAGS_SHIFT;
#endif
}

static inline void sf_header_set_class_flags(SFObjHeader_t *nillable hdr, uint32_t class_flags)
{
    if (hdr == nullptr) {
        return;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    hdr->class_flags = class_flags;
#else
    hdr->flags =
        (hdr->flags & ~SF_OBJ_CLASS_FLAGS_MASK) | ((class_flags << SF_OBJ_CLASS_FLAGS_SHIFT) & SF_OBJ_CLASS_FLAGS_MASK);
#endif
}

#define SF_OBJ_HEADER_MAGIC UINT64_C(0x53464f424a484452)
enum SFObjState {
    SF_OBJ_STATE_DISPOSED = 0U,
    SF_OBJ_STATE_LIVE = 1U,
};

SFObjCClass_t *nillable sf_class_from_name(const char *nillable name);
void sf_register_classes(SFObjCClass_t *nillable *nillable start,
                         SFObjCClass_t *nillable *nillable stop);
void sf_finalize_registered_classes(void);

Class nillable sf_object_class(id nillable obj);
bool sf_object_is_heap(id nillable obj);

SFObjHeader_t *nillable sf_header_from_object(id nillable obj);
id nillable sf_alloc_object(Class nillable cls, SFAllocator_t *nillable allocator);

size_t sf_cstr_len(const char *nillable s);
uint64_t sf_hash_bytes(const void *nillable data, size_t size);
uint64_t sf_hash_ptr(const void *nillable p);

#ifdef __cplusplus
}
#endif

#pragma clang assume_nonnull end
