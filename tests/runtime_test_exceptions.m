#include <signal.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "runtime_test_support.h"

#if SF_RUNTIME_EXCEPTIONS
#define TEST_SF_EXCEPTION_CLASS UINT64_C(0x5346574f424a4300)
#define TEST_DW_EH_PE_PTR UINT8_C(0x00)
#define TEST_DW_EH_PE_ULEB128 UINT8_C(0x01)
#define TEST_DW_EH_PE_UDATA2 UINT8_C(0x02)
#define TEST_DW_EH_PE_UDATA4 UINT8_C(0x03)
#define TEST_DW_EH_PE_UDATA8 UINT8_C(0x04)
#define TEST_DW_EH_PE_SLEB128 UINT8_C(0x09)
#define TEST_DW_EH_PE_SDATA2 UINT8_C(0x0A)
#define TEST_DW_EH_PE_SDATA4 UINT8_C(0x0B)
#define TEST_DW_EH_PE_SDATA8 UINT8_C(0x0C)
#define TEST_DW_EH_PE_PCREL UINT8_C(0x10)
#define TEST_DW_EH_PE_OMIT UINT8_C(0xFF)
#define TEST_DW_EH_PE_INDIRECT UINT8_C(0x80)

typedef struct SFTestExceptionObject {
    struct _Unwind_Exception unwind;
    id object;
    uint32_t catch_depth;
    uint32_t reserved;
} SFTestExceptionObject;

typedef struct SFTestFailAllocCtx {
    int alloc_calls;
} SFTestFailAllocCtx;

static void *fail_alloc_once(void *ctx, size_t size, size_t align)
{
    SFTestFailAllocCtx *state = (SFTestFailAllocCtx *)ctx;
    (void)size;
    (void)align;
    state->alloc_calls += 1;
    return NULL;
}

static void fail_alloc_free(void *ctx, void *ptr, size_t size, size_t align)
{
    (void)ctx;
    (void)size;
    (void)align;
    free(ptr);
}

static void child_throw_uncaught(void *ctx)
{
    (void)ctx;
    __unsafe_unretained ExceptionBase *obj = SFW_NEW(ExceptionBase);
    objc_exception_throw(obj);
}

static void child_throw_alloc_failure(void *ctx)
{
    (void)ctx;
    sf_runtime_test_fail_allocation_after(0);
    objc_exception_throw(nil);
}

static void child_direct_rethrow(void *ctx)
{
    (void)ctx;
    @try {
        @throw SFW_NEW(ExceptionBase);
    }
    @catch (id e) {
        (void)e;
        objc_exception_rethrow(NULL);
    }
}

static void child_invalid_encoding_abort(void *ctx)
{
    (void)ctx;
    static const uint8_t data[] = {0};
    const uint8_t *p = data;
    (void)sf_runtime_test_exception_read_encoded(&p, UINT8_C(0x05));
}

static int case_exceptions_begin_catch_passthrough(void)
{
    sf_test_reset_common_state();
    if (objc_begin_catch(NULL) != nil) {
        return 0;
    }
    objc_end_catch();
    return 1;
}

static int case_exceptions_internal_helpers(void)
{
    SFTestExceptionObject runtime_exc;
    SFTestExceptionObject foreign_exc;
    memset(&runtime_exc, 0, sizeof(runtime_exc));
    memset(&foreign_exc, 0, sizeof(foreign_exc));

    runtime_exc.unwind.exception_class = TEST_SF_EXCEPTION_CLASS;
    runtime_exc.object = SFW_NEW(ExceptionChild);

    if (sf_runtime_test_exception_matches_type(NULL, "@id") != 0 or
        sf_runtime_test_exception_matches_type(&runtime_exc.unwind, NULL) != 0 or
        sf_runtime_test_exception_matches_type(&foreign_exc.unwind, "@id") != 0 or
        sf_runtime_test_exception_matches_type(&runtime_exc.unwind, "@id") == 0 or
        sf_runtime_test_exception_matches_type(&runtime_exc.unwind, "ExceptionBase") == 0 or
        sf_runtime_test_exception_matches_type(&runtime_exc.unwind, "DefinitelyMissingType") != 0 or
        sf_exception_backtrace_count(nil) != 0 or
        sf_exception_backtrace_frame(nil, 0) != NULL) {
        objc_release(runtime_exc.object);
        return 0;
    }

    sf_exception_clear_metadata(nil);
    objc_release(runtime_exc.object);
    return 1;
}

