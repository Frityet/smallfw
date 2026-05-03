#include "Block-private.h"
#include "Block.h"

#if defined(__clang__) || defined(__GNUC__)
#define SF_BLOCK_ABI_CLASS_ALIAS(abi_name, class_name) __asm__(".globl " #abi_name "\n.set " #abi_name ", ._OBJC_CLASS_" #class_name "\n")
#else
#error "SmallFW block class aliases require compiler-supported assembler aliases"
#endif

static inline struct Block_layout *block_layout(Block *block)
{
    return (struct Block_layout *)(void *)block;
}

static inline uint32_t block_flags(Block *block)
{
    return (uint32_t)block_layout(block)->flags;
}

static inline struct Block_descriptor *block_descriptor(Block *block)
{
    return block_layout(block)->descriptor;
}

static inline const uintptr_t *block_descriptor_optional_fields(Block *block)
{
    return Block_descriptor_optional_fields(block_layout(block));
}

static inline size_t block_size(Block *block)
{
    auto descriptor = block_descriptor(block);
    return descriptor != NULL ? (size_t)descriptor->size : 0U;
}

static inline struct Block_byref *block_byref_layout(WeakBlockVariable *variable)
{
    return (struct Block_byref *)(void *)variable;
}

@implementation Block

+ (instancetype)allocWithAllocator:(SFAllocator_t *)allocator
{
    (void)allocator;
    SF_THROW([InvalidArgumentException exception]);
}

+ (instancetype)allocWithParent:(Object *)parent
{
    (void)parent;
    SF_THROW([InvalidArgumentException exception]);
}

+ (instancetype)allocInPlace:(void *)storage size:(size_t)size
{
    (void)storage;
    (void)size;
    return nil;
}

- (SFAllocator_t *)allocator
{
    if (![self isKindOfClass:HeapBlock.class]) {
        return sf_default_allocator();
    }
    auto header = Block_smallfw_header_for_storage((const void *)self);
    return header != NULL && header->fields.allocator != NULL ? header->fields.allocator : sf_default_allocator();
}

- (size_t)size
{
    return block_size(self);
}

- (uint32_t)flags
{
    return block_flags(self);
}

- (int32_t)reserved
{
    return block_layout(self)->reserved;
}

- (uint32_t)referenceCount
{
    return block_flags(self) & BLOCK_REFCOUNT_MASK;
}

- (bool)needsFreeStorage
{
    return (block_flags(self) & BLOCK_NEEDS_FREE) != 0U;
}

- (bool)usesGarbageCollection
{
    return (block_flags(self) & BLOCK_IS_GC) != 0U;
}

- (bool)usesConstructorHelpers
{
    return (block_flags(self) & BLOCK_HAS_CTOR) != 0U;
}

- (bool)isGlobalStorage
{
    return (block_flags(self) & BLOCK_IS_GLOBAL) != 0U;
}

- (void *)descriptorPointer
{
    return block_descriptor(self);
}

- (unsigned long)descriptorReserved
{
    auto descriptor = block_descriptor(self);
    return descriptor != NULL ? descriptor->reserved : 0UL;
}

- (void *)invokePointer
{
    return (void *)(uintptr_t)block_layout(self)->invoke;
}

- (const char *)signature
{
    if ((block_flags(self) & BLOCK_HAS_SIGNATURE) == 0U) {
        return NULL;
    }
    auto cursor = block_descriptor_optional_fields(self);
    return cursor != NULL ? (const char *)(uintptr_t)cursor[0] : NULL;
}

- (const struct SFMethodEncoding *)methodEncoding
{
    return sf_method_encoding_parse(self.signature);
}

- (const char *)extendedLayout
{
    auto flags = block_flags(self);
    if ((flags & BLOCK_HAS_EXTENDED_LAYOUT) == 0U) {
        return NULL;
    }
    auto cursor = block_descriptor_optional_fields(self);
    if (cursor == NULL) {
        return NULL;
    }
    if ((flags & BLOCK_HAS_SIGNATURE) != 0U) {
        cursor += 1;
    }
    return (const char *)(uintptr_t)cursor[0];
}

- (void *)copyHelperPointer
{
    return (void *)(uintptr_t)Block_descriptor_copy_helper(block_layout(self));
}

- (void *)disposeHelperPointer
{
    return (void *)(uintptr_t)Block_descriptor_dispose_helper(block_layout(self));
}

- (void *)capturedVariablesPointer
{
    return self.capturedVariablesSize != 0U ? (void *)((unsigned char *)(void *)self + sizeof(struct Block_layout)) : NULL;
}

- (size_t)capturedVariablesSize
{
    auto size = block_size(self);
    return size > sizeof(struct Block_layout) ? size - sizeof(struct Block_layout) : 0U;
}

@end

@implementation StackBlock
@end

@implementation HeapBlock

- (size_t)allocationSize
{
    auto header = Block_smallfw_header_for_storage((const void *)self);
    return header != NULL ? header->fields.allocation_size : self.size;
}

@end

@implementation AutomaticBlock
@end

@implementation FinalizingBlock
@end

@implementation GlobalBlock
@end

@implementation WeakBlockVariable

- (SFAllocator_t *)allocator
{
    auto header = Block_smallfw_header_for_storage((const void *)self);
    return header != NULL && header->fields.allocator != NULL ? header->fields.allocator : sf_default_allocator();
}

- (WeakBlockVariable *)forwardingVariable
{
    return (WeakBlockVariable *)block_byref_layout(self)->forwarding;
}

- (uint32_t)flags
{
    return (uint32_t)block_byref_layout(self)->flags;
}

- (uint32_t)referenceCount
{
    return self.flags & BLOCK_REFCOUNT_MASK;
}

- (size_t)size
{
    auto size = block_byref_layout(self)->size;
    return size > 0 ? (size_t)size : 0U;
}

- (void *)keepHelperPointer
{
    if ((self.flags & BLOCK_HAS_COPY_DISPOSE) == 0U) {
        return NULL;
    }
    return (void *)(uintptr_t)block_byref_layout(self)->byref_keep;
}

- (void *)destroyHelperPointer
{
    if ((self.flags & BLOCK_HAS_COPY_DISPOSE) == 0U) {
        return NULL;
    }
    return (void *)(uintptr_t)block_byref_layout(self)->byref_destroy;
}

- (void *)capturedVariablesPointer
{
    return self.capturedVariablesSize != 0U ? (void *)((unsigned char *)(void *)self + sizeof(struct Block_byref)) : NULL;
}

- (size_t)capturedVariablesSize
{
    auto size = self.size;
    return size > sizeof(struct Block_byref) ? size - sizeof(struct Block_byref) : 0U;
}

@end

SF_BLOCK_ABI_CLASS_ALIAS(_NSConcreteStackBlock, StackBlock);
SF_BLOCK_ABI_CLASS_ALIAS(_NSConcreteMallocBlock, HeapBlock);
SF_BLOCK_ABI_CLASS_ALIAS(_NSConcreteAutoBlock, AutomaticBlock);
SF_BLOCK_ABI_CLASS_ALIAS(_NSConcreteFinalizingBlock, FinalizingBlock);
SF_BLOCK_ABI_CLASS_ALIAS(_NSConcreteGlobalBlock, GlobalBlock);
SF_BLOCK_ABI_CLASS_ALIAS(_NSConcreteWeakBlockVariable, WeakBlockVariable);

void _Block_copy_error(void)
{
}
