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

#if SF_RUNTIME_TAGGED_POINTERS and UINTPTR_MAX != UINT64_MAX
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

void __objc_load(void *_Nullable init);

id _Nullable objc_msgSend(id _Nullable receiver, SEL _Nullable op, ...) SF_NOT_TAIL_CALLED;
#ifndef __OBJC__
void objc_msgSend_stret(void *_Nonnull out, id _Nullable receiver, SEL _Nullable op, ...);
#endif
IMP objc_msg_lookup(id _Nullable receiver, SEL _Nullable op);
IMP objc_msg_lookup_stret(id _Nullable receiver, SEL _Nullable op);
IMP objc_msg_lookup_super(struct sf_objc_super *_Nullable super_info, SEL _Nullable op);
IMP objc_msg_lookup_super_stret(struct sf_objc_super *_Nullable super_info, SEL _Nullable op);

id _Nullable objc_retain(id _Nullable obj);
void objc_release(id _Nullable obj);
id _Nullable objc_autorelease(id _Nullable obj);
id _Nullable objc_alloc(Class _Nullable cls);
id _Nullable objc_alloc_init(Class _Nullable cls);
id _Nullable objc_retainAutorelease(id _Nullable obj);
id _Nullable objc_retainAutoreleasedReturnValue(id _Nullable obj);
id _Nullable objc_autoreleaseReturnValue(id _Nullable obj);
id _Nullable objc_retainAutoreleaseReturnValue(id _Nullable obj);
void objc_storeStrong(id _Nullable *_Nonnull dst, id _Nullable value);
void *_Nonnull objc_autoreleasePoolPush(void);
void objc_autoreleasePoolPop(void *_Nullable pool);

void objc_exception_throw(id _Nullable obj);
id _Nullable objc_begin_catch(void *_Nullable exception);
void objc_end_catch(void);
void objc_exception_rethrow(void *_Nullable exception);
_Unwind_Reason_Code __gnustep_objc_personality_v0(int version, _Unwind_Action actions,
                                                  uint64_t exception_class,
                                                  struct _Unwind_Exception *_Nullable exception_object,
                                                  struct _Unwind_Context *_Nullable context);
_Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions,
                                              uint64_t exception_class,
                                              struct _Unwind_Exception *_Nullable exception_object,
                                              struct _Unwind_Context *_Nullable context);

size_t class_getInstanceSize(Class _Nullable cls);
Class _Nullable objc_lookup_class(const char *_Nullable name);
Class _Nullable objc_get_class(const char *_Nullable name);
id _Nullable objc_getClass(const char *_Nullable name);

#if SF_RUNTIME_REFLECTION
const char *_Nullable class_getName(Class _Nullable cls);
Class _Nullable class_getSuperclass(Class _Nullable cls);
Class _Nullable object_getClass(id _Nullable obj);
Class _Nullable objc_getMetaClass(const char *_Nullable name);
Class _Nullable *_Nullable objc_copyClassList(unsigned int *_Nullable outCount);
Method _Nullable class_getInstanceMethod(Class _Nullable cls, SEL _Nullable sel);
Method _Nullable class_getClassMethod(Class _Nullable cls, SEL _Nullable sel);
Method _Nullable *_Nullable class_copyMethodList(Class _Nullable cls, unsigned int *_Nullable outCount);
SEL _Nullable method_getName(Method _Nullable method);
IMP method_getImplementation(Method _Nullable method);
const char *_Nullable method_getTypeEncoding(Method _Nullable method);
Ivar _Nullable class_getInstanceVariable(Class _Nullable cls, const char *_Nullable name);
Ivar _Nullable *_Nullable class_copyIvarList(Class _Nullable cls, unsigned int *_Nullable outCount);
const char *_Nullable ivar_getName(Ivar _Nullable ivar);
const char *_Nullable ivar_getTypeEncoding(Ivar _Nullable ivar);
ptrdiff_t ivar_getOffset(Ivar _Nullable ivar);
const char *_Nullable sel_getName(SEL _Nullable sel);
SEL _Nullable sel_registerName(const char *_Nullable name);
int sel_isEqual(SEL _Nullable lhs, SEL _Nullable rhs);
#endif

uint64_t sf_dispatch_cache_hits(void);
uint64_t sf_dispatch_cache_misses(void);
uint64_t sf_dispatch_method_walks(void);
void sf_dispatch_reset_stats(void);

#pragma clang assume_nonnull end
#undef SF_NOT_TAIL_CALLED

#ifdef __cplusplus
}
#endif
