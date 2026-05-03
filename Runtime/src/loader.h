#pragma once

#include "internal.h"

#pragma clang assume_nonnull begin

#ifdef __cplusplus
    extern "C" {
#endif

typedef struct SFObjCAliasEntry {
    const char *nillable alias_name;
    Class nillable *nillable class_ref;
} SFObjCAliasEntry_t;

SEL nillable sf_loader_intern_selector_name_types(const char *nillable name, const char *nillable types);
void sf_loader_register_selector_region(void *nillable start, void *nillable stop);
void sf_loader_register_class_aliases(SFObjCAliasEntry_t *nillable start, SFObjCAliasEntry_t *nillable stop);
SFObjCClass_t *nillable sf_loader_class_lookup_unlocked(const char *nillable name);
bool sf_loader_local_ivar_offset_unlocked(SFObjCClass_t *cls, size_t index, int32_t *offset_out);
void sf_loader_sync_ivar_offset_unlocked(SFObjCClass_t *cls, size_t index, int32_t offset);
void sf_loader_prepare_registered_classes_unlocked(void);

#ifdef __cplusplus
    }
#endif

#pragma clang assume_nonnull end
