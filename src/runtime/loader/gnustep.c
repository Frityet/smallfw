#include "runtime/internal.h"
#include "runtime/loader/common.h"

int sf_loader_local_ivar_offset_unlocked(SFObjCClass_t *cls, size_t index, int32_t *offset_out)
{
    (void)cls;
    (void)index;
    (void)offset_out;
    return 0;
}

void sf_loader_sync_ivar_offset_unlocked(SFObjCClass_t *cls, size_t index, int32_t offset)
{
    (void)cls;
    (void)index;
    (void)offset;
}

void sf_loader_prepare_registered_classes_unlocked(void)
{
}

void __objc_load(void *init_ptr)
{
    SFObjCInit_t *init = (SFObjCInit_t *)init_ptr;
    if (init == NULL) {
        return;
    }

    sf_loader_register_selector_region(init->selectors_start, init->selectors_stop);
    sf_register_classes((SFObjCClass_t **)init->classes_start, (SFObjCClass_t **)init->classes_stop);
    sf_loader_register_class_aliases((SFObjCAliasEntry_t *)init->aliases_start,
                                     (SFObjCAliasEntry_t *)init->aliases_stop);
    sf_finalize_registered_classes();
}
