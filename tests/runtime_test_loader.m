#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <dlfcn.h>
#endif

#include "runtime_test_support.h"

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpre-c23-compat"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#pragma clang diagnostic ignored "-Wpadded"
#endif

typedef struct SFTestAliasEntry {
    const char *alias_name;
    Class *class_ref;
} SFTestAliasEntry;

typedef struct SFTestSelector {
    const char *name;
    const char *types;
} SFTestSelector;

typedef struct SFTestIvarListTwo {
    uintptr_t count;
    uintptr_t item_size;
    SFObjCIvar_t ivars[2];
} SFTestIvarListTwo;

typedef struct SFTestManualClass {
    SFObjCClass_t cls;
    SFObjCClass_t meta;
} SFTestManualClass;

typedef struct ClassLookupThreadCtx {
    const char **names;
    Class *expected;
    int name_count;
    int loops;
    int ok;
} ClassLookupThreadCtx;

typedef struct SFTestFailAllocCtx {
    int alloc_calls;
} SFTestFailAllocCtx;

typedef struct SFTestMethodListOne {
    SFObjCMethodList_t *next;
    int32_t count;
    int64_t size;
    SFObjCMethod_t methods[1];
} SFTestMethodListOne;

typedef struct SFTestInheritBundle {
    SFTestManualClass parent;
    SFTestManualClass child;
    SFTestMethodListOne methods;
} SFTestInheritBundle;

typedef struct SFTestIvarListOne {
    uintptr_t count;
    uintptr_t item_size;
    SFObjCIvar_t ivars[1];
} SFTestIvarListOne;

typedef struct SFTestIvarInheritBundle {
    SFTestManualClass parent;
    SFTestManualClass child;
    SFTestIvarListOne ivars;
} SFTestIvarInheritBundle;

#if SF_RUNTIME_THREADSAFE
static void *class_lookup_thread_main(void *arg) {
    ClassLookupThreadCtx *ctx = (ClassLookupThreadCtx *)arg;

    for (int i = 0; i < ctx->loops; ++i) {
        for (int n = 0; n < ctx->name_count; ++n) {
            Class cls = (Class)objc_getClass(ctx->names[n]);
            if (cls == Nil || cls != ctx->expected[n]) {
                ctx->ok = 0;
                return NULL;
            }
        }
    }

    return NULL;
}
#endif

#if SF_RUNTIME_REFLECTION
static void ensure_extra_registered_classes(void) {
    static int initialized = 0;
    static SFTestManualClass bundles[12];
    static const char *names[12] = {
        "ExtraCoverageClass0", "ExtraCoverageClass1", "ExtraCoverageClass2", "ExtraCoverageClass3",
        "ExtraCoverageClass4", "ExtraCoverageClass5", "ExtraCoverageClass6", "ExtraCoverageClass7",
        "ExtraCoverageClass8", "ExtraCoverageClass9", "ExtraCoverageClass10", "ExtraCoverageClass11",
    };

    if (initialized) {
        return;
    }

    SFObjCClass_t *classes[12];
    for (int i = 0; i < 12; ++i) {
        memset(&bundles[i], 0, sizeof(bundles[i]));
        bundles[i].cls.isa = &bundles[i].meta;
        bundles[i].cls.superclass = (SFObjCClass_t *)objc_getClass("Object");
        bundles[i].cls.name = names[i];
        bundles[i].meta.isa = &bundles[i].meta;
        bundles[i].meta.superclass = &bundles[i].meta;
        bundles[i].meta.name = names[i];
        classes[i] = &bundles[i].cls;
    }

    sf_register_classes(classes, classes + 12);
    sf_finalize_registered_classes();
    initialized = 1;
}
#endif

static void *fail_alloc_once(void *ctx, size_t size, size_t align) {
    SFTestFailAllocCtx *state = (SFTestFailAllocCtx *)ctx;
    (void)size;
    (void)align;
    state->alloc_calls += 1;
    return NULL;
}

static void fail_alloc_free(void *ctx, void *ptr, size_t size, size_t align) {
    (void)ctx;
    (void)size;
    (void)align;
    free(ptr);
}

