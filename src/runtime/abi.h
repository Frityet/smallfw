#pragma once

#include <stddef.h>
#include <stdint.h>
#include <iso646.h>

#include "runtime/locking.h"
#include "runtime/objc/runtime_exports.h"
#include "runtime/sf_allocator.h"

#pragma clang assume_nonnull begin

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sf_objc_method {
    IMP imp;
    SEL _Nullable selector;
    const char *_Nullable types;
} SFObjCMethod_t;

typedef struct SFObjCMethodList {
    struct SFObjCMethodList *_Nullable next;
    int32_t count;
    int64_t size;
    SFObjCMethod_t methods[];
} SFObjCMethodList_t;

typedef struct sf_objc_class {
    struct sf_objc_class *_Nullable isa;
    struct sf_objc_class *_Nullable superclass;
    const char *_Nullable name;
    long version;
    unsigned long info;
    long instance_size;
    void *_Nullable ivars;
    SFObjCMethodList_t *_Nullable methods;
    void *_Nullable dtable;
    void *_Nullable subclass_list;
    void *_Nullable sibling_class;
    void *_Nullable protocols;
    void *_Nullable gc_object_type;
    unsigned long abi_version;
#if !defined(_WIN32)
    void *_Nullable ivar_offsets;
    unsigned long flags;
#endif
    void *_Nullable properties;
} SFObjCClass_t;

typedef struct sf_objc_ivar {
    const char *_Nullable name;
    const char *_Nullable type;
    int32_t *_Nullable offset;
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
    void *_Nullable selectors_start;
    void *_Nullable selectors_stop;
    void *_Nullable classes_start;
    void *_Nullable classes_stop;
    void *_Nullable class_refs_start;
    void *_Nullable class_refs_stop;
    void *_Nullable cats_start;
    void *_Nullable cats_stop;
    void *_Nullable protocols_start;
    void *_Nullable protocols_stop;
    void *_Nullable protocol_refs_start;
    void *_Nullable protocol_refs_stop;
    void *_Nullable aliases_start;
    void *_Nullable aliases_stop;
    void *_Nullable const_strings_start;
    void *_Nullable const_strings_stop;
} SFObjCInit_t;

typedef struct SFObjCSelectorFields {
    const char *_Nullable name;
    const char *_Nullable types;
} SFObjCSelectorFields_t;

static inline const SFObjCSelectorFields_t *_Nullable sf_selector_fields(SEL _Nullable sel)
{
    return (const SFObjCSelectorFields_t *)(const void *)sel;
}

static inline const char *_Nullable sf_selector_name(SEL _Nullable sel)
{
    const SFObjCSelectorFields_t *fields = sf_selector_fields(sel);
    return fields != NULL ? fields->name : NULL;
}

static inline const char *_Nullable sf_selector_types(SEL _Nullable sel)
{
    const SFObjCSelectorFields_t *fields = sf_selector_fields(sel);
    return fields != NULL ? fields->types : NULL;
}

static inline SEL _Nullable sf_method_selector_ptr(SFObjCMethod_t *_Nullable method)
{
    return method != NULL ? method->selector : NULL;
}

static inline const char *_Nullable sf_method_types(SFObjCMethod_t *_Nullable method)
{
    return method != NULL ? method->types : NULL;
}

static inline void sf_method_assign_selector(SFObjCMethod_t *_Nonnull method, SEL _Nullable selector,
                                             const char *_Nullable types)
{
    method->selector = selector;
    method->types = (types != NULL) ? types : sf_selector_types(selector);
}

typedef uint32_t SFObjRefcount_t;
typedef struct SFObjColdState SFObjColdState_t;

typedef struct SFGroupState {
    struct SFObjHeader *_Nullable root;
    struct SFObjHeader *_Nullable head;
    size_t group_live_count;
    uint32_t dead;
    uint32_t reserved;
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
    uint32_t state;
    uint32_t flags;
    uint32_t alloc_size;
    uint32_t reserved;
    uint32_t class_flags;
    uintptr_t tagged_parent;
} SFInlineValueHeader_t;

