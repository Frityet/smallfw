#include "runtime/internal.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#if defined(__clang__) || defined(__GNUC__)
#define SF_LIKELY(x) __builtin_expect(!!(x), 1)
#define SF_ARC_RUNTIME_ENTRY __attribute__((used))
#else
#define SF_LIKELY(x) (x)
#define SF_ARC_RUNTIME_ENTRY
#endif

typedef struct SFAutoreleaseState {
    id *objects;
    size_t count;
    size_t capacity;
    size_t *markers;
    size_t marker_count;
    size_t marker_capacity;
} SFAutoreleaseState_t;

static thread_local SFAutoreleaseState_t g_autorelease_state;
static thread_local id g_last_header_obj;
static thread_local SFObjHeader_t *g_last_header_ptr;
static thread_local size_t g_pool_fallback_token;

static inline uint32_t header_class_flags(SFObjHeader_t *hdr)
{
    return sf_header_class_flags(hdr);
}

static inline int header_has_trivial_release(SFObjHeader_t *hdr)
{
    return (header_class_flags(hdr) & SF_OBJ_CLASS_FLAG_TRIVIAL_RELEASE) != 0U;
}

static inline int header_has_object_ivars(SFObjHeader_t *hdr)
{
    return (header_class_flags(hdr) & SF_OBJ_CLASS_FLAG_HAS_OBJECT_IVARS) != 0U;
}

static inline int header_has_cxx_destruct(SFObjHeader_t *hdr)
{
    return (header_class_flags(hdr) & SF_OBJ_CLASS_FLAG_HAS_CXX_DESTRUCT) != 0U;
}

void sf_runtime_test_reset_autorelease_state(void)
{
    free((void *)g_autorelease_state.objects);
    free(g_autorelease_state.markers);
    memset(&g_autorelease_state, 0, sizeof(g_autorelease_state));
    g_last_header_obj = nullptr;
    g_last_header_ptr = nullptr;
    g_pool_fallback_token = 0;
}

static inline SFObjHeader_t *header_from_heap_candidate(id obj)
{
    SFObjHeader_t *hdr = nullptr;
    if (obj == g_last_header_obj) {
        return g_last_header_ptr;
    }

    if (obj == nullptr) {
        return nullptr;
    }
#if SF_RUNTIME_TAGGED_POINTERS
    if (sf_is_tagged_pointer(obj)) {
        return nullptr;
    }
#endif

    hdr = sf_header_from_object(obj);
    if (hdr == nullptr) {
        return nullptr;
    }

    g_last_header_obj = obj;
    g_last_header_ptr = hdr;
    return hdr;
}

static int ensure_object_capacity(size_t wanted)
{
    if (g_autorelease_state.capacity >= wanted) {
        return 1;
    }
    size_t new_cap = g_autorelease_state.capacity ? g_autorelease_state.capacity * 2 : 64;
    while (new_cap < wanted)
        new_cap *= 2;
    id *next = (id *)sf_runtime_test_realloc((void *)g_autorelease_state.objects,
                                             new_cap * sizeof(id));
    if (next == nullptr) {
        return 0;
    }
    g_autorelease_state.objects = next;
    g_autorelease_state.capacity = new_cap;
    return 1;
}

static int ensure_marker_capacity(size_t wanted)
{
    if (g_autorelease_state.marker_capacity >= wanted) {
        return 1;
    }
    size_t new_cap = g_autorelease_state.marker_capacity ? g_autorelease_state.marker_capacity * 2 : 8;
    while (new_cap < wanted)
        new_cap *= 2;
    size_t *next = (size_t *)sf_runtime_test_realloc(g_autorelease_state.markers,
                                                     new_cap * sizeof(size_t));
    if (next == nullptr) {
        return 0;
    }
    g_autorelease_state.markers = next;
    g_autorelease_state.marker_capacity = new_cap;
    return 1;
}

static void clear_embedded_owner_slot(SFObjHeader_t *hdr, id obj)
{
    if (hdr == nullptr or obj == nullptr or (hdr->flags & SF_OBJ_FLAG_EMBEDDED) == 0U) {
        return;
    }

    id parent = sf_header_parent(hdr);
    if (parent == nullptr) {
        return;
    }

    unsigned char *parent_bytes = (unsigned char *)(void *)parent;
    id *owner_slot = (id *)(void *)(parent_bytes + hdr->reserved);
    if (*owner_slot == obj) {
        *owner_slot = nullptr;
    }
}

