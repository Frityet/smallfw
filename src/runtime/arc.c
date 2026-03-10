#include "runtime/internal.h"

#include <stdlib.h>
#include <string.h>

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#pragma clang diagnostic ignored "-Wnullability-extension"
#endif

#if defined(__clang__) || defined(__GNUC__)
#define SF_LIKELY(x) __builtin_expect(!!(x), 1)
#else
#define SF_LIKELY(x) (x)
#endif

typedef struct SFAutoreleaseState {
    id *objects;
    size_t count;
    size_t capacity;
    size_t *markers;
    size_t marker_count;
    size_t marker_capacity;
} SFAutoreleaseState_t;

static __thread SFAutoreleaseState_t g_autorelease_state;
static __thread id g_last_header_obj;
static __thread SFObjHeader_t *g_last_header_ptr;
static __thread size_t g_pool_fallback_token;

static inline int sf_pointer_uses_small_object_tag(id obj) {
    return ((((uintptr_t)obj) & (uintptr_t)7U) != 0U);
}

static inline int sf_object_bypasses_heap_arc(id obj) {
    static Class g_nsconstantstring_class;
    static Class g_nxconstantstring_class;
    Class cls = NULL;

    if (obj == NULL) {
        return 1;
    }
    if (sf_pointer_uses_small_object_tag(obj)) {
        return 1;
    }

    cls = *(Class *)obj;
    if (g_nsconstantstring_class == NULL) {
        g_nsconstantstring_class = (Class)sf_class_from_name("NSConstantString");
    }
    if (g_nxconstantstring_class == NULL) {
        g_nxconstantstring_class = (Class)sf_class_from_name("NXConstantString");
    }
    return cls != NULL && (cls == g_nsconstantstring_class || cls == g_nxconstantstring_class);
}

void sf_runtime_test_reset_autorelease_state(void) {
    free((void *)g_autorelease_state.objects);
    free(g_autorelease_state.markers);
    memset(&g_autorelease_state, 0, sizeof(g_autorelease_state));
    g_last_header_obj = NULL;
    g_last_header_ptr = NULL;
    g_pool_fallback_token = 0;
}

static inline SFObjHeader_t *header_from_heap_candidate(id obj) {
    SFObjHeader_t *hdr = NULL;
    if (obj == g_last_header_obj) {
        return g_last_header_ptr;
    }

    if (obj == NULL) {
        return NULL;
    }
    if (sf_object_bypasses_heap_arc(obj)) {
        return NULL;
    }

    hdr = sf_header_from_object(obj);
    if (hdr == NULL) {
        return NULL;
    }

    g_last_header_obj = obj;
    g_last_header_ptr = hdr;
    return hdr;
}

static int ensure_object_capacity(size_t wanted) {
    if (g_autorelease_state.capacity >= wanted) {
        return 1;
    }
    size_t new_cap = g_autorelease_state.capacity ? g_autorelease_state.capacity * 2 : 64;
    while (new_cap < wanted) new_cap *= 2;
    id *next = (id *)sf_runtime_test_realloc((void *)g_autorelease_state.objects,
                                             new_cap * sizeof(id));
    if (next == NULL) {
        return 0;
    }
    g_autorelease_state.objects = next;
    g_autorelease_state.capacity = new_cap;
    return 1;
}

static int ensure_marker_capacity(size_t wanted) {
    if (g_autorelease_state.marker_capacity >= wanted) {
        return 1;
    }
    size_t new_cap = g_autorelease_state.marker_capacity ? g_autorelease_state.marker_capacity * 2 : 8;
    while (new_cap < wanted) new_cap *= 2;
    size_t *next = (size_t *)sf_runtime_test_realloc(g_autorelease_state.markers,
                                                     new_cap * sizeof(size_t));
    if (next == NULL) {
        return 0;
    }
    g_autorelease_state.markers = next;
    g_autorelease_state.marker_capacity = new_cap;
    return 1;
}

static void free_group_members(SFObjHeader_t *head, SFAllocator_t *allocator) {
    SFObjHeader_t *member = head;
    SFAllocator_t *use_allocator = allocator ? allocator : sf_default_allocator();
    while (member != NULL) {
        SFObjHeader_t *next = sf_header_group_next(member);
        size_t total_size = (size_t)member->alloc_size;
        sf_header_destroy_sidecar(member, 0);
        use_allocator->free(use_allocator->ctx, (void *)member, total_size, sizeof(void *));
        member = next;
    }
}

