#include "smallfw/Object.h"

#include <string.h>

#include "runtime/abi.h"
#include "runtime/internal.h"

#if SF_RUNTIME_EXCEPTIONS
@interface AllocationFailedException (SmallFWInternal)
+ (void)raiseForAllocationFailure __attribute__((noreturn));
@end
#endif

@implementation Object

+ (instancetype)allocWithAllocator:(SFAllocator_t *)allocator
{
    id obj = sf_alloc_object((Class)self, allocator);
#if SF_RUNTIME_EXCEPTIONS
    if (obj == NULL) {
        [AllocationFailedException raiseForAllocationFailure];
    }
#else
    return (id)obj;
#endif
    return (id)obj;
}

+ (instancetype)allocInPlace:(void *)storage size:(size_t)size
{
    size_t required = sizeof(SFObjHeader_t) + sf_class_instance_size_fast((Class)self);
    SFObjHeader_t *hdr = NULL;
    id obj = NULL;

    if (storage == NULL || size < required || required > UINT32_MAX) {
        return NULL;
    }
    memset(storage, 0, size);
    hdr = (SFObjHeader_t *)storage;
#if SF_RUNTIME_VALIDATION
    hdr->magic = SF_OBJ_HEADER_MAGIC;
#endif
    hdr->refcount = 1;
    hdr->state = SF_OBJ_STATE_LIVE;
    hdr->flags = SF_OBJ_FLAG_IMMORTAL;
    hdr->alloc_size = (uint32_t)required;
    hdr->allocator = sf_default_allocator();

    obj = (id)(void *)((uintptr_t)storage + sizeof(SFObjHeader_t));
    *(Class *)obj = (Class)self;
    return (id)obj;
}

- (SFAllocator_t *)allocator
{
    SFObjHeader_t *hdr = NULL;
    SFAllocator_t *allocator = NULL;
    if (!sf_object_is_heap(self))
        return sf_default_allocator();
    hdr = sf_header_from_object(self);
    allocator = sf_header_allocator(hdr);
    if (allocator == NULL)
        return sf_default_allocator();
    return allocator;
}

+ (instancetype)allocWithParent:(Object *)parent
{
    id obj = sf_alloc_object_with_parent((Class)self, parent);
#if SF_RUNTIME_EXCEPTIONS
    if (obj == NULL) {
        [AllocationFailedException raiseForAllocationFailure];
    }
#else
    return (id)obj;
#endif
    return (id)obj;
}

- (Object *)parent
{
    SFObjHeader_t *hdr = NULL;
    id parent = NULL;
    SFObjHeader_t *parent_hdr = NULL;
    if (!sf_object_is_heap(self))
        return NULL;
    hdr = sf_header_from_object(self);
    if (hdr == NULL)
        return NULL;
    parent = sf_header_parent(hdr);
    if (parent == NULL)
        return NULL;
    parent_hdr = sf_header_from_object(parent);
    if (parent_hdr == NULL || parent_hdr->state != SF_OBJ_STATE_LIVE)
        return NULL;
    return (Object *)parent;
}

- (instancetype)init
{
    return self;
}

- (void)dealloc
{
}

- (instancetype)retain
{
    return (id)objc_retain(self);
}

- (oneway void)release
{
    objc_release(self);
}

- (instancetype)autorelease
{
    return (id)sf_autorelease(self);
}

- (int)isEqual:(Object *)other
{ return self == other; }

- (unsigned long)hash
{
    return (unsigned long)sf_hash_ptr(self);
}

#if SF_RUNTIME_FORWARDING
+ (id)forwardingTargetForSelector:(SEL)selector
{
    (void)selector;
    return (id)0;
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    (void)selector;
    return (id)0;
}
#endif

@end
