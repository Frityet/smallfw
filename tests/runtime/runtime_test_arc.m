#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "runtime_test_support.h"

typedef struct SFTestOneMethodList {
    SFObjCMethodList_t *next;
    int32_t count;
    int64_t size;
    SFObjCMethod_t methods[1];
} SFTestOneMethodList;

typedef struct SFTestSelector {
    const char *name;
    const char *types;
} SFTestSelector;

typedef struct SFTestSyntheticClass {
    SFObjCClass_t cls;
    SFObjCClass_t meta;
    SFTestOneMethodList class_methods;
    SFTestOneMethodList instance_methods;
} SFTestSyntheticClass;

static SFTestSelector g_alloc_sel = {"allocWithAllocator:", "@24@0:8^v16"};
static SFTestSelector g_init_sel = {"init", "@16@0:8"};
static id g_last_synthetic_object = nil;

static id synthetic_alloc_imp(id self, SEL cmd, SFAllocator_t *allocator)
{
    (void)cmd;
    g_last_synthetic_object = sf_alloc_object((Class)self, allocator);
    return g_last_synthetic_object;
}

static id synthetic_init_imp(id self, SEL cmd)
{
    (void)cmd;
    return self;
}

static void init_synthetic_class(SFTestSyntheticClass *bundle, const char *name, int with_alloc, int with_init)
{
    memset(bundle, 0, sizeof(*bundle));
    bundle->cls.isa = &bundle->meta;
    bundle->cls.name = name;
    bundle->meta.isa = &bundle->meta;
    bundle->meta.name = name;
    if (with_alloc) {
        bundle->class_methods.count = 1;
        bundle->class_methods.size = (int64_t)sizeof(SFObjCMethod_t);
        bundle->class_methods.methods[0].imp = (IMP)synthetic_alloc_imp;
        bundle->class_methods.methods[0].selector = (SEL)&g_alloc_sel;
        bundle->class_methods.methods[0].types = g_alloc_sel.types;
        bundle->meta.methods = (SFObjCMethodList_t *)&bundle->class_methods;
    }
    if (with_init) {
        bundle->instance_methods.count = 1;
        bundle->instance_methods.size = (int64_t)sizeof(SFObjCMethod_t);
        bundle->instance_methods.methods[0].imp = (IMP)synthetic_init_imp;
        bundle->instance_methods.methods[0].selector = (SEL)&g_init_sel;
        bundle->instance_methods.methods[0].types = g_init_sel.types;
        bundle->cls.methods = (SFObjCMethodList_t *)&bundle->instance_methods;
    }
}

static int case_arc_nil_operations(void)
{
    id slot = nil;

    if (objc_retain(nil) != nil) {
        return 0;
    }
    objc_release(nil);
    if (objc_autorelease(nil) != nil) {
        return 0;
    }
    if (sf_autorelease(nil) != nil) {
        return 0;
    }
    objc_storeStrong(&slot, nil);
    return slot == nil;
}

static int case_arc_strong_store(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *first = SFW_NEW(CounterObject);
    __unsafe_unretained CounterObject *second = SFW_NEW(CounterObject);
    id slot = (id)first;

    objc_storeStrong(&slot, second);
    if (slot != second or g_counter_deallocs != 1) {
        objc_release(second);
        return 0;
    }

    objc_storeStrong(&slot, nil);
    objc_release(second);
    return g_counter_deallocs == 2;
}

static int case_arc_strong_store_self(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    id slot = nil;

    objc_storeStrong(&slot, obj);
    objc_release(obj);
    if (g_counter_deallocs != 0) {
        objc_storeStrong(&slot, nil);
        return 0;
    }

    objc_storeStrong(&slot, slot);
    if (g_counter_deallocs != 0) {
        objc_storeStrong(&slot, nil);
        return 0;
    }

    objc_storeStrong(&slot, nil);
    return g_counter_deallocs == 1;
}

static int case_arc_autorelease_pool(void)
{
    sf_test_reset_common_state();

    void *pool = objc_autoreleasePoolPush();
    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    id retained = objc_retainAutorelease(obj);
    objc_release(retained);
    if (g_counter_deallocs != 0) {
        objc_autoreleasePoolPop(pool);
        return 0;
    }

    objc_autoreleasePoolPop(pool);
    return g_counter_deallocs == 1;
}

