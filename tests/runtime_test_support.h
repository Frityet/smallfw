#pragma once

#include <stddef.h>
#include <stdint.h>

#include "smallfw/Object.h"
#include "runtime/internal.h"

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-interface-ivars"
#endif

#ifndef nil
#define nil ((id)0)
#endif
#ifndef Nil
#define Nil ((Class)0)
#endif

#define SFW_NEW(T) ((T *)[[T allocWithAllocator:sf_default_allocator()] init])

typedef int (*SFTestFn)(void);

typedef struct SFTestCase {
    const char *name;
    SFTestFn fn;
} SFTestCase;

typedef struct SFTestAllocatorCtx {
    int alloc_calls;
    int free_calls;
    size_t active_blocks;
    size_t last_size;
    size_t last_align;
} SFTestAllocatorCtx;

typedef struct SFTestPair {
    int left;
    int right;
} SFTestPair;

typedef struct SFTestWidePair {
    long long left;
    long long right;
} SFTestWidePair;

typedef struct SFTestBigStruct {
    long long first;
    long long second;
    long long third;
    long long fourth;
} SFTestBigStruct;

typedef void (*SFTestChildFn)(void *ctx);

extern int g_counter_deallocs;

@interface CounterObject : Object
@end

@interface SuperBase : Object
- (int)ping;
@end

@interface SuperChild : SuperBase
@end

@interface AllocTracked : Object
@end

@interface HotDispatch : Object
- (int)calc:(int)x;
@end

@interface StructDispatchProbe : Object
- (SFTestPair)pairWithLeft:(int)left right:(int)right;
- (long long)sumPair:(SFTestPair)pair;
- (long long)sumBigStruct:(SFTestBigStruct)big bias:(long long)bias;
- (SFTestWidePair)widePairWithSeed:(long long)seed;
- (SFTestBigStruct)bigStructWithSeed:(long long)seed;
@end

@interface ForwardDispatchTarget : Object
- (int)forwardedValue:(int)x;
+ (int)classForwardedValue:(int)x;
@end

@interface ForwardDispatchProxy : Object
@end

@interface ReflectionProbe : Object {
@public
    int _value;
}
+ (int)classPing;
- (int)instancePing;
@end

#if SF_RUNTIME_EXCEPTIONS
@interface ExceptionBase : AllocationFailedException
@end

@interface ExceptionChild : ExceptionBase
@end
#endif

void sf_test_reset_common_state(void);
CounterObject *sf_test_factory_object(void);

void *sf_test_counting_alloc(void *ctx, size_t size, size_t align);
void sf_test_counting_free(void *ctx, void *ptr, size_t size, size_t align);
SFAllocator_t sf_test_make_counting_allocator(SFTestAllocatorCtx *ctx);

int sf_test_expect_signal(SFTestChildFn fn, void *ctx, int expected_signal);
int sf_test_expect_signal_case(const char *case_name, int expected_signal);

const SFTestCase *sf_runtime_arc_cases(size_t *count);
const SFTestCase *sf_runtime_parent_cases(size_t *count);
const SFTestCase *sf_runtime_dispatch_cases(size_t *count);
const SFTestCase *sf_runtime_loader_cases(size_t *count);
const SFTestCase *sf_runtime_exception_cases(size_t *count);

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
