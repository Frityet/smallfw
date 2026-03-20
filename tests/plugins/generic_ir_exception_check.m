#include "smallfw/Object.h"

@interface ExceptionArg : Object
@end

@implementation ExceptionArg
@end

__attribute__((sf_encode_generics))
@interface ExceptionBox<T> : Object
- (instancetype)initWithValue: (T)value;
@end

@implementation ExceptionBox

- (instancetype)initWithValue: (id)value
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    if ([value class] != self.genericTypeClass) {
        @throw value;
    }
    return self;
}

@end

Object *sf_generic_ir_exception_check(void)
{
    @try {
        return (Object *)[[ExceptionBox<ExceptionArg *> allocWithAllocator: nullptr]
            initWithValue: [[ExceptionArg allocWithAllocator: nullptr] init]];
    } @catch (id) {
        return nullptr;
    }
}
