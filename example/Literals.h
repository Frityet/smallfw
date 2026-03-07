#pragma once

#include <smallfw/Object.h>

#pragma clang assume_nonnull begin

@protocol Copying
- (instancetype)copy;
@end

@interface String : Object <Copying>
- (const char *)UTF8String;
- (unsigned long)length;
@end

@interface ConstantString : String

@end

@interface Number : Object <Copying>
+ (instancetype)numberWithInt:(int)value;
+ (instancetype)numberWithLongLong:(long long)value;
- (int)intValue;
- (long long)longLongValue;
@end

@interface Array<__covariant ObjectType> : Object <Copying>
+ (instancetype)arrayWithObjects:(ObjectType const _Nonnull * _Nonnull)objects count:(unsigned long)count;
- (unsigned long)count;
- (ObjectType)objectAtIndex:(unsigned long)index;
- (ObjectType)objectAtIndexedSubscript:(unsigned long)index;
@end

@interface Dictionary<KeyType, __covariant ObjectType> : Object <Copying>
+ (instancetype)dictionaryWithObjects:(ObjectType const _Nonnull * _Nonnull)objects
                              forKeys:(KeyType const _Nonnull * _Nonnull)keys
                                count:(unsigned long)count;
- (unsigned long)count;
- (ObjectType)objectForKey:(KeyType)key;
- (ObjectType)objectForKeyedSubscript:(KeyType)key;
@end

#pragma clang assume_nonnull end
