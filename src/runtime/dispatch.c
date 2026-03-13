#include "runtime/internal.h"

#include <stdint.h>
#include <string.h>

int sf_selector_equal(SEL a, SEL b)
{
    return a == b;
}

static int selector_slots_match(SEL lhs, SEL rhs)
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

static SFObjCMethod_t *lookup_method_in_class_local(Class cls, SEL op)
{
    SFObjCClass_t *cursor = (SFObjCClass_t *)cls;
    if (cursor == nullptr or op == nullptr) {
        return nullptr;
    }

    while (cursor != nullptr) {
        for (SFObjCMethodList_t *list = cursor->methods; list != nullptr; list = list->next) {
            for (int32_t i = 0; i < list->count; ++i) {
                SFObjCMethod_t *method = &list->methods[i];
                if (selector_slots_match(method->selector, op)) {
                    return method;
                }
            }
        }
        cursor = (cursor->superclass != cursor) ? cursor->superclass : nullptr;
    }

    return nullptr;
}

SFObjCMethod_t *sf_lookup_method_in_class(Class cls, SEL op)
{
    return lookup_method_in_class_local(cls, op);
}

IMP sf_lookup_dtable_imp(Class cls, SEL op)
{
    SFObjCClass_t *c = (SFObjCClass_t *)cls;
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

IMP sf_lookup_imp_in_class(Class cls, SEL op)
{
    IMP imp = sf_lookup_dtable_imp(cls, op);
    if (imp != nullptr) {
        return imp;
    }

    SFObjCMethod_t *method = lookup_method_in_class_local(cls, op);
    return method != nullptr ? method->imp : nullptr;
}

IMP sf_lookup_imp_miss(Class cls, SEL op)
{
    return sf_lookup_imp_in_class(cls, op);
}

IMP sf_lookup_imp(id receiver, SEL op)
{
    Class cls = sf_object_class(receiver);
    return sf_lookup_imp_in_class(cls, op);
}

IMP objc_msg_lookup(id receiver, SEL op)
{
#if SF_RUNTIME_FORWARDING
    return sf_resolve_message_dispatch(&receiver, &op);
#else
    return sf_lookup_imp(receiver, op);
#endif
}

IMP objc_msg_lookup_stret(id receiver, SEL op)
{
    return objc_msg_lookup(receiver, op);
}

IMP sf_resolve_message_dispatch(id *receiver, SEL *op)
{
    id current_receiver = nullptr;
    SEL current_sel = nullptr;

    // if (receiver == nullptr or op == nullptr) {
    //     return nullptr;
    // }

    current_receiver = *receiver;
    current_sel = *op;

#if SF_RUNTIME_FORWARDING
    {
        SEL forwarding_sel = sf_cached_selector_forwarding_target();
        int forward_hops_remaining = 8;

        for (;;) {
            IMP imp = nullptr;
            Class cls = nullptr;
            SFObjCMethod_t *forward_method = nullptr;
            id target = nullptr;

            imp = sf_lookup_imp(current_receiver, current_sel);
            if (imp != nullptr) {
                *receiver = current_receiver;
                *op = current_sel;
                return imp;
            }

            if (forward_hops_remaining <= 0 or forwarding_sel == nullptr or selector_slots_match(current_sel, forwarding_sel)) {
                break;
            }

            cls = sf_object_class(current_receiver);
            forward_method = lookup_method_in_class_local(cls, forwarding_sel);
            if (forward_method == nullptr or forward_method->imp == nullptr) {
                break;
            }

            target = ((id (*)(id, SEL, SEL))forward_method->imp)(current_receiver, forwarding_sel, current_sel);
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

IMP objc_msg_lookup_super(struct sf_objc_super *super_info, SEL op)
{
    if (super_info == nullptr) {
        return nullptr;
    }
    return sf_lookup_imp_in_class(super_info->super_class, op);
}

IMP objc_msg_lookup_super_stret(struct sf_objc_super *super_info, SEL op)
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

size_t sf_runtime_test_dispatch_cache_base_index(Class cls, SEL op)
{
    (void)cls;
    (void)op;
    return 0U;
}

const void *sf_runtime_test_dispatch_cache_entry(size_t index)
{
    (void)index;
    return nullptr;
}

const void *sf_runtime_test_dispatch_l0_entry(size_t index)
{
    (void)index;
    return nullptr;
}