static inline int embedded_owner_slot_contains_object(SFObjHeader_t *hdr, id obj)
{
    if (hdr == nullptr or obj == nullptr or (hdr->flags & SF_OBJ_FLAG_EMBEDDED) == 0U) {
        return 0;
    }

    id parent = sf_header_parent(hdr);
    if (parent == nullptr) {
        return 0;
    }

    unsigned char *parent_bytes = (unsigned char *)(void *)parent;
    id *owner_slot = (id *)(void *)(parent_bytes + hdr->reserved);
    return *owner_slot == obj;
}

static void clear_object_ivars_slow(id obj, Class cls)
{
    unsigned char *obj_bytes = (unsigned char *)(void *)obj;
    SFObjCClass_t *cursor = (SFObjCClass_t *)cls;
    while (cursor != nullptr) {
        SFObjCIvarList_t *list = (SFObjCIvarList_t *)cursor->ivars;
        if (list != nullptr and list->count > 0) {
            size_t stride = (size_t)list->item_size;
            if (stride < sizeof(SFObjCIvar_t)) {
                stride = sizeof(SFObjCIvar_t);
            }

            unsigned char *ivar_cursor = (unsigned char *)list->ivars;
            for (uintptr_t i = 0; i < list->count; ++i, ivar_cursor += stride) {
                SFObjCIvar_t *ivar = (SFObjCIvar_t *)(void *)ivar_cursor;
                const char *type = ivar->type;
                if (ivar->offset == nullptr or type == nullptr) {
                    continue;
                }
                while (*type == 'r' or *type == 'n' or *type == 'N' or *type == 'o' or *type == 'O' or
                       *type == 'R' or *type == 'V') {
                    ++type;
                }
                if (*type != '@' or type[1] == '?') {
                    continue;
                }

                int32_t offset = *ivar->offset;
                if (offset == INT32_MAX) {
                    continue;
                }

                id *slot = (id *)(void *)(obj_bytes + (size_t)offset);
                if (*slot != nullptr) {
                    objc_storeStrong(slot, nullptr);
                }
            }
        }
        cursor = (cursor->superclass != cursor) ? cursor->superclass : nullptr;
    }
}

static void clear_object_ivars(id obj, Class cls)
{
    unsigned char *obj_bytes = (unsigned char *)(void *)obj;
    size_t count = 0U;
    const uint32_t *offsets = sf_class_cached_object_ivar_offsets(cls, &count);
    if (count == 0U) {
        return;
    }
    if (offsets == nullptr) {
        clear_object_ivars_slow(obj, cls);
        return;
    }

    for (size_t i = 0U; i < count; ++i) {
        id *slot = (id *)(void *)(obj_bytes + offsets[i]);
        id old = *slot;
        if (old != nullptr) {
            *slot = nullptr;
            SFObjHeader_t *old_hdr = header_from_heap_candidate(old);
            if (old_hdr != nullptr and (old_hdr->flags & SF_OBJ_FLAG_EMBEDDED) != 0U) {
                Class old_cls = sf_object_class(old);
                SEL dealloc_sel = sf_cached_selector_dealloc();
                static struct sf_objc_selector cxx_destruct_sel_data = {".cxx_destruct", "v16@0:8"};
                static SEL cxx_destruct_sel;
                int has_object_ivars = 1;
                int has_cxx_destruct = 1;

                has_object_ivars = header_has_object_ivars(old_hdr);
                has_cxx_destruct = header_has_cxx_destruct(old_hdr);
                if (header_has_trivial_release(old_hdr)) {
                    sf_object_dispose(old);
                    continue;
                }

                IMP imp = sf_class_cached_dealloc_imp(old_cls);
                if (imp != nullptr and dealloc_sel != nullptr) {
                    (void)imp(old, dealloc_sel);
                }
                if (has_object_ivars) {
                    clear_object_ivars(old, old_cls);
                }
                if (has_cxx_destruct) {
                    if (cxx_destruct_sel == nullptr) {
                        cxx_destruct_sel = sf_intern_selector(&cxx_destruct_sel_data);
                    }
                    if (cxx_destruct_sel != nullptr) {
                        IMP cxx_destruct_imp = sf_class_cached_cxx_destruct_imp(old_cls);
                        if (cxx_destruct_imp != nullptr) {
                            (void)cxx_destruct_imp(old, cxx_destruct_sel);
                        }
                    }
                }
                sf_object_dispose(old);
                continue;
            }
            objc_release(old);
        }
    }
}

