#include <pthread.h>
#include <string.h>

#include "runtime_test_support.h"

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpre-c23-compat"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#pragma clang diagnostic ignored "-Wpadded"
#endif

typedef struct ParentThreadCtx {
    Object *parent;
    int loops;
    int ok;
} ParentThreadCtx;

#if SF_RUNTIME_THREADSAFE
static void *parent_thread_main(void *arg) {
    ParentThreadCtx *ctx = (ParentThreadCtx *)arg;

    for (int i = 0; i < ctx->loops; ++i) {
        __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:ctx->parent] init];
        if (child == nil) {
            ctx->ok = 0;
            return NULL;
        }
        objc_release(child);
    }

    return NULL;
}
#endif

static int case_parent_group_inheritance(void) {
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained CounterObject *root = [[CounterObject allocWithAllocator:&allocator] init];
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    __unsafe_unretained CounterObject *grandchild = [[CounterObject allocWithParent:child] init];
    if (root == nil || child == nil || grandchild == nil) {
        return 0;
    }

    SFObjHeader_t *root_hdr = sf_header_from_object(root);
    SFObjHeader_t *child_hdr = sf_header_from_object(child);
    SFObjHeader_t *grandchild_hdr = sf_header_from_object(grandchild);
    int ok = root_hdr != NULL &&
             child_hdr != NULL &&
             grandchild_hdr != NULL &&
             sf_header_group_root(child_hdr) == root_hdr &&
             sf_header_group_root(grandchild_hdr) == root_hdr &&
             sf_header_group_live_count(root_hdr) == 3 &&
             child.parent == root &&
             grandchild.parent == child &&
             root.parent == nil;

    objc_release(grandchild);
    objc_release(child);
    objc_release(root);
    return ok;
}

static int case_parent_allocator_propagation(void) {
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained CounterObject *root = [[CounterObject allocWithAllocator:&allocator] init];
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    if (root == nil || child == nil) {
        return 0;
    }

    int ok = [root allocator] == &allocator && [child allocator] == &allocator;
    objc_release(child);
    objc_release(root);
    return ok;
}

static int case_parent_getter_lifecycle(void) {
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *root = SFW_NEW(CounterObject);
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:root] init];
    if (child == nil || child.parent != root) {
        objc_release(child);
        objc_release(root);
        return 0;
    }

    objc_release(root);
    if (child.parent != nil || g_counter_deallocs != 1) {
        objc_release(child);
        return 0;
    }

    objc_release(child);
    return g_counter_deallocs == 2;
}

static int case_parent_child_outlives_parent(void) {
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
    if (ctx.free_calls != 0 || g_counter_deallocs != 1) {
        objc_release(child);
        return 0;
    }

    (void)[child hash];
    objc_release(child);
    return ctx.free_calls == 2 && ctx.active_blocks == 0 && g_counter_deallocs == 2;
}

static int case_parent_group_frees_on_last_release(void) {
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
    if (ctx.free_calls != 0 || g_counter_deallocs != 1) {
        objc_release(grandchild);
        objc_release(root);
        return 0;
    }

    objc_release(root);
    if (ctx.free_calls != 0 || g_counter_deallocs != 2) {
        objc_release(grandchild);
        return 0;
    }

    objc_release(grandchild);
    return ctx.free_calls == 3 && ctx.active_blocks == 0 && g_counter_deallocs == 3;
}

static int case_parent_nested_allocation_same_root(void) {
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
    int ok = great_hdr != NULL && sf_header_group_root(great_hdr) == root_hdr;

    objc_release(great_grandchild);
    objc_release(grandchild);
    objc_release(child);
    return ok && ctx.free_calls == 4 && ctx.active_blocks == 0;
}

static int case_parent_alloc_with_nil_parent(void) {
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
    int ok = hdr != NULL && sf_header_group_root(hdr) == hdr && obj.parent == nil;
    objc_release(obj);
    return ok;
}

static int case_parent_dead_parent_rejects_new_child(void) {
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
        threw = e != nil && e.exceptionBacktraceCount > 0;
    }
    if (!threw) {
        objc_release(child);
        return 0;
    }
    #else
    if ([[CounterObject allocWithParent:root] init] != nil) {
        objc_release(child);
        return 0;
    }
    #endif

    objc_release(child);
    return g_counter_deallocs == 2;
}

static int case_parent_concurrent_alloc_release(void) {
#if SF_RUNTIME_THREADSAFE
    sf_test_reset_common_state();

    enum { thread_count = 4, loops_per_thread = 2000 };
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
        if (pthread_create(&threads[i], NULL, parent_thread_main, &ctx[i]) != 0) {
            objc_release(root);
            return 0;
        }
    }

    for (int i = 0; i < thread_count; ++i) {
        if (pthread_join(threads[i], NULL) != 0 || !ctx[i].ok) {
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

const SFTestCase *sf_runtime_parent_cases(size_t *count) {
    if (count != NULL) {
        *count = sizeof(g_parent_cases) / sizeof(g_parent_cases[0]);
    }
    return g_parent_cases;
}

#ifdef __clang__
#pragma clang diagnostic pop
#endif
