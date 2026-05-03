#pragma once

#include <iso646.h>

#define nillable _Nullable
#define nonnil _Nonnull
#define nillptr nullptr

#ifndef SF_DEBUG
#    define SF_DEBUG 0
#endif

#if SF_DEBUG
#    define sf_nonnil_check(...) do { if (not(__VA_ARGS__)) { __builtin_trap(); } } while (0)
#else
#    define sf_nonnil_check(...) do { } while (0)
#endif

#if defined(__EMSCRIPTEN__) and not defined(__EMSCRIPTEN_PTHREADS__)
#    if defined(thread_local)
#        undef thread_local
#    endif
#    define thread_local
#endif

#pragma clang assume_nonnull begin
#pragma clang assume_nonnull end
