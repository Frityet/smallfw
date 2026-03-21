#pragma once

#import <smallfw/Object.h>

#include <stddef.h>

#pragma clang assume_nonnull begin

#if SF_RUNTIME_GENERIC_METADATA
__attribute__((sf_encode_generics))
#endif
@interface Array<ObjectType> : Object {
  @private size_t _count;
  @private id __unsafe_unretained _Nullable *_Nullable _items;
}

@property (nonatomic, readonly) size_t count;

+ (SF_ERRORABLE(instancetype))arrayWithObjects: (const id __unsafe_unretained _Nonnull *_Nullable)objects count: (size_t)count;
- (SF_ERRORABLE(instancetype))initWithObjects: (const id __unsafe_unretained _Nonnull *_Nullable)objects count: (size_t)count;
- (SF_ERRORABLE(ObjectType))objectAtIndex: (size_t)idx;
- (SF_ERRORABLE(ObjectType))objectAtIndexedSubscript: (size_t)idx;

@end

@compatibility_alias NSArray Array;


#pragma clang assume_nonnull end
