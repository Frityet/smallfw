#pragma once

#include <stddef.h>
#include <stdint.h>

#include "smallfw/Object.h"
#include "runtime/internal.h"

#ifndef nil
#define nil ((id)0)
#endif
#ifndef Nil
#define Nil ((Class)0)
#endif

#define SFW_NEW(T) ((T *)[[T allocWithAllocator:sf_default_allocator()] init])

typedef int (*_Nonnull SFTestFn)(void);

typedef struct SFTestCase {
    const char *_Nonnull name;
    SFTestFn fn;
} SFTestCase;

typedef const SFTestCase *_Nullable (*_Nonnull SFTestSuiteFn)(size_t *_Nullable count);

typedef struct SFTestSuite {
    const char *_Nonnull name;
    SFTestSuiteFn fn;
} SFTestSuite;

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

typedef void (*_Nonnull SFTestChildFn)(void *_Nullable ctx);

extern int g_counter_deallocs;

@interface CounterObject : Object
@end

@interface InlineValue : Object {
  @public
    int _payload;
}
@end

@interface InlineValueSub : InlineValue
@end

@interface ImplicitInlineValueSub : InlineValue
@end

@interface InlineLargeValueSub : InlineValue {
  @public
    long long _extra[4];
}
@end

@interface InlineHolder : Object {
  @public
    InlineValue *_value;
    Object *_ref;
}
@end

@interface InlinePairHolder : Object {
  @public
    InlineValue *_first;
    InlineValue *_second;
}
@end

@interface SuperBase : Object
- (int)ping;
@end

@interface SuperChild : SuperBase
@end

@interface AllocTracked : Object
@end

@interface PlainFastObject : Object
@end

@interface ImplicitFastObjectSub : PlainFastObject
@end

@interface InvalidFastObject : Object {
  @public
    Object *_child;
}
@end

@interface TrackedFastObject : Object
@end

@interface NonTrivialInlineValue : Object {
  @public
    Object *_ref;
}
@end

@interface NonTrivialHolder : Object {
  @public
    NonTrivialInlineValue *_value;
}
@end

@interface PlainTrivialObject : Object
@end

@interface InvalidTrivialObject : Object {
  @public
    Object *_child;
}
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

#if SF_RUNTIME_TAGGED_POINTERS
@interface TaggedNumberProbe : Object
+ (instancetype _Nullable)numberWithValue:(uintptr_t)value;
- (uintptr_t)value;
- (TaggedNumberProbe *_Nullable)plus:(uintptr_t)delta;
@end

@interface TaggedStringProbe : Object
+ (instancetype _Nullable)stringWithBytes:(const char *_Nullable)bytes length:(size_t)length;
- (unsigned long)length;
- (unsigned int)characterAtIndex:(unsigned long)index;
@end

@interface TaggedDuplicateA : Object
@end

@interface TaggedDuplicateB : Object
@end

@interface TaggedInvalidSlotProbe : Object
@end

@interface TaggedValueProbe : Object
@end
#endif

#if SF_RUNTIME_EXCEPTIONS
@interface ExceptionBase : AllocationFailedException
@end

@interface ExceptionChild : ExceptionBase
@end
#endif

void sf_test_reset_common_state(void);
CounterObject *_Nullable sf_test_factory_object(void);

void *_Nullable sf_test_counting_alloc(void *_Nullable ctx, size_t size, size_t align);
void sf_test_counting_free(void *_Nullable ctx, void *_Nullable ptr, size_t size, size_t align);
SFAllocator_t sf_test_make_counting_allocator(SFTestAllocatorCtx *_Nonnull ctx);

int sf_test_expect_signal(SFTestChildFn fn, void *_Nullable ctx, int expected_signal);
int sf_test_expect_signal_case(const char *_Nonnull case_name, int expected_signal);

const SFTestCase *_Nullable sf_runtime_arc_cases(size_t *_Nullable count);
const SFTestCase *_Nullable sf_runtime_parent_cases(size_t *_Nullable count);
const SFTestCase *_Nullable sf_runtime_dispatch_cases(size_t *_Nullable count);
const SFTestCase *_Nullable sf_runtime_loader_cases(size_t *_Nullable count);
const SFTestCase *_Nullable sf_runtime_tagged_cases(size_t *_Nullable count);
const SFTestCase *_Nullable sf_runtime_exception_cases(size_t *_Nullable count);
