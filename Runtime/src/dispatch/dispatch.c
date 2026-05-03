#include "internal.h"

#include <stdint.h>
#include <string.h>

#pragma clang assume_nonnull begin

static thread_local struct sf_objc_slot g_legacy_lookup_slot;

static struct sf_objc_slot *nonnil legacy_lookup_slot(id nillable receiver, SEL nillable op, IMP nillable imp)
{
    g_legacy_lookup_slot.owner = sf_object_class(receiver);
    g_legacy_lookup_slot.types = sf_selector_types(op);
    g_legacy_lookup_slot.selector = op;
    g_legacy_lookup_slot.version = 0;
    g_legacy_lookup_slot.method = imp;
    return &g_legacy_lookup_slot;
}

bool sf_selector_equal(SEL nillable a, SEL nillable b)
{
    return a == b;
}

static bool selector_slots_match(SEL nillable lhs, SEL nillable rhs)
{
    const char *lhs_name = nullptr;
    const char *rhs_name = nullptr;
    uint32_t lhs_slot = 0U;
    uint32_t rhs_slot = 0U;

    if (lhs == rhs) {
        return 1;
    }
    if (lhs == nullptr or rhs == nullptr) {
        return 0;
    }

    lhs_slot = sf_selector_slot(lhs);
    rhs_slot = sf_selector_slot(rhs);
    if (lhs_slot != UINT32_MAX and rhs_slot != UINT32_MAX) {
        return lhs_slot == rhs_slot;
    }

    lhs_name = sf_selector_name(lhs);
    rhs_name = sf_selector_name(rhs);
    return lhs_name != nullptr and rhs_name != nullptr and strcmp(lhs_name, rhs_name) == 0;
}

static SFObjCMethod_t *nillable lookup_method_in_class_local(Class nillable cls, SEL nillable op)
{
    auto cursor = (SFObjCClass_t *)cls;
    if (cursor == nullptr or op == nullptr) {
        return nullptr;
    }

    while (cursor != nullptr) {
        for (SFObjCMethodList_t *list = cursor->methods; list != nullptr; list = list->next) {
            for (int32_t i = 0; i < list->count; ++i) {
                auto method = &list->methods[i];
                if (selector_slots_match(method->selector, op)) {
                    return method;
                }
            }
        }
        cursor = (cursor->superclass != cursor) ? cursor->superclass : nullptr;
    }

    return nullptr;
}

SFObjCMethod_t *nillable sf_lookup_method_in_class(Class nillable cls, SEL nillable op)
{
    return lookup_method_in_class_local(cls, op);
}

IMP nillable sf_lookup_dtable_imp(Class nillable cls, SEL nillable op)
{
    auto c = (SFObjCClass_t *)cls;
    IMP *dtable = nullptr;
    uint32_t slot = 0U;

    if (c == nullptr or op == nullptr or c->dtable == nullptr) {
        return nullptr;
    }

    dtable = (IMP *)c->dtable;
    slot = sf_selector_slot(op);
    if ((size_t)slot >= sf_runtime_selector_count()) {
        return nullptr;
    }
    return dtable[slot];
}

IMP nillable sf_lookup_imp_in_class(Class nillable cls, SEL nillable op)
{
    auto imp = sf_lookup_dtable_imp(cls, op);
    if (imp != nullptr) {
        return imp;
    }

    auto method = lookup_method_in_class_local(cls, op);
    return method != nullptr ? method->imp : nullptr;
}

IMP nillable sf_lookup_imp_miss(Class nillable cls, SEL nillable op)
{
    return sf_lookup_imp_in_class(cls, op);
}

IMP nillable sf_lookup_imp(id nillable receiver, SEL nillable op)
{
    auto cls = sf_object_class(receiver);
    return sf_lookup_imp_in_class(cls, op);
}

IMP nillable objc_msg_lookup(id nillable receiver, SEL nillable op)
{
#if SF_RUNTIME_FORWARDING
        return sf_resolve_message_dispatch(&receiver, &op);
#else
        return sf_lookup_imp(receiver, op);
#endif
}

IMP nillable objc_msg_lookup_stret(id nillable receiver, SEL nillable op)
{
    return objc_msg_lookup(receiver, op);
}

struct sf_objc_slot *nonnil objc_msg_lookup_sender(id nillable *nonnil receiver, SEL nillable op, void *nillable sender)
{
    (void)sender;
#if SF_RUNTIME_FORWARDING
        auto current_op = op;
        auto imp = sf_resolve_message_dispatch(receiver, &current_op);
        return legacy_lookup_slot(*receiver, current_op, imp);
#else
        auto current_receiver = *receiver;
        return legacy_lookup_slot(current_receiver, op, sf_lookup_imp(current_receiver, op));
#endif
}

IMP nillable sf_resolve_message_dispatch(id nillable *nonnil receiver, SEL nillable *nonnil op)
{
    auto current_receiver = *receiver;
    auto current_sel = *op;

#if SF_RUNTIME_FORWARDING
        {
            auto forwarding_sel = sf_cached_selector_forwarding_target();
            int forward_hops_remaining = 8;

            while (true) {
                auto imp = sf_lookup_imp(current_receiver, current_sel);
                if (imp != nullptr) {
                    *receiver = current_receiver;
                    *op = current_sel;
                    return imp;
                }

                if (forward_hops_remaining <= 0 or forwarding_sel == nullptr or selector_slots_match(current_sel, forwarding_sel)) {
                    break;
                }

                auto cls = sf_object_class(current_receiver);
                auto forward_method = lookup_method_in_class_local(cls, forwarding_sel);
                if (forward_method == nullptr or forward_method->imp == nullptr) {
                    break;
                }

                auto forward_imp = (id nillable (*)(id nillable, SEL nillable, SEL nillable))forward_method->imp;
                auto target = forward_imp(current_receiver, forwarding_sel, current_sel);
                if (target == nullptr or target == current_receiver) {
                    break;
                }

                current_receiver = target;
                if (--forward_hops_remaining == 0) {
                    break;
                }
            }
        }
#endif

    *receiver = current_receiver;
    *op = current_sel;
    return sf_lookup_imp(current_receiver, current_sel);
}

IMP nillable objc_msg_lookup_super(struct sf_objc_super *nillable super_info, SEL nillable op)
{
    if (super_info == nullptr) {
        return nullptr;
    }
    return sf_lookup_imp_in_class(super_info->super_class, op);
}

IMP nillable objc_msg_lookup_super_stret(struct sf_objc_super *nillable super_info, SEL nillable op)
{
    return objc_msg_lookup_super(super_info, op);
}

uint64_t sf_dispatch_cache_hits(void)
{
    return UINT64_C(0);
}

uint64_t sf_dispatch_cache_misses(void)
{
    return UINT64_C(0);
}

uint64_t sf_dispatch_method_walks(void)
{
    return UINT64_C(0);
}

void sf_dispatch_reset_stats(void)
{
}

size_t sf_runtime_test_dispatch_cache_base_index(Class nillable cls, SEL nillable op)
{
    (void)cls;
    (void)op;
    return 0U;
}

const void *nillable sf_runtime_test_dispatch_cache_entry(size_t index)
{
    (void)index;
    return nullptr;
}

const void *nillable sf_runtime_test_dispatch_l0_entry(size_t index)
{
    (void)index;
    return nullptr;
}
#pragma clang assume_nonnull end
