#include "Block.h"

#include "c2x-compat.h"

#include "blocksruntime/Block.h"
#include "blocksruntime/Block_private.h"

#if SF_RUNTIME_EXCEPTIONS
@interface AllocationFailedException (SmallFWInternal)
+ (instancetype)allocationFailedException;
@end
#endif

@implementation Block

+ (instancetype)allocWithAllocator: (SFAllocator_t *)allocator
{
    Block *wrapper = [super allocWithAllocator: allocator];
    if (wrapper == nullptr) {
        return nullptr;
    }
    // ARC may eagerly lower `initWithBlock:^...` through `objc_retainBlock` before our initializer runs.
    if (_Block_push_allocator_override(wrapper, allocator)) {
        return wrapper;
    }

    [wrapper release];
#if SF_RUNTIME_EXCEPTIONS
    @throw [AllocationFailedException allocationFailedException];
#endif
    return nullptr;
}

+ (instancetype)blockWithBlock: (id)block
{
    Block *wrapper = [[self allocWithAllocator: nullptr] initWithBlock: block];
    return [wrapper autorelease];
}

- (instancetype)init
{
    return [self initWithBlock: nullptr];
}

- (instancetype)initWithBlock: (id)block
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    if (block == nullptr) {
        (void)_Block_discard_allocator_override(self);
        _storage = nullptr;
        return self;
    }

    _storage = (block != nullptr) ? _Block_copy_with_allocator((const void *)block, self.allocator) : nullptr;
    (void)_Block_discard_allocator_override(self);
    if (_storage == nullptr) {
        [self release];
#if SF_RUNTIME_EXCEPTIONS
        @throw [AllocationFailedException allocationFailedException];
#endif
        return nullptr;
    }
    return self;
}

- (id)block
{
    return (id)_storage;
}

- (void)dealloc
{
    if (_storage != nullptr) {
        _Block_release(_storage);
    }
    [super dealloc];
}

@end