static void free_group_members(SFObjHeader_t *head, SFAllocator_t *allocator)
{
    SFObjHeader_t *member = head;
    SFAllocator_t *use_allocator = allocator ? allocator : sf_default_allocator();
    while (member != nullptr) {
        SFObjHeader_t *next = sf_header_group_next(member);
        size_t total_size = (size_t)member->alloc_size;
        int embedded = (member->flags & SF_OBJ_FLAG_EMBEDDED) != 0U;
        sf_header_destroy_sidecar(member, 0);
        if (not embedded) {
            use_allocator->free(use_allocator->ctx, (void *)member, total_size, sizeof(void *));
        }
        member = next;
    }
}

static inline id retain_known_heap_object(id obj, SFObjHeader_t *hdr)
{
    if (hdr == nullptr or (hdr->flags & SF_OBJ_FLAG_IMMORTAL) != 0U or hdr->state != SF_OBJ_STATE_LIVE or
        embedded_owner_slot_contains_object(hdr, obj)) {
        return obj;
    }
#if SF_RUNTIME_THREADSAFE
    (void)__atomic_fetch_add(&hdr->refcount, 1, __ATOMIC_RELAXED);
#else
    hdr->refcount += 1;
#endif
    return obj;
}

static inline int header_has_sidecar_state(SFObjHeader_t *hdr)
{
#if SF_RUNTIME_COMPACT_HEADERS
    return hdr != nullptr and not sf_header_is_inline_value_prefix(hdr) and (hdr->flags & SF_OBJ_FLAG_HAS_COLD) != 0U;
#else
    return hdr != nullptr and (hdr->parent != nullptr or hdr->group != nullptr);
#endif
}

static inline int header_is_plain_live_object(SFObjHeader_t *hdr)
{
    return hdr != nullptr and hdr->state == SF_OBJ_STATE_LIVE and
           (hdr->flags & (SF_OBJ_FLAG_IMMORTAL | SF_OBJ_FLAG_EMBEDDED)) == 0U;
}

static void dispose_plain_object(SFObjHeader_t *hdr)
{
    SFAllocator_t *allocator = sf_header_allocator(hdr);
    size_t total_size = (size_t)hdr->alloc_size;

    if (hdr == nullptr or hdr->state != SF_OBJ_STATE_LIVE) {
        return;
    }
    sf_unregister_live_object_header(hdr);
    hdr->state = SF_OBJ_STATE_DISPOSED;
    sf_header_clear_live_cookie(hdr);
    sf_header_set_aux_flags(hdr, 0U);
#if SF_RUNTIME_VALIDATION
    hdr->magic = 0;
#endif
    if (allocator == nullptr) {
        allocator = sf_default_allocator();
    }
    allocator->free(allocator->ctx, (void *)hdr, total_size, sizeof(void *));
}

