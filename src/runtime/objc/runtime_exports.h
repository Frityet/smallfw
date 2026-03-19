#pragma once

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

#ifndef SF_RUNTIME_OBJC_FRAMEWORK_OBJFW
#define SF_RUNTIME_OBJC_FRAMEWORK_OBJFW 0
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
    const char *_Nullable name;
    const char *_Nullable types;
} *SEL;

typedef struct sf_objc_class *Class;
typedef struct sf_objc_object *id;
#endif

#ifndef IMP
typedef id _Nullable (*_Nullable IMP)(id _Nullable, SEL _Nullable, ...);
#endif

typedef struct sf_objc_method *Method;
typedef struct sf_objc_ivar *Ivar;

struct sf_objc_super {
    id self;
    Class super_class;
};

#if SF_RUNTIME_OBJC_FRAMEWORK_OBJFW
SF_RUNTIME_EXPORT void __objc_exec_class(void *_Nullable module, ...);
#else
SF_RUNTIME_EXPORT void __objc_load(void *_Nullable init);
#endif

SF_RUNTIME_EXPORT id _Nullable objc_msgSend(id _Nullable receiver, SEL _Nullable op, ...) SF_NOT_TAIL_CALLED;
#ifndef __OBJC__
SF_RUNTIME_EXPORT void objc_msgSend_stret(void *_Nonnull out, id _Nullable receiver, SEL _Nullable op, ...);
#endif
SF_RUNTIME_EXPORT IMP objc_msg_lookup(id _Nullable receiver, SEL _Nullable op);
SF_RUNTIME_EXPORT IMP objc_msg_lookup_stret(id _Nullable receiver, SEL _Nullable op);
SF_RUNTIME_EXPORT IMP objc_msg_lookup_super(struct sf_objc_super *_Nullable super_info, SEL _Nullable op);
SF_RUNTIME_EXPORT IMP objc_msg_lookup_super_stret(struct sf_objc_super *_Nullable super_info, SEL _Nullable op);

SF_RUNTIME_EXPORT id _Nullable objc_retain(id _Nullable obj);
SF_RUNTIME_EXPORT void objc_release(id _Nullable obj);
SF_RUNTIME_EXPORT id _Nullable objc_autorelease(id _Nullable obj);
SF_RUNTIME_EXPORT id _Nullable objc_alloc(Class _Nullable cls);
SF_RUNTIME_EXPORT id _Nullable objc_alloc_init(Class _Nullable cls);
SF_RUNTIME_EXPORT id _Nullable objc_retainAutorelease(id _Nullable obj);
SF_RUNTIME_EXPORT id _Nullable objc_retainAutoreleasedReturnValue(id _Nullable obj);
SF_RUNTIME_EXPORT id _Nullable objc_autoreleaseReturnValue(id _Nullable obj);
SF_RUNTIME_EXPORT id _Nullable objc_retainAutoreleaseReturnValue(id _Nullable obj);
SF_RUNTIME_EXPORT id _Nullable objc_retainBlock(id _Nullable obj);
SF_RUNTIME_EXPORT void objc_storeStrong(id _Nullable *_Nonnull dst, id _Nullable value);
SF_RUNTIME_EXPORT void *_Nonnull objc_autoreleasePoolPush(void);
SF_RUNTIME_EXPORT void objc_autoreleasePoolPop(void *_Nullable pool);

SF_RUNTIME_EXPORT void objc_exception_throw(id _Nullable obj);
SF_RUNTIME_EXPORT id _Nullable objc_begin_catch(void *_Nullable exception);
SF_RUNTIME_EXPORT void objc_end_catch(void);
SF_RUNTIME_EXPORT void objc_exception_rethrow(void *_Nullable exception);
SF_RUNTIME_EXPORT _Unwind_Reason_Code __gnustep_objc_personality_v0(int version, _Unwind_Action actions,
                                                                    uint64_t exception_class,
                                                                    struct _Unwind_Exception *_Nullable exception_object,
                                                                    struct _Unwind_Context *_Nullable context);
SF_RUNTIME_EXPORT _Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions,
                                                                uint64_t exception_class,
                                                                struct _Unwind_Exception *_Nullable exception_object,
                                                                struct _Unwind_Context *_Nullable context);

SF_RUNTIME_EXPORT size_t class_getInstanceSize(Class _Nullable cls);
SF_RUNTIME_EXPORT Class _Nullable objc_lookup_class(const char *_Nullable name);
SF_RUNTIME_EXPORT Class _Nullable objc_get_class(const char *_Nullable name);
SF_RUNTIME_EXPORT id _Nullable objc_getClass(const char *_Nullable name);

SF_RUNTIME_EXPORT const char *_Nullable class_getName(Class _Nullable cls);
SF_RUNTIME_EXPORT Class _Nullable class_getSuperclass(Class _Nullable cls);
SF_RUNTIME_EXPORT Class _Nullable object_getClass(id _Nullable obj);
SF_RUNTIME_EXPORT Class _Nullable objc_getMetaClass(const char *_Nullable name);
SF_RUNTIME_EXPORT Class _Nullable *_Nullable objc_copyClassList(unsigned int *_Nullable outCount);
SF_RUNTIME_EXPORT Method _Nullable class_getInstanceMethod(Class _Nullable cls, SEL _Nullable sel);
SF_RUNTIME_EXPORT Method _Nullable class_getClassMethod(Class _Nullable cls, SEL _Nullable sel);
SF_RUNTIME_EXPORT Method _Nullable *_Nullable class_copyMethodList(Class _Nullable cls, unsigned int *_Nullable outCount);
SF_RUNTIME_EXPORT SEL _Nullable method_getName(Method _Nullable method);
SF_RUNTIME_EXPORT IMP method_getImplementation(Method _Nullable method);
SF_RUNTIME_EXPORT const char *_Nullable method_getTypeEncoding(Method _Nullable method);
SF_RUNTIME_EXPORT Ivar _Nullable class_getInstanceVariable(Class _Nullable cls, const char *_Nullable name);
SF_RUNTIME_EXPORT Ivar _Nullable *_Nullable class_copyIvarList(Class _Nullable cls, unsigned int *_Nullable outCount);
SF_RUNTIME_EXPORT const char *_Nullable ivar_getName(Ivar _Nullable ivar);
SF_RUNTIME_EXPORT const char *_Nullable ivar_getTypeEncoding(Ivar _Nullable ivar);
SF_RUNTIME_EXPORT ptrdiff_t ivar_getOffset(Ivar _Nullable ivar);
SF_RUNTIME_EXPORT const char *_Nullable sel_getName(SEL _Nullable sel);
SF_RUNTIME_EXPORT SEL _Nullable sel_registerName(const char *_Nullable name);
SF_RUNTIME_EXPORT int sel_isEqual(SEL _Nullable lhs, SEL _Nullable rhs);

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
