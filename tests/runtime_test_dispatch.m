#include <pthread.h>
#include <string.h>

#include "runtime_test_support.h"

typedef struct DispatchThreadCtx {
    HotDispatch *obj;
    int loops;
    long long sum;
} DispatchThreadCtx;

typedef struct SFTestSelector {
    const char *name;
    const char *types;
} SFTestSelector;

#if SF_RUNTIME_THREADSAFE
static void *dispatch_thread_main(void *arg)
{
    DispatchThreadCtx *ctx = (DispatchThreadCtx *)arg;
    long long sum = 0;

    for (int i = 0; i < ctx->loops; ++i) {
        sum += [ctx->obj calc:i];
    }

    ctx->sum = sum;
    return NULL;
}
#endif

#ifdef SF_DISPATCH_BACKEND_C
typedef struct SFTestMethodList {
    SFObjCMethodList_t *next;
    int32_t count;
    int64_t size;
    SFObjCMethod_t methods[18];
} SFTestMethodList;

typedef struct SFTestDispatchBundle {
    SFObjCClass_t cls;
    SFObjCClass_t meta;
    SFTestMethodList methods;
} SFTestDispatchBundle;

static int g_probe_argc = 0;
static uintptr_t g_probe_values[4] = {0, 0, 0, 0};

static id probe0(id self, SEL cmd)
{
    (void)cmd;
    g_probe_argc = 0;
    memset(g_probe_values, 0, sizeof(g_probe_values));
    return self;
}

static id probe1(id self, SEL cmd, uintptr_t a0)
{
    (void)cmd;
    g_probe_argc = 1;
    g_probe_values[0] = a0;
    return self;
}

static id probe2(id self, SEL cmd, uintptr_t a0, uintptr_t a1)
{
    (void)cmd;
    g_probe_argc = 2;
    g_probe_values[0] = a0;
    g_probe_values[1] = a1;
    return self;
}

static id probe3(id self, SEL cmd, uintptr_t a0, uintptr_t a1, uintptr_t a2)
{
    (void)cmd;
    g_probe_argc = 3;
    g_probe_values[0] = a0;
    g_probe_values[1] = a1;
    g_probe_values[2] = a2;
    return self;
}

static id probe4(id self, SEL cmd, uintptr_t a0, uintptr_t a1, uintptr_t a2, uintptr_t a3)
{
    (void)cmd;
    g_probe_argc = 4;
    g_probe_values[0] = a0;
    g_probe_values[1] = a1;
    g_probe_values[2] = a2;
    g_probe_values[3] = a3;
    return self;
}

static SFTestSelector g_c_zero = {"zero", "@16@0:8"};
static SFTestSelector g_c_i = {"takeI:", "@24@0:8i16"};
static SFTestSelector g_c_Iq = {"takeIq:second:", "@32@0:8I16q24"};
static SFTestSelector g_c_QstarSel = {"takeQ:star:sel:", "@40@0:8Q16*24:32"};
static SFTestSelector g_c_objClassPtrConst = {"takeObj:cls:ptr:cstr:", "@48@0:8@16#24^v32r*40"};
static SFTestSelector g_c_char = {"takeChar:", "@24@0:8c16"};
static SFTestSelector g_c_short = {"takeShort:", "@24@0:8s16"};
static SFTestSelector g_c_bool = {"takeBool:", "@24@0:8B16"};
static SFTestSelector g_c_C = {"takeC:", "@24@0:8C16"};
static SFTestSelector g_c_S = {"takeS:", "@24@0:8S16"};
static SFTestSelector g_c_long = {"takeLong:", "@24@0:8l16"};
static SFTestSelector g_c_ulong = {"takeULong:", "@24@0:8L16"};
static SFTestSelector g_c_pointer = {"takePointer:", "@24@0:8^i16"};
static SFTestSelector g_c_struct = {"takeStruct:", "@24@0:8{Pair=ii}16"};
static SFTestSelector g_c_union = {"takeUnion:", "@24@0:8(U=ii)16"};
static SFTestSelector g_c_array = {"takeArray:", "@24@0:8[4i]16"};
static SFTestSelector g_c_block = {"takeBlock:", "@24@0:8@?16"};
static SFTestSelector g_c_unknown = {"takeUnknown:", "@24@0:8?16"};
static SFTestSelector g_c_many = {"takeMany:second:third:fourth:fifth:", "@56@0:8i16i24i32i40i48"};
static SFTestSelector g_c_empty = {"takeEmpty", ""};
static SFTestSelector g_c_null_types = {"takeNullTypes", NULL};
static SFTestSelector g_c_unsupported = {"takeDouble:", "@24@0:8d16"};