void sf_object_dispose(id obj) {
    SFObjHeader_t *hdr = header_from_heap_candidate(obj);
    if (hdr == NULL) {
        return;
    }
    if ((hdr->flags & SF_OBJ_FLAG_IMMORTAL) != 0U) {
        return;
    }
    sf_exception_clear_metadata(obj);
    if (obj == g_last_header_obj) {
        g_last_header_obj = NULL;
        g_last_header_ptr = NULL;
    }

    SFObjHeader_t *root = sf_header_group_root(hdr);
    SFObjHeader_t *free_head = NULL;
    SFAllocator_t *group_allocator = NULL;
    SFRuntimeMutex_t *group_lock = sf_header_group_lock(hdr);

    if (!sf_header_grouped(hdr) || group_lock == NULL) {
        SFAllocator_t *allocator = sf_header_allocator(hdr);
        size_t total_size = (size_t)hdr->alloc_size;
        if (hdr->state != SF_OBJ_STATE_LIVE) {
            return;
        }
        sf_unregister_live_object_header(hdr);
        hdr->state = SF_OBJ_STATE_DISPOSED;
#if SF_RUNTIME_VALIDATION
        hdr->magic = 0;
#endif
        if (allocator == NULL) {
            allocator = sf_default_allocator();
        }
        sf_header_destroy_sidecar(hdr, 0);
        allocator->free(allocator->ctx, (void *)hdr, total_size, sizeof(void *));
        return;
    }

    sf_runtime_mutex_lock(group_lock);
    if (hdr->state != SF_OBJ_STATE_LIVE) {
        sf_runtime_mutex_unlock(group_lock);
        return;
    }

    sf_unregister_live_object_header(hdr);
    hdr->state = SF_OBJ_STATE_DISPOSED;
#if SF_RUNTIME_VALIDATION
    hdr->magic = 0;
#endif
    if (sf_header_group_live_count(root) > 0) {
        (void)sf_header_set_group_live_count(root, sf_header_group_live_count(root) - 1);
    }
    if (sf_header_group_live_count(root) == 0) {
        free_head = sf_header_group_head(root);
        group_allocator = sf_header_allocator(root);
        (void)sf_header_set_group_head(root, NULL);
    }
    sf_runtime_mutex_unlock(group_lock);

    if (free_head != NULL) {
        sf_header_destroy_sidecar(root, 1);
        free_group_members(free_head, group_allocator);
    }
}

static void release_object_now(id obj) {
    SFObjHeader_t *hdr = header_from_heap_candidate(obj);
    if (hdr == NULL) {
        return;
    }
    if ((hdr->flags & SF_OBJ_FLAG_IMMORTAL) != 0U) {
        return;
    }
    if (hdr->state != SF_OBJ_STATE_LIVE) {
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

    SEL dealloc_sel = sf_cached_selector_dealloc();

    if (obj == g_last_header_obj) {
        g_last_header_obj = NULL;
        g_last_header_ptr = NULL;
    }

    IMP imp = sf_class_cached_dealloc_imp(sf_object_class(obj));
    if (imp == NULL && dealloc_sel != NULL) {
        imp = sf_lookup_imp_in_class(sf_object_class(obj), dealloc_sel);
    }
    if (imp != NULL && !sf_dispatch_imp_is_nil(imp) && dealloc_sel != NULL) {
        (void)imp(obj, dealloc_sel);
    }
    sf_object_dispose(obj);
}

id objc_retain(id obj) {
    SFObjHeader_t *hdr = header_from_heap_candidate(obj);
    if (hdr != NULL) {
        if ((hdr->flags & SF_OBJ_FLAG_IMMORTAL) != 0U) {
            return obj;
        }
        if (hdr->state != SF_OBJ_STATE_LIVE) {
            return obj;
        }
#if SF_RUNTIME_THREADSAFE
        (void)__atomic_fetch_add(&hdr->refcount, 1, __ATOMIC_RELAXED);
#else
        hdr->refcount += 1;
#endif
    }
    return obj;
}

void objc_release(id obj) {
    release_object_now(obj);
}

id sf_autorelease(id obj) {
    if (header_from_heap_candidate(obj) == NULL) {
        return obj;
    }
    if (g_autorelease_state.marker_count == 0) {
        return obj;
    }
    if (!ensure_object_capacity(g_autorelease_state.count + 1)) {
        return obj;
    }
    g_autorelease_state.objects[g_autorelease_state.count++] = obj;
    return obj;
}

void *objc_autoreleasePoolPush(void) {
    size_t marker = g_autorelease_state.count;
    size_t *token = NULL;

    if (ensure_marker_capacity(g_autorelease_state.marker_count + 1)) {
        g_autorelease_state.markers[g_autorelease_state.marker_count++] = marker;
    }

    token = (size_t *)sf_runtime_test_malloc(sizeof(size_t));
    if (token != NULL) {
        *token = marker;
        return (void *)token;
    }

    g_pool_fallback_token = marker;
    return (void *)&g_pool_fallback_token;
}

void objc_autoreleasePoolPop(void *pool) {
    size_t marker = g_autorelease_state.count;
    if (pool == (void *)&g_pool_fallback_token) {
        marker = g_pool_fallback_token;
    } else if (pool != NULL) {
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

id objc_retainAutorelease(id obj) {
    return sf_autorelease(objc_retain(obj));
}

id objc_retainAutoreleasedReturnValue(id obj) {
    return objc_retain(obj);
}

id objc_autoreleaseReturnValue(id obj) {
    return sf_autorelease(obj);
}

id objc_retainAutoreleaseReturnValue(id obj) {
    return sf_autorelease(objc_retain(obj));
}

void objc_storeStrong(id *dst, id value) {
    id old = *dst;
    if (old == value) {
        return;
    }
    if (value != NULL) {
        objc_retain(value);
    }
    *dst = value;
    if (old != NULL) {
        objc_release(old);
    }
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