void sf_object_dispose(id obj)
{
    SFObjHeader_t *hdr = header_from_heap_candidate(obj);
    if (hdr == nullptr) {
        return;
    }
    if ((hdr->flags & SF_OBJ_FLAG_IMMORTAL) != 0U) {
        return;
    }
    if (sf_header_has_aux_flag(hdr, SF_OBJ_AUX_FLAG_HAS_EXCEPTION_METADATA)) {
        sf_exception_clear_metadata(obj);
    }
    if (obj == g_last_header_obj) {
        g_last_header_obj = nullptr;
        g_last_header_ptr = nullptr;
    }
    if ((hdr->flags & SF_OBJ_FLAG_EMBEDDED) == 0U and not header_has_sidecar_state(hdr)) {
        dispose_plain_object(hdr);
        return;
    }

    SFObjHeader_t *root = sf_header_group_root(hdr);
    SFObjHeader_t *free_head = nullptr;
    SFAllocator_t *group_allocator = nullptr;
    SFRuntimeMutex_t *group_lock = sf_header_group_lock(hdr);

    if (not sf_header_grouped(hdr) or group_lock == nullptr) {
        SFAllocator_t *allocator = sf_header_allocator(hdr);
        size_t total_size = (size_t)hdr->alloc_size;
        int embedded = (hdr->flags & SF_OBJ_FLAG_EMBEDDED) != 0U;
        if (hdr->state != SF_OBJ_STATE_LIVE) {
            return;
        }
        clear_embedded_owner_slot(hdr, obj);
        sf_unregister_live_object_header(hdr);
        hdr->state = SF_OBJ_STATE_DISPOSED;
        sf_header_clear_live_cookie(hdr);
        sf_header_set_aux_flags(hdr, 0U);
#if SF_RUNTIME_VALIDATION
        hdr->magic = 0;
#endif
        if (allocator == nullptr) {
            allocator = sf_default_allocator();
        }
        sf_header_destroy_sidecar(hdr, 0);
        if (not embedded) {
            allocator->free(allocator->ctx, (void *)hdr, total_size, sizeof(void *));
        }
        return;
    }

    sf_runtime_mutex_lock(group_lock);
    if (hdr->state != SF_OBJ_STATE_LIVE) {
        sf_runtime_mutex_unlock(group_lock);
        return;
    }

    clear_embedded_owner_slot(hdr, obj);
    sf_unregister_live_object_header(hdr);
    hdr->state = SF_OBJ_STATE_DISPOSED;
    sf_header_clear_live_cookie(hdr);
    sf_header_set_aux_flags(hdr, 0U);
#if SF_RUNTIME_VALIDATION
    hdr->magic = 0;
#endif
    if (sf_header_group_live_count(root) > 0) {
        (void)sf_header_set_group_live_count(root, sf_header_group_live_count(root) - 1);
    }
    if (sf_header_group_live_count(root) == 0) {
        free_head = sf_header_group_head(root);
        group_allocator = sf_header_allocator(root);
        (void)sf_header_set_group_head(root, nullptr);
    }
    sf_runtime_mutex_unlock(group_lock);

    if (free_head != nullptr) {
        sf_header_destroy_sidecar(root, 1);
        free_group_members(free_head, group_allocator);
    }
}

static void release_object_nontrivial(id obj, SFObjHeader_t *hdr)
{
    Class cls = nullptr;
    SEL dealloc_sel = sf_cached_selector_dealloc();
    static struct sf_objc_selector cxx_destruct_sel_data = {".cxx_destruct", "v16@0:8"};
    static SEL cxx_destruct_sel;
    int has_object_ivars = header_has_object_ivars(hdr);
    int has_cxx_destruct = header_has_cxx_destruct(hdr);

    cls = sf_object_class(obj);

    IMP imp = sf_class_cached_dealloc_imp(cls);
    if (imp != nullptr and dealloc_sel != nullptr) {
        (void)imp(obj, dealloc_sel);
    }
    if (has_object_ivars) {
        clear_object_ivars(obj, cls);
    }
    if (has_cxx_destruct) {
        if (cxx_destruct_sel == nullptr) {
            cxx_destruct_sel = sf_intern_selector(&cxx_destruct_sel_data);
        }
        if (cxx_destruct_sel != nullptr) {
            IMP cxx_destruct_imp = sf_class_cached_cxx_destruct_imp(cls);
            if (cxx_destruct_imp != nullptr) {
                (void)cxx_destruct_imp(obj, cxx_destruct_sel);
            }
        }
    }
    sf_object_dispose(obj);
}

static inline void release_object_trivial(id obj)
{
    sf_object_dispose(obj);
}

static void release_object_now_known_header(id obj, SFObjHeader_t *hdr)
{
    if (hdr == nullptr or (hdr->flags & SF_OBJ_FLAG_IMMORTAL) != 0U or hdr->state != SF_OBJ_STATE_LIVE or
        embedded_owner_slot_contains_object(hdr, obj)) {
        return;
    }

#if SF_RUNTIME_THREADSAFE
    SFObjRefcount_t old = __atomic_fetch_sub(&hdr->refcount, 1, __ATOMIC_RELEASE);
    if (SF_LIKELY(old > 1)) {
        return;
    }
    if (old == 0) {
        __atomic_store_n(&hdr->refcount, 0, __ATOMIC_RELAXED);
        return;
    }
    __atomic_thread_fence(__ATOMIC_ACQUIRE);
#else
    SFObjRefcount_t rc = hdr->refcount;
    if (SF_LIKELY(rc > 1)) {
        hdr->refcount = rc - 1;
        return;
    }
    if (rc == 0) {
        return;
    }
    hdr->refcount = 0;
#endif

    if (header_has_trivial_release(hdr)) {
        release_object_trivial(obj);
        return;
    }
    release_object_nontrivial(obj, hdr);
}

static void release_object_now(id obj)
{
    release_object_now_known_header(obj, header_from_heap_candidate(obj));
}

