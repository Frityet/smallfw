#include "runtime/internal.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
#endif

typedef struct SFClassEntry {
    const char *name;
    SFObjCClass_t *cls;
} SFClassEntry_t;

typedef struct SFClassMetaEntry {
    Class cls;
    const char *name;
    SFObjCMethodList_t *methods;
    SFObjCClass_t *superclass;
    IMP dealloc_imp;
    IMP alloc_imp;
    IMP init_imp;
} SFClassMetaEntry_t;

typedef struct SFSelectorEntry {
    struct sf_objc_selector sel;
    struct SFSelectorEntry *next;
} SFSelectorEntry_t;

enum { SF_CLASS_MAP_CAPACITY = 2048 };
enum { SF_CLASS_META_CAPACITY = 4096 };
enum { SF_LIVE_OBJECT_BUCKETS = 8192U };
enum { SF_SELECTOR_BUCKETS = 256U };

static SFClassEntry_t g_class_map[SF_CLASS_MAP_CAPACITY];
static SFClassMetaEntry_t g_class_meta[SF_CLASS_META_CAPACITY];
static SFObjCClass_t *g_layout_fixed_map[SF_CLASS_MAP_CAPACITY];
static SFRuntimeRwlock_t g_class_map_lock = SF_RUNTIME_RWLOCK_INITIALIZER;
#if SF_RUNTIME_VALIDATION
static SFRuntimeRwlock_t g_live_object_lock = SF_RUNTIME_RWLOCK_INITIALIZER;
static SFObjHeader_t *g_live_object_buckets[SF_LIVE_OBJECT_BUCKETS];
#endif
static SFSelectorEntry_t *g_selector_table[SF_SELECTOR_BUCKETS];
static SFRuntimeRwlock_t g_selector_lock = SF_RUNTIME_RWLOCK_INITIALIZER;

static Class g_object_class;
static SEL g_dealloc_sel;
static SEL g_alloc_sel;
static SEL g_init_sel;

typedef struct SFObjCAliasEntry {
    const char *alias_name;
    Class *class_ref;
} SFObjCAliasEntry_t;

static void sf_cache_class_meta(Class cls);

static uint64_t hash_cstr(const char *s) {
    return sf_hash_bytes(s, sf_cstr_len(s));
}

static uint64_t hash_ptr_local(const void *p) {
    uintptr_t v = (uintptr_t)p;
    v ^= (v >> 33);
    v *= UINT64_C(0xff51afd7ed558ccd);
    v ^= (v >> 33);
    v *= UINT64_C(0xc4ceb9fe1a85ec53);
    v ^= (v >> 33);
    return (uint64_t)v;
}

#if SF_RUNTIME_VALIDATION
static size_t live_object_bucket_index(id obj) {
    uint64_t hash = hash_ptr_local(obj);
    return (size_t)(hash & (SF_LIVE_OBJECT_BUCKETS - 1U));
}
#endif

static size_t selector_bucket_for_name_types(const char *name, const char *types) {
    uint64_t hash = hash_cstr(name);
    if (types != NULL) {
        hash ^= (hash_cstr(types) << 1U);
    }
    return (size_t)(hash & (SF_SELECTOR_BUCKETS - 1U));
}

static int cstr_equal_nullable(const char *lhs, const char *rhs) {
    if (lhs == rhs) {
        return 1;
    }
    if (lhs == NULL || rhs == NULL) {
        return 0;
    }
    return strcmp(lhs, rhs) == 0;
}

static char *copy_cstr_nullable(const char *value) {
    if (value == NULL) {
        return NULL;
    }

    size_t n = sf_cstr_len(value);
    char *copy = (char *)sf_runtime_test_malloc(n + 1U);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, value, n);
    copy[n] = '\0';
    return copy;
}

static SEL intern_selector_name_types(const char *name, const char *types) {
    if (name == NULL || name[0] == '\0') {
        return NULL;
    }

    size_t bucket = selector_bucket_for_name_types(name, types);

    sf_runtime_rwlock_rdlock(&g_selector_lock);
    for (SFSelectorEntry_t *it = g_selector_table[bucket]; it != NULL; it = it->next) {
        if (cstr_equal_nullable(it->sel.name, name) && cstr_equal_nullable(it->sel.types, types)) {
            SEL found = &it->sel;
            sf_runtime_rwlock_unlock(&g_selector_lock);
            return found;
        }
    }
    sf_runtime_rwlock_unlock(&g_selector_lock);

    sf_runtime_rwlock_wrlock(&g_selector_lock);
    for (SFSelectorEntry_t *it = g_selector_table[bucket]; it != NULL; it = it->next) {
        if (cstr_equal_nullable(it->sel.name, name) && cstr_equal_nullable(it->sel.types, types)) {
            SEL found = &it->sel;
            sf_runtime_rwlock_unlock(&g_selector_lock);
            return found;
        }
    }

    SFSelectorEntry_t *entry = (SFSelectorEntry_t *)sf_runtime_test_calloc(1, sizeof(*entry));
    char *owned_name = NULL;
    char *owned_types = NULL;
    if (entry == NULL) {
        sf_runtime_rwlock_unlock(&g_selector_lock);
        return NULL;
    }

    owned_name = copy_cstr_nullable(name);
    if (owned_name == NULL) {
        free(entry);
        sf_runtime_rwlock_unlock(&g_selector_lock);
        return NULL;
    }

    owned_types = copy_cstr_nullable(types);
    if (types != NULL && owned_types == NULL) {
        free(owned_name);
        free(entry);
        sf_runtime_rwlock_unlock(&g_selector_lock);
        return NULL;
    }

    entry->sel.name = owned_name;
    entry->sel.types = owned_types;
    entry->next = g_selector_table[bucket];
    g_selector_table[bucket] = entry;
    sf_runtime_rwlock_unlock(&g_selector_lock);
    return &entry->sel;
}

