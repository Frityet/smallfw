#pragma once

#include "SFStdLib/runtime-import.h"

#include <stddef.h>
#include <stdint.h>

#if !SF_RUNTIME_TAGGED_POINTERS
#error "smallfw String literals on GNUstep require runtime-tagged-pointers=y"
#endif

#pragma clang assume_nonnull begin

@interface String : Object
@property(nonatomic, readonly) size_t length;
@property(nonatomic, readonly) const char *nonnil UTF8String;

- (SF_ERRORABLE(instancetype))initWithUTF8String:(const char *nillable)bytes;
- (SF_ERRORABLE(instancetype))initWithBytes:(const char *nillable)bytes length:(size_t)length;

#if SF_RUNTIME_TAGGED_POINTERS
+ (uintptr_t)taggedPointerSlot;
#endif

- (size_t)length;
- (unsigned short)characterAtIndex:(size_t)idx;
- (const char *nonnil)UTF8String;

@end

@interface NSConstantString : String {
  @private
    uint32_t _flags;
    uint32_t _length;
    uint32_t _size;
    uint32_t _hash;
    const void *nillable _data;
}
@end

@interface NXConstantString : String {
  @private
    uint32_t _flags;
    uint32_t _length;
    uint32_t _size;
    uint32_t _hash;
    const void *nillable _data;
}
@end

@compatibility_alias NSString String;

#pragma clang assume_nonnull end