static SFTestDispatchBundle *dispatch_bundle(void)
{
    static SFTestDispatchBundle bundle;
    static int initialized = 0;
    if (initialized) {
        return &bundle;
    }

    memset(&bundle, 0, sizeof(bundle));
    bundle.cls.isa = &bundle.meta;
    bundle.cls.name = "DispatchCFallbackProbe";
    bundle.meta.isa = &bundle.meta;
    bundle.meta.name = "DispatchCFallbackProbeMeta";
    bundle.methods.count = 18;
    bundle.methods.size = (int64_t)sizeof(SFObjCMethod_t);

    SFObjCMethod_t *methods = bundle.methods.methods;
    methods[0] = (SFObjCMethod_t){.imp = (IMP)probe0, .selector = (SEL)&g_c_zero, .types = g_c_zero.types};
    methods[1] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_i, .types = g_c_i.types};
    methods[2] = (SFObjCMethod_t){.imp = (IMP)probe2, .selector = (SEL)&g_c_Iq, .types = g_c_Iq.types};
    methods[3] = (SFObjCMethod_t){.imp = (IMP)probe3, .selector = (SEL)&g_c_QstarSel, .types = g_c_QstarSel.types};
    methods[4] = (SFObjCMethod_t){.imp = (IMP)probe4, .selector = (SEL)&g_c_objClassPtrConst, .types = g_c_objClassPtrConst.types};
    methods[5] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_char, .types = g_c_char.types};
    methods[6] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_short, .types = g_c_short.types};
    methods[7] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_bool, .types = g_c_bool.types};
    methods[8] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_C, .types = g_c_C.types};
    methods[9] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_S, .types = g_c_S.types};
    methods[10] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_long, .types = g_c_long.types};
    methods[11] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_ulong, .types = g_c_ulong.types};
    methods[12] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_pointer, .types = g_c_pointer.types};
    methods[13] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_struct, .types = g_c_struct.types};
    methods[14] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_union, .types = g_c_union.types};
    methods[15] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_array, .types = g_c_array.types};
    methods[16] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_block, .types = g_c_block.types};
    methods[17] = (SFObjCMethod_t){.imp = (IMP)probe1, .selector = (SEL)&g_c_unsupported, .types = g_c_unsupported.types};
    bundle.cls.methods = (SFObjCMethodList_t *)&bundle.methods;
    initialized = 1;
    return &bundle;
}
#endif

static int case_dispatch_cache_warm_hits(void)
{
    sf_dispatch_reset_stats();
    __unsafe_unretained HotDispatch *obj = SFW_NEW(HotDispatch);
    int sum = 0;

    for (int i = 0; i < 2000; ++i) {
        sum += [obj calc:i];
    }

    objc_release(obj);
#if SF_DISPATCH_STATS
    (void)sum;
    return sf_dispatch_cache_hits() > sf_dispatch_cache_misses() and sf_dispatch_method_walks() > 0;
#else
    return sum == ((2000 * 2001) / 2);
#endif
}

static int case_dispatch_super_lookup(void)
{
    __unsafe_unretained SuperChild *obj = SFW_NEW(SuperChild);
    int ok = [obj ping] == 17;
    objc_release(obj);
    return ok;
}

