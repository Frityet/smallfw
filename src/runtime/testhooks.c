#include "runtime/internal.h"

#include <stdlib.h>

static size_t g_test_alloc_fail_after = SIZE_MAX;

int sf_runtime_test_consume_allocation(void)
{
    if (g_test_alloc_fail_after == SIZE_MAX) {
        return 1;
    }
    if (g_test_alloc_fail_after == 0) {
        g_test_alloc_fail_after = SIZE_MAX;
        return 0;
    }
    g_test_alloc_fail_after -= 1;
    return 1;
}

void sf_runtime_test_reset_alloc_failures(void)
{
    g_test_alloc_fail_after = SIZE_MAX;
}

void sf_runtime_test_fail_allocation_after(size_t successful_allocations)
{
    g_test_alloc_fail_after = successful_allocations;
}

void *sf_runtime_test_malloc(size_t size)
{
    if (not sf_runtime_test_consume_allocation()) {
        return NULL;
    }
    return malloc(size);
}

void *sf_runtime_test_calloc(size_t count, size_t size)
{
    if (not sf_runtime_test_consume_allocation()) {
        return NULL;
    }
    return calloc(count, size);
}

void *sf_runtime_test_realloc(void *ptr, size_t size)
{
    if (not sf_runtime_test_consume_allocation()) {
        return NULL;
    }
    return realloc(ptr, size);
}
