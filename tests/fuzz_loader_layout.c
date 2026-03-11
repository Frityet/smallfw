#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "runtime/internal.h"

typedef struct FuzzIvarList {
    uintptr_t count;
    uintptr_t item_size;
    SFObjCIvar_t ivars[4];
} FuzzIvarList;

typedef struct FuzzClassBundle {
    SFObjCClass_t cls;
    SFObjCClass_t meta;
    FuzzIvarList ivars;
    int32_t offsets[4];
} FuzzClassBundle;

static const char *fuzz_type_for_byte(uint8_t value)
{
    static const char *k_types[] = {"i", "@", "^v", "{Pair=ii}", "[4I]", "q"};
    return k_types[value % (sizeof(k_types) / sizeof(k_types[0]))];
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    static const char *k_ivar_names[] = {"a", "b", "c", "d"};
    FuzzClassBundle parent;
    FuzzClassBundle child;
    SFObjCClass_t *classes[2];
    unsigned int ivar_count = 0;
    Ivar *ivars = NULL;
    size_t count = size < 8U ? size : 8U;

    if (data == NULL) {
        return 0;
    }

    memset(&parent, 0, sizeof(parent));
    memset(&child, 0, sizeof(child));

    parent.cls.isa = &parent.meta;
    parent.meta.isa = &parent.meta;
    parent.cls.name = "FuzzLayoutParent";
    parent.meta.name = "FuzzLayoutParentMeta";
    parent.ivars.count = (count > 4U) ? 2U : 1U;
    parent.ivars.item_size = sizeof(SFObjCIvar_t);
    parent.cls.ivars = &parent.ivars;

    child.cls.isa = &child.meta;
    child.meta.isa = &child.meta;
    child.cls.superclass = &parent.cls;
    child.cls.name = "FuzzLayoutChild";
    child.meta.name = "FuzzLayoutChildMeta";
    child.ivars.count = (count > 6U) ? 2U : 1U;
    child.ivars.item_size = sizeof(SFObjCIvar_t);
    child.cls.ivars = &child.ivars;

    for (uintptr_t i = 0; i < parent.ivars.count; ++i) {
        parent.offsets[i] = (int32_t)(data[i % count] & 31U);
        parent.ivars.ivars[i].name = k_ivar_names[i];
        parent.ivars.ivars[i].type = fuzz_type_for_byte(data[i % count]);
        parent.ivars.ivars[i].offset = ((data[i % count] & 1U) == 0U) ? &parent.offsets[i] : NULL;
        parent.ivars.ivars[i].size = (uint32_t)((data[i % count] & 15U) + 1U);
    }
    for (uintptr_t i = 0; i < child.ivars.count; ++i) {
        size_t index = (size_t)(i + 2U) % count;
        child.offsets[i] = (int32_t)(data[index] & 63U);
        child.ivars.ivars[i].name = k_ivar_names[i + 2U];
        child.ivars.ivars[i].type = fuzz_type_for_byte(data[index]);
        child.ivars.ivars[i].offset = ((data[index] & 1U) == 0U) ? &child.offsets[i] : NULL;
        child.ivars.ivars[i].size = (uint32_t)((data[index] & 15U) + 1U);
    }

    classes[0] = &parent.cls;
    classes[1] = &child.cls;
    sf_register_classes(classes, classes + 2);
    sf_finalize_registered_classes();

    (void)class_getInstanceSize((Class)&parent.cls);
    (void)class_getInstanceSize((Class)&child.cls);
#if SF_RUNTIME_REFLECTION
    (void)class_getInstanceVariable((Class)&child.cls, k_ivar_names[data[0] & 3U]);
    ivars = class_copyIvarList((Class)&child.cls, &ivar_count);
    free(ivars);
#else
    (void)ivar_count;
#endif
    return 0;
}
