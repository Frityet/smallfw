#include "runtime/sf_allocator.h"

#include <iso646.h>
#include <string.h>

#if defined(_WIN32)
#include <malloc.h>
#endif
#if defined(__linux__)
#include <sys/mman.h>
#include <unistd.h>
#endif
#include <stdlib.h>

typedef struct SFFreeNode {
    struct SFFreeNode *next;
} SFFreeNode_t;

enum {
    SF_FAST_ALLOC_GRANULE = 16U,
    SF_FAST_ALLOC_MAX = 512U,
    SF_FAST_ALLOC_BINS = SF_FAST_ALLOC_MAX / SF_FAST_ALLOC_GRANULE,
    SF_FAST_ALLOC_REFILL_BLOCKS = 64U,
};

static __thread SFFreeNode_t *g_fast_alloc_bins[SF_FAST_ALLOC_BINS];

int sf_default_allocator_returns_zeroed(size_t size, size_t align);

static size_t align_up(size_t value, size_t align)
{
    return (value + align - 1U) & ~(align - 1U);
}

static size_t fast_bin_size(size_t bin)
{
    return (bin + 1U) * SF_FAST_ALLOC_GRANULE;
}

static size_t runtime_page_size(void)
{
#if defined(__linux__)
    static size_t page_size = 0U;
    if (page_size == 0U) {
        long detected = sysconf(_SC_PAGESIZE);
        page_size = detected > 0 ? (size_t)detected : (size_t)4096U;
    }
    return page_size;
#else
    return 4096U;
#endif
}

static int refill_fast_bin(size_t bin)
{
    size_t block_size = fast_bin_size(bin);
    size_t page_size = runtime_page_size();
    size_t slab_bytes = align_up(block_size * SF_FAST_ALLOC_REFILL_BLOCKS, page_size);
    size_t block_count = slab_bytes / block_size;
    unsigned char *slab = NULL;

    if (block_count == 0U) {
        return 0;
    }

#if defined(__linux__)
    slab = (unsigned char *)mmap(NULL, slab_bytes, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (slab == MAP_FAILED) {
        slab = NULL;
    }
#else
    slab = calloc(1U, slab_bytes);
#endif
    if (slab == NULL) {
        return 0;
    }

    for (size_t i = block_count; i > 0U; --i) {
        SFFreeNode_t *node = (SFFreeNode_t *)(void *)(slab + ((i - 1U) * block_size));
        node->next = g_fast_alloc_bins[bin];
        g_fast_alloc_bins[bin] = node;
    }
    return 1;
}

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
        if (bin != (size_t)-1 and g_fast_alloc_bins[bin] == NULL) {
            (void)refill_fast_bin(bin);
        }
        if (bin != (size_t)-1 and g_fast_alloc_bins[bin] != NULL) {
            SFFreeNode_t *node = g_fast_alloc_bins[bin];
            g_fast_alloc_bins[bin] = node->next;
            node->next = NULL;
            return node;
        }
        return calloc(1U, size);
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
            size_t block_size = fast_bin_size(bin);
            if (block_size > sizeof(*node)) {
                memset((unsigned char *)(void *)node + sizeof(*node), 0, block_size - sizeof(*node));
            }
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

int sf_default_allocator_returns_zeroed(size_t size, size_t align)
{
    return align <= sizeof(void *) and fast_bin_index(size) != (size_t)-1;
}