static int case_arc_autorelease_no_pool(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    if (objc_autorelease(obj) != obj) {
        objc_release(obj);
        return 0;
    }
    if (g_counter_deallocs != 0) {
        objc_release(obj);
        return 0;
    }
    objc_release(obj);
    return g_counter_deallocs == 1;
}

static int case_arc_nested_autorelease_pools(void)
{
    sf_test_reset_common_state();

    void *outer = objc_autoreleasePoolPush();
    __unsafe_unretained CounterObject *outer_obj = SFW_NEW(CounterObject);
    objc_autorelease(outer_obj);

    void *inner = objc_autoreleasePoolPush();
    __unsafe_unretained CounterObject *inner_obj = SFW_NEW(CounterObject);
    objc_autorelease(inner_obj);

    objc_autoreleasePoolPop(inner);
    if (g_counter_deallocs != 1) {
        objc_autoreleasePoolPop(outer);
        return 0;
    }

    objc_autoreleasePoolPop(outer);
    return g_counter_deallocs == 2;
}

static int case_arc_marker_capacity_failure(void)
{
    sf_test_reset_common_state();
    sf_runtime_test_reset_autorelease_state();
    sf_runtime_test_fail_allocation_after(0);

    void *pool = objc_autoreleasePoolPush();

    sf_runtime_test_reset_alloc_failures();
    objc_autoreleasePoolPop(pool);
    return 1;
}

static int case_arc_autorelease_pool_fallback_token(void)
{
    sf_test_reset_common_state();
    sf_runtime_test_reset_autorelease_state();

    void *seed = objc_autoreleasePoolPush();
    objc_autoreleasePoolPop(seed);

    sf_runtime_test_fail_allocation_after(0);
    void *pool = objc_autoreleasePoolPush();
    sf_runtime_test_reset_alloc_failures();

    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    objc_autorelease(obj);
    objc_autoreleasePoolPop(pool);
    return g_counter_deallocs == 1;
}

static int case_arc_autorelease_capacity_failure(void)
{
    sf_test_reset_common_state();
    sf_runtime_test_reset_autorelease_state();

    void *pool = objc_autoreleasePoolPush();
    sf_runtime_test_fail_allocation_after(0);
    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    objc_autorelease(obj);
    sf_runtime_test_reset_alloc_failures();

    objc_autoreleasePoolPop(pool);
    if (g_counter_deallocs != 0) {
        return 0;
    }

    objc_release(obj);
    return g_counter_deallocs == 1;
}

static int case_arc_factory_return(void)
{
    CounterObject *obj = sf_test_factory_object();
    int ok = (obj != nil);
    obj = nil;
    return ok;
}

static int case_arc_retain_release_balance(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    if (obj == nil) {
        return 0;
    }

    objc_retain((id)obj);
    objc_retain((id)obj);
    objc_release((id)obj);
    if (g_counter_deallocs != 0) {
        return 0;
    }

    objc_release((id)obj);
    if (g_counter_deallocs != 0) {
        return 0;
    }

    objc_release((id)obj);
    return g_counter_deallocs == 1;
}

static int case_arc_dead_object_noop_release(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *parent = SFW_NEW(CounterObject);
    __unsafe_unretained CounterObject *child = [[CounterObject allocWithParent:parent] init];
    if (child == nil) {
        objc_release(parent);
        return 0;
    }

    objc_release(parent);
    if (g_counter_deallocs != 1) {
        objc_release(child);
        return 0;
    }

    objc_release(parent);
    objc_retain(parent);
    if (g_counter_deallocs != 1) {
        objc_release(child);
        return 0;
    }

    objc_release(child);
    return g_counter_deallocs == 2;
}

static int case_arc_return_value_helpers(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained CounterObject *first = SFW_NEW(CounterObject);
    id retained = objc_retainAutoreleasedReturnValue(first);
    objc_release(retained);

    void *pool = objc_autoreleasePoolPush();
    objc_autoreleaseReturnValue(first);
    objc_autoreleasePoolPop(pool);
    if (g_counter_deallocs != 1) {
        return 0;
    }

    __unsafe_unretained CounterObject *second = SFW_NEW(CounterObject);
    pool = objc_autoreleasePoolPush();
    id temp = objc_retainAutoreleaseReturnValue(second);
    objc_release(temp);
    objc_autoreleasePoolPop(pool);
    return g_counter_deallocs == 2;
}

