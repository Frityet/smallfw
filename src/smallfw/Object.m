#include "smallfw/Object.h"

#include <string.h>

#include "runtime/abi.h"
#include "runtime/internal.h"

#if SF_RUNTIME_EXCEPTIONS
@interface AllocationFailedException (SmallFWInternal)
+ (instancetype)allocationFailedException;
@end
#endif

@interface Object ()

@end

static int sf_class_is_or_inherits_from(Class cls, Class expected)
{
    while (cls != nullptr) {
        if (cls == expected) {
            return 1;
        }
        Class super_cls = class_getSuperclass(cls);
        if (super_cls == cls) {
            break;
        }
        cls = super_cls;
    }
    return 0;
}

@implementation Object

+ (instancetype)allocWithAllocator:(SFAllocator_t *)allocator
{
    id obj = sf_alloc_object((Class)self, allocator);
#if SF_RUNTIME_EXCEPTIONS
    if (obj == nullptr) {
        @throw [AllocationFailedException allocationFailedException];
    }
    __builtin_assume(obj != nullptr);
#endif
    return (id)obj;
}

+ (instancetype)allocInPlace:(void *)storage size:(size_t)size
{
    size_t required = sizeof(SFObjHeader_t) + sf_class_instance_size_fast((Class)self);
    SFObjHeader_t *hdr = nullptr;
    id obj = nullptr;

    if (storage == nullptr or size < required or required > UINT32_MAX) {
        return nullptr;
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
    sf_header_set_class_flags(hdr, sf_class_cached_object_flags((Class)self));
    sf_header_set_aux_flags(hdr, 0U);
    sf_header_set_live_cookie(hdr);
#if SF_RUNTIME_COMPACT_HEADERS
    hdr->cold = nullptr;
#else
    hdr->allocator = sf_default_allocator();
#endif

    obj = (id)(void *)((uintptr_t)storage + sizeof(SFObjHeader_t));
    *(Class *)obj = (Class)self;
    return (id)obj;
}

+ (Class)class
{
    return (Class)self;
}

+ (Class)superclass
{
    return class_getSuperclass((Class)self);
}

- (SFAllocator_t *)allocator
{
    SFObjHeader_t *hdr = nullptr;
    SFAllocator_t *allocator = nullptr;
    if (not sf_object_is_heap(self))
        return sf_default_allocator();
    hdr = sf_header_from_object(self);
    allocator = sf_header_allocator(hdr);
    if (allocator == nullptr)
        return sf_default_allocator();
    return allocator;
}

+ (instancetype)allocWithParent:(Object *)parent
{
    id obj = sf_alloc_object_with_parent((Class)self, parent);
#if SF_RUNTIME_EXCEPTIONS
    if (obj == nullptr) {
        @throw [AllocationFailedException allocationFailedException];
    }
    __builtin_assume(obj != nullptr);
#endif
    return (id)obj;
}

- (Object *)parent
{
    SFObjHeader_t *hdr = nullptr;
    id parent = nullptr;
    SFObjHeader_t *parent_hdr = nullptr;
    if (not sf_object_is_heap(self))
        return nullptr;
    hdr = sf_header_from_object(self);
    if (hdr == nullptr)
        return nullptr;
    parent = sf_header_parent(hdr);
    if (parent == nullptr)
        return nullptr;
    parent_hdr = sf_header_from_object(parent);
    if (parent_hdr == nullptr or parent_hdr->state != SF_OBJ_STATE_LIVE)
        return nullptr;
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

- (Class)class
{
    Class cls = object_getClass(self);
    __builtin_assume(cls != nullptr);
    return cls;
}

- (Class)superclass
{
    return class_getSuperclass(self.class);
}

- (bool)isKindOfClass:(Class)cls
{
    if (cls == nullptr) {
        return false;
    }
    return sf_class_is_or_inherits_from(self.class, cls);
}

- (bool)isMemberOfClass:(Class)cls
{
    return cls != nullptr and self.class == cls;
}

- (bool)isEqual:(Object *)other
{
    return self == other;
}

- (unsigned long)hash
{
    return (unsigned long)sf_hash_ptr(self);
}

#if SF_RUNTIME_TAGGED_POINTERS
+ (uintptr_t)taggedPointerSlot
{
    return 0U;
}

+ (instancetype)taggedPointerWithPayload:(uintptr_t)payload
{
    return (id)sf_make_tagged_pointer((Class)self, payload);
}

- (uintptr_t)taggedPointerPayload
{
    return sf_tagged_pointer_payload(self);
}

- (bool)isTaggedPointer
{
    return sf_is_tagged_pointer(self);
}
#endif

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

#if SF_RUNTIME_GENERIC_METADATA
- (Class)genericTypeClass
{ 
    return sf_object_generic_type_class(self);
}
#endif

- (void *)allocateMemoryWithSize:(size_t)size alignment:(size_t)alignment
{
    void *ptr = self.allocator->alloc(self.allocator->ctx, size, alignment);
#if SF_RUNTIME_EXCEPTIONS
    if (ptr == nullptr) {
        @throw [AllocationFailedException allocationFailedException];
    }
    __builtin_assume(ptr != nullptr);
#endif
    return ptr;
}

@end

//the idea here is that if this class is used as a type for ivars, then the class that has it as an ivar should generate the storage for it
//MyObject *myObj; //MyObject : ValueObject
//MyObject2 *myObj2;
//and this is whats generated:
//MyObject *myObj = ...;
//MyObject2 *myObj2 = ...;
//uint8_t myObj_storage[alignup(sizeof(SFObjHeader_t) + sizeof(MyObject))];
//but these aren't actual ivars.
//This should be done when the class is registered, where the runtime should make it so the instancesize of this class
//also accounts for the storage
//then, in +(instancetype)allocWithParent: (Object *)parent;, if the class is a ValueObject then it should just alloc into the storage of the parent, and return a pointer to that storage as the instance of the ValueObject
@implementation ValueObject



@end
