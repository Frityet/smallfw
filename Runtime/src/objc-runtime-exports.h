#pragma once

#include "c2x-compat.h"

#include <stddef.h>
#include <stdint.h>
#include <unwind.h>

#ifndef SF_RUNTIME_EXCEPTIONS
#define SF_RUNTIME_EXCEPTIONS 1
#endif

#ifndef SF_RUNTIME_REFLECTION
#define SF_RUNTIME_REFLECTION 1
#endif

#ifndef SF_RUNTIME_FORWARDING
#define SF_RUNTIME_FORWARDING 0
#endif

#ifndef SF_RUNTIME_TAGGED_POINTERS
#define SF_RUNTIME_TAGGED_POINTERS 0
#endif

#ifndef SF_RUNTIME_GENERIC_METADATA
#define SF_RUNTIME_GENERIC_METADATA 0
#endif

#ifndef SF_RUNTIME_TESTING
#define SF_RUNTIME_TESTING 0
#endif

#if SF_RUNTIME_TAGGED_POINTERS && UINTPTR_MAX != UINT64_MAX
#error "SF_RUNTIME_TAGGED_POINTERS requires 64-bit uintptr_t"
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__clang__)
#define SF_NOT_TAIL_CALLED __attribute__((not_tail_called))
#else
#define SF_NOT_TAIL_CALLED
#endif

#if defined(_WIN32)
#define SF_RUNTIME_EXPORT
#elif defined(__clang__) || defined(__GNUC__)
#define SF_RUNTIME_EXPORT __attribute__((visibility("default")))
#else
#define SF_RUNTIME_EXPORT
#endif

#pragma clang assume_nonnull begin

#ifndef __OBJC__
typedef struct sf_objc_selector {
    const char *nillable name;
    const char *nillable types;
} *SEL;

typedef struct sf_objc_class *Class;
typedef struct sf_objc_object *id;
#endif

#ifndef IMP
typedef id nillable (*nillable IMP)(id nillable, SEL nillable, ...);
#endif

typedef struct sf_objc_method *Method;
typedef struct sf_objc_ivar *Ivar;

struct sf_objc_super {
    id self;
    Class super_class;
};

SF_RUNTIME_EXPORT void __objc_load(void *nillable init);

SF_RUNTIME_EXPORT id nillable objc_msgSend(id nillable receiver, SEL nillable op, ...) SF_NOT_TAIL_CALLED;
#ifndef __OBJC__
SF_RUNTIME_EXPORT void objc_msgSend_stret(void *nonnil out, id nillable receiver, SEL nillable op, ...);
#endif
SF_RUNTIME_EXPORT IMP objc_msg_lookup(id nillable receiver, SEL nillable op);
SF_RUNTIME_EXPORT IMP objc_msg_lookup_stret(id nillable receiver, SEL nillable op);
SF_RUNTIME_EXPORT IMP objc_msg_lookup_super(struct sf_objc_super *nillable super_info, SEL nillable op);
SF_RUNTIME_EXPORT IMP objc_msg_lookup_super_stret(struct sf_objc_super *nillable super_info, SEL nillable op);

SF_RUNTIME_EXPORT id nillable objc_retain(id nillable obj);
SF_RUNTIME_EXPORT void objc_release(id nillable obj);
SF_RUNTIME_EXPORT id nillable objc_autorelease(id nillable obj);
SF_RUNTIME_EXPORT id nillable objc_alloc(Class nillable cls);
SF_RUNTIME_EXPORT id nillable objc_alloc_init(Class nillable cls);
SF_RUNTIME_EXPORT id nillable objc_retainAutorelease(id nillable obj);
SF_RUNTIME_EXPORT id nillable objc_retainAutoreleasedReturnValue(id nillable obj);
SF_RUNTIME_EXPORT id nillable objc_autoreleaseReturnValue(id nillable obj);
SF_RUNTIME_EXPORT id nillable objc_retainAutoreleaseReturnValue(id nillable obj);
SF_RUNTIME_EXPORT id nillable objc_retainBlock(id nillable obj);
SF_RUNTIME_EXPORT void objc_storeStrong(id nillable *nonnil dst, id nillable value);
SF_RUNTIME_EXPORT void *nonnil objc_autoreleasePoolPush(void);
SF_RUNTIME_EXPORT void objc_autoreleasePoolPop(void *nillable pool);

