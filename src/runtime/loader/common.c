#include "runtime/internal.h"
#include "runtime/loader/common.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

typedef struct SFClassEntry {
    const char *name;
    SFObjCClass_t *cls;
} SFClassEntry_t;

typedef struct SFClassMetaEntry {
    Class cls;
    const char *name;
    SFObjCMethodList_t *methods;
    SFObjCClass_t *superclass;
    void *ivars;
    IMP dealloc_imp;
    IMP alloc_imp;
    IMP init_imp;
    IMP cxx_destruct_imp;
    uint32_t flags;
    uint32_t strong_ivar_count;
    uint32_t *strong_ivar_offsets;
} SFClassMetaEntry_t;

typedef struct SFValueSlot {
    Class declared_cls;
    uint32_t owner_offset;
    uint32_t storage_offset;
    uint32_t storage_size;
    uint32_t reserved;
} SFValueSlot_t;

typedef struct SFValueSlotEntry {
    Class cls;
    const SFValueSlot_t *slots;
    size_t count;
} SFValueSlotEntry_t;

typedef struct SFSelectorEntry {
    char *name;
    char *types;
    SFFrozenSelector_t *frozen;
    struct SFSelectorEntry *next;
} SFSelectorEntry_t;

typedef struct SFSelectorRegion {
    SEL start;
    SEL stop;
    struct SFSelectorRegion *next;
} SFSelectorRegion_t;

#if SF_RUNTIME_VALIDATION && SF_RUNTIME_INLINE_VALUE_STORAGE
typedef struct SFInlineLiveEntry {
    id obj;
    SFObjHeader_t *hdr;
    struct SFInlineLiveEntry *next;
} SFInlineLiveEntry_t;
#endif

enum { SF_CLASS_MAP_CAPACITY = 2048 };
enum { SF_CLASS_META_CAPACITY = 4096 };
enum { SF_LIVE_OBJECT_BUCKETS = 8192U };
enum { SF_SELECTOR_BUCKETS = 256U };

static SFClassEntry_t g_class_map[SF_CLASS_MAP_CAPACITY];
static SFClassMetaEntry_t g_class_meta[SF_CLASS_META_CAPACITY];
static SFValueSlotEntry_t g_value_slot_map[SF_CLASS_MAP_CAPACITY];
static SFObjCClass_t *g_layout_fixed_map[SF_CLASS_MAP_CAPACITY];
static SFObjCClass_t *g_layout_active_stack[SF_CLASS_MAP_CAPACITY];
static size_t g_layout_active_count;
#if SF_RUNTIME_VALIDATION
static SFRuntimeRwlock_t g_live_object_lock = SF_RUNTIME_RWLOCK_INITIALIZER;
static SFObjHeader_t *g_live_object_buckets[SF_LIVE_OBJECT_BUCKETS];
#if SF_RUNTIME_INLINE_VALUE_STORAGE
static SFInlineLiveEntry_t *g_inline_live_buckets[SF_LIVE_OBJECT_BUCKETS];
#endif
#endif
static SFSelectorEntry_t *g_selector_table[SF_SELECTOR_BUCKETS];
static SFSelectorRegion_t *g_selector_regions;
static SFFrozenSelector_t **g_selectors_by_slot;
static size_t g_selector_count;
static size_t g_selector_capacity;

static Class g_object_class;
static Class g_value_object_class;
static Class g_nsconstantstring_class;
static Class g_nxconstantstring_class;
static SEL g_dealloc_sel;
static SEL g_alloc_sel;
static SEL g_init_sel;
static SEL g_forwarding_target_sel;
static SEL g_cxx_destruct_sel;
#if SF_RUNTIME_TAGGED_POINTERS
static SEL g_tagged_pointer_slot_sel;
Class _Nullable g_tagged_pointer_slot_classes[8];
static uint8_t g_tagged_pointer_slot_conflicts[8];
#endif
static IMP g_object_dealloc_imp;

enum {
    SF_CLASS_META_FLAG_HAS_OBJECT_IVARS = 1U << 0U,
    SF_CLASS_META_FLAG_TRIVIAL_RELEASE = 1U << 1U,
};

#if SF_RUNTIME_TAGGED_POINTERS
enum {
    SF_TAGGED_POINTER_SLOT_BITS = 3U,
    SF_TAGGED_POINTER_SLOT_MASK = (1U << SF_TAGGED_POINTER_SLOT_BITS) - 1U,
    SF_TAGGED_POINTER_SLOT_COUNT = 1U << SF_TAGGED_POINTER_SLOT_BITS,
};
#endif

static void sf_cache_class_meta(Class cls);
static IMP sf_lookup_method_imp_exact(Class cls, SEL sel);
static SFClassMetaEntry_t *sf_class_meta_for(Class cls);
static int sf_class_is_subclass_of_unlocked(Class cls, Class expected_super);
static size_t align_up(size_t value, size_t align);
static void sf_reset_class_caches_unlocked(void);
static SFSelectorEntry_t *sf_selector_entry_for_name_unlocked(const char *name);
static SFSelectorEntry_t *sf_selector_entry_insert_unlocked(const char *name, const char *types);
static void sf_collect_runtime_selectors_unlocked(void);
static void sf_rebuild_frozen_selectors_unlocked(void);
static SFFrozenSelector_t *sf_frozen_selector_for_name_unlocked(const char *name);
static void sf_build_class_dtable_unlocked(Class cls);

#if SF_RUNTIME_COMPACT_HEADERS
static uint32_t sf_class_meta_to_object_flags(const SFClassMetaEntry_t *meta)
{
    uint32_t flags = SF_OBJ_CLASS_FLAG_NONE;
    if (meta == NULL) {
        return flags;
    }
    if ((meta->flags & SF_CLASS_META_FLAG_TRIVIAL_RELEASE) != 0U) {
        flags |= SF_OBJ_CLASS_FLAG_TRIVIAL_RELEASE;
    }
    if ((meta->flags & SF_CLASS_META_FLAG_HAS_OBJECT_IVARS) != 0U) {
        flags |= SF_OBJ_CLASS_FLAG_HAS_OBJECT_IVARS;
    }
    if (meta->cxx_destruct_imp != NULL and not sf_dispatch_imp_is_nil(meta->cxx_destruct_imp)) {
        flags |= SF_OBJ_CLASS_FLAG_HAS_CXX_DESTRUCT;
    }
    return flags;
}
#endif

static int sf_class_supports_inline_value_storage_unlocked(Class cls)
{
    SFClassMetaEntry_t *meta = NULL;

    if (cls == NULL) {
        return 0;
    }
#if !SF_RUNTIME_INLINE_VALUE_STORAGE
    return 1;
#else
    meta = sf_class_meta_for(cls);
    if (meta == NULL) {
        return 0;
    }
    return (meta->flags & SF_CLASS_META_FLAG_TRIVIAL_RELEASE) != 0U and
           (meta->flags & SF_CLASS_META_FLAG_HAS_OBJECT_IVARS) == 0U;
#endif
}

static size_t sf_embedded_value_storage_size(size_t value_size)
{
#if SF_RUNTIME_INLINE_VALUE_STORAGE
    return align_up(sizeof(SFInlineValueHeader_t) + value_size, sizeof(void *));
#else
    return align_up(sizeof(SFObjHeader_t) + value_size, sizeof(void *));
#endif
}

static uint64_t hash_cstr(const char *s)
{
    return sf_hash_bytes(s, sf_cstr_len(s));
}

static uint64_t hash_ptr_local(const void *p)
{
    uintptr_t v = (uintptr_t)p;
    v ^= (v >> 33);
    v *= UINT64_C(0xff51afd7ed558ccd);
    v ^= (v >> 33);
    v *= UINT64_C(0xc4ceb9fe1a85ec53);
    v ^= (v >> 33);
    return (uint64_t)v;
}

#if SF_RUNTIME_VALIDATION
static size_t live_object_bucket_index(id obj)
{
    uint64_t hash = hash_ptr_local(obj);
    return (size_t)(hash & (SF_LIVE_OBJECT_BUCKETS - 1U));
}
#endif

static size_t selector_bucket_for_name_types(const char *name, const char *types)
{
    uint64_t hash = hash_cstr(name);
    (void)types;
    return (size_t)(hash & (SF_SELECTOR_BUCKETS - 1U));
}

static int cstr_equal_nullable(const char *lhs, const char *rhs)
{
    if (lhs == rhs) {
        return 1;
    }
    if (lhs == NULL or rhs == NULL) {
        return 0;
    }
    return strcmp(lhs, rhs) == 0;
}

