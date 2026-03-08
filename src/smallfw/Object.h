#pragma once

#include "runtime/sf_allocator.h"

#pragma clang assume_nonnull begin

__attribute__((objc_root_class))
@interface Object
@property(nonatomic, readonly) SFAllocator_t *allocator;
@property(nonatomic, readonly, nullable) Object *parent;

+ (instancetype)allocWithAllocator:(SFAllocator_t *_Nullable)allocator;
+ (instancetype)allocWithParent: (Object *)parent;
+ (instancetype _Nullable)allocInPlace:(void *_Nullable)storage size:(size_t)size;
- (instancetype)init;
- (void)dealloc;
- (instancetype)retain;
- (oneway void)release;
- (instancetype)autorelease;
- (int)isEqual:(Object *_Nullable)other;
- (unsigned long)hash;
#if SF_RUNTIME_FORWARDING
+ (id _Nullable)forwardingTargetForSelector:(SEL _Nullable)selector;
- (id _Nullable)forwardingTargetForSelector:(SEL _Nullable)selector;
#endif
@end

@interface AllocationFailedException : Object
@property(nonatomic, readonly) size_t exceptionBacktraceCount;

- (const void *_Nullable)exceptionBacktraceFrameAtIndex:(size_t)index;
@end

#pragma clang assume_nonnull end