SF_ARC_RUNTIME_ENTRY id objc_retain(id obj)
{
    SFObjHeader_t *hdr = nullptr;

    if (obj == g_last_header_obj) {
        hdr = g_last_header_ptr;
        if (header_is_plain_live_object(hdr)) {
#if SF_RUNTIME_THREADSAFE
            (void)__atomic_fetch_add(&hdr->refcount, 1, __ATOMIC_RELAXED);
#else
            hdr->refcount += 1;
#endif
            return obj;
        }
    }
    return retain_known_heap_object(obj, hdr != nullptr ? hdr : header_from_heap_candidate(obj));
}

SF_ARC_RUNTIME_ENTRY void objc_release(id obj)
{
    SFObjHeader_t *hdr = nullptr;

    if (obj == g_last_header_obj) {
        hdr = g_last_header_ptr;
#if !SF_RUNTIME_THREADSAFE
        if (header_is_plain_live_object(hdr) and SF_LIKELY(hdr->refcount > 1U)) {
            hdr->refcount -= 1U;
            return;
        }
#endif
    }
    release_object_now_known_header(obj, hdr != nullptr ? hdr : header_from_heap_candidate(obj));
}

id sf_autorelease(id obj)
{
    if (header_from_heap_candidate(obj) == nullptr) {
        return obj;
    }
    if (g_autorelease_state.marker_count == 0) {
        return obj;
    }
    if (not ensure_object_capacity(g_autorelease_state.count + 1)) {
        return obj;
    }
    g_autorelease_state.objects[g_autorelease_state.count++] = obj;
    return obj;
}

SF_ARC_RUNTIME_ENTRY void *objc_autoreleasePoolPush(void)
{
    size_t marker = g_autorelease_state.count;
    size_t *token = nullptr;

    if (ensure_marker_capacity(g_autorelease_state.marker_count + 1)) {
        g_autorelease_state.markers[g_autorelease_state.marker_count++] = marker;
    }

    token = (size_t *)sf_runtime_test_malloc(sizeof(size_t));
    if (token != nullptr) {
        *token = marker;
        return (void *)token;
    }

    g_pool_fallback_token = marker;
    return (void *)&g_pool_fallback_token;
}

SF_ARC_RUNTIME_ENTRY void objc_autoreleasePoolPop(void *pool)
{
    size_t marker = g_autorelease_state.count;
    if (pool == (void *)&g_pool_fallback_token) {
        marker = g_pool_fallback_token;
    } else if (pool != nullptr) {
        marker = *((size_t *)pool);
        free(pool);
    }

    if (g_autorelease_state.marker_count > 0) {
        size_t top = g_autorelease_state.markers[g_autorelease_state.marker_count - 1];
        if (top == marker) {
            g_autorelease_state.marker_count -= 1;
        }
    }
    if (marker > g_autorelease_state.count) {
        marker = g_autorelease_state.count;
    }
    while (g_autorelease_state.count > marker) {
        id obj = g_autorelease_state.objects[--g_autorelease_state.count];
        release_object_now(obj);
    }
}

SF_ARC_RUNTIME_ENTRY id objc_retainAutorelease(id obj)
{
    return sf_autorelease(objc_retain(obj));
}

SF_ARC_RUNTIME_ENTRY id objc_retainAutoreleasedReturnValue(id obj)
{
    return objc_retain(obj);
}

SF_ARC_RUNTIME_ENTRY id objc_autoreleaseReturnValue(id obj)
{
    return sf_autorelease(obj);
}

SF_ARC_RUNTIME_ENTRY id objc_retainAutoreleaseReturnValue(id obj)
{
    return sf_autorelease(objc_retain(obj));
}

SF_ARC_RUNTIME_ENTRY void objc_storeStrong(id *dst, id value)
{
    id old = *dst;
    SFObjHeader_t *value_hdr = nullptr;
    SFObjHeader_t *old_hdr = nullptr;
    if (old == value) {
        return;
    }
    if (value != nullptr) {
        value_hdr = header_from_heap_candidate(value);
        if (value_hdr != nullptr) {
            (void)retain_known_heap_object(value, value_hdr);
        } else {
            objc_retain(value);
        }
    }
    *dst = value;
    if (old != nullptr) {
        old_hdr = header_from_heap_candidate(old);
        if (old_hdr != nullptr) {
            release_object_now_known_header(old, old_hdr);
        } else {
            objc_release(old);
        }
    }
}