static char *copy_cstr_nullable(const char *value)
{
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

static SFSelectorEntry_t *sf_selector_entry_for_name_unlocked(const char *name)
{
    if (name == NULL or name[0] == '\0') {
        return NULL;
    }

    size_t bucket = selector_bucket_for_name_types(name, NULL);
    for (SFSelectorEntry_t *it = g_selector_table[bucket]; it != NULL; it = it->next) {
        if (cstr_equal_nullable(it->name, name)) {
            return it;
        }
    }
    return NULL;
}

static SFSelectorEntry_t *sf_selector_entry_insert_unlocked(const char *name, const char *types)
{
    size_t bucket = selector_bucket_for_name_types(name, NULL);
    SFSelectorEntry_t *entry = sf_selector_entry_for_name_unlocked(name);
    char *owned_name = NULL;
    char *owned_types = NULL;

    if (entry != NULL) {
        if (entry->types == NULL and types != NULL) {
            owned_types = copy_cstr_nullable(types);
            if (owned_types != NULL) {
                entry->types = owned_types;
            }
        }
        return entry;
    }

    entry = (SFSelectorEntry_t *)sf_runtime_test_calloc(1, sizeof(*entry));
    if (entry == NULL) {
        return NULL;
    }

    owned_name = copy_cstr_nullable(name);
    if (owned_name == NULL) {
        free(entry);
        return NULL;
    }

    owned_types = copy_cstr_nullable(types);
    if (types != NULL and owned_types == NULL) {
        free(owned_name);
        free(entry);
        return NULL;
    }

    entry->name = owned_name;
    entry->types = owned_types;
    entry->next = g_selector_table[bucket];
    g_selector_table[bucket] = entry;
    return entry;
}

static SFFrozenSelector_t *sf_frozen_selector_for_name_unlocked(const char *name)
{
    SFSelectorEntry_t *entry = sf_selector_entry_for_name_unlocked(name);
    return entry != NULL ? entry->frozen : NULL;
}

static void sf_collect_runtime_selectors_unlocked(void)
{
    static const struct {
        const char *name;
        const char *types;
    } builtin_selectors[] = {
        {"dealloc", "v16@0:8"},
        {"allocWithAllocator:", "@24@0:8^v16"},
        {"init", "@16@0:8"},
        {"forwardingTargetForSelector:", "@24@0:8:16"},
        {".cxx_destruct", "v16@0:8"},
#if SF_RUNTIME_TAGGED_POINTERS
        {"taggedPointerSlot", NULL},
#endif
    };

    for (SFSelectorRegion_t *region = g_selector_regions; region != NULL; region = region->next) {
        for (SEL sel = region->start; sel < region->stop; ++sel) {
            if (sel != NULL and sel->name != NULL and sel->name[0] != '\0') {
                (void)sf_selector_entry_insert_unlocked(sel->name, sel->types);
            }
        }
    }

    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        SFObjCClass_t *cls = slot->cls;
        if (slot->name == NULL or cls == NULL) {
            continue;
        }

        for (SFObjCClass_t *cursor = cls; cursor != NULL; cursor = (cursor->isa == cursor) ? NULL : cursor->isa) {
            for (SFObjCMethodList_t *list = cursor->methods; list != NULL; list = list->next) {
                for (int32_t method_index = 0; method_index < list->count; ++method_index) {
                    SFObjCMethod_t *method = &list->methods[method_index];
                    const char *name = (method->selector != NULL) ? method->selector->name : NULL;
                    const char *types = (method->selector != NULL and method->selector->types != NULL) ? method->selector->types : method->types;
                    if (name != NULL and name[0] != '\0') {
                        (void)sf_selector_entry_insert_unlocked(name, types);
                    }
                }
            }
        }
    }

    for (size_t i = 0; i < sizeof(builtin_selectors) / sizeof(builtin_selectors[0]); ++i) {
        (void)sf_selector_entry_insert_unlocked(builtin_selectors[i].name, builtin_selectors[i].types);
    }
}

static void sf_rebuild_frozen_selectors_unlocked(void)
{
    SFFrozenSelector_t **old_selectors = g_selectors_by_slot;
    size_t old_selector_count = g_selector_count;
    size_t selector_count = 0U;
    SFFrozenSelector_t **new_selectors = NULL;

    sf_collect_runtime_selectors_unlocked();

    for (size_t bucket = 0; bucket < SF_SELECTOR_BUCKETS; ++bucket) {
        for (SFSelectorEntry_t *entry = g_selector_table[bucket]; entry != NULL; entry = entry->next) {
            entry->frozen = NULL;
            selector_count += 1U;
        }
    }

    if (selector_count > 0U) {
        new_selectors = (SFFrozenSelector_t **)sf_runtime_test_calloc(selector_count, sizeof(*new_selectors));
        if (new_selectors == NULL) {
            return;
        }
    }

    size_t slot_index = 0U;
    for (size_t bucket = 0; bucket < SF_SELECTOR_BUCKETS; ++bucket) {
        for (SFSelectorEntry_t *entry = g_selector_table[bucket]; entry != NULL; entry = entry->next) {
            size_t name_len = sf_cstr_len(entry->name);
            size_t types_len = sf_cstr_len(entry->types);
            size_t bytes = offsetof(SFFrozenSelector_t, storage) + name_len + 1U + ((entry->types != NULL) ? (types_len + 1U) : 0U);
            SFFrozenSelector_t *frozen = (SFFrozenSelector_t *)sf_runtime_test_calloc(1U, bytes);
            char *name_dst = NULL;

            if (frozen == NULL) {
                continue;
            }

            frozen->slot = (uint32_t)slot_index;
            name_dst = frozen->storage;
            memcpy(name_dst, entry->name, name_len + 1U);
            frozen->sel.name = name_dst;
            if (entry->types != NULL) {
                char *types_dst = name_dst + name_len + 1U;
                memcpy(types_dst, entry->types, types_len + 1U);
                frozen->sel.types = types_dst;
            }

            entry->frozen = frozen;
            new_selectors[slot_index++] = frozen;
        }
    }

    g_selectors_by_slot = new_selectors;
    g_selector_count = slot_index;
    g_selector_capacity = slot_index;

    for (SFSelectorRegion_t *region = g_selector_regions; region != NULL; region = region->next) {
        for (SEL sel = region->start; sel < region->stop; ++sel) {
            SFFrozenSelector_t *frozen = NULL;
            if (sel == NULL or sel->name == NULL or sel->name[0] == '\0') {
                continue;
            }
            frozen = sf_frozen_selector_for_name_unlocked(sel->name);
            if (frozen != NULL) {
                sel->name = frozen->sel.name;
                sel->types = frozen->sel.types;
            }
        }
    }

    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        SFObjCClass_t *cls = slot->cls;
        if (slot->name == NULL or cls == NULL) {
            continue;
        }

        for (SFObjCClass_t *cursor = cls; cursor != NULL; cursor = (cursor->isa == cursor) ? NULL : cursor->isa) {
            for (SFObjCMethodList_t *list = cursor->methods; list != NULL; list = list->next) {
                for (int32_t method_index = 0; method_index < list->count; ++method_index) {
                    SFObjCMethod_t *method = &list->methods[method_index];
                    const char *name = (method->selector != NULL) ? method->selector->name : NULL;
                    SFFrozenSelector_t *frozen = NULL;
                    if (name == NULL or name[0] == '\0') {
                        continue;
                    }
                    frozen = sf_frozen_selector_for_name_unlocked(name);
                    if (frozen != NULL) {
                        method->selector = (SEL)(void *)&frozen->sel;
                        method->types = frozen->sel.types;
                    }
                }
            }
        }
    }

    if (old_selectors != NULL) {
        for (size_t i = 0; i < old_selector_count; ++i) {
            free(old_selectors[i]);
        }
        free(old_selectors);
    }
}

SEL sf_lookup_selector_named(const char *name)
{
    SFFrozenSelector_t *frozen = sf_frozen_selector_for_name_unlocked(name);
    return frozen != NULL ? (SEL)(void *)&frozen->sel : NULL;
}

SEL sf_loader_intern_selector_name_types(const char *name, const char *types)
{
    SFSelectorEntry_t *entry = NULL;
    if (name == NULL or name[0] == '\0') {
        return NULL;
    }
    entry = sf_selector_entry_insert_unlocked(name, types);
    return (entry != NULL and entry->frozen != NULL) ? (SEL)(void *)&entry->frozen->sel : NULL;
}

SEL sf_intern_selector(SEL sel)
{
    SEL interned = NULL;
    if (sel == NULL or sel->name == NULL or sel->name[0] == '\0') {
        return NULL;
    }
    interned = sf_lookup_selector_named(sel->name);
    if (interned != NULL) {
        sel->name = interned->name;
        sel->types = interned->types;
        return interned;
    }
    (void)sf_selector_entry_insert_unlocked(sel->name, sel->types);
    return sel;
}

void sf_loader_register_selector_region(void *start, void *stop)
{
    SFSelectorRegion_t *region = NULL;
    if (start == NULL or stop == NULL or stop <= start) {
        return;
    }

    region = (SFSelectorRegion_t *)sf_runtime_test_calloc(1U, sizeof(*region));
    if (region == NULL) {
        return;
    }
    region->start = (SEL)start;
    region->stop = (SEL)stop;
    region->next = g_selector_regions;
    g_selector_regions = region;

    for (SEL sel = region->start; sel < region->stop; ++sel) {
        if (sel != NULL and sel->name != NULL and sel->name[0] != '\0') {
            (void)sf_selector_entry_insert_unlocked(sel->name, sel->types);
        }
    }
}