static int case_exceptions_backtrace_metadata(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained ExceptionBase *source = SFW_NEW(ExceptionBase);
    __unsafe_unretained ExceptionBase *kept = nil;
    size_t count = 0;
    const void *frame = NULL;

    @try {
        @throw source;
    }
    @catch (ExceptionBase *e) {
        kept = [e retain];
        count = e.exceptionBacktraceCount;
        frame = [e exceptionBacktraceFrameAtIndex:0];
        if (count == 0 or
            frame == NULL or
            [e exceptionBacktraceFrameAtIndex:count] != NULL or
            sf_exception_backtrace_count(e) != count or
            sf_exception_backtrace_frame(e, 0) != frame) {
            objc_release(kept);
            return 0;
        }
    }

    if (kept == nil) {
        objc_release(source);
        return 0;
    }

    objc_release(source);
    objc_release(kept);
    return sf_exception_backtrace_count(kept) == 0 and
           sf_exception_backtrace_frame(kept, 0) == NULL;
}

static int case_exceptions_backtrace_metadata_alloc_failure(void)
{
    sf_test_reset_common_state();

    __unsafe_unretained ExceptionBase *source = SFW_NEW(ExceptionBase);
    __unsafe_unretained ExceptionBase *kept = nil;
    sf_runtime_test_fail_allocation_after(1);

    @try {
        @throw source;
    }
    @catch (ExceptionBase *e) {
        kept = [e retain];
    }

    sf_runtime_test_reset_alloc_failures();
    if (kept == nil) {
        objc_release(source);
        return 0;
    }

    int ok = kept.exceptionBacktraceCount == 0 and
             [kept exceptionBacktraceFrameAtIndex:0] == NULL;
    objc_release(source);
    objc_release(kept);
    return ok and sf_exception_backtrace_count(kept) == 0;
}

static int case_exceptions_object_alloc_failure_throws(void)
{
    SFTestFailAllocCtx ctx = {0};
    SFAllocator_t allocator = {
        .alloc = fail_alloc_once,
        .free = fail_alloc_free,
        .ctx = &ctx,
    };

    @try {
        (void)[[Object allocWithAllocator:&allocator] init];
    }
    @catch (AllocationFailedException *e) {
        return ctx.alloc_calls == 1 and
               e != nil and
               e.exceptionBacktraceCount > 0 and
               [e exceptionBacktraceFrameAtIndex:e.exceptionBacktraceCount] == NULL;
    }

    return 0;
}

static int case_exceptions_encoding_helpers(void)
{
    uintptr_t ptr_value = (uintptr_t)0x1234u;
    uintptr_t indirect_target = (uintptr_t)0x9988u;
    uintptr_t indirect_ptr = (uintptr_t)&indirect_target;
    uint16_t u16 = UINT16_C(0x4567);
    uint32_t u32 = UINT32_C(0x89ABCDEF);
    uint64_t u64 = UINT64_C(0x0123456789ABCDEF);
    int16_t s16 = -7;
    int32_t s32 = -11;
    int64_t s64 = -13;
    int32_t rel = 4;
    const uint8_t uleb[] = {0x81, 0x01};
    const uint8_t sleb[] = {0x7e};
    const uint8_t omit[] = {0};
    const uint8_t *p = NULL;

    p = (const uint8_t *)&ptr_value;
    if (sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_PTR) != ptr_value) {
        return 0;
    }
    p = (const uint8_t *)&u16;
    if (sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_UDATA2) != (uintptr_t)u16) {
        return 0;
    }
    p = (const uint8_t *)&u32;
    if (sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_UDATA4) != (uintptr_t)u32) {
        return 0;
    }
    p = (const uint8_t *)&u64;
    if (sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_UDATA8) != (uintptr_t)u64) {
        return 0;
    }
    p = uleb;
    if (sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_ULEB128) != (uintptr_t)129u) {
        return 0;
    }
    p = sleb;
    if ((intptr_t)sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_SLEB128) != -2) {
        return 0;
    }
    p = (const uint8_t *)&s16;
    if ((intptr_t)sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_SDATA2) != -7) {
        return 0;
    }
    p = (const uint8_t *)&s32;
    if ((intptr_t)sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_SDATA4) != -11) {
        return 0;
    }
    p = (const uint8_t *)&s64;
    if ((intptr_t)sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_SDATA8) != -13) {
        return 0;
    }
    p = (const uint8_t *)&rel;
    if (sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_SDATA4 | TEST_DW_EH_PE_PCREL) !=
        (uintptr_t)((const uint8_t *)&rel + 4)) {
        return 0;
    }
    p = (const uint8_t *)&indirect_ptr;
    if (sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_PTR | TEST_DW_EH_PE_INDIRECT) != indirect_target) {
        return 0;
    }
    p = omit;
    if (sf_runtime_test_exception_read_encoded(&p, TEST_DW_EH_PE_OMIT) != 0) {
        return 0;
    }

    return sf_runtime_test_exception_encoding_size(TEST_DW_EH_PE_UDATA2) == 2 and
           sf_runtime_test_exception_encoding_size(TEST_DW_EH_PE_SDATA2) == 2 and
           sf_runtime_test_exception_encoding_size(TEST_DW_EH_PE_UDATA4) == 4 and
           sf_runtime_test_exception_encoding_size(TEST_DW_EH_PE_SDATA4) == 4 and
           sf_runtime_test_exception_encoding_size(TEST_DW_EH_PE_UDATA8) == 8 and
           sf_runtime_test_exception_encoding_size(TEST_DW_EH_PE_SDATA8) == 8 and
           sf_runtime_test_exception_encoding_size(TEST_DW_EH_PE_PTR) == sizeof(uintptr_t) and
           sf_runtime_test_exception_encoding_size(UINT8_C(0x05)) == sizeof(uintptr_t);
}