static int case_no_libobjc_dependency(void) {
#if defined(_WIN32)
    return GetModuleHandleA("libobjc.dll") == NULL &&
           GetModuleHandleA("objc.dll") == NULL;
#else
    void *h = dlopen("libobjc.so.4", RTLD_LAZY | RTLD_NOLOAD);
    if (h != NULL) {
        dlclose(h);
        return 0;
    }
    return 1;
#endif
}

static int case_loader_lookup_nulls(void) {
    static SFTestSelector ping_sel = {"ping", "i16@0:8"};

    sf_register_classes(NULL, NULL);
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
#endif
    sf_register_live_object_header(NULL);
    sf_unregister_live_object_header(NULL);
#if defined(__clang__)
#pragma clang diagnostic pop
#endif
    __objc_load(NULL);
    sf_finalize_registered_classes();
    return sf_class_from_name(NULL) == NULL &&
           objc_getClass(NULL) == nil &&
           objc_lookup_class(NULL) == nil &&
           class_getInstanceSize(NULL) == sizeof(void *) &&
           sf_object_class(nil) == Nil &&
           sf_header_from_object(nil) == NULL &&
           sf_object_is_heap(nil) == 0 &&
           sf_cached_class_object() == objc_getClass("Object") &&
           sf_lookup_imp_in_class(NULL, (SEL)&ping_sel) == NULL;
}

static int case_loader_lookup_missing(void) {
    return objc_getClass("DefinitelyMissingRuntimeClass") == nil &&
           objc_lookup_class("DefinitelyMissingRuntimeClass") == nil;
}

static int case_loader_header_validation(void) {
    unsigned char storage[sizeof(SFObjHeader_t) + sizeof(void *)];
    memset(storage, 0, sizeof(storage));
    id fake = (id)(void *)(storage + sizeof(SFObjHeader_t));

#if SF_RUNTIME_VALIDATION
    if (sf_header_from_object(fake) != NULL || sf_object_is_heap(fake) != 0) {
        return 0;
    }
#else
    if (sf_header_from_object(fake) != (SFObjHeader_t *)(void *)storage || sf_object_is_heap(fake) != 0) {
        return 0;
    }
#endif

    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    SFObjHeader_t *hdr = sf_header_from_object(obj);
    int ok = hdr != NULL && sf_object_is_heap(obj) != 0;
    objc_release(obj);
    return ok;
}

static int case_loader_header_size_modes(void) {
#if SF_RUNTIME_VALIDATION
    return sizeof(SFObjHeader_t) >= 64;
#else
    return sizeof(SFObjHeader_t) >= 48 && sizeof(SFObjHeader_t) < 64;
#endif
}

static int case_loader_manual_registration(void) {
    static int initialized = 0;
    static SFTestManualClass bundle;
    static SFTestManualClass empty_name_bundle;
    static Class bundle_class_ref = Nil;

    if (!initialized) {
        memset(&bundle, 0, sizeof(bundle));
        memset(&empty_name_bundle, 0, sizeof(empty_name_bundle));
        bundle.cls.isa = &bundle.meta;
        bundle.cls.superclass = (SFObjCClass_t *)objc_getClass("Object");
        bundle.cls.name = "ManualRegisteredClass";
        bundle.meta.isa = &bundle.meta;
        bundle.meta.superclass = &bundle.meta;
        bundle.meta.name = "ManualRegisteredClassMeta";
        empty_name_bundle.cls.isa = &empty_name_bundle.meta;
        empty_name_bundle.cls.name = "";
        empty_name_bundle.meta.isa = &empty_name_bundle.meta;
        bundle_class_ref = (Class)&bundle.cls;

        SFObjCClass_t *classes[] = {NULL, &empty_name_bundle.cls, &bundle.cls};
        Class null_class = Nil;
        SFTestAliasEntry aliases[] = {
            {.alias_name = NULL, .class_ref = &bundle_class_ref},
            {.alias_name = "ManualAliasNullRef", .class_ref = NULL},
            {.alias_name = "ManualAliasNilClass", .class_ref = &null_class},
            {.alias_name = "ManualAliasClass", .class_ref = &bundle_class_ref},
        };
        SFObjCInit_t init = {
            .classes_start = classes,
            .classes_stop = classes + 3,
            .aliases_start = aliases,
            .aliases_stop = aliases + 4,
        };
        __objc_load(&init);
        initialized = 1;
    }

    return objc_getClass("ManualRegisteredClass") == (id)&bundle.cls &&
           objc_getClass("ManualAliasClass") == (id)&bundle.cls;
}

