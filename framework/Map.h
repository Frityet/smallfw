#pragma once

#import <smallfw/Object.h>

#include <stddef.h>

#pragma clang assume_nonnull begin

@interface Map<KeyType, ObjectType> : Object {
  @private
    size_t _count;
    id __unsafe_unretained _Nullable *_Nullable _keys;
    id __unsafe_unretained _Nullable *_Nullable _values;
}

@property (nonatomic, readonly) size_t count;

#if SF_RUNTIME_EXCEPTIONS
+ (instancetype _Nonnull)dictionaryWithObjects: (const id __unsafe_unretained _Nonnull * _Nullable)objects forKeys: (const id __unsafe_unretained _Nonnull * _Nullable)keys   count: (size_t)count;
#else
+ (instancetype _Nullable)dictionaryWithObjects: (const id __unsafe_unretained _Nonnull * _Nullable)objects
                                       forKeys: (const id __unsafe_unretained _Nonnull * _Nullable)keys
                                         count: (size_t)count;
#endif
#if SF_RUNTIME_EXCEPTIONS
- (instancetype _Nonnull)initWithObjects: (const id __unsafe_unretained _Nonnull * _Nullable)objects forKeys: (const id __unsafe_unretained _Nonnull * _Nullable)keys   count: (size_t)count;
#else
- (instancetype _Nullable)initWithObjects: (const id __unsafe_unretained _Nonnull * _Nullable)objects forKeys: (const id __unsafe_unretained _Nonnull * _Nullable)keys   count: (size_t)count;
#endif

- (ObjectType _Nullable)objectForKey: (KeyType _Nullable)key;
- (ObjectType _Nullable)objectForKeyedSubscript: (KeyType _Nullable)key;

@end

@compatibility_alias NSDictionary Map;

#pragma clang assume_nonnull end