static int case_exceptions_parse_lsda_helpers(void)
{
    static const uint8_t cleanup_direct[] = {
        TEST_DW_EH_PE_OMIT,
        TEST_DW_EH_PE_OMIT,
        TEST_DW_EH_PE_ULEB128,
        0x04,
        0x00,
        0x0A,
        0x04,
        0x00,
    };
    static const uint8_t cleanup_action[] = {
        TEST_DW_EH_PE_OMIT,
        TEST_DW_EH_PE_OMIT,
        TEST_DW_EH_PE_ULEB128,
        0x04,
        0x00,
        0x0A,
        0x04,
        0x01,
        0x00,
        0x00,
    };
    static const uint8_t no_handler_chain[] = {
        TEST_DW_EH_PE_OMIT,
        TEST_DW_EH_PE_OMIT,
        TEST_DW_EH_PE_ULEB128,
        0x04,
        0x00,
        0x0A,
        0x04,
        0x01,
        0x01,
        0x01,
        0x01,
        0x00,
    };
    uint8_t lpstart_zero_lp[8 + sizeof(uintptr_t)] = {0};
    uintptr_t lpstart = (uintptr_t)200u;
    SFRuntimeTestLandingInfo_t info;

    memset(&info, 0, sizeof(info));
    if (sf_runtime_test_exception_parse_lsda(NULL, 100, 100, NULL, &info) != 0) {
        return 0;
    }

    memset(&info, 0, sizeof(info));
    if (sf_runtime_test_exception_parse_lsda(cleanup_direct, 100, 105, NULL, &info) == 0 or
        info.has_cleanup == 0 or info.has_handler != 0 or info.landing_pad != (uintptr_t)104u) {
        return 0;
    }

    lpstart_zero_lp[0] = TEST_DW_EH_PE_PTR;
    memcpy(lpstart_zero_lp + 1, &lpstart, sizeof(lpstart));
    lpstart_zero_lp[1 + sizeof(lpstart)] = TEST_DW_EH_PE_OMIT;
    lpstart_zero_lp[2 + sizeof(lpstart)] = TEST_DW_EH_PE_ULEB128;
    lpstart_zero_lp[3 + sizeof(lpstart)] = 0x04;
    lpstart_zero_lp[4 + sizeof(lpstart)] = 0x00;
    lpstart_zero_lp[5 + sizeof(lpstart)] = 0x0A;
    lpstart_zero_lp[6 + sizeof(lpstart)] = 0x00;
    lpstart_zero_lp[7 + sizeof(lpstart)] = 0x00;
    memset(&info, 0, sizeof(info));
    if (sf_runtime_test_exception_parse_lsda(lpstart_zero_lp, 100, 105, NULL, &info) != 0) {
        return 0;
    }

    memset(&info, 0, sizeof(info));
    if (sf_runtime_test_exception_parse_lsda(cleanup_action, 100, 105, NULL, &info) == 0 or
        info.has_cleanup == 0 or info.has_handler != 0) {
        return 0;
    }

    memset(&info, 0, sizeof(info));
    if (sf_runtime_test_exception_parse_lsda(no_handler_chain, 100, 105, NULL, &info) != 0) {
        return 0;
    }

    memset(&info, 0, sizeof(info));
    if (sf_runtime_test_exception_parse_lsda(cleanup_direct, 100, 200, NULL, &info) != 0) {
        return 0;
    }

    return 1;
}

