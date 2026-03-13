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

static SFTestSelector g_raw_empty = {"takeEmpty", ""};
static SFTestSelector g_raw_null_types = {"takeNullTypes", nullptr};
static SFTestSelector g_raw_unknown = {"takeUnknown:", "@24@0:8?16"};

static void *dispatch_thread_main(void *arg)
{
    DispatchThreadCtx *ctx = (DispatchThreadCtx *)arg;
    long long sum = 0;

    for (int i = 0; i < ctx->loops; ++i) {
        sum += [ctx->obj calc:i];
    }

    ctx->sum = sum;
    return nullptr;
}

static int case_dispatch_cache_warm_hits(void)
{
    SEL calc_sel = sel_registerName("calc:");
    __unsafe_unretained HotDispatch *obj = SFW_NEW(HotDispatch);
    IMP imp0 = nullptr;
    IMP imp1 = nullptr;
    int sum = 0;

    if (obj == nil or calc_sel == nullptr) {
        return 0;
    }

    imp0 = sf_lookup_imp(obj, calc_sel);
    imp1 = sf_lookup_imp(obj, calc_sel);
    for (int i = 0; i < 2000; ++i) {
        sum += [obj calc:i];
    }

    objc_release(obj);
    return imp0 != nullptr and
           imp0 == imp1 and
           ((int (*)(id, SEL, int))imp0)(obj, calc_sel, 41) == 42 and
           sum == ((2000 * 2001) / 2);
}

static int case_dispatch_super_lookup(void)
{
    SEL ping_sel = sel_registerName("ping");
    __unsafe_unretained SuperChild *obj = SFW_NEW(SuperChild);
    Class super_cls = Nil;
    struct sf_objc_super super_info = {0};
    IMP super_imp = nullptr;
    int ok = 0;

    if (obj == nil or ping_sel == nullptr) {
        return 0;
    }

    super_cls = class_getSuperclass((Class)sf_object_class(obj));
    if (super_cls == Nil) {
        objc_release(obj);
        return 0;
    }
    super_info.self = obj;
    super_info.super_class = super_cls;

    super_imp = objc_msg_lookup_super(&super_info, ping_sel);
    ok = [obj ping] == 17 and super_imp != nullptr and ((int (*)(id, SEL))super_imp)(obj, ping_sel) == 10;
    objc_release(obj);
    return ok;
}

static int case_dispatch_selector_equality(void)
{
    SEL calc0 = sel_registerName("calc:");
    SEL calc1 = sel_registerName("calc:");
    SEL ping = sel_registerName("ping");

    return calc0 != nullptr and
           ping != nullptr and
           sf_selector_equal(calc0, calc1) and
           not sf_selector_equal(calc0, ping) and
           not sf_selector_equal(calc0, nullptr) and
           sf_selector_equal(nullptr, nullptr);
}

static int case_dispatch_selector_lookup_only_registration(void)
{
    SEL calc_sel = sel_registerName("calc:");
    SEL ping_sel = sel_registerName("ping");
    SEL missing = sel_registerName("definitely_missing_selector_name");

    return calc_sel != nullptr and
           ping_sel != nullptr and
           missing == nullptr and
           strcmp(sel_getName(calc_sel), "calc:") == 0 and
           strcmp(sel_getName(ping_sel), "ping") == 0;
}

static int case_dispatch_method_lookup_canonical(void)
{
    Class cls = (Class)objc_getClass("HotDispatch");
    SEL canonical = sel_registerName("calc:");
    Method method = nullptr;

    if (cls == Nil or canonical == nullptr) {
        return 0;
    }

    method = class_getInstanceMethod(cls, canonical);
    return method != nullptr and
           method_getName(method) == canonical and
           method_getImplementation(method) != nullptr and
           sf_selector_slot(method_getName(method)) == sf_selector_slot(canonical);
}

