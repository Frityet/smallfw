#pragma once

#include <stddef.h>

#pragma clang assume_nonnull begin
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-extension"
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SFAllocator {
    void *_Nullable (*_Nonnull alloc)(void *_Nullable ctx, size_t size, size_t align);
    void (*_Nonnull free)(void *_Nullable ctx, void *_Nullable ptr, size_t size, size_t align);
    void *_Nullable ctx;
} SFAllocator_t;

SFAllocator_t *sf_default_allocator(void);

#ifdef __cplusplus
}
#endif

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
#pragma clang assume_nonnull end
