#pragma once

#import <smallfw/Object.h>

#include <stddef.h>

#pragma clang assume_nonnull begin

@interface Array<ObjectType> : Object {
  @private size_t _count;
  @private id __unsafe_unretained _Nullable *_Nullable _items;
}

@property (nonatomic, readonly) size_t count;

+ (SF_ERRORABLE(instancetype))arrayWithObjects: (const id __unsafe_unretained _Nonnull * _Nullable)objects count: (size_t)count;
- (SF_ERRORABLE(instancetype))initWithObjects: (const id __unsafe_unretained _Nonnull * _Nullable)objects count: (size_t)count;
- (ObjectType _Nullable)objectAtIndex: (size_t)idx;
- (ObjectType _Nullable)objectAtIndexedSubscript: (size_t)idx;

@end

@compatibility_alias NSArray Array;


#pragma clang assume_nonnull end