static int case_dispatch_concurrent_reads(void)
{
    enum { thread_count = 4,
           loops_per_thread = 50000 };
    pthread_t threads[thread_count];
    DispatchThreadCtx ctx[thread_count];
    __unsafe_unretained HotDispatch *obj = SFW_NEW(HotDispatch);

    if (obj == nil) {
        return 0;
    }

    for (int i = 0; i < thread_count; ++i) {
        ctx[i].obj = obj;
        ctx[i].loops = loops_per_thread;
        ctx[i].sum = 0;
        if (pthread_create(&threads[i], nullptr, dispatch_thread_main, &ctx[i]) != 0) {
            objc_release(obj);
            return 0;
        }
    }

    long long total = 0;
    for (int i = 0; i < thread_count; ++i) {
        if (pthread_join(threads[i], nullptr) != 0) {
            objc_release(obj);
            return 0;
        }
        total += ctx[i].sum;
    }

    objc_release(obj);
    return total == (long long)thread_count * ((long long)loops_per_thread * (loops_per_thread + 1) / 2);
}

static int case_dispatch_c_msgsend_signatures(void)
{
#ifdef SF_DISPATCH_BACKEND_C
    SEL zero_sel = sel_registerName("zero");
    SEL take_i_sel = sel_registerName("takeI:");
    SEL take_iq_sel = sel_registerName("takeIq:second:");
    SEL take_q_sel = sel_registerName("takeQ:star:sel:");
    SEL take_obj_sel = sel_registerName("takeObj:cls:ptr:cstr:");
    SEL take_char_sel = sel_registerName("takeChar:");
    SEL take_short_sel = sel_registerName("takeShort:");
    SEL take_bool_sel = sel_registerName("takeBool:");
    SEL take_c_sel = sel_registerName("takeC:");
    SEL take_s_sel = sel_registerName("takeS:");
    SEL take_long_sel = sel_registerName("takeLong:");
    SEL take_ulong_sel = sel_registerName("takeULong:");
    SEL take_pointer_sel = sel_registerName("takePointer:");
    __unsafe_unretained CDispatchProbe *obj = SFW_NEW(CDispatchProbe);
    const char *hello = "hello";
    const char *const_text = "const";
    int pointer_value = 17;
    int ok = 0;

    if (obj == nil or zero_sel == nullptr or take_i_sel == nullptr or take_iq_sel == nullptr or take_q_sel == nullptr or
        take_obj_sel == nullptr or take_char_sel == nullptr or take_short_sel == nullptr or take_bool_sel == nullptr or
        take_c_sel == nullptr or take_s_sel == nullptr or take_long_sel == nullptr or take_ulong_sel == nullptr or
        take_pointer_sel == nullptr) {
        return 0;
    }

    sf_test_reset_c_dispatch_probe();
    if (objc_msgSend(obj, zero_sel) != obj or sf_test_c_dispatch_probe_argc() != 0) {
        objc_release(obj);
        return 0;
    }

    if (objc_msgSend(obj, take_i_sel, 11) != obj or sf_test_c_dispatch_probe_argc() != 1 or
        sf_test_c_dispatch_probe_value(0) != 11U) {
        objc_release(obj);
        return 0;
    }

    if (objc_msgSend(obj, take_iq_sel, 12U, 13LL) != obj or sf_test_c_dispatch_probe_argc() != 2 or
        sf_test_c_dispatch_probe_value(0) != 12U or sf_test_c_dispatch_probe_value(1) != 13U) {
        objc_release(obj);
        return 0;
    }

    if (objc_msgSend(obj, take_q_sel, 14ULL, hello, zero_sel) != obj or sf_test_c_dispatch_probe_argc() != 3 or
        sf_test_c_dispatch_probe_value(0) != 14U or
        sf_test_c_dispatch_probe_value(1) != (uintptr_t)(const void *)hello or
        sf_test_c_dispatch_probe_value(2) != (uintptr_t)(const void *)zero_sel) {
        objc_release(obj);
        return 0;
    }

    if (objc_msgSend(obj, take_obj_sel, obj, (Class)sf_object_class(obj), (void *)&pointer_value, const_text) != obj or
        sf_test_c_dispatch_probe_argc() != 4 or
        sf_test_c_dispatch_probe_value(0) != (uintptr_t)(const void *)obj or
        sf_test_c_dispatch_probe_value(1) != (uintptr_t)(const void *)sf_object_class(obj) or
        sf_test_c_dispatch_probe_value(2) != (uintptr_t)(void *)&pointer_value or
        sf_test_c_dispatch_probe_value(3) != (uintptr_t)(const void *)const_text) {
        objc_release(obj);
        return 0;
    }

    ok = objc_msgSend(obj, take_char_sel, 'a') == obj and
         sf_test_c_dispatch_probe_value(0) == (uintptr_t)'a' and
         objc_msgSend(obj, take_short_sel, (short)2) == obj and
         sf_test_c_dispatch_probe_value(0) == 2U and
         objc_msgSend(obj, take_bool_sel, 1) == obj and
         sf_test_c_dispatch_probe_value(0) == 1U and
         objc_msgSend(obj, take_c_sel, (unsigned char)3U) == obj and
         sf_test_c_dispatch_probe_value(0) == 3U and
         objc_msgSend(obj, take_s_sel, (unsigned short)4U) == obj and
         sf_test_c_dispatch_probe_value(0) == 4U and
         objc_msgSend(obj, take_long_sel, (long)5) == obj and
         sf_test_c_dispatch_probe_value(0) == 5U and
         objc_msgSend(obj, take_ulong_sel, (unsigned long)6) == obj and
         sf_test_c_dispatch_probe_value(0) == 6U and
         objc_msgSend(obj, take_pointer_sel, &pointer_value) == obj and
         sf_test_c_dispatch_probe_value(0) == (uintptr_t)(void *)&pointer_value;
    objc_release(obj);
    return ok;
#else
    return 1;
#endif
}