SEL sf_intern_selector(SEL sel) {
    if (sel == NULL) {
        return NULL;
    }

    SEL interned = intern_selector_name_types(sel->name, sel->types);
    if (interned == NULL) {
        return sel;
    }

    sel->name = interned->name;
    sel->types = interned->types;
    return interned;
}

static void register_selector_region(void *start, void *stop) {
    if (start == NULL || stop == NULL || stop <= start) {
        return;
    }

    SEL sel = (SEL)start;
    SEL end = (SEL)stop;
    while (sel < end) {
        (void)sf_intern_selector(sel);
        ++sel;
    }
}

static SFClassMetaEntry_t *class_meta_slot_for(Class cls) {
    if (cls == NULL) {
        return NULL;
    }

    uint64_t hash = hash_ptr_local(cls);
    for (size_t i = 0; i < SF_CLASS_META_CAPACITY; ++i) {
        size_t idx = (size_t)((hash + i) & (SF_CLASS_META_CAPACITY - 1U));
        SFClassMetaEntry_t *slot = &g_class_meta[idx];
        if (slot->cls == cls || slot->cls == NULL) {
            return slot;
        }
    }
    return NULL;
}

static int layout_fixed_contains(SFObjCClass_t *cls) {
    uint64_t h = hash_ptr_local(cls);
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((h + i) % SF_CLASS_MAP_CAPACITY);
        SFObjCClass_t *slot = g_layout_fixed_map[idx];
        if (slot == cls) {
            return 1;
        }
        if (slot == NULL) {
            return 0;
        }
    }
    return 0;
}

static SFObjCClass_t *sf_next_superclass(SFObjCClass_t *cls) {
    if (cls == NULL || cls->superclass == cls) {
        return NULL;
    }
    return cls->superclass;
}

static void layout_fixed_insert(SFObjCClass_t *cls) {
    uint64_t h = hash_ptr_local(cls);
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((h + i) % SF_CLASS_MAP_CAPACITY);
        SFObjCClass_t **slot = &g_layout_fixed_map[idx];
        if (*slot == cls) return;
        if (*slot == NULL) {
            *slot = cls;
            return;
        }
    }
}

static size_t align_up(size_t value, size_t align) {
    if (align <= 1U) return value;
    size_t mask = align - 1U;
    return (value + mask) & ~mask;
}

static size_t sf_fix_class_layout(SFObjCClass_t *cls) {
    if (cls == NULL) return sizeof(void *);
    if (layout_fixed_contains(cls)) {
        if (cls->instance_size > 0) {
            return (size_t)cls->instance_size;
        }
        return sizeof(void *);
    }

    size_t super_size = sizeof(void *);
    if (cls->superclass != NULL && cls->superclass != cls) {
        super_size = sf_fix_class_layout(cls->superclass);
    }
    if (super_size < sizeof(void *)) super_size = sizeof(void *);

    size_t max_end = super_size;
    SFObjCIvarList_t *list = (SFObjCIvarList_t *)cls->ivars;
    if (list != NULL && list->count > 0) {
        size_t stride = (size_t)list->item_size;
        if (stride < sizeof(SFObjCIvar_t)) {
            stride = sizeof(SFObjCIvar_t);
        }

        unsigned char *cursor = (unsigned char *)list->ivars;
        for (uintptr_t i = 0; i < list->count; ++i) {
            SFObjCIvar_t *ivar = (SFObjCIvar_t *)(void *)cursor;
            int32_t adjusted_offset = 0;
            int skip_size = 0;
            if (ivar->offset != NULL) {
                int64_t off = (int64_t)(*ivar->offset) + (int64_t)super_size;
                if (off < 0) {
                    off = 0;
                } else if (off > INT32_MAX) {
                    off = INT32_MAX;
                }
                *ivar->offset = (int32_t)off;
                adjusted_offset = *ivar->offset;
                if (adjusted_offset == INT32_MAX) {
                    skip_size = 1;
                }
            }
            size_t ivar_size = ivar->size ? (size_t)ivar->size : sizeof(void *);
            if (!skip_size) {
                size_t end = (size_t)adjusted_offset + ivar_size;
                if (end > max_end) {
                    max_end = end;
                }
            }
            cursor += stride;
        }
    }

    max_end = align_up(max_end, sizeof(void *));
#if defined(_WIN32)
    if (max_end > (size_t)LONG_MAX) {
        max_end = (size_t)LONG_MAX;
    }
#endif
    if (max_end < sizeof(void *)) max_end = sizeof(void *);
    cls->instance_size = (long)max_end;
    layout_fixed_insert(cls);
    return max_end;
}

