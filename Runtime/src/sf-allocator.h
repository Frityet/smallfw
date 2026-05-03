#pragma once

#include "c2x-compat.h"

#include <stddef.h>

#pragma clang assume_nonnull begin

#ifdef __cplusplus
    extern "C" {
#endif

typedef struct SFAllocator {
    void *nillable (*nonnil alloc)(void *nillable ctx, size_t size, size_t align);
    void (*nonnil free)(void *nillable ctx, void *nillable ptr, size_t size, size_t align);
    void *nillable ctx;
} SFAllocator_t;

SFAllocator_t *sf_default_allocator(void);

#ifdef __cplusplus
    }
#endif

#pragma clang assume_nonnull end