static int case_dispatch_lookup_nil_paths(void)
{
    static SFTestSelector ping_sel = {"ping", "i16@0:8"};
    static SFTestSelector missing_sel = {"missing", "@16@0:8"};

    IMP nil_receiver_imp = sf_lookup_imp(nil, (SEL)&ping_sel);
    if (nil_receiver_imp == NULL or objc_msgSend(nil, (SEL)&ping_sel) != nil) {
        return 0;
    }
    if (sf_lookup_imp_in_class(NULL, (SEL)&ping_sel) != NULL) {
        return 0;
    }
    if (sf_lookup_imp_in_class((Class)objc_getClass("HotDispatch"), NULL) != NULL) {
        return 0;
    }
    if (sf_lookup_imp_in_class((Class)objc_getClass("HotDispatch"), (SEL)&missing_sel) != NULL) {
        return 0;
    }

    __unsafe_unretained HotDispatch *obj = SFW_NEW(HotDispatch);
    IMP nil_sel_imp = sf_lookup_imp(obj, NULL);
    IMP missing_imp = sf_lookup_imp(obj, (SEL)&missing_sel);
    int ok = nil_sel_imp != NULL and
             objc_msgSend(obj, NULL) == nil and
             missing_imp != NULL and
             objc_msgSend(obj, (SEL)&missing_sel) == nil;
    objc_release(obj);
    return ok;
}

static int case_dispatch_selector_equality(void)
{
    static SFTestSelector a = {"value", "@16@0:8"};
    static SFTestSelector b = {"value", "@16@0:8"};
    static SFTestSelector c = {"value", NULL};
    static SFTestSelector d = {"other", "@16@0:8"};
    static SFTestSelector e = {NULL, "@16@0:8"};

    return sf_selector_equal((SEL)&a, (SEL)&a) and
           sf_selector_equal((SEL)&a, (SEL)&b) and
           sf_selector_equal((SEL)&a, (SEL)&c) and
           not sf_selector_equal((SEL)&a, (SEL)&e) and
           not sf_selector_equal((SEL)&a, (SEL)&d) and
           not sf_selector_equal((SEL)&a, NULL) and
           sf_selector_equal(NULL, NULL);
}

static int case_dispatch_msg_lookup_super_nil_paths(void)
{
    static SFTestSelector ping_sel = {"ping", "i16@0:8"};
    struct sf_objc_super nil_super = {.self = nil, .super_class = NULL};

    IMP imp0 = objc_msg_lookup_super(NULL, (SEL)&ping_sel);
    IMP imp1 = objc_msg_lookup_super(&nil_super, (SEL)&ping_sel);
    IMP imp2 = objc_msg_lookup_super(&nil_super, NULL);
    return imp0 != NULL and
           imp1 != NULL and
           imp2 != NULL;
}

static int case_dispatch_cache_nil_imp(void)
{
    static SFTestSelector missing_sel = {"missingDispatch", "@16@0:8"};
    __unsafe_unretained CounterObject *obj = SFW_NEW(CounterObject);
    IMP imp0 = sf_lookup_imp(obj, (SEL)&missing_sel);
    IMP imp1 = sf_lookup_imp(obj, (SEL)&missing_sel);
    int ok = imp0 != NULL and
             imp1 != NULL and
             objc_msgSend(obj, (SEL)&missing_sel) == nil;
    objc_release(obj);
    return ok;
}

static int case_dispatch_stats_accessors(void)
{
    static SFTestSelector calc_sel = {"calc:", "i20@0:8i16"};

    sf_dispatch_reset_stats();
    if (sf_dispatch_cache_hits() != 0 or sf_dispatch_cache_misses() != 0 or sf_dispatch_method_walks() != 0) {
        return 0;
    }

    __unsafe_unretained HotDispatch *obj = SFW_NEW(HotDispatch);
    if (obj == nil) {
        return 0;
    }
    (void)sf_lookup_imp(obj, (SEL)&calc_sel);
    (void)sf_lookup_imp(obj, (SEL)&calc_sel);

#if SF_DISPATCH_STATS
    int ok = sf_dispatch_cache_hits() > 0 and sf_dispatch_cache_misses() > 0 and sf_dispatch_method_walks() > 0;
#else
    int ok = sf_dispatch_cache_hits() == 0 and sf_dispatch_cache_misses() == 0 and sf_dispatch_method_walks() == 0;
#endif
    objc_release(obj);
    return ok;
}

