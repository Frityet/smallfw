#pragma once

#include <stddef.h>
#include <stdint.h>

#if defined(SF_CLANGD_NO_MODULES)
#    include "SmallFW/Object.h"
#else
    @import SFRuntime;
#endif
#include "internal.h"

#ifndef nil
#    define nil ((id)0)
#endif
#ifndef Nil
#    define Nil ((Class)0)
#endif

#define SFW_NEW(T) ((T *)[[T allocWithAllocator:sf_default_allocator()] init])

typedef bool (*nonnil SFTestFn)(void);

typedef struct SFTestCase {
    const char *nonnil name;
    SFTestFn fn;
} SFTestCase;

typedef const SFTestCase *nillable (*nonnil SFTestSuiteFn)(size_t *nillable count);

typedef struct SFTestSuite {
    const char *nonnil name;
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

typedef union SFTestEither {
    int left;
    int right;
} SFTestEither;

typedef void (*nonnil SFTestChildFn)(void *nillable ctx);

extern int g_counter_deallocs;

@interface CounterObject : Object
@end

@interface InlineValue : ValueObject {
  @public
    int _payload;
}
@end

@interface InlineValueSub : InlineValue
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

@interface NonTrivialInlineValue : ValueObject {
  @public
    Object *_ref;
}
@end

@interface NonTrivialHolder : Object {
  @public
    NonTrivialInlineValue *_value;
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

@interface CDispatchProbe : Object
- (id nonnil)zero;
- (id nonnil)takeI:(int)value;
- (id nonnil)takeIq:(unsigned int)first second:(long long)second;
- (id nonnil)takeQ:(unsigned long long)value star:(const char *nonnil)bytes sel:(SEL nonnil)selector;
- (id nonnil)takeObj:(id nonnil)obj cls:(Class nonnil)cls ptr:(void *nonnil)ptr cstr:(const char *nonnil)bytes;
- (id nonnil)takeChar:(char)value;
- (id nonnil)takeShort:(short)value;
- (id nonnil)takeBool:(_Bool)value;
- (id nonnil)takeC:(unsigned char)value;
- (id nonnil)takeS:(unsigned short)value;
- (id nonnil)takeLong:(long)value;
- (id nonnil)takeULong:(unsigned long)value;
- (id nonnil)takePointer:(int *nonnil)ptr;
- (id nonnil)takeStruct:(SFTestPair)pair;
- (id nonnil)takeUnion:(SFTestEither)either;
- (id nonnil)takeDouble:(double)value;
- (id nonnil)takeMany:(int)first second:(int)second third:(int)third fourth:(int)fourth fifth:(int)fifth;
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
    @property(nonatomic, readonly) uintptr_t value;
    + (instancetype nillable)numberWithValue:(uintptr_t)value;
    - (uintptr_t)value;
    - (TaggedNumberProbe *nillable)plus:(uintptr_t)delta;
    @end

    @interface TaggedStringProbe : Object
    @property(nonatomic, readonly) unsigned long length;
    + (instancetype nillable)stringWithBytes:(const char *nillable)bytes length:(size_t)length;
    - (unsigned long)length;
    - (unsigned int)characterAtIndex:(unsigned long)index;
    @end

    @interface TaggedDuplicateA : Object
    @end

    @interface TaggedDuplicateB : Object
    @end

    @interface TaggedInvalidSlotProbe : Object
    @end

    @interface TaggedValueProbe : ValueObject
    @end
#endif

#if SF_RUNTIME_EXCEPTIONS
    @interface ExceptionBase : AllocationFailedException
    @end

    @interface ExceptionChild : ExceptionBase
    @end
#endif

void sf_test_reset_common_state(void);
CounterObject *nillable sf_test_factory_object(void);

void *nillable sf_test_counting_alloc(void *nillable ctx, size_t size, size_t align);
void sf_test_counting_free(void *nillable ctx, void *nillable ptr, size_t size, size_t align);
SFAllocator_t sf_test_make_counting_allocator(SFTestAllocatorCtx *nonnil ctx);
void sf_test_reset_c_dispatch_probe(void);
int sf_test_c_dispatch_probe_argc(void);
uintptr_t sf_test_c_dispatch_probe_value(int index);

bool sf_test_expect_signal(SFTestChildFn fn, void *nillable ctx, int expected_signal);
bool sf_test_expect_signal_case(const char *nonnil case_name, int expected_signal);

const SFTestCase *nillable sf_runtime_arc_cases(size_t *nillable count);
const SFTestCase *nillable sf_runtime_parent_cases(size_t *nillable count);
const SFTestCase *nillable sf_runtime_dispatch_cases(size_t *nillable count);
const SFTestCase *nillable sf_runtime_loader_cases(size_t *nillable count);
const SFTestCase *nillable sf_runtime_tagged_cases(size_t *nillable count);
const SFTestCase *nillable sf_runtime_exception_cases(size_t *nillable count);