static void sf_canonicalize_method_selectors(SFObjCClass_t *cls) {
    if (cls == NULL) {
        return;
    }

    for (SFObjCMethodList_t *list = cls->methods; list != NULL; list = list->next) {
        for (int32_t i = 0; i < list->count; ++i) {
            SFObjCMethod_t *method = &list->methods[i];
            SEL canonical = method->selector;
            if (canonical != NULL) {
                if (method->types != NULL) {
                    canonical->types = method->types;
                }
                canonical = sf_intern_selector(canonical);
            }
            method->selector = canonical;
            if (canonical != NULL) {
                method->types = canonical->types;
            }
        }
    }
}

static void class_map_insert_unlocked(const char *name, SFObjCClass_t *cls) {
    uint64_t h = hash_cstr(name);
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((h + i) % SF_CLASS_MAP_CAPACITY);
        SFClassEntry_t *slot = &g_class_map[idx];
        if (slot->name == NULL || strcmp(slot->name, name) == 0) {
            slot->name = name;
            slot->cls = cls;
            return;
        }
    }
}

static SFObjCClass_t *class_map_lookup_unlocked(const char *name) {
    uint64_t h = hash_cstr(name);
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((h + i) % SF_CLASS_MAP_CAPACITY);
        SFClassEntry_t *slot = &g_class_map[idx];
        if (slot->name == NULL) {
            return NULL;
        }
        if (strcmp(slot->name, name) == 0) {
            return slot->cls;
        }
    }
    return NULL;
}

SFObjCClass_t *sf_class_from_name(const char *name) {
    if (name == NULL) {
        return NULL;
    }

    sf_runtime_rwlock_rdlock(&g_class_map_lock);
    SFObjCClass_t *result = class_map_lookup_unlocked(name);
    sf_runtime_rwlock_unlock(&g_class_map_lock);
    return result;
}

void sf_register_classes(SFObjCClass_t **start, SFObjCClass_t **stop) {
    if (start == NULL || stop == NULL || stop <= start) {
        return;
    }

    sf_runtime_rwlock_wrlock(&g_class_map_lock);
    for (SFObjCClass_t **it = start; it < stop; ++it) {
        SFObjCClass_t *cls = *it;
        if (cls == NULL || cls->name == NULL || cls->name[0] == '\0') {
            continue;
        }
        class_map_insert_unlocked(cls->name, cls);
    }
    sf_runtime_rwlock_unlock(&g_class_map_lock);
}

static void sf_register_class_aliases(SFObjCAliasEntry_t *start, SFObjCAliasEntry_t *stop) {
    if (start == NULL || stop == NULL || stop <= start) return;

    sf_runtime_rwlock_wrlock(&g_class_map_lock);
    for (SFObjCAliasEntry_t *it = start; it < stop; ++it) {
        if (it->alias_name == NULL || it->class_ref == NULL) {
            continue;
        }
        Class cls = *(it->class_ref);
        if (cls == NULL) {
            continue;
        }
        class_map_insert_unlocked(it->alias_name, (SFObjCClass_t *)cls);
    }
    sf_runtime_rwlock_unlock(&g_class_map_lock);
}

void sf_finalize_registered_classes(void) {
    if (g_dealloc_sel == NULL || g_alloc_sel == NULL || g_init_sel == NULL) {
        static struct sf_objc_selector dealloc_sel_data = {"dealloc", "v16@0:8"};
        static struct sf_objc_selector alloc_sel_data = {"allocWithAllocator:", "@24@0:8^v16"};
        static struct sf_objc_selector init_sel_data = {"init", "@16@0:8"};
        g_dealloc_sel = sf_intern_selector(&dealloc_sel_data);
        g_alloc_sel = sf_intern_selector(&alloc_sel_data);
        g_init_sel = sf_intern_selector(&init_sel_data);
    }

    sf_runtime_rwlock_wrlock(&g_class_map_lock);
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        SFObjCClass_t *cls = slot->cls;
        if (slot->name == NULL || cls == NULL || cls->isa == NULL) {
            continue;
        }
        sf_fix_class_layout(cls);
        sf_canonicalize_method_selectors(cls);
        sf_canonicalize_method_selectors(cls->isa);
        if (cls->superclass != NULL && cls->superclass->isa != NULL) {
            cls->isa->superclass = cls->superclass->isa;
        } else {
            cls->isa->superclass = cls;
        }
        sf_cache_class_meta((Class)cls);
        sf_cache_class_meta((Class)cls->isa);
    }
    sf_runtime_rwlock_unlock(&g_class_map_lock);

    sf_register_builtin_class_cache();
}

