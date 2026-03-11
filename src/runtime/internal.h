#pragma once

#include "runtime/abi.h"

#pragma clang assume_nonnull begin

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SFDispatchEntry {
    Class cls;
    SEL _Nullable sel;
    IMP _Nullable imp;
    uintptr_t reserved;
} SFDispatchEntry_t;

enum { SF_DISPATCH_CACHE_SIZE = 4096U };

extern SFDispatchEntry_t g_dispatch_cache[SF_DISPATCH_CACHE_SIZE];
#if SF_RUNTIME_THREADSAFE
extern __thread SFDispatchEntry_t g_dispatch_l0;
#else
extern SFDispatchEntry_t g_dispatch_l0;
#endif

IMP sf_lookup_imp(id _Nullable receiver, SEL _Nullable op);
SFObjCMethod_t *_Nullable sf_lookup_method_in_class(Class _Nullable cls, SEL _Nullable op);
IMP sf_lookup_imp_in_class(Class _Nullable cls, SEL _Nullable op);
IMP sf_lookup_imp_miss(Class _Nullable cls, SEL _Nullable op);
int sf_selector_equal(SEL _Nullable a, SEL _Nullable b);
int sf_dispatch_imp_is_nil(IMP _Nullable imp);
id _Nullable sf_dispatch_nil_imp(id _Nullable self, SEL _Nullable cmd, ...);
SEL _Nullable sf_intern_selector(SEL _Nullable sel);
SEL _Nullable sf_cached_selector_dealloc(void);
SEL _Nullable sf_cached_selector_alloc(void);
SEL _Nullable sf_cached_selector_init(void);
SEL _Nullable sf_cached_selector_forwarding_target(void);
IMP _Nullable sf_resolve_message_dispatch(id _Nullable *_Nonnull receiver, SEL _Nullable *_Nonnull op);
IMP _Nullable sf_class_cached_dealloc_imp(Class _Nullable cls);
IMP _Nullable sf_class_cached_alloc_imp(Class _Nullable cls);
IMP _Nullable sf_class_cached_init_imp(Class _Nullable cls);
IMP _Nullable sf_class_cached_cxx_destruct_imp(Class _Nullable cls);
const uint32_t *_Nullable sf_class_cached_object_ivar_offsets(Class _Nullable cls, size_t *_Nullable count_out);
int sf_class_has_trivial_release(Class _Nullable cls);
size_t sf_class_instance_size_fast(Class _Nullable cls);
#if SF_RUNTIME_TAGGED_POINTERS
extern Class _Nullable g_tagged_pointer_slot_classes[8];
#endif
int sf_is_tagged_pointer(id _Nullable obj);
uintptr_t sf_tagged_pointer_slot(id _Nullable obj);
uintptr_t sf_tagged_pointer_payload(id _Nullable obj);
Class _Nullable sf_tagged_pointer_class(id _Nullable obj);
Class _Nullable sf_tagged_class_for_slot(uintptr_t slot);
id _Nullable sf_make_tagged_pointer(Class _Nullable cls, uintptr_t payload);

const char *_Nonnull sf_class_name_of_object(id _Nullable obj);

