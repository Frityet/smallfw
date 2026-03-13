#pragma once

#if !defined(__cplusplus)

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
#define nullptr 0
#endif

#if defined(__clang__) || defined(__GNUC__)
#if !defined(typeof)
#define typeof __typeof__
#endif

#if !defined(auto)
#define auto __auto_type
#endif
#endif

#endif
