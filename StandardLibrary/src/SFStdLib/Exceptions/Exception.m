@import SFRuntime;

#import "Exception.h"

#pragma clang assume_nonnull begin

@implementation Exception

+ (SF_ERRORABLE(instancetype))exceptionWithMessage:(String *nillable)message
{
    auto exception = [[self allocWithAllocator:nullptr] initWithMessage:message];
    return [exception autorelease];
}

- (instancetype)init
{
    return (id nonnil)[self initWithMessage:nullptr];
}

- (SF_ERRORABLE(instancetype))initWithMessage:(String *nillable)message
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
    return [self exceptionWithMessage:@"Index out of bounds"];
}

@end
#pragma clang assume_nonnull end
