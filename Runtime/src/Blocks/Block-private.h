/*
 * Block-private.h
 *
 * Copyright 2008-2010 Apple, Inc. Permission is hereby granted, free of charge,
 * to any person obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to permit
 * persons to whom the Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

#ifndef _BLOCK_PRIVATE_H_
#    define _BLOCK_PRIVATE_H_

#    include <iso646.h>

#    if not defined(BLOCK_EXPORT)
#        if defined(__cplusplus)
#            define BLOCK_EXPORT extern "C"
#        else
#            define BLOCK_EXPORT extern
#        endif
#    endif

#    include <stddef.h>
#    include <stdint.h>
#    include <stdbool.h>

#    include "sf-allocator.h"

    struct sf_objc_class;

#    if defined(__cplusplus)
        extern "C" {
#    endif

#    pragma clang assume_nonnull begin

    enum {
        BLOCK_REFCOUNT_MASK =     (0xffff),
        BLOCK_NEEDS_FREE =        (1 << 24),
        BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
        BLOCK_HAS_CTOR =          (1 << 26), /* Helpers have C++ code. */
        BLOCK_IS_GC =             (1 << 27),
        BLOCK_IS_GLOBAL =         (1 << 28),
        BLOCK_HAS_DESCRIPTOR =    (1 << 29),
        BLOCK_HAS_SIGNATURE =     (1 << 30),
        BLOCK_HAS_EXTENDED_LAYOUT = (1U << 31)
    };

    enum {
        BLOCK_SMALLFW_ALLOC_MAGIC = 0x5346424cU
    };

    typedef union Block_smallfw_alloc_header {
        struct {
            uint32_t magic;
            uint32_t reserved;
            SFAllocator_t *allocator;
            size_t allocation_size;
        } fields;
        _Alignas(16) unsigned char alignment[16];
    } Block_smallfw_alloc_header_t;

    static inline Block_smallfw_alloc_header_t *nillable Block_smallfw_header_for_storage(const void *nillable ptr)
    {
        if (ptr == NULL) {
            return NULL;
        }
        Block_smallfw_alloc_header_t *header = ((Block_smallfw_alloc_header_t *)ptr) - 1;
        return header->fields.magic == BLOCK_SMALLFW_ALLOC_MAGIC ? header : NULL;
    }

    /* Revised new layout. */
    struct Block_descriptor {
        unsigned long int reserved;
        unsigned long int size;
    };


    struct Block_layout {
        void *isa;
        int flags;
        int reserved;
        void (*invoke)(void *, ...);
        struct Block_descriptor *descriptor;
        /* Imported variables. */
    };

    static inline const uintptr_t *nillable Block_descriptor_copy_dispose_fields(const struct Block_layout *nillable block)
    {
        if (block == NULL or block->descriptor == NULL or ((uint32_t)block->flags & BLOCK_HAS_COPY_DISPOSE) == 0U) {
            return NULL;
        }
        return (const uintptr_t *)(const void *)(block->descriptor + 1);
    }

    static inline const uintptr_t *nillable Block_descriptor_optional_fields(const struct Block_layout *nillable block)
    {
        if (block == NULL or block->descriptor == NULL) {
            return NULL;
        }
        auto cursor = (const uintptr_t *)(const void *)(block->descriptor + 1);
        if (((uint32_t)block->flags & BLOCK_HAS_COPY_DISPOSE) != 0U) {
            cursor += 2;
        }
        return cursor;
    }

    static inline void (*nillable Block_descriptor_copy_helper(const struct Block_layout *nillable block))(void *nonnil, void *nonnil)
    {
        auto fields = Block_descriptor_copy_dispose_fields(block);
        return fields != NULL ? (void (*)(void *, void *))(uintptr_t)fields[0] : NULL;
    }

    static inline void (*nillable Block_descriptor_dispose_helper(const struct Block_layout *nillable block))(void *nonnil)
    {
        auto fields = Block_descriptor_copy_dispose_fields(block);
        return fields != NULL ? (void (*)(void *))(uintptr_t)fields[1] : NULL;
    }


    struct Block_byref {
        void *isa;
        struct Block_byref *forwarding;
        int flags; /* refcount; */
        int size;
        void (*byref_keep)(struct Block_byref *dst, struct Block_byref *src);
        void (*byref_destroy)(struct Block_byref *);
        /* long shared[0]; */
    };


    struct Block_byref_header {
        void *isa;
        struct Block_byref *forwarding;
        int flags;
        int size;
    };


    /* Runtime support functions used by compiler when generating copy/dispose helpers. */

    enum {
        /* See function implementation for a more complete description of these fields and combinations */
        BLOCK_FIELD_IS_OBJECT   =  3,  /* id, NSObject, __attribute__((NSObject)), block, ... */
        BLOCK_FIELD_IS_BLOCK    =  7,  /* a block variable */
        BLOCK_FIELD_IS_BYREF    =  8,  /* the on stack structure holding the __block variable */
        BLOCK_FIELD_IS_WEAK     = 16,  /* declared __weak, only used in byref copy helpers */
        BLOCK_BYREF_CALLER      = 128  /* called from __block (byref) copy/dispose support routines. */
    };

    /* Runtime entry point called by compiler when assigning objects inside copy helper routines */
    BLOCK_EXPORT void _Block_object_assign(void *destAddr, const void *object, const int flags);
        /* BLOCK_FIELD_IS_BYREF is only used from within block copy helpers */


    /* runtime entry point called by the compiler when disposing of objects inside dispose helper routine */
    BLOCK_EXPORT void _Block_object_dispose(const void *object, const int flags);



    /* Other support functions */

    /* Runtime entry to get total size of a closure */
    extern unsigned long int Block_size(void *arg);



    /* Compiler ABI class symbols. These are real Objective-C class objects owned by SmallFW. */
    BLOCK_EXPORT struct sf_objc_class _NSConcreteStackBlock;
    BLOCK_EXPORT struct sf_objc_class _NSConcreteMallocBlock;
    BLOCK_EXPORT struct sf_objc_class _NSConcreteAutoBlock;
    BLOCK_EXPORT struct sf_objc_class _NSConcreteFinalizingBlock;
    BLOCK_EXPORT struct sf_objc_class _NSConcreteGlobalBlock;
    BLOCK_EXPORT struct sf_objc_class _NSConcreteWeakBlockVariable;


    /* the intercept routines that must be used under GC */
    BLOCK_EXPORT void _Block_use_GC(void *nonnil (*nonnil alloc)(const unsigned long, const bool isOne, const bool isObject),
                                    void (*nonnil setHasRefcount)(const void *nonnil, const bool),
                                    void (*nonnil gc_assign_strong)(void *nonnil, void *nonnil *nonnil),
                                    void (*nonnil gc_assign_weak)(const void *nonnil, void *nonnil),
                                    void (*nonnil gc_memmove)(void *nonnil, void *nonnil, unsigned long));

    /* earlier version, now simply transitional */
    BLOCK_EXPORT void _Block_use_GC5(void *nonnil (*nonnil alloc)(const unsigned long, const bool isOne, const bool isObject),
                                     void (*nonnil setHasRefcount)(const void *nonnil, const bool),
                                     void (*nonnil gc_assign_strong)(void *nonnil, void *nonnil *nonnil),
                                     void (*nonnil gc_assign_weak)(const void *nonnil, void *nonnil));

    BLOCK_EXPORT void _Block_use_RR(void (*nonnil retain)(const void *nonnil), void (*nonnil release)(const void *nonnil));

    /* make a collectable GC heap based Block.  Not useful under non-GC. */
    BLOCK_EXPORT void *_Block_copy_collectable(const void *aBlock);
    BLOCK_EXPORT void *nillable _Block_copy_with_allocator(const void *nillable arg, SFAllocator_t *nillable allocator);
    BLOCK_EXPORT bool _Block_push_allocator_override(const void *nonnil owner, SFAllocator_t *nillable allocator);
    BLOCK_EXPORT bool _Block_discard_allocator_override(const void *nonnil owner);
    BLOCK_EXPORT void *_Block_copy_with_pending_allocator(const void *arg);

    /* thread-unsafe diagnostic */
    BLOCK_EXPORT const char *_Block_dump(const void *block);

    /* Obsolete */

    /* first layout */
    struct Block_basic {
        void *isa;
        int Block_flags;  /* int32_t */
        int Block_size;  /* XXX should be packed into Block_flags */
        void (*Block_invoke)(void *);
        void (*Block_copy)(void *dst, void *src);  /* iff BLOCK_HAS_COPY_DISPOSE */
        void (*Block_dispose)(void *);             /* iff BLOCK_HAS_COPY_DISPOSE */
        /* long params[0];  // where const imports, __block storage references, etc. get laid down */
    };

#    pragma clang assume_nonnull end


#    if defined(__cplusplus)
        }
#    endif


#endif /* _BLOCK_PRIVATE_H_ */
