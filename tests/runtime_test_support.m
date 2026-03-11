#include <signal.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#include <malloc.h>
#include <stdio.h>
#include <windows.h>
#else
#include <sys/wait.h>
#include <unistd.h>
#endif

#include "runtime_test_support.h"

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
#pragma clang diagnostic ignored "-Wpre-c23-compat"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#pragma clang diagnostic ignored "-Wpadded"
#endif

int g_counter_deallocs = 0;

typedef struct SFForwardSelector {
    const char *name;
    const char *types;
} SFForwardSelector;

static SFForwardSelector g_forwarded_value_sel = {"forwardedValue:", "i20@0:8i16"};
static SFForwardSelector g_class_forwarded_value_sel = {"classForwardedValue:", "i20@0:8i16"};

extern int sf_test_llvm_profile_write_file(void) __asm__("__llvm_profile_write_file") __attribute__((weak));

#if not defined(_WIN32)
static void sf_test_flush_profile_and_reraise(int sig)
{
    if (sf_test_llvm_profile_write_file != NULL) {
        (void)sf_test_llvm_profile_write_file();
    }
    signal(sig, SIG_DFL);
    raise(sig);
}
#endif

static void *sf_test_aligned_alloc(size_t size, size_t align)
{
#if not defined(_WIN32)
    void *ptr = NULL;
#endif
    if (align <= sizeof(void *)) {
        return malloc(size);
    }
#if defined(_WIN32)
    return _aligned_malloc(size, align);
#else
    if (posix_memalign(&ptr, align, size) != 0) {
        return NULL;
    }
    return ptr;
#endif
}

static void sf_test_aligned_free(void *ptr, size_t align)
{
#if defined(_WIN32)
    if (align > sizeof(void *)) {
        _aligned_free(ptr);
        return;
    }
#else
    (void)align;
#endif
    free(ptr);
}

@implementation CounterObject
- (void)dealloc
{
    (void)__atomic_fetch_add(&g_counter_deallocs, 1, __ATOMIC_RELAXED);
}
@end

@implementation InlineValue
@end

@implementation InlineValueSub
@end

@implementation InlineLargeValueSub
@end

@implementation InlineHolder
@end

@implementation InlinePairHolder
@end

@implementation SuperBase
- (int)ping
{
    return 10;
}
@end

@implementation SuperChild
- (int)ping
{
    return [super ping] + 7;
}
@end

@implementation AllocTracked
@end

@implementation HotDispatch
- (int)calc:(int)x
{
    return x + 1;
}
@end

@implementation StructDispatchProbe
- (SFTestPair)pairWithLeft:(int)left right:(int)right
{
    SFTestPair pair = {.left = left, .right = right};
    return pair;
}

- (long long)sumPair:(SFTestPair)pair
{
    return (long long)pair.left + (long long)pair.right;
}

- (long long)sumBigStruct:(SFTestBigStruct)big bias:(long long)bias
{
    return big.first + big.second + big.third + big.fourth + bias;
}

- (SFTestWidePair)widePairWithSeed:(long long)seed
{
    SFTestWidePair pair = {.left = seed, .right = seed + 1};
    return pair;
}

- (SFTestBigStruct)bigStructWithSeed:(long long)seed
{
    SFTestBigStruct big = {
        .first = seed,
        .second = seed + 1,
        .third = seed + 2,
        .fourth = seed + 3,
    };
    return big;
}
@end

static ForwardDispatchTarget *sf_test_forward_dispatch_target(void)
{
    static ForwardDispatchTarget *target = nil;
    if (target == nil) {
        target = SFW_NEW(ForwardDispatchTarget);
    }
    return target;
}

@implementation ForwardDispatchTarget
- (int)forwardedValue:(int)x
{
    return x + 100;
}

+ (int)classForwardedValue:(int)x
{
    return x + 200;
}
@end

@implementation ForwardDispatchProxy
- (id)forwardingTargetForSelector:(SEL)selector
{
    if (sf_selector_equal(selector, (SEL)&g_forwarded_value_sel)) {
        return sf_test_forward_dispatch_target();
    }
    return nil;
}

+ (id)forwardingTargetForSelector:(SEL)selector
{
    if (sf_selector_equal(selector, (SEL)&g_class_forwarded_value_sel)) {
        return objc_getClass("ForwardDispatchTarget");
    }
    return nil;
}
@end

