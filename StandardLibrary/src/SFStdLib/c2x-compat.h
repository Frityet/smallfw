#pragma once

#include <iso646.h>

#if !defined(nillable)
#define nillable _Nullable
#endif

#if !defined(nonnil)
#define nonnil _Nonnull
#endif

#if !defined(nillptr)
#define nillptr nullptr
#endif

#if !defined(__cplusplus)
#if !defined(__STDC_VERSION__) || __STDC_VERSION__ < 202311L

#if !defined(alignas)
#define alignas _Alignas
#endif

#if !defined(alignof)
#define alignof _Alignof
#endif

#if !defined(static_assert)
#define static_assert _Static_assert
#endif

#if !defined(thread_local)
#define thread_local _Thread_local
#endif

#if !defined(nullptr)
#define nullptr ((void *nillable)0)
#endif

#endif

#if defined(__clang__) || defined(__GNUC__)
#if !defined(typeof)
#define typeof __typeof__
#endif
#endif

#if defined(__EMSCRIPTEN__) && !defined(__EMSCRIPTEN_PTHREADS__)
#if defined(thread_local)
#undef thread_local
#endif
#define thread_local
#endif
#endif
