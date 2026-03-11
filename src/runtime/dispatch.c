#include "runtime/internal.h"

#include <stdatomic.h>
#include <string.h>

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpre-c11-compat"
#endif

#if defined(__clang__) or defined(__GNUC__)
#define SF_ALWAYS_INLINE inline __attribute__((always_inline))
#else
#define SF_ALWAYS_INLINE inline
#endif

SFDispatchEntry_t g_dispatch_cache[SF_DISPATCH_CACHE_SIZE];
#if SF_RUNTIME_THREADSAFE
__thread SFDispatchEntry_t g_dispatch_l0;
#else
SFDispatchEntry_t g_dispatch_l0;
#endif

#if SF_RUNTIME_THREADSAFE
static SFRuntimeRwlock_t g_dispatch_cache_lock = SF_RUNTIME_RWLOCK_INITIALIZER;
#endif

#if SF_DISPATCH_STATS
#if SF_RUNTIME_THREADSAFE
static _Atomic(uint64_t) g_cache_hits;
static _Atomic(uint64_t) g_cache_misses;
static _Atomic(uint64_t) g_method_walks;
#define SF_STATS_INC(counter) atomic_fetch_add_explicit(&(counter), 1, memory_order_relaxed)
#define SF_STATS_LOAD(counter) atomic_load_explicit(&(counter), memory_order_relaxed)
#define SF_STATS_STORE(counter, value) atomic_store_explicit(&(counter), (value), memory_order_relaxed)
#else
static uint64_t g_cache_hits;
static uint64_t g_cache_misses;
static uint64_t g_method_walks;
#define SF_STATS_INC(counter) (++(counter))
#define SF_STATS_LOAD(counter) (counter)
#define SF_STATS_STORE(counter, value) ((counter) = (value))
#endif
#else
#define SF_STATS_INC(counter) ((void)0)
#endif

id sf_dispatch_nil_imp(id self, SEL cmd, ...)
{
    (void)self;
    (void)cmd;
    return (id)0;
}

static int selector_equal_local(SEL lhs, SEL rhs)
{
    if (lhs == rhs) {
        return 1;
    }
    if (lhs == NULL or rhs == NULL) {
        return 0;
    }

    if (lhs->name == rhs->name and lhs->types == rhs->types) {
        return 1;
    }

    if (lhs->name == NULL or rhs->name == NULL) {
        return 0;
    }
    if (strcmp(lhs->name, rhs->name) != 0) {
        return 0;
    }
    return 1;
}

int sf_selector_equal(SEL a, SEL b)
{
    return selector_equal_local(a, b);
}

int sf_dispatch_imp_is_nil(IMP imp)
{
    return imp == (IMP)sf_dispatch_nil_imp;
}

static size_t cache_index_for(Class cls, SEL op)
{
    uintptr_t cls_bits = ((uintptr_t)cls) >> 4U;
    uintptr_t sel_bits = ((uintptr_t)op) >> 4U;
    uintptr_t mixed = cls_bits ^ sel_bits ^ (sel_bits >> 9U) ^ (cls_bits >> 11U);
    return (size_t)(mixed & (SF_DISPATCH_CACHE_SIZE - 1U));
}

static SF_ALWAYS_INLINE int entry_match_inline(const SFDispatchEntry_t *entry, Class cls, SEL op, IMP *out_imp)
{
    IMP cached_imp = NULL;

    if (entry->cls != cls) {
        return 0;
    }

    if (entry->sel != op) {
        return 0;
    }

    cached_imp = entry->imp;
    if (cached_imp == NULL)
        return 0;

    *out_imp = cached_imp;
    return 1;
}

static SF_ALWAYS_INLINE void entry_store(SFDispatchEntry_t *entry, Class cls, SEL op, IMP imp)
{
    entry->cls = cls;
    entry->sel = op;
    entry->imp = imp;
    entry->reserved = 0;
}

