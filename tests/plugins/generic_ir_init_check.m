#include "smallfw/Object.h"

@interface IRArg : Object
@end

@implementation IRArg
@end

__attribute__((sf_encode_generics))
@interface IRBox<T> : Object
@end

@implementation IRBox

- (instancetype)init
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    if (self.genericTypeClass == nullptr) {
        return nullptr;
    }

    return self;
}

@end

Object *sf_generic_ir_init_check(void)
{
    return (Object *)[[IRBox<IRArg *> allocWithAllocator: nullptr] init];
}
