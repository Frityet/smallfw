#pragma once

#include <stddef.h>
#include <stdint.h>

#include "runtime/locking.h"
#include "runtime/objc/runtime_exports.h"
#include "runtime/sf_allocator.h"

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-extension"
#pragma clang diagnostic ignored "-Wpadded"
#endif
#pragma clang assume_nonnull begin

#ifdef __cplusplus
extern "C" {
#endif

#ifndef SF_RUNTIME_ABI_GNUSTEP
#define SF_RUNTIME_ABI_GNUSTEP 1
#endif

#ifndef SF_RUNTIME_ABI_OBJFW
#define SF_RUNTIME_ABI_OBJFW 0
#endif

#define SF_SELECTOR_UID_MAX UINTPTR_C(0x00FFFFFF)

#if SF_RUNTIME_ABI_OBJFW
typedef struct SFObjCSelectorRuntime {
    uintptr_t uid;
    const char *_Nullable types;
    const char *_Nullable name;
} SFObjCSelectorRuntime_t;

typedef struct sf_objc_selector_ref {
    uintptr_t uid;
    const char *_Nullable types;
} SFObjCSelectorRef_t;

typedef struct sf_objc_method {
    SFObjCSelectorRef_t selector;
    IMP imp;
} SFObjCMethod_t;

typedef struct SFObjCMethodList {
    struct SFObjCMethodList *_Nullable next;
    unsigned int count;
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
    void *_Nullable ivar_offsets;
    void *_Nullable properties;
    unsigned long flags;
    unsigned long reserved;
} SFObjCClass_t;

typedef struct sf_objc_ivar {
    const char *_Nullable name;
    const char *_Nullable type;
    unsigned int offset;
} SFObjCIvar_t;

typedef struct SFObjCIvarList {
    unsigned int count;
    SFObjCIvar_t ivars[];
} SFObjCIvarList_t;

typedef struct SFObjCProtocolList {
    struct SFObjCProtocolList *_Nullable next;
    long count;
    void *_Nullable list[];
} SFObjCProtocolList_t;

typedef struct SFObjCCategory {
    const char *_Nullable category_name;
    const char *_Nullable class_name;
    SFObjCMethodList_t *_Nullable instance_methods;
    SFObjCMethodList_t *_Nullable class_methods;
    SFObjCProtocolList_t *_Nullable protocols;
} SFObjCCategory_t;

typedef struct SFObjCSymtab {
    unsigned long unknown;
    SFObjCSelectorRef_t *_Nullable selector_refs;
    uint16_t class_defs_count;
    uint16_t category_defs_count;
    void *_Nullable defs[];
} SFObjCSymtab_t;

typedef struct SFObjCModule {
    unsigned long version;
    unsigned long size;
    const char *_Nullable name;
    SFObjCSymtab_t *_Nullable symtab;
} SFObjCModule_t;

typedef struct SFObjCDTableLevel2 {
    IMP _Nullable buckets[256];
} SFObjCDTableLevel2_t;

typedef struct SFObjCDTable {
    SFObjCDTableLevel2_t *_Nullable buckets[256];
} SFObjCDTable_t;

#else
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
#endif

const char *_Nullable sf_selector_name(SEL _Nullable sel);
const char *_Nullable sf_selector_types(SEL _Nullable sel);
uintptr_t sf_selector_uid(SEL _Nullable sel);
void sf_selector_set_uid(SEL _Nullable sel, uintptr_t uid);
void sf_selector_set_types(SEL _Nullable sel, const char *_Nullable types);

#if SF_RUNTIME_ABI_OBJFW
static inline SEL _Nullable sf_method_selector_ptr(SFObjCMethod_t *_Nullable method) {
    if (method == NULL) {
        return NULL;
    }
    return (SEL)(void *)&method->selector;
}

static inline const char *_Nullable sf_method_types(SFObjCMethod_t *_Nullable method) {
    return method != NULL ? method->selector.types : NULL;
}

static inline void sf_method_assign_selector(SFObjCMethod_t *_Nonnull method, SEL _Nullable selector,
                                             const char *_Nullable types) {
    method->selector.uid = selector != NULL ? sf_selector_uid(selector) : (uintptr_t)0;
    method->selector.types = (types != NULL) ? types : sf_selector_types(selector);
}
#else
static inline SEL _Nullable sf_method_selector_ptr(SFObjCMethod_t *_Nullable method) {
    return method != NULL ? method->selector : NULL;
}

static inline const char *_Nullable sf_method_types(SFObjCMethod_t *_Nullable method) {
    return method != NULL ? method->types : NULL;
}

static inline void sf_method_assign_selector(SFObjCMethod_t *_Nonnull method, SEL _Nullable selector,
                                             const char *_Nullable types) {
    method->selector = selector;
    method->types = (types != NULL) ? types : sf_selector_types(selector);
}
#endif

typedef uint32_t SFObjRefcount_t;

typedef struct SFGroupState {
    struct SFObjHeader *_Nullable root;
    struct SFObjHeader *_Nullable head;
    size_t group_live_count;
    uint32_t dead;
    uint32_t reserved;
    SFRuntimeMutex_t group_lock;
} SFGroupState_t;

enum {
    SF_OBJ_FLAG_NONE = 0U,
    SF_OBJ_FLAG_IMMORTAL = 1U << 0U,
};

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

#define SF_OBJ_HEADER_MAGIC UINT64_C(0x53464f424a484452)
#define SF_OBJ_STATE_DISPOSED UINT32_C(0)
#define SF_OBJ_STATE_LIVE UINT32_C(1)

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
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