@implementation ReflectionProbe
+ (int)classPing
{
    return 1;
}
- (int)instancePing
{
    return 2;
}
@end

#if SF_RUNTIME_EXCEPTIONS
@implementation ExceptionBase
@end

@implementation ExceptionChild
@end
#endif

void sf_test_reset_common_state(void)
{
    __atomic_store_n(&g_counter_deallocs, 0, __ATOMIC_RELAXED);
    sf_runtime_test_reset_alloc_failures();
}

CounterObject *sf_test_factory_object(void)
{
    return SFW_NEW(CounterObject);
}

void *sf_test_counting_alloc(void *ctx, size_t size, size_t align)
{
    SFTestAllocatorCtx *state = (SFTestAllocatorCtx *)ctx;
    void *ptr = NULL;

    (void)__atomic_fetch_add(&state->alloc_calls, 1, __ATOMIC_RELAXED);
    state->last_size = size;
    state->last_align = align;

    ptr = sf_test_aligned_alloc(size, align);

    if (ptr != NULL) {
        (void)__atomic_fetch_add(&state->active_blocks, (size_t)1, __ATOMIC_RELAXED);
    }
    return ptr;
}

void sf_test_counting_free(void *ctx, void *ptr, size_t size, size_t align)
{
    SFTestAllocatorCtx *state = (SFTestAllocatorCtx *)ctx;
    (void)size;
    (void)align;
    if (ptr != NULL) {
        (void)__atomic_fetch_add(&state->free_calls, 1, __ATOMIC_RELAXED);
        (void)__atomic_fetch_sub(&state->active_blocks, (size_t)1, __ATOMIC_RELAXED);
    }
    sf_test_aligned_free(ptr, align);
}

SFAllocator_t sf_test_make_counting_allocator(SFTestAllocatorCtx *ctx)
{
    SFAllocator_t allocator = {
        .alloc = sf_test_counting_alloc,
        .free = sf_test_counting_free,
        .ctx = ctx,
    };
    return allocator;
}

int sf_test_expect_signal(SFTestChildFn fn, void *ctx, int expected_signal)
{
#if defined(_WIN32)
    (void)fn;
    (void)ctx;
    (void)expected_signal;
    return 0;
#else
    pid_t pid = fork();
    if (pid < 0) {
        return 0;
    }
    if (pid == 0) {
        (void)signal(expected_signal, sf_test_flush_profile_and_reraise);
        fn(ctx);
        _exit(0);
    }

    int status = 0;
    if (waitpid(pid, &status, 0) != pid) {
        return 0;
    }
    return WIFSIGNALED(status) and WTERMSIG(status) == expected_signal;
#endif
}

int sf_test_expect_signal_case(const char *case_name, int expected_signal)
{
#if defined(_WIN32)
    char exe_path[MAX_PATH];
    char command_line[1024];
    STARTUPINFOA startup_info;
    PROCESS_INFORMATION process_info;
    DWORD exit_code = 0;

    (void)expected_signal;
    if (case_name == NULL or GetModuleFileNameA(NULL, exe_path, MAX_PATH) == 0) {
        return 0;
    }

    memset(&startup_info, 0, sizeof(startup_info));
    memset(&process_info, 0, sizeof(process_info));
    startup_info.cb = sizeof(startup_info);
    if ((size_t)snprintf(command_line, sizeof(command_line), "\"%s\" --case %s", exe_path, case_name) >=
        sizeof(command_line)) {
        return 0;
    }
    if (not CreateProcessA(exe_path, command_line, NULL, NULL, FALSE, 0, NULL, NULL, &startup_info, &process_info)) {
        return 0;
    }

    if (WaitForSingleObject(process_info.hProcess, INFINITE) != WAIT_OBJECT_0) {
        CloseHandle(process_info.hThread);
        CloseHandle(process_info.hProcess);
        return 0;
    }
    if (not GetExitCodeProcess(process_info.hProcess, &exit_code)) {
        CloseHandle(process_info.hThread);
        CloseHandle(process_info.hProcess);
        return 0;
    }
    CloseHandle(process_info.hThread);
    CloseHandle(process_info.hProcess);
    return exit_code != 0;
#else
    (void)case_name;
    (void)expected_signal;
    return 0;
#endif
}

#ifdef __clang__
#pragma clang diagnostic pop
#endif