static int case_loader_class_size_synthetic(void) {
    SFTestManualClass bundle;
    SFTestIvarListTwo ivars;
    int32_t first_offset = INT32_MIN;
    int32_t second_offset = INT32_MAX;

    memset(&bundle, 0, sizeof(bundle));
    memset(&ivars, 0, sizeof(ivars));

    ivars.count = 2;
    ivars.item_size = 1;
    ivars.ivars[0].name = "_first";
    ivars.ivars[0].type = "i";
    ivars.ivars[0].offset = &first_offset;
    ivars.ivars[0].size = 0;
    ivars.ivars[1].name = "_second";
    ivars.ivars[1].type = "i";
    ivars.ivars[1].offset = &second_offset;
    ivars.ivars[1].size = 4;

    bundle.cls.isa = &bundle.meta;
    bundle.cls.superclass = (SFObjCClass_t *)objc_getClass("Object");
    bundle.cls.name = "SyntheticLayoutClass";
    bundle.cls.ivars = &ivars;
    bundle.meta.isa = &bundle.meta;
    bundle.meta.superclass = &bundle.meta;
    bundle.meta.name = "SyntheticLayoutClassMeta";

    size_t size0 = class_getInstanceSize((Class)&bundle.cls);
    size_t size1 = class_getInstanceSize((Class)&bundle.cls);
    return size0 == size1 && size0 >= sizeof(void *) && first_offset == 0 && second_offset == INT32_MAX;
}

static int case_loader_hash_helpers(void) {
    static const unsigned char data[] = {1, 2, 3, 4};
    return sf_cstr_len(NULL) == 0 &&
           sf_cstr_len("abc") == 3 &&
           sf_hash_bytes(data, sizeof(data)) == sf_hash_bytes(data, sizeof(data)) &&
           sf_hash_ptr(data) == sf_hash_ptr(data) &&
           sf_class_name_of_object(nil) != NULL;
}

static int case_loader_alloc_failure_paths(void) {
    SFTestFailAllocCtx ctx = {0};
    SFAllocator_t allocator = {
        .alloc = fail_alloc_once,
        .free = fail_alloc_free,
        .ctx = &ctx,
    };

    if (sf_alloc_object((Class)objc_getClass("Object"), &allocator) != nil || ctx.alloc_calls != 1) {
        return 0;
    }

    __unsafe_unretained Object *root = [[Object allocWithAllocator:sf_default_allocator()] init];
    if (root == nil) {
        return 0;
    }

    SFObjHeader_t *hdr = sf_header_from_object(root);
    if (hdr == NULL) {
        [root release];
        return 0;
    }

    SFAllocator_t *saved_allocator = sf_header_allocator(hdr);
    if (!sf_header_set_allocator(hdr, &allocator)) {
        [root release];
        return 0;
    }
    if (sf_alloc_object_with_parent((Class)objc_getClass("Object"), root) != nil || ctx.alloc_calls != 2) {
        (void)sf_header_set_allocator(hdr, saved_allocator);
        [root release];
        return 0;
    }

    hdr->state = SF_OBJ_STATE_DISPOSED;
    if (sf_alloc_object_with_parent((Class)objc_getClass("Object"), root) != nil) {
        hdr->state = SF_OBJ_STATE_LIVE;
        (void)sf_header_set_allocator(hdr, saved_allocator);
        [root release];
        return 0;
    }

    hdr->state = SF_OBJ_STATE_LIVE;
    (void)sf_header_set_allocator(hdr, saved_allocator);
    [root release];
    return 1;
}

static int case_loader_class_name_live_object(void) {
    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    if (obj == nil) {
        return 0;
    }

    const char *name = sf_class_name_of_object(obj);
    objc_release(obj);
    return name != NULL && strcmp(name, "CounterObject") == 0;
}

