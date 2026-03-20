#include "smallfw/Object.h"

@interface IRArg : Object
@end

@implementation IRArg
@end

__attribute__((sf_encode_generics))
@interface IRBox<T> : Object
@end

@implementation IRBox
@end

Object *sf_generic_ir_check(void)
{
    return (Object *)[[IRBox<IRArg *> allocWithAllocator: nullptr] init];
}