void sf_register_builtin_class_cache(void);
Class _Nullable sf_cached_class_object(void);
id _Nullable sf_autorelease(id _Nullable obj);
void sf_object_dispose(id _Nullable obj);
id _Nullable sf_alloc_object_with_parent(Class _Nullable cls, id _Nullable parent);
SFAllocator_t *_Nullable sf_header_allocator(SFObjHeader_t *_Nullable hdr);
int sf_header_set_allocator(SFObjHeader_t *_Nullable hdr, SFAllocator_t *_Nullable allocator);
id _Nullable sf_header_parent(SFObjHeader_t *_Nullable hdr);
int sf_header_set_parent(SFObjHeader_t *_Nullable hdr, id _Nullable parent);
SFObjHeader_t *_Nullable sf_header_group_root(SFObjHeader_t *_Nullable hdr);
int sf_header_set_group_root(SFObjHeader_t *_Nullable hdr, SFObjHeader_t *_Nullable group_root);
SFObjHeader_t *_Nullable sf_header_group_next(SFObjHeader_t *_Nullable hdr);
int sf_header_set_group_next(SFObjHeader_t *_Nullable hdr, SFObjHeader_t *_Nullable group_next);
SFObjHeader_t *_Nullable sf_header_group_head(SFObjHeader_t *_Nullable hdr);
int sf_header_set_group_head(SFObjHeader_t *_Nullable hdr, SFObjHeader_t *_Nullable group_head);
size_t sf_header_group_live_count(SFObjHeader_t *_Nullable hdr);
int sf_header_set_group_live_count(SFObjHeader_t *_Nullable hdr, size_t count);
int sf_header_grouped(SFObjHeader_t *_Nullable hdr);
int sf_header_init_group_root(SFObjHeader_t *_Nullable hdr);
SFRuntimeMutex_t *_Nullable sf_header_group_lock(SFObjHeader_t *_Nullable hdr);
void sf_header_destroy_sidecar(SFObjHeader_t *_Nullable hdr, int destroy_group_lock);
size_t sf_object_allocation_size_for_object(id _Nullable obj);
void sf_register_live_object_header(SFObjHeader_t *_Nonnull hdr);
void sf_unregister_live_object_header(SFObjHeader_t *_Nonnull hdr);
size_t sf_exception_backtrace_count(id _Nullable obj);
const void *_Nullable sf_exception_backtrace_frame(id _Nullable obj, size_t index);
void sf_exception_capture_metadata(id _Nullable obj);
void sf_exception_clear_metadata(id _Nullable obj);

void sf_runtime_test_reset_alloc_failures(void);
void sf_runtime_test_fail_allocation_after(size_t successful_allocations);
int sf_runtime_test_consume_allocation(void);
void sf_runtime_test_reset_autorelease_state(void);
void *_Nullable sf_runtime_test_malloc(size_t size);
void *_Nullable sf_runtime_test_calloc(size_t count, size_t size);
void *_Nullable sf_runtime_test_realloc(void *_Nullable ptr, size_t size);

int sf_runtime_test_dispatch_is_digit_char(char c);
int sf_runtime_test_dispatch_is_type_qualifier(char c);
const char *_Nonnull sf_runtime_test_dispatch_skip_type_token(const char *_Nonnull p);
char sf_runtime_test_dispatch_primary_type_code(const char *_Nonnull p);
size_t sf_runtime_test_dispatch_collect_explicit_arg_codes(SEL _Nullable op, char *_Nonnull out_codes, int *_Nullable unsupported_sig);
size_t sf_runtime_test_dispatch_collect_explicit_arg_codes_cached(SEL _Nullable op, char *_Nonnull out_codes, int *_Nullable unsupported_sig);
uintptr_t sf_runtime_test_dispatch_read_word_arg(int code, ...);

#if SF_RUNTIME_EXCEPTIONS
typedef struct SFRuntimeTestLandingInfo {
    uintptr_t landing_pad;
    int selector;
    int has_cleanup;
    int has_handler;
    int reserved;
} SFRuntimeTestLandingInfo_t;

int sf_runtime_test_exception_matches_type(struct _Unwind_Exception *_Nullable exception_object,
                                           const char *_Nullable type_name);
uintptr_t sf_runtime_test_exception_read_encoded(const uint8_t *_Nonnull *_Nonnull ptr, uint8_t encoding);
size_t sf_runtime_test_exception_encoding_size(uint8_t encoding);
int sf_runtime_test_exception_parse_lsda(const uint8_t *_Nullable lsda, uintptr_t func_start, uintptr_t ip,
                                         struct _Unwind_Exception *_Nullable exception_object,
                                         SFRuntimeTestLandingInfo_t *_Nonnull out);
_Unwind_Reason_Code sf_runtime_test_exception_personality_result(_Unwind_Action actions, int has_cleanup,
                                                                 int has_handler);
#endif

uint64_t sf_dispatch_cache_hits(void);
uint64_t sf_dispatch_cache_misses(void);
uint64_t sf_dispatch_method_walks(void);
void sf_dispatch_reset_stats(void);

#ifdef __cplusplus
}
#endif

#pragma clang assume_nonnull end