static int case_exceptions_personality_result_helper(void)
{
    return sf_runtime_test_exception_personality_result(_UA_SEARCH_PHASE, 0, 1) == _URC_HANDLER_FOUND and
           sf_runtime_test_exception_personality_result(_UA_SEARCH_PHASE, 0, 0) == _URC_CONTINUE_UNWIND and
           sf_runtime_test_exception_personality_result((_Unwind_Action)0, 0, 0) == _URC_CONTINUE_UNWIND and
           sf_runtime_test_exception_personality_result((_Unwind_Action)(_UA_CLEANUP_PHASE | _UA_HANDLER_FRAME), 0, 0) == _URC_CONTINUE_UNWIND and
           sf_runtime_test_exception_personality_result(_UA_CLEANUP_PHASE, 0, 0) == _URC_CONTINUE_UNWIND and
           sf_runtime_test_exception_personality_result(_UA_CLEANUP_PHASE, 1, 0) == _URC_INSTALL_CONTEXT;
}

static int case_exceptions_catch_id(void)
{
    int got = 0;
    @try {
        @throw SFW_NEW(ExceptionBase);
    }
    @catch (id e) {
        got = (e != nil);
    }
    return got == 1;
}

static int case_exceptions_typed_exact(void)
{
    int got = 0;
    @try {
        @throw SFW_NEW(ExceptionBase);
    }
    @catch (ExceptionBase *e) {
        (void)e;
        got = 1;
    }
    @catch (id e) {
        (void)e;
        got = 2;
    }
    return got == 1;
}

static int case_exceptions_typed_subclass(void)
{
    int got = 0;
    @try {
        @throw SFW_NEW(ExceptionChild);
    }
    @catch (ExceptionBase *e) {
        (void)e;
        got = 1;
    }
    @catch (id e) {
        (void)e;
        got = 2;
    }
    return got == 1;
}

static int case_exceptions_finally_runs(void)
{
    int finally_flag = 0;
    @try {
        @throw SFW_NEW(ExceptionBase);
    }
    @catch (id e) {
        (void)e;
    }
    @finally {
        finally_flag = 1;
    }
    return finally_flag == 1;
}

static int case_exceptions_rethrow(void)
{
    int outer = 0;
    @try {
        @try {
            @throw SFW_NEW(ExceptionChild);
        }
        @catch (ExceptionChild *e) {
            (void)e;
            @throw;
        }
    }
    @catch (id e) {
        (void)e;
        outer = 1;
    }
    return outer == 1;
}

static int case_child_exceptions_uncaught_abort(void)
{
    child_throw_uncaught(NULL);
    return 0;
}

static int case_exceptions_uncaught_abort(void)
{
#if defined(_WIN32)
    return sf_test_expect_signal_case("__child_exceptions_uncaught_abort", SIGABRT);
#else
    return sf_test_expect_signal(child_throw_uncaught, NULL, SIGABRT);
#endif
}

static int case_child_exceptions_throw_alloc_failure_abort(void)
{
    child_throw_alloc_failure(NULL);
    return 0;
}

static int case_exceptions_throw_alloc_failure_abort(void)
{
#if defined(_WIN32)
    return sf_test_expect_signal_case("__child_exceptions_throw_alloc_failure_abort", SIGABRT);
#else
    return sf_test_expect_signal(child_throw_alloc_failure, NULL, SIGABRT);
#endif
}

static int case_child_exceptions_direct_rethrow_abort(void)
{
    child_direct_rethrow(NULL);
    return 0;
}

static int case_exceptions_direct_rethrow_abort(void)
{
#if defined(_WIN32)
    return sf_test_expect_signal_case("__child_exceptions_direct_rethrow_abort", SIGABRT);
#else
    return sf_test_expect_signal(child_direct_rethrow, NULL, SIGABRT);
#endif
}

static int case_child_exceptions_invalid_encoding_abort(void)
{
    child_invalid_encoding_abort(NULL);
    return 0;
}

static int case_exceptions_invalid_encoding_abort(void)
{
#if defined(_WIN32)
    return sf_test_expect_signal_case("__child_exceptions_invalid_encoding_abort", SIGABRT);
#else
    return sf_test_expect_signal(child_invalid_encoding_abort, NULL, SIGABRT);
#endif
}

