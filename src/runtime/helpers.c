#include "runtime/internal.h"

id objc_autorelease(id obj) {
    return sf_autorelease(obj);
}

id objc_alloc(Class cls) {
    Class meta_cls = sf_object_class((id)cls);
    SEL alloc_sel = sf_cached_selector_alloc();
    IMP imp = sf_class_cached_alloc_imp(meta_cls);
    if (imp == NULL && alloc_sel != NULL) {
        imp = sf_lookup_imp_in_class(meta_cls, alloc_sel);
    }
    if (imp == NULL || alloc_sel == NULL || sf_dispatch_imp_is_nil(imp)) {
        return (id)0;
    }
    return imp((id)cls, alloc_sel, sf_default_allocator());
}

id objc_alloc_init(Class cls) {
    SEL init_sel = sf_cached_selector_init();
    id obj = objc_alloc(cls);
    IMP imp = NULL;
    if (obj == NULL) {
        return NULL;
    }
    imp = sf_class_cached_init_imp(sf_object_class(obj));
    if (imp == NULL && init_sel != NULL) {
        imp = sf_lookup_imp_in_class(sf_object_class(obj), init_sel);
    }
    if (imp == NULL || init_sel == NULL || sf_dispatch_imp_is_nil(imp)) {
        return (id)0;
    }
    return imp(obj, init_sel);
}
