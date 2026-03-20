#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "runtime/sf_allocator.h"

#ifndef SF_RUNTIME_TAGGED_POINTERS
#define SF_RUNTIME_TAGGED_POINTERS 0
#endif

#ifndef SF_RUNTIME_GENERIC_METADATA
#define SF_RUNTIME_GENERIC_METADATA 0
#endif

#if !defined(__cplusplus) && (!defined(__STDC_VERSION__) || __STDC_VERSION__ < 202311L) && !defined(nullptr)
#define nullptr 0
#endif

#if SF_RUNTIME_EXCEPTIONS
#define SF_ERRORABLE(T) T _Nonnull
#else
#define SF_ERRORABLE(T) T _Nullable
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
+ (SF_ERRORABLE(instancetype))allocWithAllocator:(SFAllocator_t *_Nullable)allocator;
+ (SF_ERRORABLE(instancetype))allocWithParent:(Object *_Nullable)parent;
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
- (bool)isKindOfClass:(Class _Nullable)cls;
- (bool)isMemberOfClass:(Class _Nullable)cls;
- (bool)isEqual:(Object *_Nullable)other;
- (unsigned long)hash;
#if SF_RUNTIME_FORWARDING
+ (id _Nullable)forwardingTargetForSelector:(SEL _Nullable)selector;
- (id _Nullable)forwardingTargetForSelector:(SEL _Nullable)selector;
#endif
#if SF_RUNTIME_TAGGED_POINTERS
+ (uintptr_t)taggedPointerSlot;
+ (instancetype _Nullable)taggedPointerWithPayload:(uintptr_t)payload;
@property(nonatomic, readonly) uintptr_t taggedPointerPayload;
@property(nonatomic, readonly, getter=isTaggedPointer) bool isTaggedPointer;
- (uintptr_t)taggedPointerPayload;
- (bool)isTaggedPointer;
#endif

#if SF_RUNTIME_GENERIC_METADATA
@property(nonatomic, readonly, nullable) Class genericTypeClass;
- (Class _Nullable)genericTypeClass;
#endif

- (SF_ERRORABLE(void *))allocateMemoryWithSize:(size_t)size alignment:(size_t)alignment;

@end

@interface AllocationFailedException : Object
@property(nonatomic, readonly) size_t exceptionBacktraceCount;

- (const void *_Nullable)exceptionBacktraceFrameAtIndex:(size_t)index;
@end

@interface InvalidArgumentException : Object
+ (instancetype)exception;
@end

// Parent-allocated ValueObjects are embedded into the owning object's hidden inline storage.
// Their lifetime is bound to that owner slot: clearing the slot or destroying the parent
// invalidates the embedded ValueObject, and retain/release do not extend that lifetime.
@interface ValueObject : Object

@end

#pragma clang assume_nonnull end