static const SFTestCase g_exception_cases[] = {
    {"exceptions_begin_catch_passthrough", case_exceptions_begin_catch_passthrough},
    {"exceptions_internal_helpers", case_exceptions_internal_helpers},
    {"exceptions_backtrace_metadata", case_exceptions_backtrace_metadata},
    {"exceptions_backtrace_metadata_alloc_failure", case_exceptions_backtrace_metadata_alloc_failure},
    {"exceptions_object_alloc_failure_throws", case_exceptions_object_alloc_failure_throws},
    {"exceptions_encoding_helpers", case_exceptions_encoding_helpers},
    {"exceptions_parse_lsda_helpers", case_exceptions_parse_lsda_helpers},
    {"exceptions_personality_result_helper", case_exceptions_personality_result_helper},
    {"exceptions_catch_id", case_exceptions_catch_id},
    {"exceptions_typed_exact", case_exceptions_typed_exact},
    {"exceptions_typed_subclass", case_exceptions_typed_subclass},
    {"exceptions_finally_runs", case_exceptions_finally_runs},
    {"exceptions_rethrow", case_exceptions_rethrow},
    {"exceptions_uncaught_abort", case_exceptions_uncaught_abort},
    {"exceptions_throw_alloc_failure_abort", case_exceptions_throw_alloc_failure_abort},
    {"exceptions_direct_rethrow_abort", case_exceptions_direct_rethrow_abort},
    {"exceptions_invalid_encoding_abort", case_exceptions_invalid_encoding_abort},
    {"__child_exceptions_uncaught_abort", case_child_exceptions_uncaught_abort},
    {"__child_exceptions_throw_alloc_failure_abort", case_child_exceptions_throw_alloc_failure_abort},
    {"__child_exceptions_direct_rethrow_abort", case_child_exceptions_direct_rethrow_abort},
    {"__child_exceptions_invalid_encoding_abort", case_child_exceptions_invalid_encoding_abort},
};
#else
static void child_stub_throw(void *ctx)
{
    (void)ctx;
    objc_exception_throw(nil);
}

static void child_stub_begin_catch(void *ctx)
{
    (void)ctx;
    (void)objc_begin_catch(NULL);
}

static void child_stub_end_catch(void *ctx)
{
    (void)ctx;
    objc_end_catch();
}

static void child_stub_rethrow(void *ctx)
{
    (void)ctx;
    objc_exception_rethrow(NULL);
}

static void child_stub_personality(void *ctx)
{
    (void)ctx;
    (void)__gnustep_objc_personality_v0(0, (_Unwind_Action)0, 0, NULL, NULL);
}

static int case_child_exceptions_stub_throw(void)
{
    child_stub_throw(NULL);
    return 0;
}

static int case_child_exceptions_stub_begin_catch(void)
{
    child_stub_begin_catch(NULL);
    return 0;
}

static int case_child_exceptions_stub_end_catch(void)
{
    child_stub_end_catch(NULL);
    return 0;
}

static int case_child_exceptions_stub_rethrow(void)
{
    child_stub_rethrow(NULL);
    return 0;
}

static int case_child_exceptions_stub_personality(void)
{
    child_stub_personality(NULL);
    return 0;
}

static int case_exceptions_stubs_abort(void)
{
#if defined(_WIN32)
    return sf_test_expect_signal_case("__child_exceptions_stub_throw", SIGABRT) and
           sf_test_expect_signal_case("__child_exceptions_stub_begin_catch", SIGABRT) and
           sf_test_expect_signal_case("__child_exceptions_stub_end_catch", SIGABRT) and
           sf_test_expect_signal_case("__child_exceptions_stub_rethrow", SIGABRT) and
           sf_test_expect_signal_case("__child_exceptions_stub_personality", SIGABRT);
#else
    return sf_test_expect_signal(child_stub_throw, NULL, SIGABRT) and
           sf_test_expect_signal(child_stub_begin_catch, NULL, SIGABRT) and
           sf_test_expect_signal(child_stub_end_catch, NULL, SIGABRT) and
           sf_test_expect_signal(child_stub_rethrow, NULL, SIGABRT) and
           sf_test_expect_signal(child_stub_personality, NULL, SIGABRT);
#endif
}

static const SFTestCase g_exception_cases[] = {
    {"exceptions_stubs_abort", case_exceptions_stubs_abort},
    {"__child_exceptions_stub_throw", case_child_exceptions_stub_throw},
    {"__child_exceptions_stub_begin_catch", case_child_exceptions_stub_begin_catch},
    {"__child_exceptions_stub_end_catch", case_child_exceptions_stub_end_catch},
    {"__child_exceptions_stub_rethrow", case_child_exceptions_stub_rethrow},
    {"__child_exceptions_stub_personality", case_child_exceptions_stub_personality},
};
#endif

const SFTestCase *sf_runtime_exception_cases(size_t *count)
{
    if (count != NULL) {
        *count = sizeof(g_exception_cases) / sizeof(g_exception_cases[0]);
    }
    return g_exception_cases;
}