void __objc_load(void *init_ptr) {
    SFObjCInit_t *init = (SFObjCInit_t *)init_ptr;
    if (init == NULL) {
        return;
    }
    register_selector_region(init->selectors_start, init->selectors_stop);
    sf_register_classes((SFObjCClass_t **)init->classes_start, (SFObjCClass_t **)init->classes_stop);
    sf_register_class_aliases((SFObjCAliasEntry_t *)init->aliases_start,
                              (SFObjCAliasEntry_t *)init->aliases_stop);
    sf_finalize_registered_classes();
}

id objc_lookup_class(const char *name, ...) {
    return (id)sf_class_from_name(name);
}

id objc_getClass(const char *name) {
    return (id)sf_class_from_name(name);
}

size_t class_getInstanceSize(Class cls) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL) {
        return sizeof(void *);
    }

    size_t size = 0;
#if SF_RUNTIME_THREADSAFE
    sf_runtime_rwlock_rdlock(&g_class_map_lock);
    if (layout_fixed_contains(c)) {
        size = (size_t)c->instance_size;
        sf_runtime_rwlock_unlock(&g_class_map_lock);
    } else {
        sf_runtime_rwlock_unlock(&g_class_map_lock);
        sf_runtime_rwlock_wrlock(&g_class_map_lock);
        size = sf_fix_class_layout(c);
        sf_canonicalize_method_selectors(c);
        sf_canonicalize_method_selectors(c->isa);
        sf_cache_class_meta(cls);
        if (c->isa != NULL) {
            sf_cache_class_meta((Class)c->isa);
        }
        sf_runtime_rwlock_unlock(&g_class_map_lock);
    }
#else
    if (layout_fixed_contains(c)) {
        size = (size_t)c->instance_size;
    } else {
        sf_runtime_rwlock_wrlock(&g_class_map_lock);
        size = sf_fix_class_layout(c);
        sf_canonicalize_method_selectors(c);
        sf_canonicalize_method_selectors(c->isa);
        sf_cache_class_meta(cls);
        if (c->isa != NULL) {
            sf_cache_class_meta((Class)c->isa);
        }
        sf_runtime_rwlock_unlock(&g_class_map_lock);
    }
#endif

    if (size < sizeof(void *)) return sizeof(void *);
    return size;
}

size_t sf_class_instance_size_fast(Class cls) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    size_t size = sizeof(void *);
    if (c != NULL) {
        size = (c->instance_size > 0) ? (size_t)c->instance_size : class_getInstanceSize(cls);
    }
    if (size < sizeof(void *)) {
        size = sizeof(void *);
    }
    return size;
}

int sf_object_is_heap(id obj) {
    if (obj == NULL) {
        return 0;
    }
#if SF_RUNTIME_VALIDATION
    return sf_header_from_object(obj) != NULL;
#else
    SFObjHeader_t *hdr = ((SFObjHeader_t *)obj) - 1;
    return hdr->state == SF_OBJ_STATE_LIVE || (hdr->flags & SF_OBJ_FLAG_IMMORTAL) != 0U;
#endif
}

Class sf_object_class(id obj) {
    if (obj == NULL) {
        return NULL;
    }
    return *(Class *)obj;
}

void sf_register_live_object_header(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return;
    }
#if SF_RUNTIME_VALIDATION
    id obj = (id)(hdr + 1);
    size_t bucket = live_object_bucket_index(obj);

    sf_runtime_rwlock_wrlock(&g_live_object_lock);
    hdr->live_next = g_live_object_buckets[bucket];
    g_live_object_buckets[bucket] = hdr;
    sf_runtime_rwlock_unlock(&g_live_object_lock);
#else
    (void)hdr;
#endif
}

void sf_unregister_live_object_header(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return;
    }
#if SF_RUNTIME_VALIDATION
    id obj = (id)(hdr + 1);
    size_t bucket = live_object_bucket_index(obj);

    sf_runtime_rwlock_wrlock(&g_live_object_lock);
    SFObjHeader_t **slot = &g_live_object_buckets[bucket];
    while (*slot != NULL) {
        if (*slot == hdr) {
            *slot = hdr->live_next;
            hdr->live_next = NULL;
            break;
        }
        slot = &(*slot)->live_next;
    }
    sf_runtime_rwlock_unlock(&g_live_object_lock);
#else
    (void)hdr;
#endif
}

SFObjHeader_t *sf_header_from_object(id obj) {
    if (obj == NULL) {
        return NULL;
    }
#if SF_RUNTIME_VALIDATION
    size_t bucket = live_object_bucket_index(obj);

    sf_runtime_rwlock_rdlock(&g_live_object_lock);
    SFObjHeader_t *hdr = g_live_object_buckets[bucket];
    while (hdr != NULL) {
        if ((id)(hdr + 1) == obj) {
            sf_runtime_rwlock_unlock(&g_live_object_lock);
            return hdr;
        }
        hdr = hdr->live_next;
    }
    sf_runtime_rwlock_unlock(&g_live_object_lock);
    return NULL;
#else
    return ((SFObjHeader_t *)obj) - 1;
#endif
}

