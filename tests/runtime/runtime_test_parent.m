#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#include "runtime_test_support.h"

typedef struct ParentThreadCtx {
    Object *parent;
    int loops;
    int ok;
} ParentThreadCtx;

static size_t test_align_up(size_t value, size_t align)
{
    if (align <= 1U) {
        return value;
    }
    size_t mask = align - 1U;
    return (value + mask) & ~mask;
}

static size_t embedded_value_storage_size(Class cls)
{
    size_t instance_size = class_getInstanceSize(cls);
#if SF_RUNTIME_INLINE_VALUE_STORAGE
    return test_align_up(sizeof(SFInlineValueHeader_t) + instance_size, sizeof(void *));
#else
    return test_align_up(sizeof(SFObjHeader_t) + instance_size, sizeof(void *));
#endif
}

#if SF_RUNTIME_THREADSAFE
static void *parent_thread_main(void *arg)
{
    ParentThreadCtx *ctx = (ParentThreadCtx *)arg;

    for (int i = 0; i < ctx->loops; ++i) {
        __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:ctx->parent] init];
        if (child == nil) {
            ctx->ok = 0;
            return nullptr;
        }
        objc_release(child);
    }

    return nullptr;
}
#endif

static int case_value_parent_layout_hidden_storage(void)
{
    Class holder_cls = (Class)objc_getClass("InlineHolder");
    Class object_cls = (Class)objc_getClass("Object");
    Class value_cls = (Class)objc_getClass("InlineValue");
    if (holder_cls == Nil or object_cls == Nil or value_cls == Nil) {
        return 0;
    }

    size_t holder_size = class_getInstanceSize(holder_cls);
    size_t visible_min = class_getInstanceSize(object_cls) + (2U * sizeof(void *));
    size_t slot_min = embedded_value_storage_size(value_cls);
    if (holder_size < visible_min + slot_min) {
        return 0;
    }

#if SF_RUNTIME_REFLECTION
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(holder_cls, &count);
    int ok = count == 2U and
             class_getInstanceVariable(holder_cls, "_value") != nullptr and
             class_getInstanceVariable(holder_cls, "_ref") != nullptr and
             ivars != nullptr;
    free((void *)ivars);
    return ok;
#else
    return 1;
#endif
}

static int case_value_parent_alloc_embeds_in_parent(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained InlineHolder *holder = [[InlineHolder allocWithAllocator:&allocator] init];
    __unsafe_unretained InlineValueSub *child = [[InlineValueSub allocWithParent:holder] init];
    if (holder == nil or child == nil) {
        return 0;
    }

    SFObjHeader_t *holder_hdr = sf_header_from_object(holder);
    SFObjHeader_t *child_hdr = sf_header_from_object(child);
    uintptr_t holder_begin = (uintptr_t)(void *)holder_hdr;
    uintptr_t holder_end = holder_begin + sf_object_allocation_size_for_object(holder);
    uintptr_t child_begin = (uintptr_t)(void *)child_hdr;
    uintptr_t child_end = child_begin + embedded_value_storage_size((Class)objc_getClass("InlineValueSub"));
    int ok = holder_hdr != nullptr and
             child_hdr != nullptr and
             ctx.alloc_calls == 1 and
             ctx.free_calls == 0 and
             holder->_value == (InlineValue *)child and
             child.parent == holder and
             child.allocator == &allocator and
             sf_header_group_root(child_hdr) == child_hdr and
             sf_header_group_live_count(holder_hdr) == 1U and
             child_begin >= holder_begin and
             child_end <= holder_end;

    objc_storeStrong((id *)&holder->_value, nil);
    objc_release(holder);
    return ok and ctx.free_calls == 1 and ctx.active_blocks == 0;
}

static int case_value_parent_nontrivial_inline_rejected(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained NonTrivialHolder *holder = SFW_NEW(NonTrivialHolder);
    if (holder == nil) {
        return 0;
    }

    id child = sf_alloc_object_with_parent((Class)objc_getClass("NonTrivialInlineValue"), holder);
    int ok = 0;

#if SF_RUNTIME_INLINE_VALUE_STORAGE
    ok = child == nil and holder->_value == nil;
#else
    ok = child != nil and holder->_value == child and ((NonTrivialInlineValue *)child).parent == holder;
    if (child != nil) {
        objc_storeStrong((id *)&holder->_value, nil);
    }
#endif

    objc_release(holder);
    return ok;
}

