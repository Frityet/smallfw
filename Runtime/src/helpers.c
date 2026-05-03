#include "internal.h"

#define SF_ARC_RUNTIME_ENTRY __attribute__((used))

#define SF_NO_SANITIZE_FUNCTION __attribute__((no_sanitize("function")))

#pragma clang assume_nonnull begin

static SF_NO_SANITIZE_FUNCTION id nillable sf_call_alloc_imp(IMP nillable imp, id nillable cls, SEL nonnil sel, SFAllocator_t *nonnil allocator)
{
    sf_nonnil_check(imp != nullptr);
    return ((id nillable (*)(id nillable, SEL nonnil, SFAllocator_t *nonnil))imp)(cls, sel, allocator);
}

static SF_NO_SANITIZE_FUNCTION id nillable sf_call_init_imp(IMP nillable imp, id nillable obj, SEL nonnil sel)
{
    sf_nonnil_check(imp != nullptr);
    return ((id nillable (*)(id nillable, SEL nonnil))imp)(obj, sel);
}

SF_ARC_RUNTIME_ENTRY id nillable objc_autorelease(id nillable obj)
{
    return sf_autorelease(obj);
}

SF_ARC_RUNTIME_ENTRY id nillable objc_alloc(Class nillable cls)
{
    auto meta_cls = sf_object_class((id)cls);
    auto alloc_sel = sf_cached_selector_alloc();
    auto imp = sf_class_cached_alloc_imp(meta_cls);
    if (imp == nullptr and alloc_sel != nullptr) {
        imp = sf_lookup_imp_in_class(meta_cls, alloc_sel);
    }
    if (imp == nullptr or alloc_sel == nullptr) {
        return (id)0;
    }
    return sf_call_alloc_imp(imp, (id)cls, (SEL nonnil)alloc_sel, sf_default_allocator());
}

SF_ARC_RUNTIME_ENTRY id nillable objc_alloc_init(Class nillable cls)
{
    auto init_sel = sf_cached_selector_init();
    auto obj = objc_alloc(cls);
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
    return sf_call_init_imp(imp, obj, (SEL nonnil)init_sel);
}
#pragma clang assume_nonnull end
