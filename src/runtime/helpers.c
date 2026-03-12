#include "runtime/internal.h"

#if defined(__clang__) || defined(__GNUC__)
#define SF_ARC_RUNTIME_ENTRY __attribute__((used))
#else
#define SF_ARC_RUNTIME_ENTRY
#endif

SF_ARC_RUNTIME_ENTRY id objc_autorelease(id obj)
{
    return sf_autorelease(obj);
}

SF_ARC_RUNTIME_ENTRY id objc_alloc(Class cls)
{
    Class meta_cls = sf_object_class((id)cls);
    SEL alloc_sel = sf_cached_selector_alloc();
    IMP imp = sf_class_cached_alloc_imp(meta_cls);
    if (imp == NULL and alloc_sel != NULL) {
        imp = sf_lookup_imp_in_class(meta_cls, alloc_sel);
    }
    if (imp == NULL or alloc_sel == NULL or sf_dispatch_imp_is_nil(imp)) {
        return (id)0;
    }
    return imp((id)cls, alloc_sel, sf_default_allocator());
}

SF_ARC_RUNTIME_ENTRY id objc_alloc_init(Class cls)
{
    SEL init_sel = sf_cached_selector_init();
    id obj = objc_alloc(cls);
    IMP imp = NULL;
    if (obj == NULL) {
        return NULL;
    }
    imp = sf_class_cached_init_imp(sf_object_class(obj));
    if (imp == NULL and init_sel != NULL) {
        imp = sf_lookup_imp_in_class(sf_object_class(obj), init_sel);
    }
    if (imp == NULL or init_sel == NULL or sf_dispatch_imp_is_nil(imp)) {
        return (id)0;
    }
    return imp(obj, init_sel);
}