static int case_dispatch_c_msgsend_unsupported_float(void)
{
#ifdef SF_DISPATCH_BACKEND_C
    SEL take_double_sel = sel_registerName("takeDouble:");
    __unsafe_unretained CDispatchProbe *obj = SFW_NEW(CDispatchProbe);
    id result = nil;

    if (obj == nil or take_double_sel == nullptr) {
        return 0;
    }

    sf_test_reset_c_dispatch_probe();
    result = objc_msgSend(obj, take_double_sel, 1.25);
    objc_release(obj);
    return result == nil and sf_test_c_dispatch_probe_argc() == 0;
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
    SEL zero_sel = sel_registerName("zero");
    SEL obj_class_ptr_sel = sel_registerName("takeObj:cls:ptr:cstr:");
    SEL struct_sel = sel_registerName("takeStruct:");
    SEL union_sel = sel_registerName("takeUnion:");
    SEL unsupported_sel = sel_registerName("takeDouble:");
    SEL many_sel = sel_registerName("takeMany:second:third:fourth:fifth:");
    Class probe_class = (Class)objc_getClass("CDispatchProbe");

    if (zero_sel == nullptr or obj_class_ptr_sel == nullptr or struct_sel == nullptr or union_sel == nullptr or
        unsupported_sel == nullptr or many_sel == nullptr or probe_class == Nil) {
        return 0;
    }

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
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes(nullptr, codes, &unsupported) != 0 or unsupported != 0) {
        return 0;
    }
    unsupported = 7;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes((SEL)&g_raw_null_types, codes, &unsupported) != 0 or
        unsupported != 0) {
        return 0;
    }
    unsupported = 7;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes((SEL)&g_raw_empty, codes, &unsupported) != 0 or
        unsupported != 0) {
        return 0;
    }

    memset(codes, 0, sizeof(codes));
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes(obj_class_ptr_sel, codes, &unsupported) != 4 or
        codes[0] != '@' or codes[1] != '#' or codes[2] != '^' or codes[3] != '*') {
        return 0;
    }

    memset(codes, 0, sizeof(codes));
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes(struct_sel, codes, &unsupported) != 1 or codes[0] != '{') {
        return 0;
    }

    memset(codes, 0, sizeof(codes));
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes(union_sel, codes, &unsupported) != 1 or codes[0] != '(') {
        return 0;
    }

    unsupported = 0;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes(unsupported_sel, codes, &unsupported) != 0 or
        unsupported == 0) {
        return 0;
    }

    unsupported = 0;
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes(many_sel, codes, &unsupported) != 4 or unsupported == 0) {
        return 0;
    }

    memset(codes, 0, sizeof(codes));
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes_cached(obj_class_ptr_sel, codes, &unsupported) != 4) {
        return 0;
    }

    memset(codes, 0, sizeof(codes));
    if (sf_runtime_test_dispatch_collect_explicit_arg_codes_cached(obj_class_ptr_sel, codes, &unsupported) != 4 or
        codes[0] != '@' or codes[1] != '#' or codes[2] != '^' or codes[3] != '*') {
        return 0;
    }

    if (sf_runtime_test_dispatch_collect_explicit_arg_codes_cached(nullptr, codes, &unsupported) != 0) {
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
        sf_runtime_test_dispatch_read_word_arg('#', probe_class) != (uintptr_t)(const void *)probe_class or
        sf_runtime_test_dispatch_read_word_arg('^', (void *)&codes) != (uintptr_t)(void *)&codes or
        sf_runtime_test_dispatch_read_word_arg('[', (void *)&codes) != (uintptr_t)(void *)&codes or
        sf_runtime_test_dispatch_read_word_arg('(', (void *)&codes) != (uintptr_t)(void *)&codes or
        sf_runtime_test_dispatch_read_word_arg('{', (void *)&codes) != (uintptr_t)(void *)&codes or
        sf_runtime_test_dispatch_read_word_arg('?', (void *)&g_raw_unknown) != (uintptr_t)(void *)&g_raw_unknown) {
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
         [obj sumBigStruct:big bias:10] == 20;
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

static int case_dispatch_dtable_lookup(void)
{
    Class cls = (Class)objc_getClass("HotDispatch");
    SEL calc_sel = sel_registerName("calc:");
    __unsafe_unretained HotDispatch *obj = SFW_NEW(HotDispatch);
    IMP imp = nullptr;
    int ok = 0;

    if (cls == Nil or calc_sel == nullptr or obj == nil) {
        return 0;
    }

    imp = sf_lookup_imp_in_class(cls, calc_sel);
    ok = imp != nullptr and ((int (*)(id, SEL, int))imp)(obj, calc_sel, 41) == 42;
    objc_release(obj);
    return ok;
}

static int case_dispatch_forwarding_targets(void)
{
#if SF_RUNTIME_FORWARDING
    SEL instance_sel = sel_registerName("forwardedValue:");
    SEL class_sel = sel_registerName("classForwardedValue:");
    Class proxy_cls = (Class)objc_getClass("ForwardDispatchProxy");
    __unsafe_unretained ForwardDispatchProxy *proxy = SFW_NEW(ForwardDispatchProxy);
    int instance_result0 = 0;
    int instance_result1 = 0;
    int class_result0 = 0;
    int class_result1 = 0;

    if (proxy == nil or proxy_cls == Nil or instance_sel == nullptr or class_sel == nullptr) {
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
    {"dispatch_selector_equality", case_dispatch_selector_equality},
    {"dispatch_selector_lookup_only_registration", case_dispatch_selector_lookup_only_registration},
    {"dispatch_method_lookup_canonical", case_dispatch_method_lookup_canonical},
    {"dispatch_concurrent_reads", case_dispatch_concurrent_reads},
    {"dispatch_c_msgsend_signatures", case_dispatch_c_msgsend_signatures},
    {"dispatch_c_msgsend_unsupported_float", case_dispatch_c_msgsend_unsupported_float},
    {"dispatch_c_internal_helpers", case_dispatch_c_internal_helpers},
    {"dispatch_struct_params", case_dispatch_struct_params},
    {"dispatch_struct_returns", case_dispatch_struct_returns},
    {"dispatch_dtable_lookup", case_dispatch_dtable_lookup},
    {"dispatch_forwarding_targets", case_dispatch_forwarding_targets},
};

const SFTestCase *sf_runtime_dispatch_cases(size_t *count)
{
    if (count != nullptr) {
        *count = sizeof(g_dispatch_cases) / sizeof(g_dispatch_cases[0]);
    }
    return g_dispatch_cases;
}