uint32_t sf_selector_slot(SEL sel)
{
    const char *name = NULL;
    const SFFrozenSelector_t *frozen = NULL;

    if (sel == NULL) {
        return UINT32_MAX;
    }

    name = sf_selector_name(sel);
    if (name == NULL) {
        return UINT32_MAX;
    }
    frozen = (const SFFrozenSelector_t *)(const void *)(name - SF_FROZEN_SELECTOR_NAME_OFFSET);
    return frozen->slot;
}

size_t sf_runtime_selector_count(void)
{
    return g_selector_count;
}

static void sf_reset_class_caches_unlocked(void)
{
    memset(g_layout_fixed_map, 0, sizeof(g_layout_fixed_map));
    memset(g_layout_active_stack, 0, sizeof(g_layout_active_stack));
    memset(g_value_slot_map, 0, sizeof(g_value_slot_map));
    g_layout_active_count = 0U;

    for (size_t i = 0; i < SF_CLASS_META_CAPACITY; ++i) {
        free(g_class_meta[i].strong_ivar_offsets);
        memset(&g_class_meta[i], 0, sizeof(g_class_meta[i]));
    }

    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        SFObjCClass_t *cls = slot->cls;
        if (slot->name == NULL or cls == NULL or slot->name != cls->name) {
            continue;
        }
        free(cls->dtable);
        cls->dtable = NULL;
        if (cls->isa != NULL and cls->isa != cls) {
            free(cls->isa->dtable);
            cls->isa->dtable = NULL;
        }
    }

    g_object_dealloc_imp = NULL;
}

static SFClassMetaEntry_t *class_meta_slot_for(Class cls)
{
    if (cls == NULL) {
        return NULL;
    }

    uint64_t hash = hash_ptr_local(cls);
    for (size_t i = 0; i < SF_CLASS_META_CAPACITY; ++i) {
        size_t idx = (size_t)((hash + i) & (SF_CLASS_META_CAPACITY - 1U));
        SFClassMetaEntry_t *slot = &g_class_meta[idx];
        if (slot->cls == cls or slot->cls == NULL) {
            return slot;
        }
    }
    return NULL;
}

static SFValueSlotEntry_t *value_slot_entry_for_unlocked(Class cls)
{
    if (cls == NULL) {
        return NULL;
    }

    uint64_t hash = hash_ptr_local(cls);
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((hash + i) & (SF_CLASS_MAP_CAPACITY - 1U));
        SFValueSlotEntry_t *slot = &g_value_slot_map[idx];
        if (slot->cls == cls or slot->cls == NULL) {
            return slot;
        }
    }
    return NULL;
}

static const SFValueSlot_t *sf_value_slots_for_class(Class cls, size_t *count_out)
{
    if (count_out != NULL) {
        *count_out = 0;
    }

    SFValueSlotEntry_t *entry = value_slot_entry_for_unlocked(cls);
    if (entry == NULL or entry->cls != cls or entry->slots == NULL or entry->count == 0) {
        return NULL;
    }

    if (count_out != NULL) {
        *count_out = entry->count;
    }
    return entry->slots;
}

static void sf_set_value_slots_for_class_unlocked(Class cls, const SFValueSlot_t *slots, size_t count)
{
    SFValueSlotEntry_t *entry = value_slot_entry_for_unlocked(cls);
    if (entry == NULL) {
        return;
    }
    entry->cls = (count > 0 and slots != NULL) ? cls : NULL;
    entry->slots = (count > 0 and slots != NULL) ? slots : NULL;
    entry->count = (count > 0 and slots != NULL) ? count : 0;
}

static int layout_fixed_contains(SFObjCClass_t *cls)
{
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

static int layout_active_contains(SFObjCClass_t *cls)
{
    for (size_t i = 0; i < g_layout_active_count; ++i) {
        if (g_layout_active_stack[i] == cls) {
            return 1;
        }
    }
    return 0;
}

static int layout_active_push(SFObjCClass_t *cls)
{
    if (g_layout_active_count >= SF_CLASS_MAP_CAPACITY) {
        return 0;
    }
    g_layout_active_stack[g_layout_active_count++] = cls;
    return 1;
}

static void layout_active_pop(SFObjCClass_t *cls)
{
    if (g_layout_active_count == 0) {
        return;
    }
    if (g_layout_active_stack[g_layout_active_count - 1U] == cls) {
        g_layout_active_count -= 1U;
        return;
    }
    for (size_t i = g_layout_active_count; i > 0; --i) {
        if (g_layout_active_stack[i - 1U] == cls) {
            memmove((void *)&g_layout_active_stack[i - 1U], &g_layout_active_stack[i],
                    (g_layout_active_count - i) * sizeof(g_layout_active_stack[0]));
            g_layout_active_count -= 1U;
            return;
        }
    }
}

static SFObjCClass_t *sf_next_superclass(SFObjCClass_t *cls)
{
    if (cls == NULL or cls->superclass == cls) {
        return NULL;
    }
    return cls->superclass;
}

static void layout_fixed_insert(SFObjCClass_t *cls)
{
    uint64_t h = hash_ptr_local(cls);
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((h + i) % SF_CLASS_MAP_CAPACITY);
        SFObjCClass_t **slot = &g_layout_fixed_map[idx];
        if (*slot == cls)
            return;
        if (*slot == NULL) {
            *slot = cls;
            return;
        }
    }
}

static size_t align_up(size_t value, size_t align)
{
    if (align <= 1U)
        return value;
    size_t mask = align - 1U;
    return (value + mask) & ~mask;
}

static int sf_extract_object_class_name(const char *type, char *buf, size_t buf_size)
{
    if (type == NULL or buf == NULL or buf_size < 2U or type[0] != '@' or type[1] != '"') {
        return 0;
    }

    const char *name_start = type + 2;
    const char *name_end = strchr(name_start, '"');
    if (name_end == NULL or name_end == name_start) {
        return 0;
    }

    size_t len = (size_t)(name_end - name_start);
    if (len + 1U > buf_size) {
        return 0;
    }

    memcpy(buf, name_start, len);
    buf[len] = '\0';
    return 1;
}

static int sf_type_is_object_ivar(const char *type)
{
    if (type == NULL) {
        return 0;
    }
    while (*type == 'r' or *type == 'n' or *type == 'N' or *type == 'o' or *type == 'O' or
           *type == 'R' or *type == 'V') {
        ++type;
    }
    return (*type == '@' and type[1] != '?');
}

static size_t sf_count_object_ivars_in_list(SFObjCIvarList_t *list)
{
    if (list == NULL or list->count == 0U) {
        return 0U;
    }

    size_t count = 0U;
    size_t stride = (size_t)list->item_size;
    if (stride < sizeof(SFObjCIvar_t)) {
        stride = sizeof(SFObjCIvar_t);
    }

    unsigned char *cursor = (unsigned char *)list->ivars;
    for (uintptr_t i = 0; i < list->count; ++i, cursor += stride) {
        SFObjCIvar_t *ivar = (SFObjCIvar_t *)(void *)cursor;
        if (ivar->offset == NULL or *ivar->offset == INT32_MAX) {
            continue;
        }
        if (sf_type_is_object_ivar(ivar->type)) {
            count += 1U;
        }
    }
    return count;
}

static size_t sf_collect_object_ivar_offsets(SFObjCIvarList_t *list, uint32_t *offsets, size_t start_index)
{
    if (list == NULL or offsets == NULL or list->count == 0U) {
        return start_index;
    }

    size_t stride = (size_t)list->item_size;
    if (stride < sizeof(SFObjCIvar_t)) {
        stride = sizeof(SFObjCIvar_t);
    }

    unsigned char *cursor = (unsigned char *)list->ivars;
    size_t index = start_index;
    for (uintptr_t i = 0; i < list->count; ++i, cursor += stride) {
        SFObjCIvar_t *ivar = (SFObjCIvar_t *)(void *)cursor;
        if (ivar->offset == NULL or *ivar->offset == INT32_MAX) {
            continue;
        }
        if (not sf_type_is_object_ivar(ivar->type)) {
            continue;
        }
        offsets[index++] = (uint32_t)(*ivar->offset);
    }
    return index;
}

static int sf_class_is_subclass_of_unlocked(Class cls, Class expected_super)
{
    SFObjCClass_t *cursor = (SFObjCClass_t *)cls;
    while (cursor != NULL) {
        if ((Class)cursor == expected_super) {
            return 1;
        }
        cursor = sf_next_superclass(cursor);
    }
    return 0;
}

static int sf_class_is_value_object_unlocked(Class cls)
{
    if (cls == NULL) {
        return 0;
    }
    if (g_value_object_class == NULL) {
        g_value_object_class = (Class)sf_loader_class_lookup_unlocked("ValueObject");
    }
    if (g_value_object_class == NULL) {
        return 0;
    }
    return sf_class_is_subclass_of_unlocked(cls, g_value_object_class);
}