#if SF_RUNTIME_REFLECTION
static id inherited_probe(id self, SEL cmd, ...) {
    (void)cmd;
    return self;
}

static int case_reflection_class_lookup(void) {
    Class cls = (Class)objc_getClass("ReflectionProbe");
    Class super_cls = (Class)objc_getClass("Object");
    unsigned int count = 0;
    Class *list = NULL;
    int found = 0;

    if (cls == Nil || super_cls == Nil) {
        return 0;
    }
    if (class_getName(cls) == NULL || strcmp(class_getName(cls), "ReflectionProbe") != 0) {
        return 0;
    }
    if (class_getSuperclass(cls) != super_cls) {
        return 0;
    }
    if (object_getClass((id)cls) != objc_getMetaClass("ReflectionProbe")) {
        return 0;
    }

    list = objc_copyClassList(&count);
    if (count == 0 || list == NULL) {
        free((void *)list);
        return 0;
    }

    for (unsigned int i = 0; i < count; ++i) {
        if (list[i] == cls) {
            found = 1;
            break;
        }
    }
    free((void *)list);
    return found;
}

static int case_reflection_inherited_method_lookup(void) {
    static int initialized = 0;
    static SFTestInheritBundle bundle;
    static SFTestSelector inherited_sel = {"inheritedPing", "@16@0:8"};

    if (!initialized) {
        memset(&bundle, 0, sizeof(bundle));
        bundle.parent.cls.isa = &bundle.parent.meta;
        bundle.parent.cls.superclass = (SFObjCClass_t *)objc_getClass("Object");
        bundle.parent.cls.name = "ReflectionMethodParent";
        bundle.parent.meta.isa = &bundle.parent.meta;
        bundle.parent.meta.superclass = &bundle.parent.meta;
        bundle.parent.meta.name = "ReflectionMethodParentMeta";

        bundle.child.cls.isa = &bundle.child.meta;
        bundle.child.cls.superclass = &bundle.parent.cls;
        bundle.child.cls.name = "ReflectionMethodChild";
        bundle.child.meta.isa = &bundle.child.meta;
        bundle.child.meta.superclass = &bundle.parent.meta;
        bundle.child.meta.name = "ReflectionMethodChildMeta";

        bundle.methods.count = 1;
        bundle.methods.size = (int64_t)sizeof(SFObjCMethod_t);
        bundle.methods.methods[0].imp = (IMP)inherited_probe;
        bundle.methods.methods[0].selector = (SEL)&inherited_sel;
        bundle.methods.methods[0].types = inherited_sel.types;
        bundle.parent.cls.methods = (SFObjCMethodList_t *)&bundle.methods;

        SFObjCClass_t *classes[] = {&bundle.parent.cls, &bundle.child.cls};
        sf_register_classes(classes, classes + 2);
        sf_finalize_registered_classes();
        initialized = 1;
    }

    Method method = class_getInstanceMethod((Class)&bundle.child.cls, (SEL)&inherited_sel);
    return method != NULL &&
           method_getImplementation(method) != NULL &&
           method_getTypeEncoding(method) != NULL;
}

static int case_reflection_method_lookup(void) {
    Class cls = (Class)objc_getClass("ReflectionProbe");
    SEL instance_sel = sel_registerName("instancePing");
    SEL class_sel = sel_registerName("classPing");
    Method instance_method = NULL;
    Method class_method = NULL;
    Method *method_list = NULL;
    unsigned int count = 0;
    int found_instance = 0;

    if (cls == Nil || instance_sel == NULL || class_sel == NULL) {
        return 0;
    }

    instance_method = class_getInstanceMethod(cls, instance_sel);
    class_method = class_getClassMethod(cls, class_sel);
    if (instance_method == NULL || class_method == NULL) {
        return 0;
    }
    if (method_getName(instance_method) == NULL || !sel_isEqual(method_getName(instance_method), instance_sel)) {
        return 0;
    }
    if (method_getImplementation(instance_method) == NULL || method_getTypeEncoding(instance_method) == NULL) {
        return 0;
    }

    method_list = class_copyMethodList(cls, &count);
    if (count == 0 || method_list == NULL) {
        free((void *)method_list);
        return 0;
    }

    for (unsigned int i = 0; i < count; ++i) {
        SEL sel = method_getName(method_list[i]);
        if (sel != NULL && sel_isEqual(sel, instance_sel)) {
            found_instance = 1;
            break;
        }
    }
    free((void *)method_list);
    return found_instance;
}