SF_RUNTIME_EXPORT void objc_exception_throw(id nillable obj);
SF_RUNTIME_EXPORT id nillable objc_begin_catch(void *nillable exception);
SF_RUNTIME_EXPORT void objc_end_catch(void);
SF_RUNTIME_EXPORT void objc_exception_rethrow(void *nillable exception);
SF_RUNTIME_EXPORT _Unwind_Reason_Code __gnustep_objc_personality_v0(int version, _Unwind_Action actions,
                                                                    uint64_t exception_class,
                                                                    struct _Unwind_Exception *nillable exception_object,
                                                                    struct _Unwind_Context *nillable context);
SF_RUNTIME_EXPORT _Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions,
                                                                uint64_t exception_class,
                                                                struct _Unwind_Exception *nillable exception_object,
                                                                struct _Unwind_Context *nillable context);

SF_RUNTIME_EXPORT size_t class_getInstanceSize(Class nillable cls);
SF_RUNTIME_EXPORT Class nillable objc_lookup_class(const char *nillable name);
SF_RUNTIME_EXPORT Class nillable objc_get_class(const char *nillable name);
SF_RUNTIME_EXPORT id nillable objc_getClass(const char *nillable name);
SF_RUNTIME_EXPORT void class_registerAlias_np(Class nillable cls, const char *nillable name);

SF_RUNTIME_EXPORT const char *nillable class_getName(Class nillable cls);
SF_RUNTIME_EXPORT Class nillable class_getSuperclass(Class nillable cls);
SF_RUNTIME_EXPORT Class nillable object_getClass(id nillable obj);
SF_RUNTIME_EXPORT Class nillable objc_getMetaClass(const char *nillable name);
SF_RUNTIME_EXPORT Class nillable *nillable objc_copyClassList(unsigned int *nillable outCount);
SF_RUNTIME_EXPORT Method nillable class_getInstanceMethod(Class nillable cls, SEL nillable sel);
SF_RUNTIME_EXPORT Method nillable class_getClassMethod(Class nillable cls, SEL nillable sel);
SF_RUNTIME_EXPORT Method nillable *nillable class_copyMethodList(Class nillable cls, unsigned int *nillable outCount);
SF_RUNTIME_EXPORT SEL nillable method_getName(Method nillable method);
SF_RUNTIME_EXPORT IMP method_getImplementation(Method nillable method);
SF_RUNTIME_EXPORT const char *nillable method_getTypeEncoding(Method nillable method);
SF_RUNTIME_EXPORT Ivar nillable class_getInstanceVariable(Class nillable cls, const char *nillable name);
SF_RUNTIME_EXPORT Ivar nillable *nillable class_copyIvarList(Class nillable cls, unsigned int *nillable outCount);
SF_RUNTIME_EXPORT const char *nillable ivar_getName(Ivar nillable ivar);
SF_RUNTIME_EXPORT const char *nillable ivar_getTypeEncoding(Ivar nillable ivar);
SF_RUNTIME_EXPORT ptrdiff_t ivar_getOffset(Ivar nillable ivar);
SF_RUNTIME_EXPORT const char *nillable sel_getName(SEL nillable sel);
SF_RUNTIME_EXPORT SEL nillable sel_registerName(const char *nillable name);
SF_RUNTIME_EXPORT int sel_isEqual(SEL nillable lhs, SEL nillable rhs);

SF_RUNTIME_EXPORT uint64_t sf_dispatch_cache_hits(void);
SF_RUNTIME_EXPORT uint64_t sf_dispatch_cache_misses(void);
SF_RUNTIME_EXPORT uint64_t sf_dispatch_method_walks(void);
SF_RUNTIME_EXPORT void sf_dispatch_reset_stats(void);

#pragma clang assume_nonnull end
#undef SF_NOT_TAIL_CALLED
#undef SF_RUNTIME_EXPORT

#ifdef __cplusplus
}
#endif
