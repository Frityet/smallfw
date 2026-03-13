#pragma once

#import <smallfw/Object.h>

#include <stdbool.h>
#include <stdint.h>

#pragma clang assume_nonnull begin

@interface Number : Object {
  @public
    uint8_t _kind;
    uint8_t _reserved[7];
    union {
        long long _signed_value;
        unsigned long long _unsigned_value;
        double _double_value;
    } _storage;
}
@property(nonatomic, readonly) char charValue;
@property(nonatomic, readonly) unsigned char unsignedCharValue;
@property(nonatomic, readonly) short shortValue;
@property(nonatomic, readonly) unsigned short unsignedShortValue;
@property(nonatomic, readonly) int intValue;
@property(nonatomic, readonly) unsigned int unsignedIntValue;
@property(nonatomic, readonly) long longValue;
@property(nonatomic, readonly) unsigned long unsignedLongValue;
@property(nonatomic, readonly) long long longLongValue;
@property(nonatomic, readonly) unsigned long long unsignedLongLongValue;
@property(nonatomic, readonly) double doubleValue;
@property(nonatomic, readonly) bool boolValue;

#if SF_RUNTIME_EXCEPTIONS
+ (instancetype _Nonnull)numberWithChar: (char)value;
+ (instancetype _Nonnull)numberWithUnsignedChar: (unsigned char)value;
+ (instancetype _Nonnull)numberWithShort: (short)value;
+ (instancetype _Nonnull)numberWithUnsignedShort: (unsigned short)value;
+ (instancetype _Nonnull)numberWithInt: (int)value;
+ (instancetype _Nonnull)numberWithUnsignedInt: (unsigned int)value;
+ (instancetype _Nonnull)numberWithLong: (long)value;
+ (instancetype _Nonnull)numberWithUnsignedLong: (unsigned long)value;
+ (instancetype _Nonnull)numberWithLongLong: (long long)value;
+ (instancetype _Nonnull)numberWithUnsignedLongLong: (unsigned long long)value;
+ (instancetype _Nonnull)numberWithDouble: (double)value;
+ (instancetype _Nonnull)numberWithBool: (bool)value;
#else
+ (instancetype _Nullable)numberWithChar: (char)value;
+ (instancetype _Nullable)numberWithUnsignedChar: (unsigned char)value;
+ (instancetype _Nullable)numberWithShort: (short)value;
+ (instancetype _Nullable)numberWithUnsignedShort: (unsigned short)value;
+ (instancetype _Nullable)numberWithInt: (int)value;
+ (instancetype _Nullable)numberWithUnsignedInt: (unsigned int)value;
+ (instancetype _Nullable)numberWithLong: (long)value;
+ (instancetype _Nullable)numberWithUnsignedLong: (unsigned long)value;
+ (instancetype _Nullable)numberWithLongLong: (long long)value;
+ (instancetype _Nullable)numberWithUnsignedLongLong: (unsigned long long)value;
+ (instancetype _Nullable)numberWithDouble: (double)value;
+ (instancetype _Nullable)numberWithBool: (bool)value;
#endif

- (char)charValue;
- (unsigned char)unsignedCharValue;
- (short)shortValue;
- (unsigned short)unsignedShortValue;
- (int)intValue;
- (unsigned int)unsignedIntValue;
- (long)longValue;
- (unsigned long)unsignedLongValue;
- (long long)longLongValue;
- (unsigned long long)unsignedLongLongValue;
- (double)doubleValue;
- (bool)boolValue;

@end

@compatibility_alias NSNumber Number;

#pragma clang assume_nonnull end