static int case_reflection_ivar_lookup(void) {
    Class cls = (Class)objc_getClass("ReflectionProbe");
    Ivar ivar = NULL;
    Ivar *ivars = NULL;
    unsigned int count = 0;
    int found = 0;

    if (cls == Nil) {
        return 0;
    }

    ivar = class_getInstanceVariable(cls, "_value");
    if (ivar == NULL) {
        return 0;
    }
    if (ivar_getName(ivar) == NULL || strcmp(ivar_getName(ivar), "_value") != 0) {
        return 0;
    }
    if (ivar_getTypeEncoding(ivar) == NULL) {
        return 0;
    }
    if (ivar_getOffset(ivar) < 0) {
        return 0;
    }

    ivars = class_copyIvarList(cls, &count);
    if (count == 0 || ivars == NULL) {
        free((void *)ivars);
        return 0;
    }

    for (unsigned int i = 0; i < count; ++i) {
        const char *name = ivar_getName(ivars[i]);
        if (name != NULL && strcmp(name, "_value") == 0) {
            found = 1;
            break;
        }
    }
    free((void *)ivars);
    return found;
}

static int case_reflection_inherited_ivar_lookup(void) {
    static int initialized = 0;
    static SFTestIvarInheritBundle bundle;
    static int32_t offset = 4;

    if (!initialized) {
        memset(&bundle, 0, sizeof(bundle));
        bundle.parent.cls.isa = &bundle.parent.meta;
        bundle.parent.cls.superclass = (SFObjCClass_t *)objc_getClass("Object");
        bundle.parent.cls.name = "ReflectionIvarParent";
        bundle.parent.meta.isa = &bundle.parent.meta;
        bundle.parent.meta.superclass = &bundle.parent.meta;
        bundle.parent.meta.name = "ReflectionIvarParentMeta";

        bundle.child.cls.isa = &bundle.child.meta;
        bundle.child.cls.superclass = &bundle.parent.cls;
        bundle.child.cls.name = "ReflectionIvarChild";
        bundle.child.meta.isa = &bundle.child.meta;
        bundle.child.meta.superclass = &bundle.parent.meta;
        bundle.child.meta.name = "ReflectionIvarChildMeta";

        bundle.ivars.count = 1;
        bundle.ivars.item_size = 1;
        bundle.ivars.ivars[0].name = "_inherited";
        bundle.ivars.ivars[0].type = "i";
        bundle.ivars.ivars[0].offset = &offset;
        bundle.ivars.ivars[0].size = 4;
        bundle.parent.cls.ivars = &bundle.ivars;

        SFObjCClass_t *classes[] = {&bundle.parent.cls, &bundle.child.cls};
        sf_register_classes(classes, classes + 2);
        sf_finalize_registered_classes();
        initialized = 1;
    }

    Ivar ivar = class_getInstanceVariable((Class)&bundle.child.cls, "_inherited");
    Ivar *ivars = class_copyIvarList((Class)&bundle.parent.cls, NULL);
    int ok = ivar != NULL &&
             ivar_getName(ivar) != NULL &&
             strcmp(ivar_getName(ivar), "_inherited") == 0 &&
             ivars != NULL;
    free((void *)ivars);
    return ok;
}

