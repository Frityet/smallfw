#pragma once

#include "SFStdLib/runtime-import.h"

#include <stddef.h>

#pragma clang assume_nonnull begin

#if SF_RUNTIME_GENERIC_METADATA
    __attribute__((sf_encode_generics))
#endif
@interface Array<ObjectType> : Object {
  @private
    size_t _count;
  @private
    __unsafe_unretained id nillable *nillable _items;
}

@property(nonatomic, readonly) size_t count;

+ (SF_ERRORABLE(instancetype))arrayWithObjects:(const __unsafe_unretained id nonnil *nillable)objects count:(size_t)count;
- (SF_ERRORABLE(instancetype))initWithObjects:(const __unsafe_unretained id nonnil *nillable)objects count:(size_t)count;
- (SF_ERRORABLE(ObjectType))objectAtIndex:(size_t)idx;
- (SF_ERRORABLE(ObjectType))objectAtIndexedSubscript:(size_t)idx;

@end

@compatibility_alias NSArray Array;

#pragma clang assume_nonnull end