static SFObjCMethod_t *lookup_method_in_class_local(Class cls, SEL op)
{
    SFObjCClass_t *c = NULL;
    SFObjCClass_t *next = NULL;

    if (cls == NULL or op == NULL) {
        return NULL;
    }

    c = (SFObjCClass_t *)cls;
    while (c != NULL) {
        SFObjCMethodList_t *list = c->methods;
        while (list != NULL) {
            int32_t i = 0;
            for (i = 0; i < list->count; ++i) {
                SFObjCMethod_t *m = &list->methods[i];
                if (m->selector == op or
                    (m->selector != NULL and op != NULL and
                     m->selector->name == op->name and m->selector->types == op->types) or
                    selector_equal_local(m->selector, op)) {
                    return m;
                }
            }
            list = list->next;
        }
        next = c->superclass;
        c = (next == c) ? NULL : next;
    }

    return NULL;
}

SFObjCMethod_t *sf_lookup_method_in_class(Class cls, SEL op)
{
    return lookup_method_in_class_local(cls, op);
}

IMP sf_lookup_imp_in_class(Class cls, SEL op)
{
    SFObjCMethod_t *method = lookup_method_in_class_local(cls, op);
    return method != NULL ? method->imp : NULL;
}

IMP sf_lookup_imp_miss(Class cls, SEL op)
{
    IMP imp = NULL;
    SFDispatchEntry_t *entry = NULL;
    size_t index = 0;

    SF_STATS_INC(g_cache_misses);
    SF_STATS_INC(g_method_walks);

    imp = sf_lookup_imp_in_class(cls, op);
    if (imp == NULL) {
        imp = (IMP)sf_dispatch_nil_imp;
    }

    index = cache_index_for(cls, op);
    entry = &g_dispatch_cache[index];

#if SF_RUNTIME_THREADSAFE
    sf_runtime_rwlock_wrlock(&g_dispatch_cache_lock);
#endif
    entry_store(entry, cls, op, imp);
#if SF_RUNTIME_THREADSAFE
    sf_runtime_rwlock_unlock(&g_dispatch_cache_lock);
#endif
    entry_store(&g_dispatch_l0, cls, op, imp);

    return imp;
}

static SF_ALWAYS_INLINE IMP lookup_cached_inline(Class cls, SEL op)
{
    IMP imp = NULL;
    SFDispatchEntry_t *entry = NULL;
    size_t index = 0;

    if (entry_match_inline(&g_dispatch_l0, cls, op, &imp)) {
        SF_STATS_INC(g_cache_hits);
        return imp;
    }

    index = cache_index_for(cls, op);
    entry = &g_dispatch_cache[index];

#if SF_RUNTIME_THREADSAFE
    sf_runtime_rwlock_rdlock(&g_dispatch_cache_lock);
#endif
    if (entry_match_inline(entry, cls, op, &imp)) {
#if SF_RUNTIME_THREADSAFE
        sf_runtime_rwlock_unlock(&g_dispatch_cache_lock);
#endif
        entry_store(&g_dispatch_l0, cls, op, imp);
        SF_STATS_INC(g_cache_hits);
        return imp;
    }
#if SF_RUNTIME_THREADSAFE
    sf_runtime_rwlock_unlock(&g_dispatch_cache_lock);
#endif

    return sf_lookup_imp_miss(cls, op);
}

IMP sf_lookup_imp(id receiver, SEL op)
{
    Class cls = NULL;

    if (receiver == NULL or op == NULL) {
        return (IMP)sf_dispatch_nil_imp;
    }

    cls = sf_object_class(receiver);
    if (cls == NULL) {
        return (IMP)sf_dispatch_nil_imp;
    }

    return lookup_cached_inline(cls, op);
}

static int selector_types_missing(SEL sel)
{
    return sel == NULL or sel->types == NULL or sel->types[0] == '\0';
}

static SEL resolved_selector_for_method(const SFObjCMethod_t *method, SEL fallback)
{
    if (method == NULL) {
        return fallback;
    }
    if (method->selector != NULL) {
        return method->selector;
    }
    return fallback;
}