static int case_dispatch_fake_object_null_class(void)
{
    static SFTestSelector ping_sel = {"ping", "i16@0:8"};
    Class fake_cls = Nil;
    id fake = (id)&fake_cls;
    IMP imp = sf_lookup_imp(fake, (SEL)&ping_sel);
    return imp != NULL and objc_msgSend(fake, (SEL)&ping_sel) == nil;
}

static int case_dispatch_concurrent_cache(void)
{
#if SF_RUNTIME_THREADSAFE
    enum { thread_count = 4,
           loops_per_thread = 50000 };
    pthread_t threads[thread_count];
    DispatchThreadCtx ctx[thread_count];
    __unsafe_unretained HotDispatch *obj = SFW_NEW(HotDispatch);

    for (int i = 0; i < thread_count; ++i) {
        ctx[i].obj = obj;
        ctx[i].loops = loops_per_thread;
        ctx[i].sum = 0;
        if (pthread_create(&threads[i], NULL, dispatch_thread_main, &ctx[i]) != 0) {
            objc_release(obj);
            return 0;
        }
    }

    long long total = 0;
    for (int i = 0; i < thread_count; ++i) {
        if (pthread_join(threads[i], NULL) != 0) {
            objc_release(obj);
            return 0;
        }
        total += ctx[i].sum;
    }

    objc_release(obj);
    long long expected = (long long)thread_count * ((long long)loops_per_thread * (loops_per_thread + 1) / 2);
    return total == expected;
#else
    return 1;
#endif
}

static int case_dispatch_c_msgsend_signatures(void)
{
#ifdef SF_DISPATCH_BACKEND_C
    SFTestDispatchBundle *bundle = dispatch_bundle();

    __unsafe_unretained Object *obj = (Object *)sf_alloc_object((Class)&bundle->cls, NULL);
    int array_values[4] = {1, 2, 3, 4};
    struct {
        int left;
        int right;
    } pair = {5, 6};
    union {
        int left;
        int right;
    } either = {.left = 7};

    if (objc_msgSend(obj, (SEL)&g_c_zero) != obj) {
        sf_object_dispose(obj);
        return 0;
    }
    if (objc_msgSend(obj, (SEL)&g_c_i, 11) != obj or g_probe_argc != 1 or g_probe_values[0] != 11U) {
        sf_object_dispose(obj);
        return 0;
    }
    if (objc_msgSend(obj, (SEL)&g_c_Iq, 12U, 13LL) != obj or g_probe_argc != 2) {
        sf_object_dispose(obj);
        return 0;
    }
    if (objc_msgSend(obj, (SEL)&g_c_QstarSel, 14ULL, "hello", (SEL)&g_c_zero) != obj or g_probe_argc != 3) {
        sf_object_dispose(obj);
        return 0;
    }
    if (objc_msgSend(obj, (SEL)&g_c_objClassPtrConst, obj, (Class)&bundle->cls, (void *)&pair, "const") != obj or
        g_probe_argc != 4) {
        sf_object_dispose(obj);
        return 0;
    }
    if (objc_msgSend(obj, (SEL)&g_c_char, 'a') != obj or
        objc_msgSend(obj, (SEL)&g_c_short, (short)2) != obj or
        objc_msgSend(obj, (SEL)&g_c_bool, 1) != obj or
        objc_msgSend(obj, (SEL)&g_c_C, (unsigned int)3) != obj or
        objc_msgSend(obj, (SEL)&g_c_S, (unsigned int)4) != obj or
        objc_msgSend(obj, (SEL)&g_c_long, (long)5) != obj or
        objc_msgSend(obj, (SEL)&g_c_ulong, (unsigned long)6) != obj or
        objc_msgSend(obj, (SEL)&g_c_pointer, (void *)&pair) != obj or
        objc_msgSend(obj, (SEL)&g_c_struct, (void *)&pair) != obj or
        objc_msgSend(obj, (SEL)&g_c_union, (void *)&either) != obj or
        objc_msgSend(obj, (SEL)&g_c_array, (void *)array_values) != obj or
        objc_msgSend(obj, (SEL)&g_c_block, (void *)bundle) != obj) {
        sf_object_dispose(obj);
        return 0;
    }

    sf_object_dispose(obj);
    return 1;
#else
    return 1;
#endif
}

