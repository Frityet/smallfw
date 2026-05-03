#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "encoding.h"
#include "objc-runtime-exports.h"
#include "sf-allocator.h"

#ifndef SF_RUNTIME_TAGGED_POINTERS
#    define SF_RUNTIME_TAGGED_POINTERS 0
#endif

#ifndef SF_RUNTIME_GENERIC_METADATA
#    define SF_RUNTIME_GENERIC_METADATA 0
#endif

#ifndef nil
#    define nil ((id)0)
#endif

#if SF_RUNTIME_EXCEPTIONS
#    define SF_ERRORABLE(T) T nonnil
#else
#    define SF_ERRORABLE(T) T nillable
#endif

#if not defined(SF_THROW)
#    if SF_RUNTIME_EXCEPTIONS
#        define SF_THROW(...) do { @throw (__VA_ARGS__); __builtin_unreachable(); } while (0)
#    else
#        define SF_THROW(...) return nillptr
#    endif
#endif

#if SF_RUNTIME_TAGGED_POINTERS and UINTPTR_MAX != UINT64_MAX
#    error "SF_RUNTIME_TAGGED_POINTERS requires 64-bit uintptr_t"
#endif

#pragma clang assume_nonnull begin

__attribute__((objc_root_class))
@interface Object
@property(class, nonatomic, readonly, getter=class) Class objectClass;
@property(class, nonatomic, readonly) Class nillable superclass;
@property(class, nonatomic, readonly) const struct SFEncoding *nillable encoding;
@property(nonatomic, readonly) SFAllocator_t *allocator;
@property(nonatomic, readonly) Object *nillable parent;
@property(nonatomic, readonly, getter=class) Class objectClass;
@property(nonatomic, readonly) Class nillable superclass;
@property(nonatomic, readonly) unsigned long hash;
@property(nonatomic, readonly) const struct SFEncoding *nillable encoding;
+ (SF_ERRORABLE(instancetype))allocWithAllocator:(SFAllocator_t *nillable)allocator;
+ (SF_ERRORABLE(instancetype))allocWithParent:(Object *nillable)parent;
+ (instancetype nillable)allocInPlace:(void *nillable)storage size:(size_t)size;
- (instancetype)init;
- (void)dealloc;
- (instancetype)retain;
- (oneway void)release;
- (instancetype)autorelease;
- (bool)isKindOfClass:(Class nillable)cls;
- (bool)isMemberOfClass:(Class nillable)cls;
- (bool)isEqual:(Object *nillable)other;
#if SF_RUNTIME_FORWARDING
    + (id nillable)forwardingTargetForSelector:(SEL nillable)selector;
    - (id nillable)forwardingTargetForSelector:(SEL nillable)selector;
#endif
#if SF_RUNTIME_TAGGED_POINTERS
    @property(class, nonatomic, readonly) uintptr_t taggedPointerSlot;
    + (instancetype nillable)taggedPointerWithPayload:(uintptr_t)payload;
    @property(nonatomic, readonly) uintptr_t taggedPointerPayload;
    @property(nonatomic, readonly, getter=isTaggedPointer) bool isTaggedPointer;
#endif

#if SF_RUNTIME_GENERIC_METADATA
    @property(nonatomic, readonly) Class nillable genericTypeClass;
#endif

- (SF_ERRORABLE(void *))allocateMemoryWithSize:(size_t)size alignment:(size_t)alignment;

@end

@interface AllocationFailedException : Object
@property(nonatomic, readonly) size_t exceptionBacktraceCount;

- (const void *nillable)exceptionBacktraceFrameAtIndex:(size_t)index;
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