IMP sf_resolve_message_dispatch(id *receiver, SEL *op)
{
    id current_receiver = NULL;
    SEL current_sel = NULL;
#if SF_RUNTIME_FORWARDING
    SEL forwarding_sel = NULL;
    int forward_hops_remaining = 0;
#endif

    if (receiver == NULL or op == NULL) {
        return (IMP)sf_dispatch_nil_imp;
    }

    current_receiver = *receiver;
    current_sel = *op;

#if SF_RUNTIME_FORWARDING
    forwarding_sel = sf_cached_selector_forwarding_target();
    forward_hops_remaining = 8;
#endif

    for (;;) {
        IMP imp = NULL;
        Class cls = NULL;
        SFObjCMethod_t *method = NULL;
#if SF_RUNTIME_FORWARDING
        SFObjCMethod_t *forward_method = NULL;
        id target = NULL;
#endif

        if (current_receiver == NULL or current_sel == NULL) {
            break;
        }

        cls = sf_object_class(current_receiver);
        if (cls == NULL) {
            break;
        }

        imp = sf_lookup_imp(current_receiver, current_sel);
        if (imp != NULL and not sf_dispatch_imp_is_nil(imp)) {
            method = lookup_method_in_class_local(cls, current_sel);
            if (method != NULL and (selector_types_missing(current_sel) or method->selector != current_sel)) {
                current_sel = resolved_selector_for_method(method, current_sel);
            }
            *receiver = current_receiver;
            *op = current_sel;
            return imp;
        }

#if SF_RUNTIME_FORWARDING
        if (forward_hops_remaining <= 0 or forwarding_sel == NULL or sf_selector_equal(current_sel, forwarding_sel)) {
            break;
        }

        forward_method = lookup_method_in_class_local(cls, forwarding_sel);
        if (forward_method == NULL or forward_method->imp == NULL) {
            break;
        }

        target = ((id (*)(id, SEL, SEL))forward_method->imp)(current_receiver, forwarding_sel, current_sel);
        if (target == NULL or target == current_receiver) {
            break;
        }

        current_receiver = target;
        if (--forward_hops_remaining == 0) {
            break;
        }
        continue;
#else
        break;
#endif
    }

    *receiver = current_receiver;
    *op = current_sel;
    return (IMP)sf_dispatch_nil_imp;
}

IMP objc_msg_lookup_super(struct sf_objc_super *super_info, SEL op)
{
    if (super_info == NULL or super_info->super_class == NULL or op == NULL) {
        return (IMP)sf_dispatch_nil_imp;
    }
    return lookup_cached_inline(super_info->super_class, op);
}

uint64_t sf_dispatch_cache_hits(void)
{
#if SF_DISPATCH_STATS
    return SF_STATS_LOAD(g_cache_hits);
#else
    return UINT64_C(0);
#endif
}

uint64_t sf_dispatch_cache_misses(void)
{
#if SF_DISPATCH_STATS
    return SF_STATS_LOAD(g_cache_misses);
#else
    return UINT64_C(0);
#endif
}

uint64_t sf_dispatch_method_walks(void)
{
#if SF_DISPATCH_STATS
    return SF_STATS_LOAD(g_method_walks);
#else
    return UINT64_C(0);
#endif
}

void sf_dispatch_reset_stats(void)
{
    size_t i = 0;

#if SF_RUNTIME_THREADSAFE
    sf_runtime_rwlock_wrlock(&g_dispatch_cache_lock);
#endif
    for (i = 0; i < SF_DISPATCH_CACHE_SIZE; ++i) {
        entry_store(&g_dispatch_cache[i], NULL, NULL, NULL);
    }
#if SF_RUNTIME_THREADSAFE
    sf_runtime_rwlock_unlock(&g_dispatch_cache_lock);
#endif

    entry_store(&g_dispatch_l0, NULL, NULL, NULL);

#if SF_DISPATCH_STATS
    SF_STATS_STORE(g_cache_hits, UINT64_C(0));
    SF_STATS_STORE(g_cache_misses, UINT64_C(0));
    SF_STATS_STORE(g_method_walks, UINT64_C(0));
#endif
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