static int case_reflection_full_map_exhaustion(void) {
    static int initialized = 0;
    enum { bundle_count = 4096 };
    static SFTestManualClass *bundles = NULL;
    static SFObjCClass_t **classes = NULL;

    if (!initialized) {
        bundles = (SFTestManualClass *)calloc(bundle_count, sizeof(*bundles));
        classes = (SFObjCClass_t **)calloc(bundle_count, sizeof(*classes));
        if (bundles == NULL || classes == NULL) {
            free(classes);
            free(bundles);
            bundles = NULL;
            classes = NULL;
            return 0;
        }

        for (int i = 0; i < bundle_count; ++i) {
            char *name = (char *)malloc(48);
            char *meta_name = (char *)malloc(52);
            if (name == NULL || meta_name == NULL) {
                free(name);
                free(meta_name);
                return 0;
            }

            (void)snprintf(name, 48, "ReflectionFullMapClass%d", i);
            (void)snprintf(meta_name, 52, "ReflectionFullMapClassMeta%d", i);

            bundles[i].cls.isa = &bundles[i].meta;
            bundles[i].cls.superclass = (SFObjCClass_t *)objc_getClass("Object");
            bundles[i].cls.name = name;
            bundles[i].meta.isa = &bundles[i].meta;
            bundles[i].meta.superclass = &bundles[i].meta;
            bundles[i].meta.name = meta_name;
            classes[i] = &bundles[i].cls;
        }

        sf_register_classes(classes, classes + bundle_count);
        sf_finalize_registered_classes();
        initialized = 1;
    }

    SFTestManualClass probe;
    memset(&probe, 0, sizeof(probe));
    probe.cls.isa = &probe.meta;
    probe.cls.superclass = (SFObjCClass_t *)objc_getClass("Object");
    probe.cls.name = "ReflectionFullMapProbe";
    probe.meta.isa = &probe.meta;
    probe.meta.superclass = &probe.meta;
    probe.meta.name = "ReflectionFullMapProbeMeta";

    return class_getInstanceSize((Class)&probe.cls) >= sizeof(void *) &&
           objc_getClass("DefinitelyMissingAfterFullMap") == nil;
}

static int case_reflection_null_paths(void) {
    unsigned int count = 77;
    SFTestManualClass bundle;

    memset(&bundle, 0, sizeof(bundle));
    bundle.cls.isa = &bundle.meta;
    bundle.cls.name = "NoMethodsClass";
    bundle.meta.isa = &bundle.meta;
    bundle.meta.name = "NoMethodsClassMeta";

    return class_getName(NULL) == NULL &&
           class_getSuperclass(NULL) == NULL &&
           object_getClass(nil) == Nil &&
           objc_getMetaClass(NULL) == Nil &&
           class_getInstanceMethod(NULL, NULL) == NULL &&
           class_getClassMethod(NULL, NULL) == NULL &&
           class_copyMethodList(NULL, &count) == NULL &&
           count == 0 &&
           class_copyMethodList((Class)&bundle.cls, &count) == NULL &&
           method_getName(NULL) == NULL &&
           method_getImplementation(NULL) == NULL &&
           method_getTypeEncoding(NULL) == NULL &&
           class_getInstanceVariable(NULL, NULL) == NULL &&
           class_copyIvarList(NULL, &count) == NULL &&
           ivar_getName(NULL) == NULL &&
           ivar_getTypeEncoding(NULL) == NULL &&
           ivar_getOffset(NULL) == 0 &&
           sel_getName(NULL) == NULL &&
           sel_registerName(NULL) == NULL &&
           sel_registerName("") == NULL &&
           sel_isEqual(NULL, NULL);
}

static int case_reflection_selector_registration(void) {
    SEL first = sel_registerName("reflection_selector_registration");
    SEL second = sel_registerName("reflection_selector_registration");
    return first != NULL && first == second && strcmp(sel_getName(first), "reflection_selector_registration") == 0;
}