static int case_value_parent_duplicate_slots_reuse(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained InlinePairHolder *holder = SFW_NEW(InlinePairHolder);
    __unsafe_unretained InlineValue *first = [[InlineValue allocWithParent:holder] init];
    __unsafe_unretained InlineValue *second = [[InlineValue allocWithParent:holder] init];
    if (holder == nil or first == nil or second == nil) {
        return 0;
    }

    int ok = holder->_first == first and holder->_second == second;

    objc_release(first);
    objc_release(second);
    objc_storeStrong((id *)&holder->_first, nil);
    if (holder->_first != nil or holder->_second != second) {
        objc_storeStrong((id *)&holder->_second, nil);
        objc_release(holder);
        return 0;
    }

    __unsafe_unretained InlineValue *reused = [[InlineValue allocWithParent:holder] init];
    ok = ok and reused != nil and holder->_first == reused and holder->_second == second;

    if (reused != nil) {
        objc_release(reused);
    }
    objc_storeStrong((id *)&holder->_first, nil);
    objc_storeStrong((id *)&holder->_second, nil);
    objc_release(holder);
    return ok;
}

static int case_value_parent_child_expires_with_parent(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained InlineHolder *holder = [[InlineHolder allocWithAllocator:&allocator] init];
    __unsafe_unretained InlineValue *child = [[InlineValue allocWithParent:holder] init];
    if (holder == nil or child == nil) {
        return 0;
    }

    objc_release(holder);
    int ok = ctx.alloc_calls == 1 and ctx.free_calls == 1 and ctx.active_blocks == 0;
#if SF_RUNTIME_VALIDATION
    ok = ok and sf_header_from_object(child) == nullptr and not sf_object_is_heap(child);
#endif
    return ok;
}

static int case_value_parent_standalone_heap_alloc(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained InlineValue *direct = [[InlineValue allocWithAllocator:&allocator] init];
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
#endif
    __unsafe_unretained InlineValue *nil_parent = [[InlineValue allocWithParent:nil] init];
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
    if (direct == nil or nil_parent == nil) {
        return 0;
    }

    SFObjHeader_t *direct_hdr = sf_header_from_object(direct);
    SFObjHeader_t *nil_parent_hdr = sf_header_from_object(nil_parent);
    int ok = direct_hdr != nullptr and
             nil_parent_hdr != nullptr and
             sf_header_group_root(direct_hdr) == direct_hdr and
             sf_header_group_root(nil_parent_hdr) == nil_parent_hdr and
             direct.parent == nil and
             nil_parent.parent == nil and
             direct.allocator == &allocator and
             ctx.alloc_calls == 1;

    objc_release(direct);
    objc_release(nil_parent);
    return ok and ctx.free_calls == 1;
}

static int case_value_parent_slot_exhaustion(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained InlineHolder *holder = SFW_NEW(InlineHolder);
    __unsafe_unretained InlineValue *child = [[InlineValue allocWithParent:holder] init];
    if (holder == nil or child == nil) {
        return 0;
    }

#if SF_RUNTIME_EXCEPTIONS
    int ok = 0;
    @try {
        (void)[[InlineValue allocWithParent:holder] init];
    }
    @catch (AllocationFailedException *e) {
        ok = e != nil;
    }
#else
    __unsafe_unretained InlineValue *extra = [InlineValue allocWithParent:holder];
    int ok = extra == nil;
    if (extra != nil) {
        extra = [extra init];
        if (extra != nil) {
            objc_release(extra);
        }
    }
#endif

    objc_release(child);
    objc_storeStrong((id *)&holder->_value, nil);
    objc_release(holder);
    return ok;
}

static int case_value_parent_oversized_subclass_rejected(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained InlineHolder *holder = SFW_NEW(InlineHolder);
    if (holder == nil) {
        return 0;
    }

#if SF_RUNTIME_EXCEPTIONS
    int ok = 0;
    @try {
        (void)[[InlineLargeValueSub allocWithParent:holder] init];
    }
    @catch (AllocationFailedException *e) {
        ok = e != nil;
    }
#else
    __unsafe_unretained InlineLargeValueSub *child = [InlineLargeValueSub allocWithParent:holder];
    int ok = child == nil;
    if (child != nil) {
        child = [child init];
        if (child != nil) {
            objc_release(child);
        }
    }
#endif

    objc_release(holder);
    return ok;
}