#if SF_RUNTIME_TAGGED_POINTERS
static IMP sf_lookup_method_imp_local(Class cls, SEL sel)
{
    return sf_lookup_dtable_imp(cls, sel);
}

static void sf_reset_tagged_pointer_classes_unlocked(void)
{
    memset(g_tagged_pointer_slot_classes, 0, sizeof(g_tagged_pointer_slot_classes));
    memset(g_tagged_pointer_slot_conflicts, 0, sizeof(g_tagged_pointer_slot_conflicts));
}

static void sf_register_tagged_pointer_class_unlocked(SFObjCClass_t *cls, const char *entry_name)
{
    if (cls == NULL or cls->isa == NULL or entry_name == NULL or cls->name == NULL) {
        return;
    }
    if (strcmp(entry_name, cls->name) != 0) {
        return;
    }
    if (g_object_class == NULL or not sf_class_is_subclass_of_unlocked((Class)cls, g_object_class) or
        sf_class_is_value_object_unlocked((Class)cls)) {
        return;
    }

    IMP slot_imp = sf_lookup_method_imp_local((Class)cls->isa, g_tagged_pointer_slot_sel);
    if (slot_imp == NULL) {
        return;
    }

    uintptr_t slot = 0U;
    slot = ((uintptr_t (*)(id, SEL))slot_imp)((id)cls, g_tagged_pointer_slot_sel);
    if (slot == 0U or slot >= SF_TAGGED_POINTER_SLOT_COUNT) {
        return;
    }
    if (g_tagged_pointer_slot_conflicts[slot] != 0U) {
        return;
    }
    if (g_tagged_pointer_slot_classes[slot] == NULL) {
        g_tagged_pointer_slot_classes[slot] = (Class)cls;
        return;
    }
    if (g_tagged_pointer_slot_classes[slot] != (Class)cls) {
        g_tagged_pointer_slot_classes[slot] = NULL;
        g_tagged_pointer_slot_conflicts[slot] = 1U;
    }
}

static void sf_rebuild_tagged_pointer_class_map_unlocked(void)
{
    sf_reset_tagged_pointer_classes_unlocked();
    if (g_tagged_pointer_slot_sel == NULL) {
        return;
    }

    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        if (slot->name == NULL or slot->cls == NULL) {
            continue;
        }
        sf_register_tagged_pointer_class_unlocked(slot->cls, slot->name);
    }
}
#endif

static IMP sf_object_dealloc_imp_unlocked(void)
{
    if (g_object_class == NULL) {
        g_object_class = (Class)sf_loader_class_lookup_unlocked("Object");
    }
    if (g_object_dealloc_imp == NULL and g_object_class != NULL and g_dealloc_sel != NULL) {
        g_object_dealloc_imp = sf_lookup_method_imp_exact(g_object_class, g_dealloc_sel);
    }
    return g_object_dealloc_imp;
}

static size_t sf_fix_class_layout(SFObjCClass_t *cls)
{
    if (cls == NULL)
        return sizeof(void *);
    if (layout_fixed_contains(cls)) {
        if (cls->instance_size > 0) {
            return (size_t)cls->instance_size;
        }
        return sizeof(void *);
    }
    if (layout_active_contains(cls)) {
        if (cls->instance_size > 0) {
            return (size_t)cls->instance_size;
        }
        return sizeof(void *);
    }
    if (not layout_active_push(cls)) {
        if (cls->instance_size > 0) {
            return (size_t)cls->instance_size;
        }
        return sizeof(void *);
    }

    size_t super_size = sizeof(void *);
    const SFValueSlot_t *super_slots = NULL;
    size_t super_slot_count = 0;
    if (cls->superclass != NULL and cls->superclass != cls) {
        super_size = sf_fix_class_layout(cls->superclass);
        super_slots = sf_value_slots_for_class((Class)cls->superclass, &super_slot_count);
    }
    if (super_size < sizeof(void *))
        super_size = sizeof(void *);

    size_t max_end = super_size;
    SFValueSlot_t *local_slots = NULL;
    size_t local_slot_count = 0;
    int disable_local_slots = 0;
    SFObjCIvarList_t *list = (SFObjCIvarList_t *)cls->ivars;
    if (list != NULL and list->count > 0) {
        size_t stride = (size_t)list->item_size;
        if (stride < sizeof(SFObjCIvar_t)) {
            stride = sizeof(SFObjCIvar_t);
        }

        unsigned char *cursor = (unsigned char *)list->ivars;
        for (uintptr_t i = 0; i < list->count; ++i) {
            SFObjCIvar_t *ivar = (SFObjCIvar_t *)(void *)cursor;
            int32_t adjusted_offset = 0;
            int32_t local_offset = 0;
            int has_local_offset = 0;
            int skip_size = 0;
            if (ivar->offset != NULL) {
                int64_t off = 0;
                has_local_offset = sf_loader_local_ivar_offset_unlocked(cls, (size_t)i, &local_offset);
                if (has_local_offset) {
                    off = (int64_t)local_offset + (int64_t)super_size;
                } else {
                    off = (int64_t)(*ivar->offset) + (int64_t)super_size;
                }
                if (off < 0) {
                    off = 0;
                } else if (off > INT32_MAX) {
                    off = INT32_MAX;
                }
                adjusted_offset = (int32_t)off;
                if (has_local_offset) {
                    sf_loader_sync_ivar_offset_unlocked(cls, (size_t)i, adjusted_offset);
                }
                *ivar->offset = adjusted_offset;
                if (adjusted_offset == INT32_MAX) {
                    skip_size = 1;
                }
            }
            size_t ivar_size = ivar->size ? (size_t)ivar->size : sizeof(void *);
            if (not skip_size) {
                size_t end = (size_t)adjusted_offset + ivar_size;
                if (end > max_end) {
                    max_end = end;
                }
            }
            if (not disable_local_slots and ivar->offset != NULL and adjusted_offset != INT32_MAX) {
                char class_name[256];
                if (sf_extract_object_class_name(ivar->type, class_name, sizeof(class_name))) {
                    Class value_cls = (Class)sf_loader_class_lookup_unlocked(class_name);
                    if (value_cls != NULL and sf_class_is_value_object_unlocked(value_cls) and
                        sf_class_supports_inline_value_storage_unlocked(value_cls) and
                        not layout_active_contains((SFObjCClass_t *)value_cls)) {
                        if (local_slots == NULL) {
                            local_slots = (SFValueSlot_t *)sf_runtime_test_calloc((size_t)list->count,
                                                                                  sizeof(*local_slots));
                            if (local_slots == NULL) {
                                disable_local_slots = 1;
                                cursor += stride;
                                continue;
                            }
                        }
                        size_t value_size = sf_fix_class_layout((SFObjCClass_t *)value_cls);
                        size_t slot_size = sf_embedded_value_storage_size(value_size);
                        if (slot_size <= UINT32_MAX) {
                            local_slots[local_slot_count].declared_cls = value_cls;
                            local_slots[local_slot_count].owner_offset = (uint32_t)adjusted_offset;
                            local_slots[local_slot_count].storage_size = (uint32_t)slot_size;
                            local_slots[local_slot_count].storage_offset = 0U;
                            local_slots[local_slot_count].reserved = 0U;
                            local_slot_count += 1U;
                        }
                    }
                }
            }
            cursor += stride;
        }
    }

    size_t visible_end = align_up(max_end, sizeof(void *));
    const SFValueSlot_t *final_slots = NULL;
    size_t final_slot_count = 0;
    size_t final_end = visible_end;

    if (local_slot_count > 0) {
        size_t slot_cursor = visible_end;
        for (size_t i = 0; i < local_slot_count; ++i) {
            slot_cursor = align_up(slot_cursor, sizeof(void *));
            local_slots[i].storage_offset = (uint32_t)slot_cursor;
            slot_cursor += (size_t)local_slots[i].storage_size;
        }
        slot_cursor = align_up(slot_cursor, sizeof(void *));

        if (super_slot_count > 0) {
            size_t merged_count = super_slot_count + local_slot_count;
            SFValueSlot_t *merged = (SFValueSlot_t *)sf_runtime_test_calloc(merged_count, sizeof(*merged));
            if (merged != NULL) {
                memcpy(merged, super_slots, super_slot_count * sizeof(*merged));
                memcpy(merged + super_slot_count, local_slots, local_slot_count * sizeof(*merged));
                final_slots = merged;
                final_slot_count = merged_count;
                final_end = slot_cursor;
            } else {
                final_slots = super_slots;
                final_slot_count = super_slot_count;
            }
            free(local_slots);
            local_slots = NULL;
        } else {
            final_slots = local_slots;
            final_slot_count = local_slot_count;
            final_end = slot_cursor;
        }
    } else {
        free(local_slots);
        local_slots = NULL;
        final_slots = super_slots;
        final_slot_count = super_slot_count;
    }

    max_end = final_end;
#if defined(_WIN32)
    if (max_end > (size_t)LONG_MAX) {
        max_end = (size_t)LONG_MAX;
    }
#endif
    if (max_end < sizeof(void *))
        max_end = sizeof(void *);
    cls->instance_size = (long)max_end;
    sf_set_value_slots_for_class_unlocked((Class)cls, final_slots, final_slot_count);
    layout_fixed_insert(cls);
    layout_active_pop(cls);
    return max_end;
}

