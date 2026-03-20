#pragma once

#import <smallfw/Object.h>

#include <stddef.h>

#pragma clang assume_nonnull begin

#if SF_RUNTIME_GENERIC_METADATA
__attribute__((sf_encode_generics))
#endif
@interface Map<KeyType, ObjectType> : Object {
  @private
    size_t _count;
    id __unsafe_unretained _Nullable *_Nullable _keys;
    id __unsafe_unretained _Nullable *_Nullable _values;
}

@property (nonatomic, readonly) size_t count;


+ (SF_ERRORABLE(instancetype))dictionaryWithObjects: (const id __unsafe_unretained _Nonnull * _Nullable)objects forKeys: (const id __unsafe_unretained _Nonnull * _Nullable)keys   count: (size_t)count;
- (SF_ERRORABLE(instancetype))initWithObjects: (const id __unsafe_unretained _Nonnull * _Nullable)objects forKeys: (const id __unsafe_unretained _Nonnull * _Nullable)keys   count: (size_t)count;

- (ObjectType _Nullable)objectForKey: (KeyType _Nullable)key;
- (ObjectType _Nullable)objectForKeyedSubscript: (KeyType _Nullable)key;

@end

@compatibility_alias NSDictionary Map;

#pragma clang assume_nonnull end
