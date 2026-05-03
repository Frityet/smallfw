#pragma once

#include "SFStdLib/runtime-import.h"

#pragma clang assume_nonnull begin

#if SF_RUNTIME_GENERIC_METADATA
__attribute__((sf_encode_generics))
#endif
@interface List<T> : Object {
  @private
    size_t _count, _capacity;
  @private
    __unsafe_unretained id *_items;
}

@property(nonatomic, readonly) size_t count;
- (SF_ERRORABLE(instancetype))initWithCapacity:(size_t)capacity;
#if SF_RUNTIME_EXCEPTIONS
- (void)addObject:(T)object;
#else
- (bool)addObject:(T)object;
#endif
- (SF_ERRORABLE(T))objectAtIndex:(size_t)idx;
- (SF_ERRORABLE(T))objectAtIndexedSubscript:(size_t)idx;

@end

@compatibility_alias NSMutableArray List;

#pragma clang assume_nonnull end