static int case_dispatch_c_msgsend_unsupported_float(void)
{
#ifdef SF_DISPATCH_BACKEND_C
    SFTestDispatchBundle *bundle = dispatch_bundle();

    __unsafe_unretained Object *obj = (Object *)sf_alloc_object((Class)&bundle->cls, NULL);
    g_probe_argc = 0;
    id result = objc_msgSend(obj, (SEL)&g_c_unsupported, 1.25);
    sf_object_dispose(obj);
    return result == nil and g_probe_argc == 0;
#else
    return 1;
#endif
}

static int case_dispatch_c_msgsend_parser_edges(void)
{
#ifdef SF_DISPATCH_BACKEND_C
    if (objc_msgSend(nil, NULL) != nil) {
        return 0;
    }
    if (objc_msgSend(nil, (SEL)&g_c_empty) != nil) {
        return 0;
    }
    if (objc_msgSend(nil, (SEL)&g_c_null_types) != nil) {
        return 0;
    }
    if (objc_msgSend(nil, (SEL)&g_c_unknown, (void *)&g_c_zero) != nil) {
        return 0;
    }
    if (objc_msgSend(nil, (SEL)&g_c_many, 1, 2, 3, 4, 5) != nil) {
        return 0;
    }
    return 1;
#else
    return 1;
#endif
}

