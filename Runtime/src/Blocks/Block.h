/*
 * Block.h
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

#ifndef _BLOCK_H_
#    define _BLOCK_H_

#    include <iso646.h>
#    include <stdbool.h>
#    include <stddef.h>
#    include <stdint.h>

#    if not defined(BLOCK_EXPORT)
#        if defined(__cplusplus)
#            define BLOCK_EXPORT extern "C"
#        else
#            define BLOCK_EXPORT extern
#        endif
#    endif

#    include "objc-runtime-exports.h"
#    include "sf-allocator.h"
#    if defined(__OBJC__)
#        include "SmallFW/Object.h"
#    endif

#    if defined(__cplusplus)
        extern "C" {
#    endif

#    pragma clang assume_nonnull begin

    /* Create a heap based copy of a Block or simply add a reference to an existing one.
     * This must be paired with Block_release to recover memory, even when running
     * under Objective-C Garbage Collection.
     */
    BLOCK_EXPORT void *_Block_copy(const void *arg);

    /* Lose the reference, and if heap based and last reference, recover the memory. */
    BLOCK_EXPORT void _Block_release(const void *arg);

#    pragma clang assume_nonnull end

#    if defined(__cplusplus)
        }
#    endif

    /* Type correct macros. */

#    define Block_copy(...) ((__typeof(__VA_ARGS__))_Block_copy((const void *)(__VA_ARGS__)))
#    define Block_release(...) _Block_release((const void *)(__VA_ARGS__))

#    if defined(__OBJC__)

#        pragma clang assume_nonnull begin

        @interface Block : Object
        @property(nonatomic, readonly) size_t size;
        @property(nonatomic, readonly) uint32_t flags;
        @property(nonatomic, readonly) int32_t reserved;
        @property(nonatomic, readonly) uint32_t referenceCount;
        @property(nonatomic, readonly) bool needsFreeStorage;
        @property(nonatomic, readonly) bool usesGarbageCollection;
        @property(nonatomic, readonly) bool usesConstructorHelpers;
        @property(nonatomic, readonly) bool isGlobalStorage;
        @property(nonatomic, readonly) void *nillable descriptorPointer;
        @property(nonatomic, readonly) unsigned long descriptorReserved;
        @property(nonatomic, readonly) void *nillable invokePointer;
        @property(nonatomic, readonly) const char *nillable signature;
        @property(nonatomic, readonly) const struct SFMethodEncoding *nillable methodEncoding;
        @property(nonatomic, readonly) const char *nillable extendedLayout;
        @property(nonatomic, readonly) void *nillable copyHelperPointer;
        @property(nonatomic, readonly) void *nillable disposeHelperPointer;
        @property(nonatomic, readonly) void *nillable capturedVariablesPointer;
        @property(nonatomic, readonly) size_t capturedVariablesSize;

        + (SF_ERRORABLE(instancetype))allocWithAllocator:(SFAllocator_t *nillable)allocator __attribute__((unavailable("Blocks are compiler-created objects; copy an existing block instead")));
        + (SF_ERRORABLE(instancetype))allocWithParent:(Object *nillable)parent __attribute__((unavailable("Blocks are compiler-created objects; copy an existing block instead")));
        + (instancetype nillable)allocInPlace:(void *nillable)storage size:(size_t)size __attribute__((unavailable("Blocks are compiler-created objects; copy an existing block instead")));
        @end

        @interface StackBlock : Block
        @end

        @interface HeapBlock : Block
        @property(nonatomic, readonly) size_t allocationSize;
        @end

        @interface AutomaticBlock : HeapBlock
        @end

        @interface FinalizingBlock : AutomaticBlock
        @end

        @interface GlobalBlock : Block
        @end

        @interface WeakBlockVariable : Object
        @property(nonatomic, readonly) WeakBlockVariable *nillable forwardingVariable;
        @property(nonatomic, readonly) uint32_t flags;
        @property(nonatomic, readonly) uint32_t referenceCount;
        @property(nonatomic, readonly) size_t size;
        @property(nonatomic, readonly) void *nillable keepHelperPointer;
        @property(nonatomic, readonly) void *nillable destroyHelperPointer;
        @property(nonatomic, readonly) void *nillable capturedVariablesPointer;
        @property(nonatomic, readonly) size_t capturedVariablesSize;
        @end

#        pragma clang assume_nonnull end

#    endif

#endif
