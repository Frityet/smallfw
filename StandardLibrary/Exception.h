#import <smallfw/Object.h>
#import "String.h"

#pragma clang assume_nonnull begin

@interface Exception : Object {
  @private
    String *_Nullable _message;
}

@property(nonatomic, readonly, nullable) String *message;

// no real reason to not allocate for an exception
+ (SF_ERRORABLE(instancetype))exceptionWithMessage: (String *_Nullable)message;
- (SF_ERRORABLE(instancetype))initWithMessage: (String *_Nullable)message;

@end

@interface IndexOutOfBoundsException : Exception

+ (SF_ERRORABLE(instancetype))indexOutOfBoundsException;

@end

@compatibility_alias NSException Exception;

#pragma clang assume_nonnull end