static SFGroupState_t *sf_create_group_state(SFObjHeader_t *root) {
    SFGroupState_t *group = (SFGroupState_t *)sf_runtime_test_calloc(1, sizeof(*group));
    if (group == NULL) {
        return NULL;
    }
    group->root = root;
    group->head = root;
    group->group_live_count = 1;
    group->dead = 0;
    sf_runtime_mutex_init(&group->group_lock);
    return group;
}

SFAllocator_t *sf_header_allocator(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return NULL;
    }
    return hdr->allocator;
}

int sf_header_set_allocator(SFObjHeader_t *hdr, SFAllocator_t *allocator) {
    if (hdr == NULL) {
        return 0;
    }
    hdr->allocator = allocator;
    return 1;
}

id sf_header_parent(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return NULL;
    }
    return hdr->parent;
}

int sf_header_set_parent(SFObjHeader_t *hdr, id parent) {
    if (hdr == NULL) {
        return 0;
    }
    hdr->parent = parent;
    return 1;
}

SFObjHeader_t *sf_header_group_root(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return NULL;
    }
    if (hdr->group != NULL && hdr->group->root != NULL) {
        return hdr->group->root;
    }
    return hdr;
}

int sf_header_set_group_root(SFObjHeader_t *hdr, SFObjHeader_t *group_root) {
    if (hdr == NULL) {
        return 0;
    }
    if (group_root == NULL) {
        hdr->group = NULL;
        return 1;
    }
    if (!sf_header_init_group_root(group_root)) {
        return 0;
    }
    hdr->group = group_root->group;
    return hdr->group != NULL;
}

SFObjHeader_t *sf_header_group_next(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return NULL;
    }
    return hdr->group_next;
}

int sf_header_set_group_next(SFObjHeader_t *hdr, SFObjHeader_t *group_next) {
    if (hdr == NULL) {
        return 0;
    }
    hdr->group_next = group_next;
    return 1;
}

SFObjHeader_t *sf_header_group_head(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return NULL;
    }
    if (hdr->group != NULL && hdr->group->head != NULL) {
        return hdr->group->head;
    }
    return hdr;
}

int sf_header_set_group_head(SFObjHeader_t *hdr, SFObjHeader_t *group_head) {
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == NULL) {
        return 0;
    }
    if (group_head == NULL && root->group == NULL) {
        return 1;
    }
    if (!sf_header_init_group_root(root)) {
        return 0;
    }
    root->group->head = group_head;
    return 1;
}

size_t sf_header_group_live_count(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return 0;
    }
    if (hdr->group != NULL) {
        return hdr->group->group_live_count;
    }
    return (hdr->state == SF_OBJ_STATE_LIVE) ? (size_t)1 : (size_t)0;
}

int sf_header_set_group_live_count(SFObjHeader_t *hdr, size_t count) {
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == NULL) {
        return 0;
    }
    if (count <= (size_t)1 && root->group == NULL) {
        return 1;
    }
    if (!sf_header_init_group_root(root)) {
        return 0;
    }
    root->group->group_live_count = count;
    root->group->dead = (count == 0) ? 1U : 0U;
    return 1;
}

int sf_header_grouped(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return 0;
    }
    return hdr->group != NULL;
}

int sf_header_init_group_root(SFObjHeader_t *hdr) {
    if (hdr == NULL) {
        return 0;
    }
    if (hdr->group != NULL) {
        return 1;
    }
    hdr->group = sf_create_group_state(hdr);
    hdr->group_next = NULL;
    if (hdr->group == NULL) {
        return 0;
    }
    return 1;
}

SFRuntimeMutex_t *sf_header_group_lock(SFObjHeader_t *hdr) {
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == NULL || root->group == NULL) {
        return NULL;
    }
    return &root->group->group_lock;
}

void sf_header_destroy_sidecar(SFObjHeader_t *hdr, int destroy_group_lock) {
    if (hdr == NULL) {
        return;
    }
    SFGroupState_t *group = hdr->group;
    hdr->group = NULL;
    hdr->parent = NULL;
    hdr->group_next = NULL;
    if (destroy_group_lock && group != NULL && group->root == hdr) {
        sf_runtime_mutex_destroy(&group->group_lock);
        free(group);
    }
}

size_t sf_object_allocation_size_for_object(id obj) {
    SFObjHeader_t *hdr = sf_header_from_object(obj);
    if (hdr != NULL && hdr->alloc_size != 0U) {
        return (size_t)hdr->alloc_size;
    }
    return sizeof(SFObjHeader_t) + sf_class_instance_size_fast(sf_object_class(obj));
}

static size_t sf_object_total_size(Class cls, size_t *align_out) {
    size_t instance_size = sf_class_instance_size_fast(cls);
    size_t align = sizeof(void *);
    if (align_out != NULL) {
        *align_out = align;
    }
    return sizeof(SFObjHeader_t) + instance_size;
}

