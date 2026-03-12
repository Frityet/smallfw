#pragma once

#include <stdint.h>

#ifndef SF_RUNTIME_THREADSAFE
#define SF_RUNTIME_THREADSAFE 0
#endif

#ifndef SF_DISPATCH_STATS
#define SF_DISPATCH_STATS 0
#endif

#ifndef SF_RUNTIME_EXCEPTIONS
#define SF_RUNTIME_EXCEPTIONS 1
#endif

#ifndef SF_RUNTIME_REFLECTION
#define SF_RUNTIME_REFLECTION 1
#endif

#ifndef SF_RUNTIME_FORWARDING
#define SF_RUNTIME_FORWARDING 0
#endif

#ifndef SF_RUNTIME_SLIM_ALLOC
#define SF_RUNTIME_SLIM_ALLOC 0
#endif

#ifndef SF_RUNTIME_VALIDATION
#define SF_RUNTIME_VALIDATION 1
#endif

#ifndef SF_RUNTIME_TAGGED_POINTERS
#define SF_RUNTIME_TAGGED_POINTERS 0
#endif

#ifndef SF_RUNTIME_COMPACT_HEADERS
#define SF_RUNTIME_COMPACT_HEADERS 0
#endif

#ifndef SF_RUNTIME_FAST_OBJECTS
#define SF_RUNTIME_FAST_OBJECTS 0
#endif

#ifndef SF_RUNTIME_INLINE_VALUE_STORAGE
#define SF_RUNTIME_INLINE_VALUE_STORAGE 0
#endif

#ifndef SF_RUNTIME_INLINE_GROUP_STATE
#define SF_RUNTIME_INLINE_GROUP_STATE 0
#endif

#ifndef SF_DISPATCH_L0_DUAL
#define SF_DISPATCH_L0_DUAL 0
#endif

#ifndef SF_DISPATCH_CACHE_2WAY
#define SF_DISPATCH_CACHE_2WAY 0
#endif

#ifndef SF_DISPATCH_CACHE_NEGATIVE
#define SF_DISPATCH_CACHE_NEGATIVE 0
#endif

#if SF_RUNTIME_TAGGED_POINTERS && UINTPTR_MAX != UINT64_MAX
#error "SF_RUNTIME_TAGGED_POINTERS requires 64-bit uintptr_t"
#endif

#if SF_RUNTIME_THREADSAFE
#include <pthread.h>
typedef pthread_rwlock_t SFRuntimeRwlock_t;
typedef pthread_mutex_t SFRuntimeMutex_t;
#define SF_RUNTIME_RWLOCK_INITIALIZER PTHREAD_RWLOCK_INITIALIZER
#define SF_RUNTIME_MUTEX_INITIALIZER PTHREAD_MUTEX_INITIALIZER
static inline void sf_runtime_rwlock_rdlock(SFRuntimeRwlock_t *lock)
{
    (void)pthread_rwlock_rdlock(lock);
}
static inline void sf_runtime_rwlock_wrlock(SFRuntimeRwlock_t *lock)
{
    (void)pthread_rwlock_wrlock(lock);
}
static inline void sf_runtime_rwlock_unlock(SFRuntimeRwlock_t *lock)
{
    (void)pthread_rwlock_unlock(lock);
}
static inline void sf_runtime_mutex_init(SFRuntimeMutex_t *lock)
{
    (void)pthread_mutex_init(lock, NULL);
}
static inline void sf_runtime_mutex_destroy(SFRuntimeMutex_t *lock)
{
    (void)pthread_mutex_destroy(lock);
}
static inline void sf_runtime_mutex_lock(SFRuntimeMutex_t *lock)
{
    (void)pthread_mutex_lock(lock);
}
static inline void sf_runtime_mutex_unlock(SFRuntimeMutex_t *lock)
{
    (void)pthread_mutex_unlock(lock);
}
#else
typedef int SFRuntimeRwlock_t;
typedef int SFRuntimeMutex_t;
#define SF_RUNTIME_RWLOCK_INITIALIZER 0
#define SF_RUNTIME_MUTEX_INITIALIZER 0
static inline void sf_runtime_rwlock_rdlock(SFRuntimeRwlock_t *lock)
{
    (void)lock;
}
static inline void sf_runtime_rwlock_wrlock(SFRuntimeRwlock_t *lock)
{
    (void)lock;
}
static inline void sf_runtime_rwlock_unlock(SFRuntimeRwlock_t *lock)
{
    (void)lock;
}
static inline void sf_runtime_mutex_init(SFRuntimeMutex_t *lock)
{
    (void)lock;
}
static inline void sf_runtime_mutex_destroy(SFRuntimeMutex_t *lock)
{
    (void)lock;
}
static inline void sf_runtime_mutex_lock(SFRuntimeMutex_t *lock)
{
    (void)lock;
}
static inline void sf_runtime_mutex_unlock(SFRuntimeMutex_t *lock)
{
    (void)lock;
}
#endif