static int case_arc_object_method_wrappers(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained Object *root = [[Object allocWithAllocator:&allocator] init];
    __unsafe_unretained Object *child = [[Object allocWithParent:root] init];
    if (root == nil or child == nil) {
        return 0;
    }
    if (root.allocator != &allocator or child.allocator != &allocator) {
        [child release];
        [root release];
        return 0;
    }
    if (child.parent != root or root.parent != nil) {
        [child release];
        [root release];
        return 0;
    }
    if (![root isEqual:root] or [root isEqual:child]) {
        [child release];
        [root release];
        return 0;
    }
    if (root.hash != (unsigned long)sf_hash_ptr(root)) {
        [child release];
        [root release];
        return 0;
    }
    if (sf_exception_backtrace_count(root) != 0 or sf_exception_backtrace_frame(root, 0) != nullptr) {
        [child release];
        [root release];
        return 0;
    }
    if (objc_msgSend(root, @selector(retain)) != root) {
        [child release];
        [root release];
        [root release];
        return 0;
    }

    void *pool = objc_autoreleasePoolPush();
    if (objc_msgSend(root, @selector(autorelease)) != root) {
        objc_autoreleasePoolPop(pool);
        [child release];
        [root release];
        return 0;
    }
    objc_autoreleasePoolPop(pool);
    (void)objc_msgSend(child, @selector(release));
    (void)objc_msgSend(root, @selector(release));
    return ctx.alloc_calls == 2 and ctx.free_calls == 2 and ctx.active_blocks == 0;
}

static int case_arc_object_nonheap_fallbacks(void)
{
    sf_test_reset_common_state();

    SFObjCClass_t *object_class = (SFObjCClass_t *)objc_getClass("Object");
    struct {
        SFObjCClass_t *isa;
    } fake = {.isa = object_class};
    __unsafe_unretained Object *fake_obj = (Object *)&fake;

    if (fake_obj.allocator != sf_default_allocator() or
        fake_obj.parent != nil or
        sf_exception_backtrace_count(fake_obj) != 0 or
        sf_exception_backtrace_frame(fake_obj, 0) != nullptr) {
        return 0;
    }

    __unsafe_unretained Object *obj = SFW_NEW(Object);
    if (obj == nil) {
        return 0;
    }

    SFObjHeader_t *hdr = sf_header_from_object(obj);
    if (hdr == nullptr) {
        objc_release(obj);
        return 0;
    }

    SFAllocator_t *saved_allocator = sf_header_allocator(hdr);
    id saved_parent = sf_header_parent(hdr);

    if (not sf_header_set_allocator(hdr, nullptr) or not sf_header_set_parent(hdr, fake_obj)) {
        objc_release(obj);
        return 0;
    }
    int ok = obj.allocator == sf_default_allocator() and obj.parent == nil;

    (void)sf_header_set_parent(hdr, saved_parent);
    (void)sf_header_set_allocator(hdr, saved_allocator);
    objc_release(obj);
    return ok;
}

static int case_arc_object_alloc_in_place(void)
{
    sf_test_reset_common_state();

    struct {
        SFObjHeader_t hdr;
        Class isa;
    } storage;

    __unsafe_unretained CounterObject *obj = [[CounterObject allocInPlace:&storage size:sizeof(storage)] init];
    if (obj == nil) {
        return 0;
    }
    if (obj.allocator != sf_default_allocator() or obj.parent != nil or sf_object_class(obj) != (Class)objc_getClass("CounterObject")) {
        return 0;
    }

    objc_release(obj);
    return objc_retain(obj) == obj and g_counter_deallocs == 0 and [CounterObject allocInPlace:nullptr size:sizeof(storage)] == nil;
}

static int case_arc_objc_alloc_init_success(void)
{
    sf_test_reset_common_state();

    SFTestSyntheticClass bundle;
    g_last_synthetic_object = nil;
    init_synthetic_class(&bundle, "SyntheticAllocInit", 1, 1);

    __unsafe_unretained Object *obj = (Object *)objc_alloc_init((Class)&bundle.cls);
    if (obj == nil) {
        return 0;
    }

    sf_object_dispose(obj);
    return 1;
}

