#pragma once

#include "SFStdLib/runtime-import.h"
#import "SFStdLib/String.h"

#pragma clang assume_nonnull begin

@interface Exception : Object {
  @private
    String *nillable _message;
}

@property(nonatomic, readonly) String *nillable message;

// no real reason to not heap/default allocate for an exception
+ (SF_ERRORABLE(instancetype))exceptionWithMessage:(String *nillable)message;
- (SF_ERRORABLE(instancetype))initWithMessage:(String *nillable)message;

+ (instancetype nillable)allocInPlace:(void *nillable)storage size:(size_t)size [[clang::unavailable("Exceptions should probably not be in-place allocated!")]];
+ (SF_ERRORABLE(instancetype))allocWithParent:(Object *nillable)parent [[clang::unavailable("Exceptions should probably not be parent-allocated!")]];

@end

@interface IndexOutOfBoundsException : Exception

+ (SF_ERRORABLE(instancetype))indexOutOfBoundsException;

@end

@compatibility_alias NSException Exception;

#pragma clang assume_nonnull end