static SFObjHeader_t *sf_init_allocated_header(void *raw, size_t total_size, SFAllocator_t *allocator) {
    memset(raw, 0, total_size);

    SFObjHeader_t *hdr = (SFObjHeader_t *)raw;
#if SF_RUNTIME_VALIDATION
    hdr->magic = SF_OBJ_HEADER_MAGIC;
    hdr->live_next = NULL;
#endif
    hdr->refcount = 1;
    hdr->state = SF_OBJ_STATE_LIVE;
    hdr->flags = SF_OBJ_FLAG_NONE;
    hdr->alloc_size = (uint32_t)total_size;
    hdr->allocator = allocator;
    return hdr;
}

static id sf_finish_object_alloc(Class cls, SFObjHeader_t *hdr) {
    id obj = (id)(hdr + 1);
    *(Class *)obj = cls;
    return obj;
}

id sf_alloc_object(Class cls, SFAllocator_t *allocator) {
    size_t align = 0;
    size_t total_size = sf_object_total_size(cls, &align);

    SFAllocator_t *use_allocator = allocator ? allocator : sf_default_allocator();
    void *raw = use_allocator->alloc(use_allocator->ctx, total_size, align);
    if (raw == NULL) {
        return NULL;
    }

    SFObjHeader_t *hdr = sf_init_allocated_header(raw, total_size, use_allocator);
    sf_register_live_object_header(hdr);
    return sf_finish_object_alloc(cls, hdr);
}

id sf_alloc_object_with_parent(Class cls, id parent) {
    if (parent == NULL) {
        return sf_alloc_object(cls, NULL);
    }

    SFObjHeader_t *parent_hdr = sf_header_from_object(parent);
    if (parent_hdr == NULL) {
        return NULL;
    }

    SFObjHeader_t *root = sf_header_group_root(parent_hdr);
    size_t align = 0;
    size_t total_size = sf_object_total_size(cls, &align);
    void *raw = NULL;

    if (!sf_header_init_group_root(root)) {
        return NULL;
    }
    if (root->group == NULL) {
        return NULL;
    }

    SFAllocator_t *use_allocator = root->allocator ? root->allocator : sf_default_allocator();
    SFRuntimeMutex_t *group_lock = &root->group->group_lock;

    sf_runtime_mutex_lock(group_lock);
    if (parent_hdr->state != SF_OBJ_STATE_LIVE || root->group->dead != 0U || root->group->group_live_count == 0U) {
        sf_runtime_mutex_unlock(group_lock);
        return NULL;
    }

    raw = use_allocator->alloc(use_allocator->ctx, total_size, align);
    if (raw == NULL) {
        sf_runtime_mutex_unlock(group_lock);
        return NULL;
    }

    SFObjHeader_t *hdr = sf_init_allocated_header(raw, total_size, use_allocator);
    hdr->parent = parent;
    hdr->group = root->group;
    hdr->group_next = root->group->head;
    root->group->head = hdr;
    root->group->group_live_count += 1U;
    sf_runtime_mutex_unlock(group_lock);
    sf_register_live_object_header(hdr);
    return sf_finish_object_alloc(cls, hdr);
}

size_t sf_cstr_len(const char *s) {
    if (s == NULL) {
        return 0;
    }
    size_t n = 0;
    while (s[n] != '\0') {
        ++n;
    }
    return n;
}

uint64_t sf_hash_bytes(const void *data, size_t size) {
    const unsigned char *p = (const unsigned char *)data;
    uint64_t h = UINT64_C(1469598103934665603);
    for (size_t i = 0; i < size; ++i) {
        h ^= (uint64_t)p[i];
        h *= UINT64_C(1099511628211);
    }
    return h;
}

uint64_t sf_hash_ptr(const void *p) {
    uintptr_t v = (uintptr_t)p;
    v ^= (v >> 33);
    v *= UINT64_C(0xff51afd7ed558ccd);
    v ^= (v >> 33);
    v *= UINT64_C(0xc4ceb9fe1a85ec53);
    v ^= (v >> 33);
    return (uint64_t)v;
}

static IMP sf_lookup_method_imp_exact(Class cls, SEL sel) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    while (c != NULL) {
        for (SFObjCMethodList_t *list = c->methods; list != NULL; list = list->next) {
            for (int32_t i = 0; i < list->count; ++i) {
                SFObjCMethod_t *method = &list->methods[i];
                if (method->selector == sel || sf_selector_equal(method->selector, sel)) {
                    return method->imp;
                }
            }
        }
        c = sf_next_superclass(c);
    }
    return NULL;
}

static int sf_class_meta_entry_stale(const SFClassMetaEntry_t *entry, Class cls) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (entry == NULL || entry->cls != cls || c == NULL) {
        return 1;
    }
    return entry->name != c->name || entry->methods != c->methods || entry->superclass != c->superclass;
}