static int case_arc_large_autorelease_growth(void)
{
    sf_test_reset_common_state();
    sf_runtime_test_reset_autorelease_state();

    void *pool = objc_autoreleasePoolPush();
    for (int i = 0; i < 129; ++i) {
        __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
        objc_autorelease(obj);
    }
    objc_autoreleasePoolPop(pool);
    return g_counter_deallocs == 129;
}

static int case_arc_large_marker_growth(void)
{
    sf_test_reset_common_state();
    sf_runtime_test_reset_autorelease_state();

    void *pools[17];
    for (int i = 0; i < 17; ++i) {
        pools[i] = objc_autoreleasePoolPush();
        if (pools[i] == nullptr) {
            while (i-- > 0) {
                objc_autoreleasePoolPop(pools[i]);
            }
            return 0;
        }
    }
    for (int i = 16; i >= 0; --i) {
        objc_autoreleasePoolPop(pools[i]);
    }
    return 1;
}

static int case_arc_pool_pop_marker_clamp(void)
{
    sf_runtime_test_reset_autorelease_state();

    size_t *bogus = (size_t *)malloc(sizeof(size_t));
    if (bogus == nullptr) {
        return 0;
    }
    *bogus = 999;
    objc_autoreleasePoolPop(bogus);
    return 1;
}

static int case_arc_dispose_edge_paths(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained Object *obj = [[Object allocWithAllocator:sf_default_allocator()] init];
    if (obj == nil) {
        return 0;
    }

    SFObjHeader_t *hdr = sf_header_from_object(obj);
    if (hdr == nullptr) {
        [obj release];
        return 0;
    }

    (void)objc_retain(obj);
    sf_object_dispose(nil);
    objc_release(obj);

    hdr->state = SF_OBJ_STATE_DISPOSED;
    sf_object_dispose(obj);
#if SF_RUNTIME_VALIDATION
    if (hdr->magic != SF_OBJ_HEADER_MAGIC) {
        return 0;
    }
#endif

    hdr->state = SF_OBJ_STATE_LIVE;
    hdr->refcount = 0;
    objc_release(obj);
#if SF_RUNTIME_VALIDATION
    if (hdr->magic != SF_OBJ_HEADER_MAGIC) {
        return 0;
    }
#endif

    hdr->refcount = 1;
    sf_object_dispose(obj);
    return 1;
}

static int case_arc_runtime_test_alloc_wrappers(void)
{
    void *p = sf_runtime_test_malloc(8);
    void *q = sf_runtime_test_calloc(2, 8);
    if (p == nullptr or q == nullptr) {
        free(p);
        free(q);
        return 0;
    }

    q = sf_runtime_test_realloc(q, 64);
    if (q == nullptr) {
        free(p);
        return 0;
    }

    sf_runtime_test_fail_allocation_after(0);
    if (sf_runtime_test_malloc(1) != nullptr) {
        sf_runtime_test_reset_alloc_failures();
        free(p);
        free(q);
        return 0;
    }
    sf_runtime_test_fail_allocation_after(0);
    if (sf_runtime_test_calloc(1, 1) != nullptr) {
        sf_runtime_test_reset_alloc_failures();
        free(p);
        free(q);
        return 0;
    }
    sf_runtime_test_fail_allocation_after(0);
    if (sf_runtime_test_realloc(q, 128) != nullptr) {
        sf_runtime_test_reset_alloc_failures();
        free(p);
        free(q);
        return 0;
    }

    sf_runtime_test_reset_alloc_failures();
    free(p);
    free(q);
    return 1;
}

static int case_arc_objc_alloc_null(void)
{
    return objc_alloc(nullptr) == nil and objc_alloc_init(nullptr) == nil;
}

static int case_arc_objc_alloc_missing_alloc(void)
{
    SFTestSyntheticClass bundle;

    init_synthetic_class(&bundle, "SyntheticMissingAlloc", 0, 0);
    return objc_alloc((Class)&bundle.cls) == nil;
}

