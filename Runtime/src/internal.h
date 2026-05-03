#pragma once

#include "abi.h"
#include "c2x-compat.h"
#include "encoding.h"

#include <stdlib.h>

#pragma clang assume_nonnull begin

#ifdef __cplusplus
    extern "C" {
#endif

typedef struct SFFrozenSelector {
    SFObjCSelectorFields_t sel;
    uint32_t slot;
    uint32_t flags;
    char storage[];
} SFFrozenSelector_t;

#define SF_FROZEN_SELECTOR_NAME_OFFSET ((int)(sizeof(SFObjCSelectorFields_t) + sizeof(uint32_t) + sizeof(uint32_t)))

IMP sf_lookup_imp(id nillable receiver, SEL nillable op);
SFObjCMethod_t *nillable sf_lookup_method_in_class(Class nillable cls, SEL nillable op);
IMP sf_lookup_imp_in_class(Class nillable cls, SEL nillable op);
IMP sf_lookup_imp_miss(Class nillable cls, SEL nillable op);
bool sf_selector_equal(SEL nillable a, SEL nillable b);
SEL nillable sf_intern_selector(SEL nillable sel);
SEL nillable sf_lookup_selector_named(const char *nillable name);
uint32_t sf_selector_slot(SEL nillable sel);
size_t sf_runtime_selector_count(void);
SEL nillable sf_cached_selector_dealloc(void);
SEL nillable sf_cached_selector_alloc(void);
SEL nillable sf_cached_selector_init(void);
SEL nillable sf_cached_selector_forwarding_target(void);
IMP nillable sf_resolve_message_dispatch(id nillable *nonnil receiver, SEL nillable *nonnil op);
IMP nillable sf_lookup_dtable_imp(Class nillable cls, SEL nillable op);
IMP nillable sf_class_cached_dealloc_imp(Class nillable cls);
IMP nillable sf_class_cached_alloc_imp(Class nillable cls);
IMP nillable sf_class_cached_init_imp(Class nillable cls);
IMP nillable sf_class_cached_cxx_destruct_imp(Class nillable cls);
const uint32_t *nillable sf_class_cached_object_ivar_offsets(Class nillable cls, size_t *nillable count_out);
bool sf_class_has_trivial_release(Class nillable cls);
uint32_t sf_class_cached_object_flags(Class nillable cls);
const struct SFEncoding *nillable sf_class_cached_encoding(Class nillable cls);
bool sf_class_is_constant_string(Class nillable cls);
size_t sf_class_instance_size_fast(Class nillable cls);
#if SF_RUNTIME_TAGGED_POINTERS
    extern Class nillable g_tagged_pointer_slot_classes[8];
#endif
bool sf_is_tagged_pointer(id nillable obj);
uintptr_t sf_tagged_pointer_slot(id nillable obj);
uintptr_t sf_tagged_pointer_payload(id nillable obj);
Class nillable sf_tagged_pointer_class(id nillable obj);
Class nillable sf_tagged_class_for_slot(uintptr_t slot);
id nillable sf_make_tagged_pointer(Class nillable cls, uintptr_t payload);

const char *nonnil sf_class_name_of_object(id nillable obj);

void sf_register_builtin_class_cache(void);
Class nillable sf_cached_class_object(void);
id nillable sf_autorelease(id nillable obj);
void sf_object_dispose(id nillable obj);
id nillable sf_alloc_object_with_parent(Class nillable cls, id nillable parent);
bool sf_default_allocator_returns_zeroed(size_t size, size_t align);
SFAllocator_t *nillable sf_header_allocator(SFObjHeader_t *nillable hdr);
bool sf_header_set_allocator(SFObjHeader_t *nillable hdr, SFAllocator_t *nillable allocator);
#if SF_RUNTIME_GENERIC_METADATA
    Class nillable sf_header_generic_type_class(SFObjHeader_t *nillable hdr);
    bool sf_header_set_generic_type_class(SFObjHeader_t *nillable hdr, Class nillable cls);
    void sf_object_set_generic_type_class(id nillable obj, Class nillable cls);
    Class nillable sf_object_generic_type_class(id nillable obj);
#endif
id nillable sf_header_object(SFObjHeader_t *nillable hdr);
bool sf_header_is_inline_value_prefix(SFObjHeader_t *nillable hdr);
SFObjHeader_t *nillable sf_header_live_next(SFObjHeader_t *nillable hdr);
void sf_header_set_live_next(SFObjHeader_t *nillable hdr, SFObjHeader_t *nillable next);
id nillable sf_header_parent(SFObjHeader_t *nillable hdr);
bool sf_header_set_parent(SFObjHeader_t *nillable hdr, id nillable parent);
SFObjHeader_t *nillable sf_header_group_root(SFObjHeader_t *nillable hdr);
bool sf_header_set_group_root(SFObjHeader_t *nillable hdr, SFObjHeader_t *nillable group_root);
SFObjHeader_t *nillable sf_header_group_next(SFObjHeader_t *nillable hdr);
bool sf_header_set_group_next(SFObjHeader_t *nillable hdr, SFObjHeader_t *nillable group_next);
SFObjHeader_t *nillable sf_header_group_head(SFObjHeader_t *nillable hdr);
bool sf_header_set_group_head(SFObjHeader_t *nillable hdr, SFObjHeader_t *nillable group_head);
size_t sf_header_group_live_count(SFObjHeader_t *nillable hdr);
bool sf_header_set_group_live_count(SFObjHeader_t *nillable hdr, size_t count);
bool sf_header_group_dead(SFObjHeader_t *nillable hdr);
bool sf_header_grouped(SFObjHeader_t *nillable hdr);
bool sf_header_init_group_root(SFObjHeader_t *nillable hdr);
SFRuntimeMutex_t *nillable sf_header_group_lock(SFObjHeader_t *nillable hdr);
void sf_header_destroy_sidecar(SFObjHeader_t *nillable hdr, int destroy_group_lock);
size_t sf_object_allocation_size_for_object(id nillable obj);
void sf_register_live_object_header(SFObjHeader_t *nillable hdr);
void sf_unregister_live_object_header(SFObjHeader_t *nillable hdr);
size_t sf_exception_backtrace_count(id nillable obj);
const void *nillable sf_exception_backtrace_frame(id nillable obj, size_t index);
void sf_exception_capture_metadata(id nillable obj);
void sf_exception_clear_metadata(id nillable obj);

#if SF_RUNTIME_TESTING
    void sf_runtime_test_reset_autorelease_state(void);
    void sf_runtime_test_reset_alloc_failures(void);
    void sf_runtime_test_fail_allocation_after(size_t successful_allocations);
    bool sf_runtime_test_consume_allocation(void);
    void *nillable sf_runtime_test_malloc(size_t size);
    void *nillable sf_runtime_test_calloc(size_t count, size_t size);
    void *nillable sf_runtime_test_realloc(void *nillable ptr, size_t size);
#else
    static inline void sf_runtime_test_reset_alloc_failures(void)
    {
    }

    static inline void sf_runtime_test_fail_allocation_after(size_t successful_allocations)
    {
        (void)successful_allocations;
    }

    static inline bool sf_runtime_test_consume_allocation(void)
    {
        return true;
    }

    static inline void *nillable sf_runtime_test_malloc(size_t size)
    {
        return malloc(size);
    }

    static inline void *nillable sf_runtime_test_calloc(size_t count, size_t size)
    {
        return calloc(count, size);
    }

    static inline void *nillable sf_runtime_test_realloc(void *nillable ptr, size_t size)
    {
        return realloc(ptr, size);
    }
#endif

bool sf_runtime_test_dispatch_is_digit_char(char c);
bool sf_runtime_test_dispatch_is_type_qualifier(char c);
const char *nonnil sf_runtime_test_dispatch_skip_type_token(const char *nonnil p);
char sf_runtime_test_dispatch_primary_type_code(const char *nonnil p);
size_t sf_runtime_test_dispatch_collect_explicit_arg_codes(SEL nillable op, char *nonnil out_codes, bool *nillable unsupported_sig);
size_t sf_runtime_test_dispatch_collect_explicit_arg_codes_cached(SEL nillable op, char *nonnil out_codes, bool *nillable unsupported_sig);
uintptr_t sf_runtime_test_dispatch_read_word_arg(int code, ...);
size_t sf_runtime_test_dispatch_cache_base_index(Class nillable cls, SEL nillable op);
const void *nillable sf_runtime_test_dispatch_cache_entry(size_t index);
const void *nillable sf_runtime_test_dispatch_l0_entry(size_t index);

#if SF_RUNTIME_EXCEPTIONS
    typedef struct SFRuntimeTestLandingInfo {
        uintptr_t landing_pad;
        int selector;
        bool has_cleanup;
        bool has_handler;
        int reserved;
    } SFRuntimeTestLandingInfo_t;

    bool sf_runtime_test_exception_matches_type(struct _Unwind_Exception *nillable exception_object,
                                                const char *nillable type_name);
    uintptr_t sf_runtime_test_exception_read_encoded(const uint8_t *nonnil *nonnil ptr, uint8_t encoding);
    size_t sf_runtime_test_exception_encoding_size(uint8_t encoding);
    bool sf_runtime_test_exception_parse_lsda(const uint8_t *nillable lsda, uintptr_t func_start, uintptr_t ip,
                                              struct _Unwind_Exception *nillable exception_object,
                                              SFRuntimeTestLandingInfo_t *nonnil out);
    _Unwind_Reason_Code sf_runtime_test_exception_personality_result(_Unwind_Action actions, bool has_cleanup,
                                                                     bool has_handler);
#endif

uint64_t sf_dispatch_cache_hits(void);
uint64_t sf_dispatch_cache_misses(void);
uint64_t sf_dispatch_method_walks(void);
void sf_dispatch_reset_stats(void);

#ifdef __cplusplus
    }
#endif

#pragma clang assume_nonnull end
