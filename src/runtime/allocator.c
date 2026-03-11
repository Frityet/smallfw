#include "runtime/sf_allocator.h"

#include <iso646.h>

#if defined(_WIN32)
#include <malloc.h>
#endif
#include <stdlib.h>

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#endif

typedef struct SFFreeNode {
    struct SFFreeNode *next;
} SFFreeNode_t;

enum {
    SF_FAST_ALLOC_GRANULE = 16U,
    SF_FAST_ALLOC_MAX = 256U,
    SF_FAST_ALLOC_BINS = SF_FAST_ALLOC_MAX / SF_FAST_ALLOC_GRANULE,
};

static __thread SFFreeNode_t *g_fast_alloc_bins[SF_FAST_ALLOC_BINS];

static int is_valid_alignment(size_t align)
{
    if (align <= sizeof(void *)) {
        return 1;
    }
    if ((align % sizeof(void *)) != 0) {
        return 0;
    }
    return (align & (align - 1U)) == 0;
}

static size_t fast_bin_index(size_t size)
{
    if (size == 0 or size > SF_FAST_ALLOC_MAX) {
        return (size_t)-1;
    }
    return (size - 1U) / SF_FAST_ALLOC_GRANULE;
}

static void *default_alloc(void *ctx, size_t size, size_t align)
{
#if !defined(_WIN32)
    void *ptr = NULL;
#endif
    (void)ctx;
    if (align <= sizeof(void *)) {
        size_t bin = fast_bin_index(size);
        if (bin != (size_t)-1 and g_fast_alloc_bins[bin] != NULL) {
            SFFreeNode_t *node = g_fast_alloc_bins[bin];
            g_fast_alloc_bins[bin] = node->next;
            return node;
        }
        return malloc(size);
    }
    if (not is_valid_alignment(align)) {
        return NULL;
    }
#if defined(_WIN32)
    return _aligned_malloc(size, align);
#else
    if (posix_memalign(&ptr, align, size) != 0) {
        return NULL;
    }
    return ptr;
#endif
}

static void default_free(void *ctx, void *ptr, size_t size, size_t align)
{
    (void)ctx;
    if (ptr == NULL) {
        return;
    }
    if (align <= sizeof(void *)) {
        size_t bin = fast_bin_index(size);
        if (bin != (size_t)-1) {
            SFFreeNode_t *node = (SFFreeNode_t *)ptr;
            node->next = g_fast_alloc_bins[bin];
            g_fast_alloc_bins[bin] = node;
            return;
        }
    }
#if defined(_WIN32)
    if (align > sizeof(void *)) {
        _aligned_free(ptr);
        return;
    }
#else
    (void)align;
#endif
    free(ptr);
}

SFAllocator_t *sf_default_allocator(void)
{
    static SFAllocator_t allocator = {
        .alloc = default_alloc,
        .free = default_free,
        .ctx = NULL,
    };
    return &allocator;
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