static void sf_canonicalize_method_selectors(SFObjCClass_t *cls)
{
    if (cls == NULL) {
        return;
    }

    for (SFObjCMethodList_t *list = cls->methods; list != NULL; list = list->next) {
        for (int32_t i = 0; i < list->count; ++i) {
            SFObjCMethod_t *method = &list->methods[i];
            SEL canonical = NULL;
            if (method->selector != NULL and method->selector->name != NULL) {
                canonical = sf_lookup_selector_named(method->selector->name);
            }
            method->selector = canonical;
            if (canonical != NULL) {
                method->types = canonical->types;
            }
        }
    }
}

static void sf_build_class_dtable_unlocked(Class cls)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    IMP *dtable = NULL;

    if (c == NULL or c->dtable != NULL or g_selector_count == 0U) {
        return;
    }

    if (c->superclass != NULL and c->superclass != c) {
        sf_build_class_dtable_unlocked((Class)c->superclass);
    }

    dtable = (IMP *)sf_runtime_test_calloc(g_selector_count, sizeof(*dtable));
    if (dtable == NULL) {
        return;
    }

    if (c->superclass != NULL and c->superclass != c and c->superclass->dtable != NULL) {
        memcpy(dtable, c->superclass->dtable, g_selector_count * sizeof(*dtable));
    }

    for (SFObjCMethodList_t *list = c->methods; list != NULL; list = list->next) {
        for (int32_t i = 0; i < list->count; ++i) {
            SFObjCMethod_t *method = &list->methods[i];
            uint32_t slot = 0U;
            if (method->selector == NULL) {
                continue;
            }
            slot = sf_selector_slot(method->selector);
            if ((size_t)slot < g_selector_count) {
                dtable[slot] = method->imp;
            }
        }
    }

    c->dtable = dtable;
}

static void class_map_insert_unlocked(const char *name, SFObjCClass_t *cls)
{
    uint64_t h = hash_cstr(name);
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((h + i) % SF_CLASS_MAP_CAPACITY);
        SFClassEntry_t *slot = &g_class_map[idx];
        if (slot->name == NULL or strcmp(slot->name, name) == 0) {
            slot->name = name;
            slot->cls = cls;
            return;
        }
    }
}

SFObjCClass_t *sf_loader_class_lookup_unlocked(const char *name)
{
    if (name == NULL) {
        return NULL;
    }
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

SFObjCClass_t *sf_class_from_name(const char *name)
{
    if (name == NULL) {
        return NULL;
    }
    return sf_loader_class_lookup_unlocked(name);
}

void sf_register_classes(SFObjCClass_t **start, SFObjCClass_t **stop)
{
    if (start == NULL or stop == NULL or stop <= start) {
        return;
    }

    for (SFObjCClass_t **it = start; it < stop; ++it) {
        SFObjCClass_t *cls = *it;
        if (cls == NULL or cls->name == NULL or cls->name[0] == '\0') {
            continue;
        }
        class_map_insert_unlocked(cls->name, cls);
    }
}

void sf_loader_register_class_aliases(SFObjCAliasEntry_t *start, SFObjCAliasEntry_t *stop)
{
    if (start == NULL or stop == NULL or stop <= start)
        return;

    for (SFObjCAliasEntry_t *it = start; it < stop; ++it) {
        if (it->alias_name == NULL or it->class_ref == NULL) {
            continue;
        }
        Class cls = *(it->class_ref);
        if (cls == NULL) {
            continue;
        }
        class_map_insert_unlocked(it->alias_name, (SFObjCClass_t *)cls);
    }
}

void sf_finalize_registered_classes(void)
{
    sf_loader_prepare_registered_classes_unlocked();
    sf_reset_class_caches_unlocked();
    sf_rebuild_frozen_selectors_unlocked();
    g_dealloc_sel = sf_lookup_selector_named("dealloc");
    g_alloc_sel = sf_lookup_selector_named("allocWithAllocator:");
    g_init_sel = sf_lookup_selector_named("init");
    g_forwarding_target_sel = sf_lookup_selector_named("forwardingTargetForSelector:");
    g_cxx_destruct_sel = sf_lookup_selector_named(".cxx_destruct");
#if SF_RUNTIME_TAGGED_POINTERS
    g_tagged_pointer_slot_sel = sf_lookup_selector_named("taggedPointerSlot");
#endif
    g_object_class = (Class)sf_loader_class_lookup_unlocked("Object");
    g_value_object_class = (Class)sf_loader_class_lookup_unlocked("ValueObject");
    g_nsconstantstring_class = (Class)sf_loader_class_lookup_unlocked("NSConstantString");
    g_nxconstantstring_class = (Class)sf_loader_class_lookup_unlocked("NXConstantString");
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        SFObjCClass_t *cls = slot->cls;
        if (slot->name == NULL or cls == NULL or cls->isa == NULL) {
            continue;
        }
        sf_fix_class_layout(cls);
        sf_canonicalize_method_selectors(cls);
        sf_canonicalize_method_selectors(cls->isa);
        if (cls->superclass != NULL and cls->superclass->isa != NULL) {
            cls->isa->superclass = cls->superclass->isa;
        } else {
            cls->isa->superclass = cls;
        }
    }
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        SFObjCClass_t *cls = slot->cls;
        if (slot->name == NULL or cls == NULL or cls->isa == NULL) {
            continue;
        }
        sf_build_class_dtable_unlocked((Class)cls);
        sf_build_class_dtable_unlocked((Class)cls->isa);
    }
    g_object_dealloc_imp = sf_object_dealloc_imp_unlocked();
    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        SFObjCClass_t *cls = slot->cls;
        if (slot->name == NULL or cls == NULL or cls->isa == NULL) {
            continue;
        }
        sf_cache_class_meta((Class)cls);
        sf_cache_class_meta((Class)cls->isa);
    }
#if SF_RUNTIME_TAGGED_POINTERS
    sf_rebuild_tagged_pointer_class_map_unlocked();
#endif

    sf_register_builtin_class_cache();
}

Class objc_lookup_class(const char *name)
{
    return (Class)sf_class_from_name(name);
}

Class objc_get_class(const char *name)
{
    return (Class)sf_class_from_name(name);
}

id objc_getClass(const char *name)
{
    return (id)sf_class_from_name(name);
}

size_t class_getInstanceSize(Class cls)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    size_t size = 0U;

    if (c == NULL) {
        return sizeof(void *);
    }

    size = (c->instance_size > 0) ? (size_t)c->instance_size : sizeof(void *);

    if (size < sizeof(void *))
        return sizeof(void *);
    return size;
}

size_t sf_class_instance_size_fast(Class cls)
{
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

int sf_object_is_heap(id obj)
{
    SFObjHeader_t *hdr = NULL;

    if (obj == NULL) {
        return 0;
    }
#if SF_RUNTIME_TAGGED_POINTERS
    if (sf_is_tagged_pointer(obj)) {
        return 0;
    }
#endif
    hdr = sf_header_from_object(obj);
    return hdr != NULL and (hdr->state == SF_OBJ_STATE_LIVE or (hdr->flags & SF_OBJ_FLAG_IMMORTAL) != 0U);
}

Class sf_object_class(id obj)
{
    if (obj == NULL) {
        return NULL;
    }
#if SF_RUNTIME_TAGGED_POINTERS
    if (sf_is_tagged_pointer(obj)) {
        return sf_tagged_pointer_class(obj);
    }
#endif
    return *(Class *)obj;
}

void sf_register_live_object_header(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return;
    }
#if SF_RUNTIME_VALIDATION
    id obj = sf_header_object(hdr);
    size_t bucket = live_object_bucket_index(obj);

    sf_runtime_rwlock_wrlock(&g_live_object_lock);
#if SF_RUNTIME_INLINE_VALUE_STORAGE
    if (sf_header_is_inline_value_prefix(hdr)) {
        SFInlineLiveEntry_t *entry = (SFInlineLiveEntry_t *)sf_runtime_test_calloc(1U, sizeof(*entry));
        if (entry != NULL) {
            entry->obj = obj;
            entry->hdr = hdr;
            entry->next = g_inline_live_buckets[bucket];
            g_inline_live_buckets[bucket] = entry;
        }
        sf_runtime_rwlock_unlock(&g_live_object_lock);
        return;
    }
#endif
    sf_header_set_live_next(hdr, g_live_object_buckets[bucket]);
    g_live_object_buckets[bucket] = hdr;
    sf_runtime_rwlock_unlock(&g_live_object_lock);
#else
    (void)hdr;
#endif
}

void sf_unregister_live_object_header(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return;
    }
#if SF_RUNTIME_VALIDATION
    id obj = sf_header_object(hdr);
    size_t bucket = live_object_bucket_index(obj);

    sf_runtime_rwlock_wrlock(&g_live_object_lock);
