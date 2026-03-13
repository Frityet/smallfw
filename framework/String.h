#pragma once

#import <smallfw/Object.h>

#include <stddef.h>
#include <stdint.h>

#if !SF_RUNTIME_OBJC_FRAMEWORK_OBJFW && !SF_RUNTIME_TAGGED_POINTERS
#error "smallfw String literals on GNUstep require runtime-tagged-pointers=y"
#endif

#pragma clang assume_nonnull begin

@interface String : Object
@property(nonatomic, readonly) size_t length;
@property(nonatomic, readonly) const char *_Nonnull UTF8String;

// #if SF_RUNTIME_EXCEPTIONS
// // + (instancetype _Nonnull)stringWithUTF8String: (const char *_Nullable)bytes;
// // + (instancetype _Nonnull)stringWithBytes: (const char *_Nullable)bytes length: (size_t)length;
// #else
// + (instancetype _Nullable)stringWithUTF8String: (const char *_Nullable)bytes;
// + (instancetype _Nullable)stringWithBytes: (const char *_Nullable)bytes length: (size_t)length;
// #endif

#if SF_RUNTIME_TAGGED_POINTERS
+ (uintptr_t)taggedPointerSlot;
#endif

- (size_t)length;
- (unsigned short)characterAtIndex: (size_t)idx;
- (const char *_Nonnull)UTF8String;

@end

@interface NSConstantString : String {
  @private
#if SF_RUNTIME_OBJC_FRAMEWORK_OBJFW
    const char *_Nullable _bytes;
    uint32_t _size;
#else
    uint32_t _flags;
    uint32_t _length;
    uint32_t _size;
    uint32_t _hash;
    const void *_Nullable _data;
#endif
}
@end

@interface NXConstantString : String {
  @private
#if SF_RUNTIME_OBJC_FRAMEWORK_OBJFW
    const char *_Nullable _bytes;
    uint32_t _size;
#else
    uint32_t _flags;
    uint32_t _length;
    uint32_t _size;
    uint32_t _hash;
    const void *_Nullable _data;
#endif
}
@end

@compatibility_alias NSString String;

#pragma clang assume_nonnull end
