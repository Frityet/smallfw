#include "runtime/internal.h"

#if defined(__clang__) || defined(__GNUC__)
#define SF_ARC_RUNTIME_ENTRY __attribute__((used))
#else
#define SF_ARC_RUNTIME_ENTRY
#endif

#if defined(__clang__)
#define SF_NO_SANITIZE_FUNCTION __attribute__((no_sanitize("function")))
#else
#define SF_NO_SANITIZE_FUNCTION
#endif

static SF_NO_SANITIZE_FUNCTION id sf_call_alloc_imp(IMP imp, id cls, SEL sel, SFAllocator_t *allocator)
{
    return ((id (*)(id, SEL, SFAllocator_t *))imp)(cls, sel, allocator);
}

static SF_NO_SANITIZE_FUNCTION id sf_call_init_imp(IMP imp, id obj, SEL sel)
{
    return ((id (*)(id, SEL))imp)(obj, sel);
}

SF_ARC_RUNTIME_ENTRY id objc_autorelease(id obj)
{
    return sf_autorelease(obj);
}

SF_ARC_RUNTIME_ENTRY id objc_alloc(Class cls)
{
    Class meta_cls = sf_object_class((id)cls);
    SEL alloc_sel = sf_cached_selector_alloc();
    IMP imp = sf_class_cached_alloc_imp(meta_cls);
    if (imp == nullptr and alloc_sel != nullptr) {
        imp = sf_lookup_imp_in_class(meta_cls, alloc_sel);
    }
    if (imp == nullptr or alloc_sel == nullptr) {
        return (id)0;
    }
    return sf_call_alloc_imp(imp, (id)cls, alloc_sel, sf_default_allocator());
}

SF_ARC_RUNTIME_ENTRY id objc_alloc_init(Class cls)
{
    SEL init_sel = sf_cached_selector_init();
    id obj = objc_alloc(cls);
    IMP imp = nullptr;
    if (obj == nullptr) {
        return nullptr;
    }
    imp = sf_class_cached_init_imp(sf_object_class(obj));
    if (imp == nullptr and init_sel != nullptr) {
        imp = sf_lookup_imp_in_class(sf_object_class(obj), init_sel);
    }
    if (imp == nullptr or init_sel == nullptr) {
        return (id)0;
    }
    return sf_call_init_imp(imp, obj, init_sel);
}
