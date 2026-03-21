#include "runtime/internal.h"
#include "runtime/loader/common.h"
#include "runtime/loader/objfw.h"

#include <stdlib.h>

typedef struct SFObjFWClassEntry {
    SFObjFWClass_t *cls;
    SFObjFWIvarList_t *compiler_ivars;
    const char *super_name;
    unsigned long state;
    size_t ivar_count;
    int32_t *local_ivar_offsets;
    int32_t *runtime_ivar_offsets;
} SFObjFWClassEntry_t;

// ObjFW normalization tracks both classes and metaclasses, so the generated JS
// surface needs substantially more than the raw class count during module load.
enum { SF_OBJFW_CLASS_MAP_CAPACITY = 4096U };

enum {
    SF_OBJFW_CLASS_STATE_NORMALIZED = 1UL << 0U,
    SF_OBJFW_CLASS_STATE_SUPERCLASS_RESOLVED = 1UL << 1U,
};

static SFObjFWClassEntry_t g_objfw_class_map[SF_OBJFW_CLASS_MAP_CAPACITY];

static SFObjFWClassEntry_t *sf_objfw_class_entry_lookup_unlocked(const SFObjFWClass_t *cls)
{
    if (cls == nullptr) {
        return nullptr;
    }

    uint64_t hash = sf_hash_ptr(cls);
    for (size_t i = 0; i < SF_OBJFW_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((hash + i) % SF_OBJFW_CLASS_MAP_CAPACITY);
        SFObjFWClassEntry_t *slot = &g_objfw_class_map[idx];
        if (slot->cls == cls) {
            return slot;
        }
        if (slot->cls == nullptr) {
            return nullptr;
        }
    }
    return nullptr;
}

static SFObjFWClassEntry_t *sf_objfw_class_entry_for_unlocked(SFObjFWClass_t *cls)
{
    if (cls == nullptr) {
        return nullptr;
    }

    uint64_t hash = sf_hash_ptr(cls);
    for (size_t i = 0; i < SF_OBJFW_CLASS_MAP_CAPACITY; ++i) {
        size_t idx = (size_t)((hash + i) % SF_OBJFW_CLASS_MAP_CAPACITY);
        SFObjFWClassEntry_t *slot = &g_objfw_class_map[idx];
        if (slot->cls == cls) {
            return slot;
        }
        if (slot->cls == nullptr) {
            slot->cls = cls;
            return slot;
        }
    }
    return nullptr;
}

static size_t sf_objfw_local_instance_size(const SFObjFWClass_t *cls)
{
    if (cls == nullptr) {
        return 0U;
    }
    if (cls->instance_size < 0) {
        return (size_t)(-cls->instance_size);
    }
    return (size_t)cls->instance_size;
}

static uint32_t sf_objfw_ivar_size(const SFObjFWClass_t *cls, const SFObjFWIvarList_t *ivars, int32_t index)
{
    if (cls == nullptr or ivars == nullptr or index < 0 or index >= ivars->count) {
        return 0U;
    }

    int32_t start = ivars->ivars[index].offset;
    int32_t end = (int32_t)sf_objfw_local_instance_size(cls);
    for (int32_t i = index + 1; i < ivars->count; ++i) {
        int32_t next = ivars->ivars[i].offset;
        if (next > start) {
            end = next;
            break;
        }
    }
    if (end <= start) {
        return 0U;
    }
    return (uint32_t)(end - start);
}

static size_t sf_objfw_ivar_count(const SFObjFWClassEntry_t *entry)
{
    if (entry == nullptr or entry->compiler_ivars == nullptr or entry->compiler_ivars->count <= 0) {
        return 0U;
    }
    return (size_t)entry->compiler_ivars->count;
}

static int sf_objfw_init_ivar_offset_storage_unlocked(SFObjFWClassEntry_t *entry)
{
    if (entry == nullptr or entry->cls == nullptr) {
        return 0;
    }
    if (entry->runtime_ivar_offsets != nullptr and entry->local_ivar_offsets != nullptr) {
        return 1;
    }

    size_t count = sf_objfw_ivar_count(entry);
    entry->ivar_count = count;
    if (count == 0U) {
        return 1;
    }

    if (entry->local_ivar_offsets == nullptr) {
        entry->local_ivar_offsets = (int32_t *)sf_runtime_test_calloc(count, sizeof(*entry->local_ivar_offsets));
        if (entry->local_ivar_offsets == nullptr) {
            return 0;
        }
    }
    if (entry->runtime_ivar_offsets == nullptr) {
        entry->runtime_ivar_offsets = (int32_t *)sf_runtime_test_calloc(count, sizeof(*entry->runtime_ivar_offsets));
        if (entry->runtime_ivar_offsets == nullptr) {
            return 0;
        }
    }

    for (size_t i = 0; i < count; ++i) {
        int32_t offset = entry->compiler_ivars->ivars[i].offset;
        entry->local_ivar_offsets[i] = offset;
        entry->runtime_ivar_offsets[i] = offset;
    }
    return 1;
}

