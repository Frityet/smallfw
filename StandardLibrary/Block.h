#pragma once

#import <smallfw/Object.h>

#include <stddef.h>

#pragma clang assume_nonnull begin

#if SF_RUNTIME_GENERIC_METADATA
__attribute__((sf_encode_generics))
#endif
@interface Block<__covariant BlockType> : Object {
  @private
    const void *_Nullable _storage;
}

@property(nonatomic, readonly, nullable) BlockType block;

+ (SF_ERRORABLE(instancetype))blockWithBlock: (BlockType _Nullable)block;
- (SF_ERRORABLE(instancetype))initWithBlock: (BlockType _Nullable)block;

@end

#pragma clang assume_nonnull end