static void sf_cache_class_meta(Class cls) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    SFClassMetaEntry_t *slot = class_meta_slot_for(cls);
    if (slot == NULL || c == NULL) {
        return;
    }
    slot->cls = cls;
    slot->name = c->name;
    slot->methods = c->methods;
    slot->superclass = c->superclass;
    slot->dealloc_imp = (g_dealloc_sel != NULL) ? sf_lookup_method_imp_exact(cls, g_dealloc_sel) : NULL;
    slot->alloc_imp = (g_alloc_sel != NULL) ? sf_lookup_method_imp_exact(cls, g_alloc_sel) : NULL;
    slot->init_imp = (g_init_sel != NULL) ? sf_lookup_method_imp_exact(cls, g_init_sel) : NULL;
}

static SFClassMetaEntry_t *sf_class_meta_for(Class cls) {
    SFClassMetaEntry_t *slot = class_meta_slot_for(cls);
    if (slot == NULL) {
        return NULL;
    }
    if (slot->cls == NULL || sf_class_meta_entry_stale(slot, cls)) {
        sf_cache_class_meta(cls);
    }
    return (slot->cls == cls) ? slot : NULL;
}

SEL sf_cached_selector_dealloc(void) {
    return g_dealloc_sel;
}

SEL sf_cached_selector_alloc(void) {
    return g_alloc_sel;
}

SEL sf_cached_selector_init(void) {
    return g_init_sel;
}

IMP sf_class_cached_dealloc_imp(Class cls) {
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    return meta != NULL ? meta->dealloc_imp : NULL;
}

IMP sf_class_cached_alloc_imp(Class cls) {
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    return meta != NULL ? meta->alloc_imp : NULL;
}

IMP sf_class_cached_init_imp(Class cls) {
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    return meta != NULL ? meta->init_imp : NULL;
}

void sf_register_builtin_class_cache(void) {
    static struct sf_objc_selector dealloc_sel_data = {"dealloc", "v16@0:8"};
    static struct sf_objc_selector alloc_sel_data = {"allocWithAllocator:", "@24@0:8^v16"};
    static struct sf_objc_selector init_sel_data = {"init", "@16@0:8"};

    g_dealloc_sel = sf_intern_selector(&dealloc_sel_data);
    g_alloc_sel = sf_intern_selector(&alloc_sel_data);
    g_init_sel = sf_intern_selector(&init_sel_data);
    g_object_class = (Class)sf_class_from_name("Object");
}

Class sf_cached_class_object(void) {
    return g_object_class;
}

const char *sf_class_name_of_object(id obj) {
    Class cls = sf_object_class(obj);
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL || c->name == NULL) {
        return "(null)";
    }
    return c->name;
}

#if SF_RUNTIME_REFLECTION

static Method class_get_method_impl(Class cls, SEL sel, int include_super) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    while (c != NULL) {
        for (SFObjCMethodList_t *list = c->methods; list != NULL; list = list->next) {
            for (int32_t i = 0; i < list->count; ++i) {
                SFObjCMethod_t *m = &list->methods[i];
                if (m->selector == sel || sf_selector_equal(m->selector, sel)) {
                    return (Method)(void *)m;
                }
            }
        }
        c = include_super ? sf_next_superclass(c) : NULL;
    }
    return NULL;
}

const char *class_getName(Class cls) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL) {
        return NULL;
    }
    return c->name;
}

Class class_getSuperclass(Class cls) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL) {
        return NULL;
    }
    return (Class)c->superclass;
}

Class object_getClass(id obj) {
    return sf_object_class(obj);
}

Class objc_getMetaClass(const char *name) {
    SFObjCClass_t *cls = sf_class_from_name(name);
    if (cls == NULL) {
        return NULL;
    }
    return (Class)cls->isa;
}

Class *objc_copyClassList(unsigned int *outCount) {
    if (outCount != NULL) {
        *outCount = 0;
    }

    sf_runtime_rwlock_rdlock(&g_class_map_lock);

    size_t cap = 16;
    size_t count = 0;
    Class *list = (Class *)sf_runtime_test_malloc(cap * sizeof(Class));
    if (list == NULL) {
        sf_runtime_rwlock_unlock(&g_class_map_lock);
        return NULL;
    }

    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        if (slot->name == NULL || slot->cls == NULL) {
            continue;
        }

        Class cls = (Class)slot->cls;
        int duplicate = 0;
        for (size_t j = 0; j < count; ++j) {
            if (list[j] == cls) {
                duplicate = 1;
                break;
            }
        }
        if (duplicate) {
            continue;
        }

        if (count == cap) {
            size_t next_cap = cap * 2;
            Class *next = (Class *)sf_runtime_test_realloc((void *)list, next_cap * sizeof(Class));
            if (next == NULL) {
                free((void *)list);
                sf_runtime_rwlock_unlock(&g_class_map_lock);
                return NULL;
            }
            list = next;
            cap = next_cap;
        }
        list[count++] = cls;
    }

    sf_runtime_rwlock_unlock(&g_class_map_lock);

    if (outCount != NULL) {
        *outCount = (unsigned int)count;
    }
    if (count == 0) { free((void *)list); return NULL; }

    Class *exact = (Class *)sf_runtime_test_realloc((void *)list, count * sizeof(Class));
    return exact ? exact : list;
}

