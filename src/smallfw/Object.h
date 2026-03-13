#pragma once

#include <stdint.h>

#include "runtime/sf_allocator.h"

#ifndef SF_RUNTIME_TAGGED_POINTERS
#define SF_RUNTIME_TAGGED_POINTERS 0
#endif


#if SF_RUNTIME_TAGGED_POINTERS && UINTPTR_MAX != UINT64_MAX
#error "SF_RUNTIME_TAGGED_POINTERS requires 64-bit uintptr_t"
#endif

#pragma clang assume_nonnull begin

__attribute__((objc_root_class))
@interface Object
@property(nonatomic, readonly) SFAllocator_t *allocator;
@property(nonatomic, readonly, nullable) Object *parent;
@property(nonatomic, readonly) Class class;
@property(nonatomic, readonly, nullable) Class superclass;
@property(nonatomic, readonly) unsigned long hash;
#if SF_RUNTIME_EXCEPTIONS
+ (instancetype _Nonnull)allocWithAllocator:(SFAllocator_t *_Nullable)allocator;
+ (instancetype _Nonnull)allocWithParent:(Object *_Nullable)parent;
#else
+ (instancetype _Nullable)allocWithAllocator:(SFAllocator_t *_Nullable)allocator;
+ (instancetype _Nullable)allocWithParent:(Object *_Nullable)parent;
#endif
+ (instancetype _Nullable)allocInPlace:(void *_Nullable)storage size:(size_t)size;
+ (Class _Nonnull)class;
+ (Class _Nullable)superclass;
- (instancetype)init;
- (void)dealloc;
- (instancetype)retain;
- (oneway void)release;
- (instancetype)autorelease;
- (Class _Nonnull)class;
- (Class _Nullable)superclass;
- (int)isKindOfClass:(Class _Nullable)cls;
- (int)isMemberOfClass:(Class _Nullable)cls;
- (int)isEqual:(Object *_Nullable)other;
- (unsigned long)hash;
#if SF_RUNTIME_FORWARDING
+ (id _Nullable)forwardingTargetForSelector:(SEL _Nullable)selector;
- (id _Nullable)forwardingTargetForSelector:(SEL _Nullable)selector;
#endif
#if SF_RUNTIME_TAGGED_POINTERS
+ (uintptr_t)taggedPointerSlot;
+ (instancetype _Nullable)taggedPointerWithPayload:(uintptr_t)payload;
@property(nonatomic, readonly) uintptr_t taggedPointerPayload;
@property(nonatomic, readonly, getter=isTaggedPointer) int isTaggedPointer;
- (uintptr_t)taggedPointerPayload;
- (int)isTaggedPointer;
#endif

#if SF_RUNTIME_EXCEPTIONS
- (void *_Nonnull)allocateMemoryWithSize:(size_t)size alignment:(size_t)alignment;
#else
- (void *_Nullable)allocateMemoryWithSize:(size_t)size alignment:(size_t)alignment;
#endif

@end

@interface AllocationFailedException : Object
@property(nonatomic, readonly) size_t exceptionBacktraceCount;

- (const void *_Nullable)exceptionBacktraceFrameAtIndex:(size_t)index;
@end

@interface InvalidArgumentException : Object

@end

// Parent-allocated ValueObjects are embedded into the owning object's hidden inline storage.
// Their lifetime is bound to that owner slot: clearing the slot or destroying the parent
// invalidates the embedded ValueObject, and retain/release do not extend that lifetime.
@interface ValueObject : Object

@end

#pragma clang assume_nonnull end