static int case_reflection_failure_paths(void) {
    ensure_extra_registered_classes();

    unsigned int count = 0;
    sf_runtime_test_fail_allocation_after(0);
    Class *classes = objc_copyClassList(&count);
    sf_runtime_test_reset_alloc_failures();
    if (classes != NULL || count != 0) {
        free((void *)classes);
        return 0;
    }

    sf_runtime_test_fail_allocation_after(1);
    classes = objc_copyClassList(&count);
    sf_runtime_test_reset_alloc_failures();
    if (classes != NULL) {
        free((void *)classes);
        return 0;
    }

    sf_runtime_test_fail_allocation_after(2);
    classes = objc_copyClassList(&count);
    sf_runtime_test_reset_alloc_failures();
    if (classes == NULL || count == 0) {
        free((void *)classes);
        return 0;
    }
    free((void *)classes);

    sf_runtime_test_fail_allocation_after(0);
    Method *methods = class_copyMethodList((Class)objc_getClass("ReflectionProbe"), &count);
    sf_runtime_test_reset_alloc_failures();
    if (methods != NULL) {
        free((void *)methods);
        return 0;
    }

    sf_runtime_test_fail_allocation_after(0);
    Ivar *ivars = class_copyIvarList((Class)objc_getClass("ReflectionProbe"), &count);
    sf_runtime_test_reset_alloc_failures();
    if (ivars != NULL) {
        free((void *)ivars);
        return 0;
    }

    sf_runtime_test_fail_allocation_after(0);
    if (sel_registerName("reflection_failure_selector_0") != NULL) {
        sf_runtime_test_reset_alloc_failures();
        return 0;
    }
    sf_runtime_test_fail_allocation_after(1);
    if (sel_registerName("reflection_failure_selector_1") != NULL) {
        sf_runtime_test_reset_alloc_failures();
        return 0;
    }
    sf_runtime_test_reset_alloc_failures();
    return 1;
}
#endif

static int case_class_lookup_concurrent(void) {
#if SF_RUNTIME_THREADSAFE
    enum { thread_count = 4, loops_per_thread = 40000, class_count = 5 };
    const char *names[class_count] = {"Object", "CounterObject", "SuperBase", "SuperChild", "HotDispatch"};
    Class expected[class_count];
    pthread_t threads[thread_count];
    ClassLookupThreadCtx ctx[thread_count];

    for (int i = 0; i < class_count; ++i) {
        expected[i] = (Class)objc_getClass(names[i]);
        if (expected[i] == Nil) {
            return 0;
        }
    }

    for (int i = 0; i < thread_count; ++i) {
        ctx[i].names = names;
        ctx[i].expected = expected;
        ctx[i].name_count = class_count;
        ctx[i].loops = loops_per_thread;
        ctx[i].ok = 1;
        if (pthread_create(&threads[i], NULL, class_lookup_thread_main, &ctx[i]) != 0) {
            return 0;
        }
    }

    for (int i = 0; i < thread_count; ++i) {
        if (pthread_join(threads[i], NULL) != 0 || !ctx[i].ok) {
            return 0;
        }
    }
    return 1;
#else
    return 1;
#endif
}

static const SFTestCase g_loader_cases[] = {
    {"no_libobjc_dependency", case_no_libobjc_dependency},
    {"loader_lookup_nulls", case_loader_lookup_nulls},
    {"loader_lookup_missing", case_loader_lookup_missing},
    {"loader_header_validation", case_loader_header_validation},
    {"loader_header_size_modes", case_loader_header_size_modes},
    {"loader_manual_registration", case_loader_manual_registration},
    {"loader_class_size_synthetic", case_loader_class_size_synthetic},
    {"loader_hash_helpers", case_loader_hash_helpers},
    {"loader_alloc_failure_paths", case_loader_alloc_failure_paths},
    {"loader_class_name_live_object", case_loader_class_name_live_object},
#if SF_RUNTIME_REFLECTION
    {"reflection_class_lookup", case_reflection_class_lookup},
    {"reflection_inherited_method_lookup", case_reflection_inherited_method_lookup},
    {"reflection_method_lookup", case_reflection_method_lookup},
    {"reflection_ivar_lookup", case_reflection_ivar_lookup},
    {"reflection_inherited_ivar_lookup", case_reflection_inherited_ivar_lookup},
    {"reflection_null_paths", case_reflection_null_paths},
    {"reflection_selector_registration", case_reflection_selector_registration},
    {"reflection_failure_paths", case_reflection_failure_paths},
    {"reflection_full_map_exhaustion", case_reflection_full_map_exhaustion},
#endif
    {"class_lookup_concurrent", case_class_lookup_concurrent},
};

const SFTestCase *sf_runtime_loader_cases(size_t *count) {
    if (count != NULL) {
        *count = sizeof(g_loader_cases) / sizeof(g_loader_cases[0]);
    }
    return g_loader_cases;
}

#ifdef __clang__
#pragma clang diagnostic pop
#endif
