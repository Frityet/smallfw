#include <string.h>

#include "runtime_test_support.h"

#if SF_RUNTIME_TAGGED_POINTERS
static id sf_test_make_raw_tagged(uintptr_t slot, uintptr_t payload)
{
    return (id)(void *)((payload << 3U) | slot);
}

static int case_tagged_arc_noop_semantics(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained TaggedNumberProbe *num = [TaggedNumberProbe numberWithValue:41U];
    id slot = nil;
    void *pool = objc_autoreleasePoolPush();

    if (num == nil or objc_retain(num) != num or objc_autorelease(num) != num or
        objc_retainAutorelease(num) != num or objc_retainAutoreleasedReturnValue(num) != num or
        objc_autoreleaseReturnValue(num) != num or objc_retainAutoreleaseReturnValue(num) != num) {
        objc_autoreleasePoolPop(pool);
        return 0;
    }

    objc_storeStrong(&slot, num);
    if (slot != num) {
        objc_autoreleasePoolPop(pool);
        objc_storeStrong(&slot, nil);
        return 0;
    }

    objc_autoreleasePoolPop(pool);
    objc_storeStrong(&slot, nil);
    objc_release(num);
    return g_counter_deallocs == 0;
}

static int case_tagged_object_decode_paths(void)
{
    __unsafe_unretained TaggedNumberProbe *num = [TaggedNumberProbe numberWithValue:99U];
    const char *name = NULL;
    Class cls = (Class)objc_getClass("TaggedNumberProbe");
    if (num == nil or cls == Nil) {
        return 0;
    }

    name = sf_class_name_of_object(num);
    return sf_object_class(num) == cls and
           object_getClass(num) == cls and
           sf_header_from_object(num) == NULL and
           sf_object_is_heap(num) == 0 and
           [num isTaggedPointer] != 0 and
           [num taggedPointerPayload] == 99U and
           [num allocator] == sf_default_allocator() and
           num.parent == nil and
           name != NULL and strcmp(name, "TaggedNumberProbe") == 0;
}

static int case_tagged_dispatch_methods(void)
{
    __unsafe_unretained TaggedNumberProbe *num = [TaggedNumberProbe numberWithValue:41U];
    __unsafe_unretained TaggedStringProbe *str = [TaggedStringProbe stringWithBytes:"hello!" length:6U];
    __unsafe_unretained TaggedNumberProbe *sum = nil;
    IMP plus_imp = NULL;
    IMP char_imp = NULL;
    id resolved_plus_receiver = nil;
    SEL resolved_plus_op = NULL;
    IMP resolved_plus_imp = NULL;
    id resolved_char_receiver = nil;
    SEL resolved_char_op = NULL;
    IMP resolved_char_imp = NULL;
    if (num == nil or str == nil) {
        return 0;
    }

    plus_imp = sf_lookup_imp(num, @selector(plus:));
    char_imp = sf_lookup_imp(str, @selector(characterAtIndex:));
    resolved_plus_receiver = num;
    resolved_plus_op = @selector(plus:);
    resolved_plus_imp = sf_resolve_message_dispatch(&resolved_plus_receiver, &resolved_plus_op);
    resolved_char_receiver = str;
    resolved_char_op = @selector(characterAtIndex:);
    resolved_char_imp = sf_resolve_message_dispatch(&resolved_char_receiver, &resolved_char_op);
    sum = [num plus:(uintptr_t)1U];
    return [num value] == 41U and
           plus_imp != NULL and
           char_imp != NULL and
           resolved_plus_imp != NULL and
           resolved_plus_op != NULL and
           sf_selector_types(resolved_plus_op) != NULL and
           resolved_char_imp != NULL and
           resolved_char_op != NULL and
           sf_selector_types(resolved_char_op) != NULL and
           sum != nil and
           sf_object_class(sum) == (Class)objc_getClass("TaggedNumberProbe") and
           [sum value] == 42U and
           [str length] == 6UL and
           [str characterAtIndex:1UL] == (unsigned int)'e';
}

static int case_tagged_slot_registration_rules(void)
{
    id conflicted = sf_test_make_raw_tagged(3U, 7U);
    id unknown = sf_test_make_raw_tagged(7U, 11U);

    return [TaggedDuplicateA taggedPointerWithPayload:1U] == nil and
           [TaggedDuplicateB taggedPointerWithPayload:1U] == nil and
           [TaggedInvalidSlotProbe taggedPointerWithPayload:1U] == nil and
           [TaggedValueProbe taggedPointerWithPayload:1U] == nil and
           sf_object_class(conflicted) == Nil and
           sf_object_class(unknown) == Nil;
}

static const SFTestCase g_tagged_cases[] = {
    {"tagged_arc_noop_semantics", case_tagged_arc_noop_semantics},
    {"tagged_object_decode_paths", case_tagged_object_decode_paths},
    {"tagged_dispatch_methods", case_tagged_dispatch_methods},
    {"tagged_slot_registration_rules", case_tagged_slot_registration_rules},
};
#endif

const SFTestCase *sf_runtime_tagged_cases(size_t *count)
{
#if SF_RUNTIME_TAGGED_POINTERS
    if (count != NULL) {
        *count = sizeof(g_tagged_cases) / sizeof(g_tagged_cases[0]);
    }
    return g_tagged_cases;
#else
    if (count != NULL) {
        *count = 0U;
    }
    return NULL;
#endif
}