static void sf_objfw_sync_ivar_offset_unlocked(SFObjFWClassEntry_t *entry, size_t index, int32_t offset)
{
    if (entry == nullptr or entry->cls == nullptr or index >= entry->ivar_count) {
        return;
    }

    if (entry->runtime_ivar_offsets != nullptr) {
        entry->runtime_ivar_offsets[index] = offset;
    }
    if (entry->compiler_ivars != nullptr and index < (size_t)entry->compiler_ivars->count) {
        entry->compiler_ivars->ivars[index].offset = offset;
    }
    if (entry->cls->ivar_offsets != nullptr and entry->cls->ivar_offsets[index] != nullptr) {
        *entry->cls->ivar_offsets[index] = offset;
    }
}

int sf_loader_local_ivar_offset_unlocked(SFObjCClass_t *cls, size_t index, int32_t *offset_out)
{
    SFObjFWClassEntry_t *entry = sf_objfw_class_entry_lookup_unlocked((const SFObjFWClass_t *)(const void *)cls);
    if (entry == nullptr or not sf_objfw_init_ivar_offset_storage_unlocked(entry) or
        entry->local_ivar_offsets == nullptr or index >= entry->ivar_count) {
        return 0;
    }

    *offset_out = entry->local_ivar_offsets[index];
    return 1;
}

void sf_loader_sync_ivar_offset_unlocked(SFObjCClass_t *cls, size_t index, int32_t offset)
{
    SFObjFWClassEntry_t *entry = sf_objfw_class_entry_lookup_unlocked((const SFObjFWClass_t *)(const void *)cls);
    if (entry == nullptr) {
        return;
    }

    (void)sf_objfw_init_ivar_offset_storage_unlocked(entry);
    sf_objfw_sync_ivar_offset_unlocked(entry, index, offset);
}

static SFObjCMethodList_t *sf_objfw_normalize_method_lists(SFObjFWMethodList_t *lists)
{
    SFObjCMethodList_t *head = nullptr;
    SFObjCMethodList_t **tail = &head;

    for (; lists != nullptr; lists = lists->next) {
        int32_t count = lists->count;
        if (count < 0) {
            count = 0;
        }

        size_t bytes = offsetof(SFObjCMethodList_t, methods) + ((size_t)count * sizeof(SFObjCMethod_t)) +
                       ((size_t)count * sizeof(struct sf_objc_selector));
        SFObjCMethodList_t *copy = (SFObjCMethodList_t *)sf_runtime_test_calloc(1U, bytes);
        struct sf_objc_selector *selectors = nullptr;
        if (copy == nullptr) {
            break;
        }

        copy->count = count;
        copy->size = (int64_t)sizeof(SFObjCMethod_t);
        selectors = (struct sf_objc_selector *)(void *)(copy->methods + count);
        for (int32_t i = 0; i < count; ++i) {
            selectors[i].name = lists->methods[i].name;
            selectors[i].types = lists->methods[i].types;
            (void)sf_loader_intern_selector_name_types(lists->methods[i].name, lists->methods[i].types);
            copy->methods[i].imp = lists->methods[i].imp;
            copy->methods[i].selector = (SEL)(void *)&selectors[i];
            copy->methods[i].types = lists->methods[i].types;
        }

        *tail = copy;
        tail = &copy->next;
    }

    return head;
}

static SFObjCIvarList_t *sf_objfw_normalize_ivar_list(SFObjFWClass_t *cls)
{
    if (cls == nullptr or cls->ivars == nullptr or cls->ivars->count <= 0) {
        return nullptr;
    }

    SFObjFWClassEntry_t *entry = sf_objfw_class_entry_for_unlocked(cls);
    if (entry != nullptr) {
        if (entry->compiler_ivars == nullptr) {
            entry->compiler_ivars = cls->ivars;
        }
        (void)sf_objfw_init_ivar_offset_storage_unlocked(entry);
    }

    size_t count = (size_t)cls->ivars->count;
    size_t bytes = offsetof(SFObjCIvarList_t, ivars) + (count * sizeof(SFObjCIvar_t));
    SFObjCIvarList_t *copy = (SFObjCIvarList_t *)sf_runtime_test_calloc(1U, bytes);
    if (copy == nullptr) {
        return nullptr;
    }

    copy->count = (uintptr_t)count;
    copy->item_size = sizeof(SFObjCIvar_t);
    for (size_t i = 0; i < count; ++i) {
        SFObjFWIvar_t *ivar = &cls->ivars->ivars[i];
        copy->ivars[i].name = ivar->name;
        copy->ivars[i].type = ivar->type;
        if (entry != nullptr and entry->runtime_ivar_offsets != nullptr and i < entry->ivar_count) {
            copy->ivars[i].offset = &entry->runtime_ivar_offsets[i];
        } else if (cls->ivar_offsets != nullptr) {
            copy->ivars[i].offset = cls->ivar_offsets[i];
        } else {
            copy->ivars[i].offset = &ivar->offset;
        }
        copy->ivars[i].size = sf_objfw_ivar_size(cls, cls->ivars, (int32_t)i);
        copy->ivars[i].flags = 0U;
    }

    return copy;
}