#if SF_RUNTIME_INLINE_VALUE_STORAGE
    if (sf_header_is_inline_value_prefix(hdr)) {
        SFInlineLiveEntry_t *current = g_inline_live_buckets[bucket];
        SFInlineLiveEntry_t *prev = NULL;
        while (current != NULL) {
            if (current->hdr == hdr) {
                if (prev == NULL) {
                    g_inline_live_buckets[bucket] = current->next;
                } else {
                    prev->next = current->next;
                }
                free(current);
                break;
            }
            prev = current;
            current = current->next;
        }
        sf_runtime_rwlock_unlock(&g_live_object_lock);
        return;
    }
#endif
    SFObjHeader_t *current = g_live_object_buckets[bucket];
    SFObjHeader_t *prev = NULL;
    while (current != NULL) {
        if (current == hdr) {
            SFObjHeader_t *next = sf_header_live_next(hdr);
            if (prev == NULL) {
                g_live_object_buckets[bucket] = next;
            } else {
                sf_header_set_live_next(prev, next);
            }
            sf_header_set_live_next(hdr, NULL);
            break;
        }
        prev = current;
        current = sf_header_live_next(current);
    }
    sf_runtime_rwlock_unlock(&g_live_object_lock);
#else
    (void)hdr;
#endif
}

SFObjHeader_t *sf_header_from_object(id obj)
{
    if (obj == NULL) {
        return NULL;
    }
#if SF_RUNTIME_TAGGED_POINTERS
    if (sf_is_tagged_pointer(obj)) {
        return NULL;
    }
#endif
#if SF_RUNTIME_VALIDATION
    size_t bucket = live_object_bucket_index(obj);

    sf_runtime_rwlock_rdlock(&g_live_object_lock);
    SFObjHeader_t *hdr = g_live_object_buckets[bucket];
    while (hdr != NULL) {
        if ((id)(hdr + 1) == obj) {
            sf_runtime_rwlock_unlock(&g_live_object_lock);
            return hdr;
        }
        hdr = sf_header_live_next(hdr);
    }
#if SF_RUNTIME_INLINE_VALUE_STORAGE
    SFInlineLiveEntry_t *inline_entry = g_inline_live_buckets[bucket];
    while (inline_entry != NULL) {
        if (inline_entry->obj == obj) {
            sf_runtime_rwlock_unlock(&g_live_object_lock);
            return inline_entry->hdr;
        }
        inline_entry = inline_entry->next;
    }
#endif
    sf_runtime_rwlock_unlock(&g_live_object_lock);
    return NULL;
#else
#if SF_RUNTIME_COMPACT_HEADERS && SF_RUNTIME_INLINE_VALUE_STORAGE
    uintptr_t tagged_parent = *((uintptr_t *)(void *)((unsigned char *)(void *)obj - sizeof(uintptr_t)));
    if ((tagged_parent & (uintptr_t)1U) != 0U) {
        SFInlineValueHeader_t *inline_hdr =
            (SFInlineValueHeader_t *)(void *)((unsigned char *)(void *)obj - sizeof(SFInlineValueHeader_t));
        if ((inline_hdr->flags & SF_OBJ_FLAG_INLINE_VALUE) != 0U) {
            return (SFObjHeader_t *)(void *)inline_hdr;
        }
    }
#endif
    return ((SFObjHeader_t *)obj) - 1;
#endif
}

size_t sf_object_allocation_size_for_object(id obj)
{
    SFObjHeader_t *hdr = sf_header_from_object(obj);
    if (hdr != NULL and hdr->alloc_size != 0U) {
        return (size_t)hdr->alloc_size;
    }
    return sizeof(SFObjHeader_t) + sf_class_instance_size_fast(sf_object_class(obj));
}

static size_t sf_object_total_size(Class cls, size_t *align_out)
{
    size_t instance_size = sf_class_instance_size_fast(cls);
    size_t align = sizeof(void *);
    if (align_out != NULL) {
        *align_out = align;
    }
    return sizeof(SFObjHeader_t) + instance_size;
}

static SFObjHeader_t *sf_init_allocated_header(void *raw, size_t total_size, SFAllocator_t *allocator)
{
    memset(raw, 0, total_size);

    SFObjHeader_t *hdr = (SFObjHeader_t *)raw;
#if SF_RUNTIME_VALIDATION
    hdr->magic = SF_OBJ_HEADER_MAGIC;
#if !SF_RUNTIME_COMPACT_HEADERS
    hdr->live_next = NULL;
#endif
#endif
    hdr->refcount = 1;
    hdr->state = SF_OBJ_STATE_LIVE;
    hdr->flags = SF_OBJ_FLAG_NONE;
    hdr->alloc_size = (uint32_t)total_size;
#if SF_RUNTIME_COMPACT_HEADERS
    hdr->class_flags = 0U;
    hdr->aux_flags = 0U;
    hdr->cold = NULL;
    (void)sf_header_set_allocator(hdr, allocator);
#else
    hdr->allocator = allocator;
#endif
    return hdr;
}

static id sf_finish_object_alloc(Class cls, SFObjHeader_t *hdr)
{
#if SF_RUNTIME_COMPACT_HEADERS
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    hdr->class_flags = sf_class_meta_to_object_flags(meta);
#endif
    id obj = sf_header_object(hdr);
    *(Class *)obj = cls;
    return obj;
}

static int sf_value_slot_is_compatible(const SFValueSlot_t *slot, Class cls, size_t required)
{
    if (slot == NULL or slot->declared_cls == NULL or cls == NULL) {
        return 0;
    }
    if (required > (size_t)slot->storage_size) {
        return 0;
    }
    if (slot->declared_cls == cls) {
        return 1;
    }
    return sf_class_is_subclass_of_unlocked(cls, slot->declared_cls);
}

static id sf_alloc_embedded_value_object(Class cls, id parent, SFAllocator_t *allocator)
{
    size_t slot_count = 0;
    const SFValueSlot_t *slots = sf_value_slots_for_class(sf_object_class(parent), &slot_count);
    size_t required = 0U;
    int use_inline_prefix = 0;
    if (slots == NULL or slot_count == 0) {
        return NULL;
    }
#if SF_RUNTIME_INLINE_VALUE_STORAGE
    if (not sf_class_supports_inline_value_storage_unlocked(cls)) {
        return NULL;
    }
    use_inline_prefix = 1;
#endif
    required = sf_embedded_value_storage_size(sf_class_instance_size_fast(cls));

    unsigned char *parent_bytes = (unsigned char *)(void *)parent;
    for (size_t i = 0; i < slot_count; ++i) {
        const SFValueSlot_t *slot = &slots[i];
        if (not sf_value_slot_is_compatible(slot, cls, required)) {
            continue;
        }

        id *owner_slot = (id *)(void *)(parent_bytes + slot->owner_offset);
        if (*owner_slot != NULL) {
            continue;
        }

        SFObjHeader_t *hdr = (SFObjHeader_t *)(void *)(parent_bytes + slot->storage_offset);
        if (hdr->state == SF_OBJ_STATE_LIVE) {
            continue;
        }

        if (use_inline_prefix) {
#if SF_RUNTIME_INLINE_VALUE_STORAGE
            SFInlineValueHeader_t *inline_hdr = (SFInlineValueHeader_t *)(void *)hdr;
            memset(inline_hdr, 0, sizeof(*inline_hdr));
#if SF_RUNTIME_VALIDATION
            inline_hdr->magic = SF_OBJ_HEADER_MAGIC;
#endif
            inline_hdr->refcount = 1U;
            inline_hdr->state = SF_OBJ_STATE_LIVE;
            inline_hdr->flags = SF_OBJ_FLAG_EMBEDDED | SF_OBJ_FLAG_INLINE_VALUE;
            inline_hdr->alloc_size = slot->storage_size;
            inline_hdr->reserved = slot->owner_offset;
            inline_hdr->class_flags = sf_class_meta_to_object_flags(sf_class_meta_for(cls));
            inline_hdr->tagged_parent = ((uintptr_t)parent) | (uintptr_t)1U;
#endif
        } else {
            hdr = sf_init_allocated_header((void *)hdr, (size_t)slot->storage_size, allocator);
            hdr->flags |= SF_OBJ_FLAG_EMBEDDED;
            hdr->reserved = slot->owner_offset;
            if (not sf_header_set_parent(hdr, parent)) {
                return NULL;
            }
        }

        id obj = sf_finish_object_alloc(cls, hdr);
        sf_register_live_object_header(hdr);
        *owner_slot = obj;
        return obj;
    }

    return NULL;
}

