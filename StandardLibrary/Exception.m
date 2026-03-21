#import "Exception.h"

#pragma clang assume_nonnull begin

@implementation Exception

@synthesize message = _message;

+ (SF_ERRORABLE(instancetype))exceptionWithMessage: (String *_Nullable)message
{
    Exception *exception = [[self allocWithAllocator: nullptr] initWithMessage: message];
    return [exception autorelease];
}

- (instancetype)init
{
    return [self initWithMessage: nullptr];
}

- (SF_ERRORABLE(instancetype))initWithMessage: (String *_Nullable)message
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    if (message != nullptr) {
        _message = [message retain];
    } else {
        _message = nullptr;
    }
    return self;
}

- (void)dealloc
{
    if (_message != nullptr) {
        [_message release];
    }
    [super dealloc];
}

@end

@implementation IndexOutOfBoundsException

+ (SF_ERRORABLE(instancetype))indexOutOfBoundsException
{
    return [self exceptionWithMessage: @"Index out of bounds"];
}

@end

#pragma clang assume_nonnull end