static int case_dispatch_c_internal_helpers(void)
{
#ifdef SF_DISPATCH_BACKEND_C
    char codes[4] = {0, 0, 0, 0};
    int unsupported = -1;
    const char *ptr_arg = "ptr";
    SEL zero_sel = (SEL)&g_c_zero;
    Class zero_class = (Class)&g_c_zero;

    if (not sf_runtime_test_dispatch_is_digit_char('7') or sf_runtime_test_dispatch_is_digit_char('x')) {
        return 0;
    }
    if (not sf_runtime_test_dispatch_is_type_qualifier('r') or sf_runtime_test_dispatch_is_type_qualifier('x')) {
        return 0;
    }
    if (*sf_runtime_test_dispatch_skip_type_token("r^i") != '\0' or
        *sf_runtime_test_dispatch_skip_type_token("{Pair=ii}") != '\0' or
        *sf_runtime_test_dispatch_skip_type_token("(Either=ii)") != '\0' or
        *sf_runtime_test_dispatch_skip_type_token("[4i]") != '\0' or
        *sf_runtime_test_dispatch_skip_type_token("@?") != '\0' or
        *sf_runtime_test_dispatch_skip_type_token("i") != '\0') {
        return 0;
    }
    if (sf_runtime_test_dispatch_primary_type_code("r^i") != '^' or
        sf_runtime_test_dispatch_primary_type_code("i") != 'i') {
        return 0;
    }

    unsupported = 7;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes(NULL, codes, &unsupported) != 0 or unsupported != 0) {
        return 0;
    }
    unsupported = 7;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes((SEL)&g_c_null_types, codes, &unsupported) != 0 or
        unsupported != 0) {
        return 0;
    }
    unsupported = 7;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes((SEL)&g_c_empty, codes, &unsupported) != 0 or
        unsupported != 0) {
        return 0;
    }
    memset(codes, 0, sizeof(codes));
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes((SEL)&g_c_objClassPtrConst, codes, &unsupported) != 4 or
        codes[0] != '@' or codes[1] != '#' or codes[2] != '^' or codes[3] != '*') {
        return 0;
    }
    unsupported = 0;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes((SEL)&g_c_unsupported, codes, &unsupported) != 0 or
        unsupported == 0) {
        return 0;
    }
    unsupported = 0;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes((SEL)&g_c_many, codes, &unsupported) != 4 or
        unsupported == 0) {
        return 0;
    }
    memset(codes, 0, sizeof(codes));
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes_cached((SEL)&g_c_objClassPtrConst, codes, &unsupported) != 4) {
        return 0;
    }
    memset(codes, 0, sizeof(codes));
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes_cached((SEL)&g_c_objClassPtrConst, codes, &unsupported) != 4 or
        codes[0] != '@' or codes[1] != '#' or codes[2] != '^' or codes[3] != '*') {
        return 0;
    }
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes_cached(NULL, codes, &unsupported) != 0) {
        return 0;
    }

    if (sf_runtime_test_dispatch_read_word_arg('c', 11) != (uintptr_t)11 or
        sf_runtime_test_dispatch_read_word_arg('s', 12) != (uintptr_t)12 or
        sf_runtime_test_dispatch_read_word_arg('i', 13) != (uintptr_t)13 or
        sf_runtime_test_dispatch_read_word_arg('B', 1) != (uintptr_t)1 or
        sf_runtime_test_dispatch_read_word_arg('C', (unsigned int)14) != (uintptr_t)14 or
        sf_runtime_test_dispatch_read_word_arg('S', (unsigned int)15) != (uintptr_t)15 or
        sf_runtime_test_dispatch_read_word_arg('I', (unsigned int)16) != (uintptr_t)16 or
        sf_runtime_test_dispatch_read_word_arg('l', (long)17) != (uintptr_t)17 or
        sf_runtime_test_dispatch_read_word_arg('L', (unsigned long)18) != (uintptr_t)18 or
        sf_runtime_test_dispatch_read_word_arg('q', (long long)19) != (uintptr_t)19 or
        sf_runtime_test_dispatch_read_word_arg('Q', (unsigned long long)20) != (uintptr_t)20 or
        sf_runtime_test_dispatch_read_word_arg('*', ptr_arg) != (uintptr_t)(const void *)ptr_arg or
        sf_runtime_test_dispatch_read_word_arg(':', zero_sel) != (uintptr_t)(const void *)zero_sel or
        sf_runtime_test_dispatch_read_word_arg('@', nil) != (uintptr_t)nil or
        sf_runtime_test_dispatch_read_word_arg('#', zero_class) != (uintptr_t)(const void *)zero_class or
        sf_runtime_test_dispatch_read_word_arg('^', (void *)&codes) != (uintptr_t)(void *)&codes or
        sf_runtime_test_dispatch_read_word_arg('[', (void *)&codes) != (uintptr_t)(void *)&codes or
        sf_runtime_test_dispatch_read_word_arg('(', (void *)&codes) != (uintptr_t)(void *)&codes or
        sf_runtime_test_dispatch_read_word_arg('{', (void *)&codes) != (uintptr_t)(void *)&codes or
        sf_runtime_test_dispatch_read_word_arg('?', (void *)&codes) != (uintptr_t)(void *)&codes) {
        return 0;
    }
    return 1;
#else
    return 1;
#endif
}

static int case_dispatch_struct_params(void)
{
    __unsafe_unretained StructDispatchProbe *obj = SFW_NEW(StructDispatchProbe);
    SFTestPair pair = {0, 0};
    SFTestBigStruct big = {0, 0, 0, 0};
    int ok = 0;

    if (obj == nil) {
        return 0;
    }

    pair = [obj pairWithLeft:5 right:9];
    big = (SFTestBigStruct){.first = 1, .second = 2, .third = 3, .fourth = 4};
    ok = pair.left == 5 and
         pair.right == 9 and
         [obj sumPair:(SFTestPair){.left = 7, .right = 11}] == 18 and
         [obj sumBigStruct:big
                      bias:10] == 20;
    objc_release(obj);
    return ok;
}

static int case_dispatch_struct_returns(void)
{
    __unsafe_unretained StructDispatchProbe *obj = SFW_NEW(StructDispatchProbe);
    SFTestWidePair wide = {0, 0};
    SFTestBigStruct big = {0, 0, 0, 0};
    int ok = 0;

    if (obj == nil) {
        return 0;
    }

    wide = [obj widePairWithSeed:20];
    big = [obj bigStructWithSeed:40];
    ok = wide.left == 20 and
         wide.right == 21 and
         big.first == 40 and
         big.second == 41 and
         big.third == 42 and
         big.fourth == 43;
    objc_release(obj);
    return ok;
}