id sf_alloc_object(Class cls, SFAllocator_t *allocator)
{
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

id sf_alloc_object_with_parent(Class cls, id parent)
{
    if (parent == NULL) {
        return sf_alloc_object(cls, NULL);
    }

    SFObjHeader_t *parent_hdr = sf_header_from_object(parent);
    if (parent_hdr == NULL) {
        return NULL;
    }

    if (sf_class_is_value_object_unlocked(cls)) {
        SFAllocator_t *use_allocator = sf_header_allocator(parent_hdr);
        if (use_allocator == NULL) {
            use_allocator = sf_default_allocator();
        }
        if (parent_hdr->state != SF_OBJ_STATE_LIVE) {
            return NULL;
        }
        return sf_alloc_embedded_value_object(cls, parent, use_allocator);
    }

    SFObjHeader_t *root = sf_header_group_root(parent_hdr);
    size_t align = 0;
    size_t total_size = sf_object_total_size(cls, &align);
    void *raw = NULL;

    if (not sf_header_init_group_root(root)) {
        return NULL;
    }
    if (not sf_header_grouped(root)) {
        return NULL;
    }

    SFAllocator_t *use_allocator = sf_header_allocator(root);
    if (use_allocator == NULL) {
        use_allocator = sf_default_allocator();
    }
    SFRuntimeMutex_t *group_lock = sf_header_group_lock(root);
    if (group_lock == NULL) {
        return NULL;
    }

    sf_runtime_mutex_lock(group_lock);
    if (parent_hdr->state != SF_OBJ_STATE_LIVE or sf_header_group_dead(root) or
        sf_header_group_live_count(root) == 0U) {
        sf_runtime_mutex_unlock(group_lock);
        return NULL;
    }

    raw = use_allocator->alloc(use_allocator->ctx, total_size, align);
    if (raw == NULL) {
        sf_runtime_mutex_unlock(group_lock);
        return NULL;
    }

    SFObjHeader_t *hdr = sf_init_allocated_header(raw, total_size, use_allocator);
    if (not sf_header_set_parent(hdr, parent) or not sf_header_set_group_root(hdr, root) or not sf_header_set_group_next(hdr, sf_header_group_head(root)) or not sf_header_set_group_head(root, hdr) or not sf_header_set_group_live_count(root, sf_header_group_live_count(root) + 1U)) {
        sf_runtime_mutex_unlock(group_lock);
        sf_header_destroy_sidecar(hdr, 0);
        use_allocator->free(use_allocator->ctx, raw, total_size, align);
        return NULL;
    }
    sf_runtime_mutex_unlock(group_lock);
    sf_register_live_object_header(hdr);
    return sf_finish_object_alloc(cls, hdr);
}

size_t sf_cstr_len(const char *s)
{
    if (s == NULL) {
        return 0;
    }
    size_t n = 0;
    while (s[n] != '\0') {
        ++n;
    }
    return n;
}

uint64_t sf_hash_bytes(const void *data, size_t size)
{
    const unsigned char *p = (const unsigned char *)data;
    uint64_t h = UINT64_C(1469598103934665603);
    for (size_t i = 0; i < size; ++i) {
        h ^= (uint64_t)p[i];
        h *= UINT64_C(1099511628211);
    }
    return h;
}

uint64_t sf_hash_ptr(const void *p)
{
    uintptr_t v = (uintptr_t)p;
    v ^= (v >> 33);
    v *= UINT64_C(0xff51afd7ed558ccd);
    v ^= (v >> 33);
    v *= UINT64_C(0xc4ceb9fe1a85ec53);
    v ^= (v >> 33);
    return (uint64_t)v;
}

static IMP sf_lookup_method_imp_exact(Class cls, SEL sel)
{
    return sf_lookup_dtable_imp(cls, sel);
}

static void sf_cache_class_meta(Class cls)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    SFClassMetaEntry_t *slot = class_meta_slot_for(cls);
    SFClassMetaEntry_t *super_meta = NULL;
    size_t super_count = 0U;
    size_t local_count = 0U;
    size_t total_count = 0U;
    uint32_t *offsets = NULL;
    size_t copied = 0U;
    IMP base_dealloc_imp = NULL;
    if (slot == NULL or c == NULL) {
        return;
    }

    if (c->superclass != NULL and c->superclass != c) {
        super_meta = sf_class_meta_for((Class)c->superclass);
        if (super_meta != NULL) {
            super_count = (size_t)super_meta->strong_ivar_count;
        }
    }
    local_count = sf_count_object_ivars_in_list((SFObjCIvarList_t *)c->ivars);
    total_count = super_count + local_count;
    if (total_count > 0U) {
        offsets = (uint32_t *)sf_runtime_test_calloc(total_count, sizeof(*offsets));
        if (offsets != NULL) {
            if (super_meta != NULL and super_count > 0U and super_meta->strong_ivar_offsets != NULL) {
                memcpy(offsets, super_meta->strong_ivar_offsets, super_count * sizeof(*offsets));
                copied = super_count;
            }
            copied = sf_collect_object_ivar_offsets((SFObjCIvarList_t *)c->ivars, offsets, copied);
        }
    }

    free(slot->strong_ivar_offsets);
    slot->cls = cls;
    slot->name = c->name;
    slot->methods = c->methods;
    slot->superclass = c->superclass;
    slot->ivars = c->ivars;
    slot->dealloc_imp = (g_dealloc_sel != NULL) ? sf_lookup_method_imp_exact(cls, g_dealloc_sel) : NULL;
    slot->alloc_imp = (g_alloc_sel != NULL) ? sf_lookup_method_imp_exact(cls, g_alloc_sel) : NULL;
    slot->init_imp = (g_init_sel != NULL) ? sf_lookup_method_imp_exact(cls, g_init_sel) : NULL;
    slot->cxx_destruct_imp = (g_cxx_destruct_sel != NULL) ? sf_lookup_method_imp_exact(cls, g_cxx_destruct_sel) : NULL;
    slot->flags = 0U;
    slot->strong_ivar_count = (offsets != NULL) ? (uint32_t)copied : 0U;
    slot->strong_ivar_offsets = offsets;

    if (total_count > 0U) {
        slot->flags |= SF_CLASS_META_FLAG_HAS_OBJECT_IVARS;
    }

    base_dealloc_imp = sf_object_dealloc_imp_unlocked();
    if (total_count == 0U and (slot->cxx_destruct_imp == NULL or sf_dispatch_imp_is_nil(slot->cxx_destruct_imp)) and
        (slot->dealloc_imp == NULL or slot->dealloc_imp == base_dealloc_imp or sf_dispatch_imp_is_nil(slot->dealloc_imp))) {
        slot->flags |= SF_CLASS_META_FLAG_TRIVIAL_RELEASE;
    }
}

static SFClassMetaEntry_t *sf_class_meta_for(Class cls)
{
    SFClassMetaEntry_t *slot = class_meta_slot_for(cls);
    return (slot != NULL and slot->cls == cls) ? slot : NULL;
}

SEL sf_cached_selector_dealloc(void)
{
    return g_dealloc_sel;
}

SEL sf_cached_selector_alloc(void)
{
    return g_alloc_sel;
}

SEL sf_cached_selector_init(void)
{
    return g_init_sel;
}

SEL sf_cached_selector_forwarding_target(void)
{
    return g_forwarding_target_sel;
}

IMP sf_class_cached_dealloc_imp(Class cls)
{
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    return meta != NULL ? meta->dealloc_imp : NULL;
}

IMP sf_class_cached_alloc_imp(Class cls)
{
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    return meta != NULL ? meta->alloc_imp : NULL;
}

IMP sf_class_cached_init_imp(Class cls)
{
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    return meta != NULL ? meta->init_imp : NULL;
}

IMP sf_class_cached_cxx_destruct_imp(Class cls)
{
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    return meta != NULL ? meta->cxx_destruct_imp : NULL;
}

const uint32_t *sf_class_cached_object_ivar_offsets(Class cls, size_t *count_out)
{
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    if (count_out != NULL) {
        *count_out = (meta != NULL) ? (size_t)meta->strong_ivar_count : 0U;
    }
    return (meta != NULL) ? meta->strong_ivar_offsets : NULL;
}

int sf_class_has_trivial_release(Class cls)
{
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    return (meta != NULL and (meta->flags & SF_CLASS_META_FLAG_TRIVIAL_RELEASE) != 0U);
}

uint32_t sf_class_cached_object_flags(Class cls)
{
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_class_meta_to_object_flags(sf_class_meta_for(cls));
#else
    SFClassMetaEntry_t *meta = sf_class_meta_for(cls);
    uint32_t flags = 0U;
    if (meta == NULL) {
        return 0U;
    }
    if ((meta->flags & SF_CLASS_META_FLAG_TRIVIAL_RELEASE) != 0U) {
        flags |= 1U << 0U;
    }
    if ((meta->flags & SF_CLASS_META_FLAG_HAS_OBJECT_IVARS) != 0U) {
        flags |= 1U << 1U;
    }
    if (meta->cxx_destruct_imp != NULL and not sf_dispatch_imp_is_nil(meta->cxx_destruct_imp)) {
        flags |= 1U << 2U;
    }
    return flags;
#endif
}

int sf_class_is_constant_string(Class cls)
{
    return cls != NULL and (cls == g_nsconstantstring_class or cls == g_nxconstantstring_class);
}