static int case_arc_objc_alloc_init_missing_init(void)
{
    SFTestSyntheticClass bundle;

    g_last_synthetic_object = nil;
    init_synthetic_class(&bundle, "SyntheticMissingInit", 1, 0);
    if (objc_alloc_init((Class)&bundle.cls) != nil) {
        return 0;
    }
    if (g_last_synthetic_object != nil) {
        sf_object_dispose(g_last_synthetic_object);
        g_last_synthetic_object = nil;
    }
    return 1;
}

static int case_allocator_custom_alloc_free(void)
{
    sf_test_reset_common_state();

    SFTestAllocatorCtx ctx = {0};
    SFAllocator_t allocator = sf_test_make_counting_allocator(&ctx);

    __unsafe_unretained AllocTracked *obj = [[AllocTracked allocWithAllocator:&allocator] init];
    if (obj == nil) {
        return 0;
    }

    sf_object_dispose(obj);
    return ctx.alloc_calls == 1 and ctx.free_calls == 1 and ctx.active_blocks == 0;
}

static int case_allocator_default_alignment(void)
{
    SFAllocator_t *allocator = sf_default_allocator();
    void *ptr = allocator->alloc(allocator->ctx, 128, 64);
    if (ptr == nullptr) {
        return 0;
    }
    int ok = (((uintptr_t)ptr) & (uintptr_t)63) == 0;
    allocator->free(allocator->ctx, ptr, 128, 64);
    return ok;
}

static int case_allocator_default_invalid_alignment(void)
{
    SFAllocator_t *allocator = sf_default_allocator();
    void *ptr = allocator->alloc(allocator->ctx, 16, 24);
    if (ptr != nullptr) {
        allocator->free(allocator->ctx, ptr, 16, 24);
        return 0;
    }
    return 1;
}

static const SFTestCase g_arc_cases[] = {
    {"arc_nil_operations", case_arc_nil_operations},
    {"arc_strong_store", case_arc_strong_store},
    {"arc_strong_store_self", case_arc_strong_store_self},
    {"arc_autorelease_pool", case_arc_autorelease_pool},
    {"arc_autorelease_no_pool", case_arc_autorelease_no_pool},
    {"arc_nested_autorelease_pools", case_arc_nested_autorelease_pools},
    {"arc_marker_capacity_failure", case_arc_marker_capacity_failure},
    {"arc_autorelease_pool_fallback_token", case_arc_autorelease_pool_fallback_token},
    {"arc_autorelease_capacity_failure", case_arc_autorelease_capacity_failure},
    {"arc_factory_return", case_arc_factory_return},
    {"arc_retain_release_balance", case_arc_retain_release_balance},
    {"arc_dead_object_noop_release", case_arc_dead_object_noop_release},
    {"arc_return_value_helpers", case_arc_return_value_helpers},
    {"arc_object_method_wrappers", case_arc_object_method_wrappers},
    {"arc_object_nonheap_fallbacks", case_arc_object_nonheap_fallbacks},
    {"arc_object_alloc_in_place", case_arc_object_alloc_in_place},
    {"arc_objc_alloc_init_success", case_arc_objc_alloc_init_success},
    {"arc_large_autorelease_growth", case_arc_large_autorelease_growth},
    {"arc_large_marker_growth", case_arc_large_marker_growth},
    {"arc_pool_pop_marker_clamp", case_arc_pool_pop_marker_clamp},
    {"arc_dispose_edge_paths", case_arc_dispose_edge_paths},
    {"arc_runtime_test_alloc_wrappers", case_arc_runtime_test_alloc_wrappers},
    {"arc_objc_alloc_null", case_arc_objc_alloc_null},
    {"arc_objc_alloc_missing_alloc", case_arc_objc_alloc_missing_alloc},
    {"arc_objc_alloc_init_missing_init", case_arc_objc_alloc_init_missing_init},
    {"allocator_custom_alloc_free", case_allocator_custom_alloc_free},
    {"allocator_default_alignment", case_allocator_default_alignment},
    {"allocator_default_invalid_alignment", case_allocator_default_invalid_alignment},
};

const SFTestCase *sf_runtime_arc_cases(size_t *count)
{
    if (count != nullptr) {
        *count = sizeof(g_arc_cases) / sizeof(g_arc_cases[0]);
    }
    return g_arc_cases;
}