static int case_dispatch_runtime_selector_resolution(void)
{
#if SF_RUNTIME_FORWARDING
    static SFTestSelector calc_sel_data = {"calc:", NULL};
    SEL calc_sel = (SEL)&calc_sel_data;
    __unsafe_unretained HotDispatch *obj = SFW_NEW(HotDispatch);
    int result = 0;

    if (obj == nil) {
        return 0;
    }

    result = ((int (*)(id, SEL, int))objc_msgSend)(obj, calc_sel, 41);
    objc_release(obj);
    return result == 42;
#else
    return 1;
#endif
}

static int case_dispatch_forwarding_targets(void)
{
#if SF_RUNTIME_FORWARDING
    static SFTestSelector instance_sel_data = {"forwardedValue:", NULL};
    static SFTestSelector class_sel_data = {"classForwardedValue:", NULL};
    SEL instance_sel = (SEL)&instance_sel_data;
    SEL class_sel = (SEL)&class_sel_data;
    Class proxy_cls = (Class)objc_getClass("ForwardDispatchProxy");
    __unsafe_unretained ForwardDispatchProxy *proxy = SFW_NEW(ForwardDispatchProxy);
    int instance_result0 = 0;
    int instance_result1 = 0;
    int class_result0 = 0;
    int class_result1 = 0;

    if (proxy == nil or proxy_cls == Nil) {
        return 0;
    }

    instance_result0 = ((int (*)(id, SEL, int))objc_msgSend)(proxy, instance_sel, 5);
    instance_result1 = ((int (*)(id, SEL, int))objc_msgSend)(proxy, instance_sel, 6);
    class_result0 = ((int (*)(id, SEL, int))objc_msgSend)((id)proxy_cls, class_sel, 7);
    class_result1 = ((int (*)(id, SEL, int))objc_msgSend)((id)proxy_cls, class_sel, 8);
    objc_release(proxy);
    return instance_result0 == 105 and
           instance_result1 == 106 and
           class_result0 == 207 and
           class_result1 == 208;
#else
    return 1;
#endif
}

static const SFTestCase g_dispatch_cases[] = {
    {"dispatch_cache_warm_hits", case_dispatch_cache_warm_hits},
    {"dispatch_super_lookup", case_dispatch_super_lookup},
    {"dispatch_lookup_nil_paths", case_dispatch_lookup_nil_paths},
    {"dispatch_selector_equality", case_dispatch_selector_equality},
    {"dispatch_msg_lookup_super_nil_paths", case_dispatch_msg_lookup_super_nil_paths},
    {"dispatch_cache_nil_imp", case_dispatch_cache_nil_imp},
    {"dispatch_stats_accessors", case_dispatch_stats_accessors},
    {"dispatch_fake_object_null_class", case_dispatch_fake_object_null_class},
    {"dispatch_concurrent_cache", case_dispatch_concurrent_cache},
    {"dispatch_c_msgsend_signatures", case_dispatch_c_msgsend_signatures},
    {"dispatch_c_msgsend_unsupported_float", case_dispatch_c_msgsend_unsupported_float},
    {"dispatch_c_msgsend_parser_edges", case_dispatch_c_msgsend_parser_edges},
    {"dispatch_c_internal_helpers", case_dispatch_c_internal_helpers},
    {"dispatch_struct_params", case_dispatch_struct_params},
    {"dispatch_struct_returns", case_dispatch_struct_returns},
    {"dispatch_runtime_selector_resolution", case_dispatch_runtime_selector_resolution},
    {"dispatch_forwarding_targets", case_dispatch_forwarding_targets},
};

const SFTestCase *sf_runtime_dispatch_cases(size_t *count)
{
    if (count != NULL) {
        *count = sizeof(g_dispatch_cases) / sizeof(g_dispatch_cases[0]);
    }
    return g_dispatch_cases;
}