void sf_register_builtin_class_cache(void)
{
    g_dealloc_sel = sf_lookup_selector_named("dealloc");
    g_alloc_sel = sf_lookup_selector_named("allocWithAllocator:");
    g_init_sel = sf_lookup_selector_named("init");
    g_forwarding_target_sel = sf_lookup_selector_named("forwardingTargetForSelector:");
    g_cxx_destruct_sel = sf_lookup_selector_named(".cxx_destruct");
    g_object_class = (Class)sf_class_from_name("Object");
    g_value_object_class = (Class)sf_class_from_name("ValueObject");
    g_nsconstantstring_class = (Class)sf_class_from_name("NSConstantString");
    g_nxconstantstring_class = (Class)sf_class_from_name("NXConstantString");
    g_object_dealloc_imp = (g_object_class != NULL and g_dealloc_sel != NULL) ? sf_lookup_method_imp_exact(g_object_class, g_dealloc_sel) : NULL;
}

Class sf_cached_class_object(void)
{
    return g_object_class;
}

const char *sf_class_name_of_object(id obj)
{
    Class cls = sf_object_class(obj);
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    const char *name = NULL;
    if (c == NULL or c->name == NULL) {
        return "(null)";
    }
    name = c->name;
    return name != NULL ? name : "(null)";
}

int sf_is_tagged_pointer(id obj)
{
#if SF_RUNTIME_TAGGED_POINTERS
    return obj != NULL and ((((uintptr_t)obj) & (uintptr_t)SF_TAGGED_POINTER_SLOT_MASK) != 0U);
#else
    (void)obj;
    return 0;
#endif
}

uintptr_t sf_tagged_pointer_slot(id obj)
{
#if SF_RUNTIME_TAGGED_POINTERS
    if (not sf_is_tagged_pointer(obj)) {
        return 0U;
    }
    return ((uintptr_t)obj) & (uintptr_t)SF_TAGGED_POINTER_SLOT_MASK;
#else
    (void)obj;
    return 0U;
#endif
}

uintptr_t sf_tagged_pointer_payload(id obj)
{
#if SF_RUNTIME_TAGGED_POINTERS
    if (not sf_is_tagged_pointer(obj)) {
        return 0U;
    }
    return ((uintptr_t)obj) >> SF_TAGGED_POINTER_SLOT_BITS;
#else
    (void)obj;
    return 0U;
#endif
}

Class sf_tagged_class_for_slot(uintptr_t slot)
{
#if SF_RUNTIME_TAGGED_POINTERS
    if (slot == 0U or slot >= SF_TAGGED_POINTER_SLOT_COUNT) {
        return NULL;
    }
    return g_tagged_pointer_slot_classes[slot];
#else
    (void)slot;
    return NULL;
#endif
}

Class sf_tagged_pointer_class(id obj)
{
    return sf_tagged_class_for_slot(sf_tagged_pointer_slot(obj));
}

id sf_make_tagged_pointer(Class cls, uintptr_t payload)
{
#if SF_RUNTIME_TAGGED_POINTERS
    if (cls == NULL or payload > (UINTPTR_MAX >> SF_TAGGED_POINTER_SLOT_BITS)) {
        return NULL;
    }

    for (uintptr_t slot = 1U; slot < SF_TAGGED_POINTER_SLOT_COUNT; ++slot) {
        if (g_tagged_pointer_slot_classes[slot] == cls) {
            return (id)(void *)((payload << SF_TAGGED_POINTER_SLOT_BITS) | slot);
        }
    }
    return NULL;
#else
    (void)cls;
    (void)payload;
    return NULL;
#endif
}

#if SF_RUNTIME_REFLECTION

static Method class_get_method_impl(Class cls, SEL sel, int include_super)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    while (c != NULL) {
        for (SFObjCMethodList_t *list = c->methods; list != NULL; list = list->next) {
            for (int32_t i = 0; i < list->count; ++i) {
                SFObjCMethod_t *m = &list->methods[i];
                if (m->selector != NULL and sel != NULL and sf_selector_slot(m->selector) == sf_selector_slot(sel)) {
                    return (Method)(void *)m;
                }
            }
        }
        c = include_super ? sf_next_superclass(c) : NULL;
    }
    return NULL;
}

const char *class_getName(Class cls)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL) {
        return NULL;
    }
    return c->name;
}

Class class_getSuperclass(Class cls)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL) {
        return NULL;
    }
    return (Class)c->superclass;
}

Class object_getClass(id obj)
{
    return sf_object_class(obj);
}

Class objc_getMetaClass(const char *name)
{
    SFObjCClass_t *cls = sf_class_from_name(name);
    if (cls == NULL) {
        return NULL;
    }
    return (Class)cls->isa;
}

Class *objc_copyClassList(unsigned int *outCount)
{
    if (outCount != NULL) {
        *outCount = 0;
    }

    size_t cap = 16;
    size_t count = 0;
    Class *list = (Class *)sf_runtime_test_malloc(cap * sizeof(Class));
    if (list == NULL) {
        return NULL;
    }

    for (size_t i = 0; i < SF_CLASS_MAP_CAPACITY; ++i) {
        SFClassEntry_t *slot = &g_class_map[i];
        if (slot->name == NULL or slot->cls == NULL) {
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
                return NULL;
            }
            list = next;
            cap = next_cap;
        }
        list[count++] = cls;
    }

    if (outCount != NULL) {
        *outCount = (unsigned int)count;
    }
    if (count == 0) {
        free((void *)list);
        return NULL;
    }

    Class *exact = (Class *)sf_runtime_test_realloc((void *)list, count * sizeof(Class));
    return exact ? exact : list;
}

Method class_getInstanceMethod(Class cls, SEL sel)
{
    return class_get_method_impl(cls, sel, 1);
}

Method class_getClassMethod(Class cls, SEL sel)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL or c->isa == NULL) {
        return NULL;
    }
    return class_get_method_impl((Class)c->isa, sel, 1);
}

Method *class_copyMethodList(Class cls, unsigned int *outCount)
{
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

SEL method_getName(Method method)
{
    SFObjCMethod_t *m = (SFObjCMethod_t *)(void *)method;
    if (m == NULL) {
        return NULL;
    }
    return m->selector;
}

IMP method_getImplementation(Method method)
{
    SFObjCMethod_t *m = (SFObjCMethod_t *)(void *)method;
    if (m == NULL) {
        return NULL;
    }
    return m->imp;
}

const char *method_getTypeEncoding(Method method)
{
    SFObjCMethod_t *m = (SFObjCMethod_t *)(void *)method;
    if (m == NULL) {
        return NULL;
    }
    return m->types;
}

Ivar class_getInstanceVariable(Class cls, const char *name)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    while (c != NULL) {
        SFObjCIvarList_t *list = (SFObjCIvarList_t *)c->ivars;
        if (list != NULL and list->count > 0) {
            size_t stride = (size_t)list->item_size;
            if (stride < sizeof(SFObjCIvar_t))
                stride = sizeof(SFObjCIvar_t);
            unsigned char *cursor = (unsigned char *)list->ivars;
            for (uintptr_t i = 0; i < list->count; ++i, cursor += stride) {
                SFObjCIvar_t *ivar = (SFObjCIvar_t *)(void *)cursor;
                if (ivar->name != NULL and name != NULL and strcmp(ivar->name, name) == 0) {
                    return (Ivar)(void *)ivar;
                }
            }
        }
        c = sf_next_superclass(c);
    }
    return NULL;
}

Ivar *class_copyIvarList(Class cls, unsigned int *outCount)
{
    if (outCount != NULL) {
        *outCount = 0;
    }

    SFObjCClass_t *c = (SFObjCClass_t *)cls;
    if (c == NULL) {
        return NULL;
    }

    SFObjCIvarList_t *list = (SFObjCIvarList_t *)c->ivars;
    if (list == NULL or list->count == 0)
        return NULL;

    size_t count = (size_t)list->count;
    Ivar *arr = (Ivar *)sf_runtime_test_malloc(count * sizeof(Ivar));
    if (arr == NULL) {
        return NULL;
    }

    size_t stride = (size_t)list->item_size;
    if (stride < sizeof(SFObjCIvar_t))
        stride = sizeof(SFObjCIvar_t);

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

const char *ivar_getName(Ivar ivar)
{
    SFObjCIvar_t *v = (SFObjCIvar_t *)(void *)ivar;
    if (v == NULL) {
        return NULL;
    }
    return v->name;
}

const char *ivar_getTypeEncoding(Ivar ivar)
{
    SFObjCIvar_t *v = (SFObjCIvar_t *)(void *)ivar;
    if (v == NULL) {
        return NULL;
    }
    return v->type;
}

ptrdiff_t ivar_getOffset(Ivar ivar)
{
    SFObjCIvar_t *v = (SFObjCIvar_t *)(void *)ivar;
    if (v == NULL or v->offset == NULL) {
        return (ptrdiff_t)0;
    }
    return (ptrdiff_t)(*v->offset);
}

const char *sel_getName(SEL sel)
{
    if (sel == NULL) {
        return NULL;
    }
    return sel->name;
}

SEL sel_registerName(const char *name)
{
    return sf_lookup_selector_named(name);
}

int sel_isEqual(SEL lhs, SEL rhs)
{
    return sf_selector_equal(lhs, rhs);
}

#endif
