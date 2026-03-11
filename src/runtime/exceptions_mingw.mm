#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wc99-extensions"
#pragma clang diagnostic ignored "-Wc++98-compat"
#pragma clang diagnostic ignored "-Wc++98-compat-pedantic"
#pragma clang diagnostic ignored "-Wold-style-cast"
#pragma clang diagnostic ignored "-Wexit-time-destructors"
#pragma clang diagnostic ignored "-Wglobal-constructors"
#pragma clang diagnostic ignored "-Wreserved-identifier"
#pragma clang diagnostic ignored "-Wsign-conversion"
#pragma clang diagnostic ignored "-Wweak-vtables"
#pragma clang diagnostic ignored "-Wzero-as-null-pointer-constant"
#endif

#include "runtime/internal.h"

#if defined(_WIN32) && SF_RUNTIME_EXCEPTIONS

#include <cxxabi.h>
#include <stdlib.h>
#include <typeinfo>

namespace {

static id sf_dereference_thrown_object(void **thrown_object)
{
    if (thrown_object == nullptr) {
        return (id)0;
    }
    return *(id *)thrown_object;
}

static int sf_class_is_kind_of(const SFObjCClass_t *actual, const SFObjCClass_t *wanted)
{
    while (actual != nullptr) {
        if (actual == wanted) {
            return 1;
        }
        actual = actual->superclass;
    }
    return 0;
}

static void sf_objc_exception_cleanup(void *exception_object)
{
    if (exception_object == nullptr) {
        return;
    }
    objc_release(*(id *)exception_object);
}

static thread_local unsigned g_manual_catch_depth;

} // namespace

namespace gnustep {
namespace libobjc {

struct __objc_type_info : public std::type_info {
    explicit __objc_type_info(const char *name) : std::type_info(name)
    {
    }

    bool __is_pointer_p() const override
    {
        return true;
    }

    bool __is_function_p() const override
    {
        return false;
    }

    bool __do_catch(const std::type_info *thrown_type, void **thrown_object, unsigned outer) const override
    {
        (void)thrown_type;
        (void)thrown_object;
        (void)outer;
        return false;
    }

    bool __do_upcast(const __cxxabiv1::__class_type_info *target, void **thrown_object) const override
    {
        (void)target;
        (void)thrown_object;
        return false;
    }
};

struct __objc_class_type_info : public __objc_type_info {
    using __objc_type_info::__objc_type_info;
    ~__objc_class_type_info() override;

    bool __do_catch(const std::type_info *thrown_type, void **thrown_object, unsigned outer) const override
    {
        (void)outer;
        if (dynamic_cast<const __objc_type_info *>(thrown_type) == nullptr) {
            return false;
        }

        id thrown = sf_dereference_thrown_object(thrown_object);
        if (thrown == (id)0) {
            return false;
        }

        const SFObjCClass_t *wanted = sf_class_from_name(name());
        const SFObjCClass_t *actual = (const SFObjCClass_t *)sf_object_class(thrown);
        if (wanted == nullptr || actual == nullptr || !sf_class_is_kind_of(actual, wanted)) {
            return false;
        }

        *thrown_object = (void *)thrown;
        return true;
    }
};

struct __objc_id_type_info : public __objc_type_info {
    __objc_id_type_info() : __objc_type_info("@id")
    {
    }

    ~__objc_id_type_info() override;

    bool __do_catch(const std::type_info *thrown_type, void **thrown_object, unsigned outer) const override
    {
        (void)outer;
        if (dynamic_cast<const __objc_type_info *>(thrown_type) == nullptr) {
            return false;
        }

        *thrown_object = (void *)sf_dereference_thrown_object(thrown_object);
        return true;
    }
};

} // namespace libobjc
} // namespace gnustep

gnustep::libobjc::__objc_class_type_info::~__objc_class_type_info() = default;
gnustep::libobjc::__objc_id_type_info::~__objc_id_type_info() = default;

extern "C" gnustep::libobjc::__objc_id_type_info __objc_id_type_info;

gnustep::libobjc::__objc_id_type_info __objc_id_type_info;

extern "C" void *__cxa_allocate_exception(size_t thrown_size) __attribute__((nothrow));

extern "C" __attribute__((noreturn)) void objc_exception_throw(id obj)
{
    if (!sf_runtime_test_consume_allocation()) {
        abort();
    }

    id *exception_object = (id *)__cxa_allocate_exception(sizeof(id));
    if (exception_object == nullptr) {
        abort();
    }

    *exception_object = objc_retain(obj);
    sf_exception_capture_metadata(*exception_object);
    __cxxabiv1::__cxa_throw(exception_object, &__objc_id_type_info, sf_objc_exception_cleanup);
}

extern "C" id objc_begin_catch(void *exception)
{
    if (exception == nullptr) {
        return (id)0;
    }

    g_manual_catch_depth += 1;
    return (id)__cxxabiv1::__cxa_begin_catch(exception);
}

extern "C" void objc_end_catch(void)
{
    if (g_manual_catch_depth == 0) {
        return;
    }

    g_manual_catch_depth -= 1;
    __cxxabiv1::__cxa_end_catch();
}

extern "C" __attribute__((noreturn)) void objc_exception_rethrow(void *exception)
{
    (void)exception;
    __cxxabiv1::__cxa_rethrow();
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif

#endif