Method class_getInstanceMethod(Class cls, SEL sel) {
    return class_get_method_impl(cls, sel, 1);
}

Method class_getClassMethod(Class cls, SEL sel) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL || c->isa == NULL) {
        return NULL;
    }
    return class_get_method_impl((Class)c->isa, sel, 1);
}

Method *class_copyMethodList(Class cls, unsigned int *outCount) {
    if (outCount != NULL) {
        *outCount = 0;
    }

    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL) {
        return NULL;
    }

    size_t count = 0;
    for (SFObjCMethodList_t *list = c->methods; list != NULL; list = list->next) {
        if (list->count > 0) {
            count += (size_t)list->count;
        }
    }
    if (count == 0) {
        return NULL;
    }

    Method *arr = (Method *)sf_runtime_test_malloc(count * sizeof(Method));
    if (arr == NULL) {
        return NULL;
    }

    size_t idx = 0;
    for (SFObjCMethodList_t *list = c->methods; list != NULL; list = list->next) {
        for (int32_t i = 0; i < list->count; ++i) {
            arr[idx++] = (Method)(void *)&list->methods[i];
        }
    }

    if (outCount != NULL) {
        *outCount = (unsigned int)count;
    }
    return arr;
}

SEL method_getName(Method method) {
    SFObjCMethod_t *m = (SFObjCMethod_t *)(void *)method;
    if (m == NULL) {
        return NULL;
    }
    return m->selector;
}

IMP method_getImplementation(Method method) {
    SFObjCMethod_t *m = (SFObjCMethod_t *)(void *)method;
    if (m == NULL) {
        return NULL;
    }
    return m->imp;
}

const char *method_getTypeEncoding(Method method) {
    SFObjCMethod_t *m = (SFObjCMethod_t *)(void *)method;
    if (m == NULL) {
        return NULL;
    }
    return m->types;
}

Ivar class_getInstanceVariable(Class cls, const char *name) {
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    while (c != NULL) {
        SFObjCIvarList_t *list = (SFObjCIvarList_t *)c->ivars;
        if (list != NULL && list->count > 0) {
            size_t stride = (size_t)list->item_size;
            if (stride < sizeof(SFObjCIvar_t)) stride = sizeof(SFObjCIvar_t);
            unsigned char *cursor = (unsigned char *)list->ivars;
            for (uintptr_t i = 0; i < list->count; ++i, cursor += stride) {
                SFObjCIvar_t *ivar = (SFObjCIvar_t *)(void *)cursor;
                if (ivar->name != NULL && name != NULL && strcmp(ivar->name, name) == 0) {
                    return (Ivar)(void *)ivar;
                }
            }
        }
        c = sf_next_superclass(c);
    }
    return NULL;
}

Ivar *class_copyIvarList(Class cls, unsigned int *outCount) {
    if (outCount != NULL) {
        *outCount = 0;
    }

    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL) {
        return NULL;
    }

    SFObjCIvarList_t *list = (SFObjCIvarList_t *)c->ivars;
    if (list == NULL || list->count == 0) return NULL;

    size_t count = (size_t)list->count;
    Ivar *arr = (Ivar *)sf_runtime_test_malloc(count * sizeof(Ivar));
    if (arr == NULL) {
        return NULL;
    }

    size_t stride = (size_t)list->item_size;
    if (stride < sizeof(SFObjCIvar_t)) stride = sizeof(SFObjCIvar_t);

    unsigned char *cursor = (unsigned char *)list->ivars;
    for (uintptr_t i = 0; i < list->count; ++i) {
        arr[i] = (Ivar)(void *)cursor;
        cursor += stride;
    }

    if (outCount != NULL) {
        *outCount = (unsigned int)count;
    }
    return arr;
}

const char *ivar_getName(Ivar ivar) {
    SFObjCIvar_t *v = (SFObjCIvar_t *)(void *)ivar;
    if (v == NULL) {
        return NULL;
    }
    return v->name;
}

const char *ivar_getTypeEncoding(Ivar ivar) {
    SFObjCIvar_t *v = (SFObjCIvar_t *)(void *)ivar;
    if (v == NULL) {
        return NULL;
    }
    return v->type;
}

ptrdiff_t ivar_getOffset(Ivar ivar) {
    SFObjCIvar_t *v = (SFObjCIvar_t *)(void *)ivar;
    if (v == NULL || v->offset == NULL) {
        return (ptrdiff_t)0;
    }
    return (ptrdiff_t)(*v->offset);
}

const char *sel_getName(SEL sel) {
    if (sel == NULL) {
        return NULL;
    }
    return sel->name;
}

SEL sel_registerName(const char *name) {
    return intern_selector_name_types(name, NULL);
}

int sel_isEqual(SEL lhs, SEL rhs) {
    return sf_selector_equal(lhs, rhs);
}

#endif

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