static int case_parent_group_inheritance(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained CounterObject *root = [[CounterObject allocWithAllocator:&allocator] init];
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    __unsafe_unretained CounterObject *grandchild = [[CounterObject allocWithParent:child] init];
    if (root == nil or child == nil or grandchild == nil) {
        return 0;
    }

    SFObjHeader_t *root_hdr = sf_header_from_object(root);
    SFObjHeader_t *child_hdr = sf_header_from_object(child);
    SFObjHeader_t *grandchild_hdr = sf_header_from_object(grandchild);
    int ok = root_hdr != nullptr and
             child_hdr != nullptr and
             grandchild_hdr != nullptr and
             sf_header_group_root(child_hdr) == root_hdr and
             sf_header_group_root(grandchild_hdr) == root_hdr and
             sf_header_group_live_count(root_hdr) == 3 and
             child.parent == root and
             grandchild.parent == child and
             root.parent == nil;

    objc_release(grandchild);
    objc_release(child);
    objc_release(root);
    return ok;
}

static int case_parent_allocator_propagation(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained CounterObject *root = [[CounterObject allocWithAllocator:&allocator] init];
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    if (root == nil or child == nil) {
        return 0;
    }

    int ok = root.allocator == &allocator and child.allocator == &allocator;
    objc_release(child);
    objc_release(root);
    return ok;
}

static int case_parent_getter_lifecycle(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *root = SFW_NEW(CounterObject);
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    if (child == nil or child.parent != root) {
        objc_release(child);
        objc_release(root);
        return 0;
    }

    objc_release(root);
    if (child.parent != nil or g_counter_deallocs != 1) {
        objc_release(child);
        return 0;
    }

    objc_release(child);
    return g_counter_deallocs == 2;
}

static int case_parent_child_outlives_parent(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained CounterObject *root = [[CounterObject allocWithAllocator:&allocator] init];
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    if (child == nil) {
        objc_release(root);
        return 0;
    }

    objc_release(root);
    if (ctx.free_calls != 0 or g_counter_deallocs != 1) {
        objc_release(child);
        return 0;
    }

    (void)child.hash;
    objc_release(child);
    return ctx.free_calls == 2 and ctx.active_blocks == 0 and g_counter_deallocs == 2;
}

static int case_parent_group_frees_on_last_release(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained CounterObject *root = [[CounterObject allocWithAllocator:&allocator] init];
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    __unsafe_unretained CounterObject *grandchild = [[CounterObject allocWithParent:child] init];
    if (grandchild == nil) {
        return 0;
    }

    objc_release(child);
    if (ctx.free_calls != 0 or g_counter_deallocs != 1) {
        objc_release(grandchild);
        objc_release(root);
        return 0;
    }

    objc_release(root);
    if (ctx.free_calls != 0 or g_counter_deallocs != 2) {
        objc_release(grandchild);
        return 0;
    }

    objc_release(grandchild);
    return ctx.free_calls == 3 and ctx.active_blocks == 0 and g_counter_deallocs == 3;
}

static int case_parent_nested_allocation_same_root(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained CounterObject *root = [[CounterObject allocWithAllocator:&allocator] init];
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    __unsafe_unretained CounterObject *grandchild = [[CounterObject allocWithParent:child] init];
    if (grandchild == nil) {
        return 0;
    }

    SFObjHeader_t *root_hdr = sf_header_from_object(root);
    objc_release(root);

    __unsafe_unretained CounterObject *great_grandchild = [[CounterObject allocWithParent:grandchild] init];
    if (great_grandchild == nil) {
        objc_release(grandchild);
        objc_release(child);
        return 0;
    }

    SFObjHeader_t *great_hdr = sf_header_from_object(great_grandchild);
    int ok = great_hdr != nullptr and sf_header_group_root(great_hdr) == root_hdr;

    objc_release(great_grandchild);
    objc_release(grandchild);
    objc_release(child);
    return ok and ctx.free_calls == 4 and ctx.active_blocks == 0;
}

