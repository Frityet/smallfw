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

+ (SF_ERRORABLE(instancetype))numberWithChar: (char)value;
+ (SF_ERRORABLE(instancetype))numberWithUnsignedChar: (unsigned char)value;
+ (SF_ERRORABLE(instancetype))numberWithShort: (short)value;
+ (SF_ERRORABLE(instancetype))numberWithUnsignedShort: (unsigned short)value;
+ (SF_ERRORABLE(instancetype))numberWithInt: (int)value;
+ (SF_ERRORABLE(instancetype))numberWithUnsignedInt: (unsigned int)value;
+ (SF_ERRORABLE(instancetype))numberWithLong: (long)value;
+ (SF_ERRORABLE(instancetype))numberWithUnsignedLong: (unsigned long)value;
+ (SF_ERRORABLE(instancetype))numberWithLongLong: (long long)value;
+ (SF_ERRORABLE(instancetype))numberWithUnsignedLongLong: (unsigned long long)value;
+ (SF_ERRORABLE(instancetype))numberWithDouble: (double)value;
+ (SF_ERRORABLE(instancetype))numberWithBool: (bool)value;

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
