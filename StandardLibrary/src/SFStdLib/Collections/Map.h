#pragma once

#include "SFStdLib/runtime-import.h"

#include <stddef.h>

#pragma clang assume_nonnull begin

#if SF_RUNTIME_GENERIC_METADATA
    __attribute__((sf_encode_generics))
#endif
@interface Map<KeyType, ObjectType> : Object {
  @private
    size_t _count;
    __unsafe_unretained id nillable *nillable _keys;
    __unsafe_unretained id nillable *nillable _values;
}

@property(nonatomic, readonly) size_t count;

+ (SF_ERRORABLE(instancetype))dictionaryWithObjects:(const __unsafe_unretained id nonnil *nillable)objects forKeys:(const __unsafe_unretained id nonnil *nillable)keys count:(size_t)count;
- (SF_ERRORABLE(instancetype))initWithObjects:(const __unsafe_unretained id nonnil *nillable)objects forKeys:(const __unsafe_unretained id nonnil *nillable)keys count:(size_t)count;

- (ObjectType nillable)objectForKey:(KeyType nillable)key;
- (ObjectType nillable)objectForKeyedSubscript:(KeyType nillable)key;

@end

@compatibility_alias NSDictionary Map;

#pragma clang assume_nonnull end