static int sf_objfw_class_has_state(const SFObjFWClass_t *cls, unsigned long state)
{
    SFObjFWClassEntry_t *entry = sf_objfw_class_entry_lookup_unlocked(cls);
    return entry != nullptr and (entry->state & state) != 0U;
}

static void sf_objfw_class_add_state(SFObjFWClass_t *cls, unsigned long state)
{
    SFObjFWClassEntry_t *entry = sf_objfw_class_entry_for_unlocked(cls);
    if (entry != nullptr) {
        entry->state |= state;
    }
}

static void sf_objfw_normalize_class(SFObjFWClass_t *cls)
{
    if (cls == nullptr or sf_objfw_class_has_state(cls, SF_OBJFW_CLASS_STATE_NORMALIZED)) {
        return;
    }

    SFObjCClass_t *runtime_cls = (SFObjCClass_t *)(void *)cls;
    SFObjFWClassEntry_t *entry = sf_objfw_class_entry_for_unlocked(cls);
    if (entry != nullptr and cls->superclass != nullptr and entry->super_name == nullptr) {
        entry->super_name = (const char *)(const void *)cls->superclass;
        runtime_cls->superclass = nullptr;
    }
    if (entry != nullptr and entry->compiler_ivars == nullptr) {
        entry->compiler_ivars = cls->ivars;
    }
    runtime_cls->methods = sf_objfw_normalize_method_lists(cls->methods);
    runtime_cls->ivars = sf_objfw_normalize_ivar_list(cls);
    sf_objfw_class_add_state(cls, SF_OBJFW_CLASS_STATE_NORMALIZED);
}

static void sf_objfw_resolve_superclass_unlocked(SFObjFWClass_t *cls)
{
    if (cls == nullptr or sf_objfw_class_has_state(cls, SF_OBJFW_CLASS_STATE_SUPERCLASS_RESOLVED)) {
        return;
    }

    SFObjFWClassEntry_t *entry = sf_objfw_class_entry_for_unlocked(cls);
    if (entry != nullptr and entry->super_name != nullptr) {
        cls->superclass = (SFObjFWClass_t *)(void *)sf_loader_class_lookup_unlocked(entry->super_name);
        if (cls->superclass != nullptr) {
            sf_objfw_class_add_state(cls, SF_OBJFW_CLASS_STATE_SUPERCLASS_RESOLVED);
        }
        if (cls->superclass == nullptr) {
            ((SFObjCClass_t *)(void *)cls)->superclass = nullptr;
        }
        return;
    }

    cls->superclass = nullptr;
    sf_objfw_class_add_state(cls, SF_OBJFW_CLASS_STATE_SUPERCLASS_RESOLVED);
}

void sf_loader_prepare_registered_classes_unlocked(void)
{
    for (size_t i = 0; i < SF_OBJFW_CLASS_MAP_CAPACITY; ++i) {
        SFObjFWClass_t *cls = g_objfw_class_map[i].cls;
        if (cls == nullptr or sf_objfw_class_has_state(cls, SF_OBJFW_CLASS_STATE_SUPERCLASS_RESOLVED)) {
            continue;
        }
        sf_objfw_resolve_superclass_unlocked(cls);
    }
}

static void sf_objfw_register_selector_list(SFObjFWSelector_t *selectors, uintptr_t count)
{
    if (selectors == nullptr or count == 0U) {
        return;
    }
    sf_loader_register_selector_region((void *)selectors, (void *)(selectors + count));
}

static void sf_objfw_register_module(SFObjFWSymtab_t *symtab)
{
    if (symtab == nullptr or symtab->class_count == 0U) {
        return;
    }

    size_t class_count = (size_t)symtab->class_count;
    SFObjCClass_t **classes = (SFObjCClass_t **)sf_runtime_test_calloc(class_count, sizeof(*classes));
    if (classes == nullptr) {
        return;
    }

    size_t normalized_count = 0U;
    for (size_t i = 0; i < class_count; ++i) {
        SFObjFWClass_t *cls = (SFObjFWClass_t *)symtab->definitions[i];
        if (cls == nullptr or cls->name == nullptr or cls->name[0] == '\0') {
            continue;
        }

        sf_objfw_normalize_class(cls);
        sf_objfw_normalize_class(cls->isa);
        classes[normalized_count++] = (SFObjCClass_t *)(void *)cls;
    }

    if (normalized_count == 0U) {
        free(classes);
        return;
    }

    sf_register_classes(classes, classes + normalized_count);
    free(classes);
}

void __objc_exec_class(void *module_ptr, ...)
{
    SFObjFWModule_t *module = (SFObjFWModule_t *)module_ptr;
    if (module == nullptr or module->symtab == nullptr) {
        return;
    }

    sf_objfw_register_selector_list(module->symtab->selectors, module->symtab->selector_count);
    sf_objfw_register_module(module->symtab);
    sf_finalize_registered_classes();
}