struct SFObjColdState {
#if SF_RUNTIME_VALIDATION
    struct SFObjHeader *_Nullable live_next;
#endif
    SFAllocator_t *_Nullable allocator;
    id _Nullable parent;
    struct SFObjHeader *_Nullable group_root;
    struct SFObjHeader *_Nullable group_next;
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *_Nullable group;
#else
    struct SFObjHeader *_Nullable inline_group_head;
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
    uint32_t state;
    uint32_t flags;
    uint32_t alloc_size;
    uint32_t reserved;
    uint32_t class_flags;
    uint32_t aux_flags;
    SFObjColdState_t *_Nullable cold;
} SFObjHeader_t;
#else
typedef struct SFObjHeader {
#if SF_RUNTIME_VALIDATION
    uint64_t magic;
    struct SFObjHeader *_Nullable live_next;
#endif
    SFObjRefcount_t refcount;
    uint32_t state;
    uint32_t flags;
    uint32_t alloc_size;
    uint32_t reserved;
    SFAllocator_t *_Nullable allocator;
    id _Nullable parent;
    SFGroupState_t *_Nullable group;
    struct SFObjHeader *_Nullable group_next;
} SFObjHeader_t;
#endif

static inline uint32_t sf_header_aux_flags(SFObjHeader_t *_Nullable hdr)
{
    if (hdr == NULL) {
        return 0U;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return hdr->aux_flags;
#else
    return (hdr->flags & SF_OBJ_AUX_FLAGS_MASK) >> SF_OBJ_AUX_FLAGS_SHIFT;
#endif
}

static inline void sf_header_set_aux_flags(SFObjHeader_t *_Nullable hdr, uint32_t aux_flags)
{
    if (hdr == NULL) {
        return;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    hdr->aux_flags = aux_flags;
#else
    hdr->flags =
        (hdr->flags & ~SF_OBJ_AUX_FLAGS_MASK) | ((aux_flags << SF_OBJ_AUX_FLAGS_SHIFT) & SF_OBJ_AUX_FLAGS_MASK);
#endif
}

static inline void sf_header_or_aux_flags(SFObjHeader_t *_Nullable hdr, uint32_t aux_flags)
{
    sf_header_set_aux_flags(hdr, sf_header_aux_flags(hdr) | aux_flags);
}

static inline void sf_header_clear_aux_flags(SFObjHeader_t *_Nullable hdr, uint32_t aux_flags)
{
    sf_header_set_aux_flags(hdr, sf_header_aux_flags(hdr) & ~aux_flags);
}

static inline int sf_header_has_aux_flag(SFObjHeader_t *_Nullable hdr, uint32_t aux_flag)
{
    return (sf_header_aux_flags(hdr) & aux_flag) != 0U;
}

static inline void sf_header_set_live_cookie(SFObjHeader_t *_Nullable hdr)
{
    if (hdr == NULL) {
        return;
    }
    hdr->flags =
        (hdr->flags & ~SF_OBJ_COOKIE_MASK) | ((uint32_t)SF_OBJ_HEADER_COOKIE_LIVE << SF_OBJ_COOKIE_SHIFT);
}

static inline void sf_header_clear_live_cookie(SFObjHeader_t *_Nullable hdr)
{
    if (hdr == NULL) {
        return;
    }
    hdr->flags &= ~SF_OBJ_COOKIE_MASK;
}

static inline int sf_header_has_live_cookie(SFObjHeader_t *_Nullable hdr)
{
    return hdr != NULL and
           ((hdr->flags & SF_OBJ_COOKIE_MASK) >> SF_OBJ_COOKIE_SHIFT) == (uint32_t)SF_OBJ_HEADER_COOKIE_LIVE;
}

static inline uint32_t sf_header_class_flags(SFObjHeader_t *_Nullable hdr)
{
    if (hdr == NULL) {
        return 0U;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return hdr->class_flags;
#else
    return (hdr->flags & SF_OBJ_CLASS_FLAGS_MASK) >> SF_OBJ_CLASS_FLAGS_SHIFT;
#endif
}

static inline void sf_header_set_class_flags(SFObjHeader_t *_Nullable hdr, uint32_t class_flags)
{
    if (hdr == NULL) {
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

SFObjCClass_t *_Nullable sf_class_from_name(const char *_Nullable name);
void sf_register_classes(SFObjCClass_t *_Nullable *_Nullable start,
                         SFObjCClass_t *_Nullable *_Nullable stop);
void sf_finalize_registered_classes(void);

Class _Nullable sf_object_class(id _Nullable obj);
int sf_object_is_heap(id _Nullable obj);

SFObjHeader_t *_Nullable sf_header_from_object(id _Nullable obj);
id _Nullable sf_alloc_object(Class _Nullable cls, SFAllocator_t *_Nullable allocator);

size_t sf_cstr_len(const char *_Nullable s);
uint64_t sf_hash_bytes(const void *_Nullable data, size_t size);
uint64_t sf_hash_ptr(const void *_Nullable p);

#ifdef __cplusplus
}
#endif

#pragma clang assume_nonnull end
