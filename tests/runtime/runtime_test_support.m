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
#endif

int g_counter_deallocs = 0;
static int g_c_dispatch_probe_argc = 0;
static uintptr_t g_c_dispatch_probe_values[4] = {0U, 0U, 0U, 0U};

extern int sf_test_llvm_profile_write_file(void) __asm__("__llvm_profile_write_file") __attribute__((weak));

#if not defined(_WIN32)
static void sf_test_flush_profile_and_reraise(int sig)
{
    if (sf_test_llvm_profile_write_file != nullptr) {
        (void)sf_test_llvm_profile_write_file();
    }
    signal(sig, SIG_DFL);
    raise(sig);
}
#endif

static void *sf_test_aligned_alloc(size_t size, size_t align)
{
#if not defined(_WIN32)
    void *ptr = nullptr;
#endif
    if (align <= sizeof(void *)) {
        return malloc(size);
    }
#if defined(_WIN32)
    return _aligned_malloc(size, align);
#else
    if (posix_memalign(&ptr, align, size) != 0) {
        return nullptr;
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

@implementation NonTrivialInlineValue
@end

@implementation NonTrivialHolder
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

static void sf_test_record_c_dispatch_probe(int argc, uintptr_t v0, uintptr_t v1, uintptr_t v2, uintptr_t v3)
{
    g_c_dispatch_probe_argc = argc;
    g_c_dispatch_probe_values[0] = v0;
    g_c_dispatch_probe_values[1] = v1;
    g_c_dispatch_probe_values[2] = v2;
    g_c_dispatch_probe_values[3] = v3;
}

@implementation CDispatchProbe
- (id _Nonnull)zero
{
    sf_test_record_c_dispatch_probe(0, 0U, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeI:(int)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeIq:(unsigned int)first second:(long long)second
{
    sf_test_record_c_dispatch_probe(2, (uintptr_t)first, (uintptr_t)second, 0U, 0U);
    return self;
}

- (id _Nonnull)takeQ:(unsigned long long)value star:(const char *_Nonnull)bytes sel:(SEL _Nonnull)selector
{
    sf_test_record_c_dispatch_probe(3, (uintptr_t)value, (uintptr_t)(const void *)bytes, (uintptr_t)(const void *)selector, 0U);
    return self;
}

- (id _Nonnull)takeObj:(id _Nonnull)obj cls:(Class _Nonnull)cls ptr:(void *_Nonnull)ptr cstr:(const char *_Nonnull)bytes
{
    sf_test_record_c_dispatch_probe(4, (uintptr_t)(const void *)obj, (uintptr_t)(const void *)cls, (uintptr_t)ptr,
                                    (uintptr_t)(const void *)bytes);
    return self;
}

- (id _Nonnull)takeChar:(char)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeShort:(short)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeBool:(_Bool)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeC:(unsigned char)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeS:(unsigned short)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeLong:(long)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeULong:(unsigned long)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takePointer:(int *_Nonnull)ptr
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)(const void *)ptr, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeStruct:(SFTestPair)pair
{
    sf_test_record_c_dispatch_probe(2, (uintptr_t)pair.left, (uintptr_t)pair.right, 0U, 0U);
    return self;
}

- (id _Nonnull)takeUnion:(SFTestEither)either
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)either.left, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeDouble:(double)value
{
    sf_test_record_c_dispatch_probe(1, (uintptr_t)value, 0U, 0U, 0U);
    return self;
}

- (id _Nonnull)takeMany:(int)first second:(int)second third:(int)third fourth:(int)fourth fifth:(int)fifth
{
    sf_test_record_c_dispatch_probe(4, (uintptr_t)first, (uintptr_t)second, (uintptr_t)third, (uintptr_t)fourth);
    (void)fifth;
    return self;
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
    static SEL forwarded_value_sel = nullptr;
    if (forwarded_value_sel == nullptr) {
        forwarded_value_sel = sel_registerName("forwardedValue:");
    }
    if (sf_selector_equal(selector, forwarded_value_sel)) {
        return sf_test_forward_dispatch_target();
    }
    return nil;
}

+ (id)forwardingTargetForSelector:(SEL)selector
{
    static SEL class_forwarded_value_sel = nullptr;
    if (class_forwarded_value_sel == nullptr) {
        class_forwarded_value_sel = sel_registerName("classForwardedValue:");
    }
    if (sf_selector_equal(selector, class_forwarded_value_sel)) {
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

#if SF_RUNTIME_TAGGED_POINTERS
static uintptr_t sf_test_pack_short_string(const char *bytes, size_t length)
{
    uintptr_t payload = 0U;
    if (bytes == nullptr or length > 6U) {
        return UINTPTR_MAX;
    }

    payload = (uintptr_t)length;
    for (size_t i = 0; i < length; ++i) {
        payload |= ((uintptr_t)(uint8_t)bytes[i]) << (3U + (i * 8U));
    }
    return payload;
}

@implementation TaggedNumberProbe
+ (uintptr_t)taggedPointerSlot
{
    return 1U;
}

+ (instancetype)numberWithValue:(uintptr_t)value
{
    return [self taggedPointerWithPayload:value];
}

- (uintptr_t)value
{
    return self.taggedPointerPayload;
}

- (TaggedNumberProbe *)plus:(uintptr_t)delta
{
    return (TaggedNumberProbe *)sf_make_tagged_pointer(sf_object_class(self), self.taggedPointerPayload + delta);
}
@end

@implementation TaggedStringProbe
+ (uintptr_t)taggedPointerSlot
{
    return 2U;
}

+ (instancetype)stringWithBytes:(const char *)bytes length:(size_t)length
{
    uintptr_t payload = sf_test_pack_short_string(bytes, length);
    if (payload == UINTPTR_MAX) {
        return nil;
    }
    return [self taggedPointerWithPayload:payload];
}

- (unsigned long)length
{
    return (unsigned long)(self.taggedPointerPayload & (uintptr_t)7U);
}

- (unsigned int)characterAtIndex:(unsigned long)index
{
    uintptr_t payload = self.taggedPointerPayload;
    if (index >= self.length) {
        return 0U;
    }
    return (unsigned int)((payload >> (3U + ((uintptr_t)index * 8U))) & (uintptr_t)0xffU);
}
@end

@implementation TaggedDuplicateA
+ (uintptr_t)taggedPointerSlot
{
    return 3U;
}
@end

@implementation TaggedDuplicateB
+ (uintptr_t)taggedPointerSlot
{
    return 3U;
}
@end

@implementation TaggedInvalidSlotProbe
+ (uintptr_t)taggedPointerSlot
{
    return 8U;
}
@end

@implementation TaggedValueProbe
+ (uintptr_t)taggedPointerSlot
{
    return 4U;
}
@end
#endif

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
    void *ptr = nullptr;

    (void)__atomic_fetch_add(&state->alloc_calls, 1, __ATOMIC_RELAXED);
    state->last_size = size;
    state->last_align = align;

    ptr = sf_test_aligned_alloc(size, align);

    if (ptr != nullptr) {
        (void)__atomic_fetch_add(&state->active_blocks, (size_t)1, __ATOMIC_RELAXED);
    }
    return ptr;
}

void sf_test_counting_free(void *ctx, void *ptr, size_t size, size_t align)
{
    SFTestAllocatorCtx *state = (SFTestAllocatorCtx *)ctx;
    (void)size;
    (void)align;
    if (ptr != nullptr) {
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

void sf_test_reset_c_dispatch_probe(void)
{
    sf_test_record_c_dispatch_probe(0, 0U, 0U, 0U, 0U);
}

int sf_test_c_dispatch_probe_argc(void)
{
    return g_c_dispatch_probe_argc;
}

uintptr_t sf_test_c_dispatch_probe_value(int index)
{
    if (index < 0 or index >= 4) {
        return 0U;
    }
    return g_c_dispatch_probe_values[index];
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
    if (case_name == nullptr or GetModuleFileNameA(nullptr, exe_path, MAX_PATH) == 0) {
        return 0;
    }

    memset(&startup_info, 0, sizeof(startup_info));
    memset(&process_info, 0, sizeof(process_info));
    startup_info.cb = sizeof(startup_info);
    if ((size_t)snprintf(command_line, sizeof(command_line), "\"%s\" --case %s", exe_path, case_name) >=
        sizeof(command_line)) {
        return 0;
    }
    if (not CreateProcessA(exe_path, command_line, nullptr, nullptr, FALSE, 0, nullptr, nullptr, &startup_info, &process_info)) {
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