static int case_parent_alloc_with_nil_parent(void)
{
    sf_test_reset_common_state();

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
#endif
    __unsafe_unretained CounterObject *obj = [[CounterObject allocWithParent:nil] init];
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
    if (obj == nil) {
        return 0;
    }

    SFObjHeader_t *hdr = sf_header_from_object(obj);
    int ok = hdr != nullptr and sf_header_group_root(hdr) == hdr and obj.parent == nil;
    objc_release(obj);
    return ok;
}

static int case_parent_dead_parent_rejects_new_child(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *root = SFW_NEW(CounterObject);
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    if (child == nil) {
        objc_release(root);
        return 0;
    }

    objc_release(root);
#if SF_RUNTIME_EXCEPTIONS
    int threw = 0;
    @try {
        (void)[[CounterObject allocWithParent:root] init];
    }
    @catch (AllocationFailedException *e) {
        threw = e != nil and e.exceptionBacktraceCount > 0;
    }
    if (not threw) {
        objc_release(child);
        return 0;
    }
#else
    __unsafe_unretained CounterObject *replacement = [CounterObject allocWithParent:root];
    if (replacement != nil) {
        replacement = [replacement init];
    }
    if (replacement != nil) {
        objc_release(replacement);
        objc_release(child);
        return 0;
    }
#endif

    objc_release(child);
    return g_counter_deallocs == 2;
}

static int case_parent_concurrent_alloc_release(void)
{
#if SF_RUNTIME_THREADSAFE
    sf_test_reset_common_state();

    enum { thread_count = 4,
           loops_per_thread = 2000 };
    pthread_t threads[thread_count];
    ParentThreadCtx ctx[thread_count];

    __unsafe_unretained CounterObject *root = SFW_NEW(CounterObject);
    if (root == nil) {
        return 0;
    }

    for (int i = 0; i < thread_count; ++i) {
        ctx[i].parent = root;
        ctx[i].loops = loops_per_thread;
        ctx[i].ok = 1;
        if (pthread_create(&threads[i], nullptr, parent_thread_main, &ctx[i]) != 0) {
            objc_release(root);
            return 0;
        }
    }

    for (int i = 0; i < thread_count; ++i) {
        if (pthread_join(threads[i], nullptr) != 0 or not ctx[i].ok) {
            objc_release(root);
            return 0;
        }
    }

    objc_release(root);
    return __atomic_load_n(&g_counter_deallocs, __ATOMIC_RELAXED) == (thread_count * loops_per_thread) + 1;
#else
    return 1;
#endif
}

static const SFTestCase g_parent_cases[] = {
    {"value_parent_layout_hidden_storage", case_value_parent_layout_hidden_storage},
    {"value_parent_alloc_embeds_in_parent", case_value_parent_alloc_embeds_in_parent},
    {"value_parent_nontrivial_inline_rejected", case_value_parent_nontrivial_inline_rejected},
    {"value_parent_duplicate_slots_reuse", case_value_parent_duplicate_slots_reuse},
    {"value_parent_child_expires_with_parent", case_value_parent_child_expires_with_parent},
    {"value_parent_standalone_heap_alloc", case_value_parent_standalone_heap_alloc},
    {"value_parent_slot_exhaustion", case_value_parent_slot_exhaustion},
    {"value_parent_oversized_subclass_rejected", case_value_parent_oversized_subclass_rejected},
    {"parent_group_inheritance", case_parent_group_inheritance},
    {"parent_allocator_propagation", case_parent_allocator_propagation},
    {"parent_getter_lifecycle", case_parent_getter_lifecycle},
    {"parent_child_outlives_parent", case_parent_child_outlives_parent},
    {"parent_group_frees_on_last_release", case_parent_group_frees_on_last_release},
    {"parent_nested_allocation_same_root", case_parent_nested_allocation_same_root},
    {"parent_alloc_with_nil_parent", case_parent_alloc_with_nil_parent},
    {"parent_dead_parent_rejects_new_child", case_parent_dead_parent_rejects_new_child},
    {"parent_concurrent_alloc_release", case_parent_concurrent_alloc_release},
};

const SFTestCase *sf_runtime_parent_cases(size_t *count)
{
    if (count != nullptr) {
        *count = sizeof(g_parent_cases) / sizeof(g_parent_cases[0]);
    }
    return g_parent_cases;
}
