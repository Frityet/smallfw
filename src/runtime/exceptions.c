#include "runtime/internal.h"

#include <stdlib.h>
#include <string.h>
#include <unwind.h>
#if defined(_WIN32) && !defined(_WIN32_WINNT)
#define _WIN32_WINNT 0x0600
#endif
#if defined(_WIN32)
#include <windows.h>
#endif

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-noreturn"
#pragma clang diagnostic ignored "-Wunused-macros"
#endif

#if SF_RUNTIME_EXCEPTIONS

#define SF_EXCEPTION_CLASS UINT64_C(0x5346574f424a4300)
#define SF_EXCEPTION_BACKTRACE_LIMIT 32

typedef struct SFException {
    struct _Unwind_Exception unwind;
    id object;
    uint32_t catch_depth;
    uint32_t reserved;
    struct SFException *next_active;
} SFException_t;

typedef struct SFExceptionMetadata {
    struct SFExceptionMetadata *next;
    id object;
    size_t count;
    const void *frames[SF_EXCEPTION_BACKTRACE_LIMIT];
} SFExceptionMetadata_t;

#if not defined(_WIN32)
typedef struct SFBacktraceCapture {
    const void **frames;
    size_t count;
    size_t limit;
    size_t skip;
} SFBacktraceCapture_t;
#endif

#if not defined(_WIN32)
static __thread SFException_t *g_catch_stack[32];
static __thread size_t g_catch_stack_size;
static __thread SFException_t *g_gnu_current_exception;
#endif
static SFRuntimeMutex_t g_exception_metadata_lock = SF_RUNTIME_MUTEX_INITIALIZER;
static SFExceptionMetadata_t *g_exception_metadata;
static SFRuntimeMutex_t g_exception_active_lock = SF_RUNTIME_MUTEX_INITIALIZER;
static SFException_t *g_exception_active;

static SFException_t *sf_exception_from_unwind(struct _Unwind_Exception *exception_object)
{
    if (exception_object == NULL or exception_object->exception_class != SF_EXCEPTION_CLASS) {
        return NULL;
    }
    return (SFException_t *)exception_object;
}

static void sf_exception_register_active(SFException_t *exc)
{
    if (exc == NULL) {
        return;
    }

    sf_runtime_mutex_lock(&g_exception_active_lock);
    exc->next_active = g_exception_active;
    g_exception_active = exc;
    sf_runtime_mutex_unlock(&g_exception_active_lock);
}

static void sf_exception_unregister_active(SFException_t *exc)
{
    if (exc == NULL) {
        return;
    }

    sf_runtime_mutex_lock(&g_exception_active_lock);
    SFException_t **slot = &g_exception_active;
    while (*slot != NULL and *slot != exc) {
        slot = &(*slot)->next_active;
    }
    if (*slot == exc) {
        *slot = exc->next_active;
        exc->next_active = NULL;
    }
    sf_runtime_mutex_unlock(&g_exception_active_lock);
}

static SFException_t *sf_exception_from_object(id obj)
{
    SFException_t *result = NULL;

    if (obj == NULL) {
        return NULL;
    }

    sf_runtime_mutex_lock(&g_exception_active_lock);
    for (SFException_t *it = g_exception_active; it != NULL; it = it->next_active) {
        if (it->object == obj) {
            result = it;
            break;
        }
    }
    sf_runtime_mutex_unlock(&g_exception_active_lock);
    return result;
}

static SFException_t *sf_exception_resolve(void *exception_or_object)
{
    SFException_t *exc = NULL;

    if (exception_or_object == NULL) {
        return NULL;
    }

    exc = sf_exception_from_unwind((struct _Unwind_Exception *)exception_or_object);
    if (exc != NULL) {
        return exc;
    }
    return sf_exception_from_object((id)exception_or_object);
}

#if not defined(_WIN32)
static _Unwind_Reason_Code capture_backtrace_frame(struct _Unwind_Context *context, void *arg)
{
    SFBacktraceCapture_t *capture = (SFBacktraceCapture_t *)arg;
    uintptr_t ip = (uintptr_t)_Unwind_GetIP(context);
    if (ip == 0 or capture->count == capture->limit)
        return _URC_END_OF_STACK;
    if (capture->skip > 0) {
        capture->skip -= 1;
        return _URC_NO_REASON;
    }
    capture->frames[capture->count++] = (const void *)ip;
    return capture->count == capture->limit ? _URC_END_OF_STACK : _URC_NO_REASON;
}
#endif

static size_t capture_backtrace(const void **frames, size_t limit)
{
#if defined(_WIN32)
    void *captured[SF_EXCEPTION_BACKTRACE_LIMIT];
    USHORT count = 0;

    if (limit > SF_EXCEPTION_BACKTRACE_LIMIT) {
        limit = SF_EXCEPTION_BACKTRACE_LIMIT;
    }
    count = CaptureStackBackTrace(2, (ULONG)limit, captured, NULL);
    for (USHORT i = 0; i < count; ++i) {
        frames[i] = captured[i];
    }
    return (size_t)count;
#else
    SFBacktraceCapture_t capture = {
        .frames = frames,
        .count = 0,
        .limit = limit,
        .skip = 2,
    };
    (void)_Unwind_Backtrace(capture_backtrace_frame, &capture);
    return capture.count;
#endif
}

static SFExceptionMetadata_t **find_exception_metadata_slot(id obj)
{
    SFExceptionMetadata_t **slot = &g_exception_metadata;
    while (*slot != NULL and (*slot)->object != obj)
        slot = &(*slot)->next;
    return slot;
}

void sf_exception_capture_metadata(id obj)
{
    if (obj == NULL)
        return;

    const void *frames[SF_EXCEPTION_BACKTRACE_LIMIT];
    size_t count = capture_backtrace(frames, SF_EXCEPTION_BACKTRACE_LIMIT);

    sf_runtime_mutex_lock(&g_exception_metadata_lock);
    SFExceptionMetadata_t **slot = find_exception_metadata_slot(obj);
    SFExceptionMetadata_t *meta = *slot;
    if (meta == NULL) {
        meta = (SFExceptionMetadata_t *)sf_runtime_test_calloc(1, sizeof(*meta));
        if (meta != NULL) {
            meta->object = obj;
            *slot = meta;
        }
    }
    if (meta != NULL) {
        meta->count = count;
        if (count > 0)
            memcpy((void *)meta->frames, (const void *)frames, count * sizeof(frames[0]));
    }
    sf_runtime_mutex_unlock(&g_exception_metadata_lock);
}

size_t sf_exception_backtrace_count(id obj)
{
    size_t count = 0;
    if (obj == NULL)
        return 0;

    sf_runtime_mutex_lock(&g_exception_metadata_lock);
    SFExceptionMetadata_t *meta = *find_exception_metadata_slot(obj);
    if (meta != NULL)
        count = meta->count;
    sf_runtime_mutex_unlock(&g_exception_metadata_lock);
    return count;
}

const void *sf_exception_backtrace_frame(id obj, size_t index)
{
    const void *frame = NULL;
    if (obj == NULL)
        return NULL;

    sf_runtime_mutex_lock(&g_exception_metadata_lock);
    SFExceptionMetadata_t *meta = *find_exception_metadata_slot(obj);
    if (meta != NULL and index < meta->count)
        frame = meta->frames[index];
    sf_runtime_mutex_unlock(&g_exception_metadata_lock);
    return frame;
}

void sf_exception_clear_metadata(id obj)
{
    SFExceptionMetadata_t *meta = NULL;
    if (obj == NULL)
        return;

    sf_runtime_mutex_lock(&g_exception_metadata_lock);
    SFExceptionMetadata_t **slot = find_exception_metadata_slot(obj);
    meta = *slot;
    if (meta != NULL)
        *slot = meta->next;
    sf_runtime_mutex_unlock(&g_exception_metadata_lock);
    free(meta);
}

#if not defined(_WIN32)
static void sf_exception_cleanup(_Unwind_Reason_Code code, struct _Unwind_Exception *exception_object)
{
    (void)code;
    SFException_t *exc = (SFException_t *)exception_object;
    sf_exception_unregister_active(exc);
    if (g_gnu_current_exception == exc) {
        g_gnu_current_exception = NULL;
    }
    if (exc->object != NULL and SF_RUNTIME_OBJC_FRAMEWORK_OBJFW == 0) {
        objc_release(exc->object);
    }
    free(exc);
}

void objc_exception_throw(id obj)
{
    SFException_t *rethrow_exc = NULL;
    if (g_gnu_current_exception != NULL and g_gnu_current_exception->object == obj) {
        rethrow_exc = g_gnu_current_exception;
    }
    if (rethrow_exc != NULL) {
        _Unwind_Resume_or_Rethrow(&rethrow_exc->unwind);
        abort();
    }

    SFException_t *exc = (SFException_t *)sf_runtime_test_calloc(1, sizeof(SFException_t));
    if (exc == NULL) {
        abort();
    }
    exc->object = (SF_RUNTIME_OBJC_FRAMEWORK_OBJFW != 0) ? obj : objc_retain(obj);
    sf_exception_capture_metadata(exc->object);
    exc->unwind.exception_class = SF_EXCEPTION_CLASS;
    exc->unwind.exception_cleanup = sf_exception_cleanup;
    sf_exception_register_active(exc);

    _Unwind_Reason_Code rc = _Unwind_RaiseException(&exc->unwind);
    sf_exception_cleanup(rc, &exc->unwind);
    abort();
}

id objc_begin_catch(void *exception)
{
    SFException_t *exc = sf_exception_resolve(exception);
    if (exc == NULL) {
        return (id)exception;
    }
    exc->catch_depth += 1;
    g_gnu_current_exception = exc;
    if (g_catch_stack_size < (sizeof(g_catch_stack) / sizeof(g_catch_stack[0]))) {
        g_catch_stack[g_catch_stack_size++] = exc;
    }
    return exc->object;
}

void objc_end_catch(void)
{
    if (g_catch_stack_size == 0) {
        return;
    }
    SFException_t *exc = g_catch_stack[--g_catch_stack_size];
    if (g_catch_stack_size == 0 or g_catch_stack[g_catch_stack_size - 1U] != exc) {
        g_gnu_current_exception = (g_catch_stack_size > 0) ? g_catch_stack[g_catch_stack_size - 1U] : NULL;
    }
    if (exc->catch_depth > 0) {
        exc->catch_depth -= 1;
    }
    if (exc->catch_depth == 0) {
        _Unwind_DeleteException(&exc->unwind);
    }
}

void objc_exception_rethrow(void *exception)
{
    SFException_t *exc = sf_exception_resolve(exception);
    if (exc == NULL and g_catch_stack_size > 0) {
        exc = g_catch_stack[g_catch_stack_size - 1];
    }
    if (exc == NULL) {
        exc = g_gnu_current_exception;
    }
    if (exc != NULL) {
        _Unwind_Resume_or_Rethrow(&exc->unwind);
    }
    abort();
}
#endif

#define DW_EH_PE_PTR 0x00
#define DW_EH_PE_ULEB128 0x01
#define DW_EH_PE_UDATA2 0x02
#define DW_EH_PE_UDATA4 0x03
#define DW_EH_PE_UDATA8 0x04
#define DW_EH_PE_SLEB128 0x09
#define DW_EH_PE_SDATA2 0x0A
#define DW_EH_PE_SDATA4 0x0B
#define DW_EH_PE_SDATA8 0x0C

#define DW_EH_PE_ABSPTR 0x00
#define DW_EH_PE_PCREL 0x10
#define DW_EH_PE_OMIT 0xFF
#define DW_EH_PE_INDIRECT 0x80

static uint64_t read_uleb(const uint8_t **ptr)
{
    uint64_t result = 0;
    unsigned shift = 0;
    const uint8_t *p = *ptr;
    while (1) {
        uint8_t b = *p++;
        if (shift < 64U) {
            result |= (uint64_t)(b & 0x7FU) << shift;
        }
        if ((b & 0x80) == 0) {
            break;
        }
        shift = shift <= 56U and shift + 7U or 64U;
    }
    *ptr = p;
    return result;
}

static int64_t read_sleb(const uint8_t **ptr)
{
    uint64_t result = 0;
    unsigned shift = 0;
    uint8_t b = 0;
    const uint8_t *p = *ptr;
    while (1) {
        b = *p++;
        if (shift < 64U) {
            result |= (uint64_t)(b & 0x7FU) << shift;
        }
        if ((b & 0x80) == 0) {
            break;
        }
        shift = shift <= 56U and shift + 7U or 64U;
    }
    if ((shift < 64U) and ((b & 0x40U) != 0U)) {
        result |= UINT64_MAX << shift;
    }
    *ptr = p;
    return (int64_t)result;
}

static uintptr_t read_indirect_uintptr(uintptr_t address)
{
    uintptr_t value = 0;
    memcpy(&value, (const void *)address, sizeof(value));
    return value;
}

static uintptr_t read_encoded(const uint8_t **ptr, uint8_t encoding)
{
    if (encoding == DW_EH_PE_OMIT) {
        return 0;
    }

    const uint8_t *p = *ptr;
    const uint8_t *start = p;
    uintptr_t value = 0;

    switch (encoding & 0x0F) {
        case DW_EH_PE_PTR:
            memcpy(&value, p, sizeof(uintptr_t));
            p += sizeof(uintptr_t);
            break;
        case DW_EH_PE_ULEB128:
            value = (uintptr_t)read_uleb(&p);
            break;
        case DW_EH_PE_UDATA2: {
            uint16_t v;
            memcpy(&v, p, sizeof(v));
            value = v;
            p += sizeof(v);
            break;
        }
        case DW_EH_PE_UDATA4: {
            uint32_t v;
            memcpy(&v, p, sizeof(v));
            value = v;
            p += sizeof(v);
            break;
        }
        case DW_EH_PE_UDATA8: {
            uint64_t v;
            memcpy(&v, p, sizeof(v));
            value = (uintptr_t)v;
            p += sizeof(v);
            break;
        }
        case DW_EH_PE_SLEB128:
            value = (uintptr_t)read_sleb(&p);
            break;
        case DW_EH_PE_SDATA2: {
            int16_t v;
            memcpy(&v, p, sizeof(v));
            value = (uintptr_t)v;
            p += sizeof(v);
            break;
        }
        case DW_EH_PE_SDATA4: {
            int32_t v;
            memcpy(&v, p, sizeof(v));
            value = (uintptr_t)v;
            p += sizeof(v);
            break;
        }
        case DW_EH_PE_SDATA8: {
            int64_t v;
            memcpy(&v, p, sizeof(v));
            value = (uintptr_t)v;
            p += sizeof(v);
            break;
        }
        default:
            abort();
    }

    if ((encoding & 0x70) == DW_EH_PE_PCREL) {
        value += (uintptr_t)start;
    }

    if ((encoding & DW_EH_PE_INDIRECT) != 0) {
        value = read_indirect_uintptr(value);
    }

    *ptr = p;
    return value;
}

static size_t encoding_size(uint8_t encoding)
{
    switch (encoding & 0x0F) {
        case DW_EH_PE_UDATA2:
        case DW_EH_PE_SDATA2:
            return 2;
        case DW_EH_PE_UDATA4:
        case DW_EH_PE_SDATA4:
            return 4;
        case DW_EH_PE_UDATA8:
        case DW_EH_PE_SDATA8:
            return 8;
        case DW_EH_PE_PTR:
            return sizeof(uintptr_t);
        default:
            return sizeof(uintptr_t);
    }
}

static int class_name_matches(id object, const char *wanted)
{
    if (object == NULL or wanted == NULL)
        return 0;

    SFObjCClass_t *cls = (SFObjCClass_t *)sf_object_class(object);
    while (cls != NULL) {
        if (cls->name and strcmp(cls->name, wanted) == 0) {
            return 1;
        }
        cls = cls->superclass;
    }
    return 0;
}

static int exception_matches_type(struct _Unwind_Exception *exception_object, const char *type_name)
{
    if (exception_object == NULL or type_name == NULL) {
        return 0;
    }

    SFException_t *exc = sf_exception_resolve(exception_object);
    if (exc == NULL) {
        return 0;
    }

    if (strcmp(type_name, "@id") == 0) {
        return 1;
    }

    return class_name_matches(exc->object, type_name);
}

typedef struct SFLandingInfo {
    uintptr_t landing_pad;
    int selector;
    int has_cleanup;
    int has_handler;
} SFLandingInfo_t;

static int parse_lsda_for_ip_raw(const uint8_t *lsda, uintptr_t func_start, uintptr_t ip,
                                 struct _Unwind_Exception *exception_object, SFLandingInfo_t *out)
{
    if (lsda == NULL) {
        return 0;
    }

    if (ip > func_start) {
        ip -= 1;
    }
    uintptr_t ip_offset = ip - func_start;

    const uint8_t *p = lsda;

    uint8_t lpstart_encoding = *p++;
    uintptr_t lpstart = func_start;
    if (lpstart_encoding != DW_EH_PE_OMIT) {
        lpstart = read_encoded(&p, lpstart_encoding);
    }

    uint8_t ttype_encoding = *p++;
    const uint8_t *class_info = NULL;
    if (ttype_encoding != DW_EH_PE_OMIT) {
        uint64_t ttype_offset = read_uleb(&p);
        class_info = p + ttype_offset;
    }

    uint8_t call_site_encoding = *p++;
    uint64_t call_site_table_len = read_uleb(&p);
    const uint8_t *call_site_table = p;
    const uint8_t *action_table = call_site_table + call_site_table_len;

    while (p < action_table) {
        uintptr_t cs_start = read_encoded(&p, call_site_encoding);
        uintptr_t cs_len = read_encoded(&p, call_site_encoding);
        uintptr_t cs_lp = read_encoded(&p, call_site_encoding);
        uint64_t cs_action = read_uleb(&p);

        if (ip_offset < cs_start or ip_offset >= (cs_start + cs_len)) {
            continue;
        }

        if (cs_lp == 0) {
            return 0;
        }

        out->landing_pad = lpstart + cs_lp;
        out->selector = 0;
        out->has_cleanup = 0;
        out->has_handler = 0;

        if (cs_action == 0) {
            out->has_cleanup = 1;
            return 1;
        }

        const uint8_t *record = action_table + cs_action - 1;
        while (record != NULL) {
            const uint8_t *cursor = record;
            int64_t tti = read_sleb(&cursor);
            const uint8_t *next_field = cursor;
            int64_t next_offset = read_sleb(&cursor);

            if (tti > 0 and class_info != NULL) {
                size_t entry_size = encoding_size(ttype_encoding);
                const uint8_t *type_entry = class_info - (size_t)tti * entry_size;
                const uint8_t *type_cursor = type_entry;
                uintptr_t type_info_ptr = read_encoded(&type_cursor, ttype_encoding);
                const char *type_name = (const char *)type_info_ptr;
                if (exception_matches_type(exception_object, type_name)) {
                    out->selector = (int)tti;
                    out->has_handler = 1;
                    return 1;
                }
            } else if (tti == 0) {
                out->has_cleanup = 1;
            }

            if (next_offset == 0) {
                break;
            }
            record = next_field + next_offset;
        }

        if (out->has_cleanup) {
            return 1;
        }
        return 0;
    }

    return 0;
}

#if not defined(_WIN32)
static int parse_lsda_for_ip(struct _Unwind_Context *context, struct _Unwind_Exception *exception_object,
                             SFLandingInfo_t *out)
{
    const uint8_t *lsda = (const uint8_t *)_Unwind_GetLanguageSpecificData(context);
    uintptr_t func_start = (uintptr_t)_Unwind_GetRegionStart(context);
    uintptr_t ip = (uintptr_t)_Unwind_GetIP(context);
    return parse_lsda_for_ip_raw(lsda, func_start, ip, exception_object, out);
}
#endif

int sf_runtime_test_exception_matches_type(struct _Unwind_Exception *exception_object, const char *type_name)
{
    return exception_matches_type(exception_object, type_name);
}

uintptr_t sf_runtime_test_exception_read_encoded(const uint8_t **ptr, uint8_t encoding)
{
    return read_encoded(ptr, encoding);
}

size_t sf_runtime_test_exception_encoding_size(uint8_t encoding)
{
    return encoding_size(encoding);
}

int sf_runtime_test_exception_parse_lsda(const uint8_t *lsda, uintptr_t func_start, uintptr_t ip,
                                         struct _Unwind_Exception *exception_object,
                                         SFRuntimeTestLandingInfo_t *out)
{
    SFLandingInfo_t info;
    memset(&info, 0, sizeof(info));
    int ok = parse_lsda_for_ip_raw(lsda, func_start, ip, exception_object, &info);
    out->landing_pad = info.landing_pad;
    out->selector = info.selector;
    out->has_cleanup = info.has_cleanup;
    out->has_handler = info.has_handler;
    out->reserved = 0;
    return ok;
}

static _Unwind_Reason_Code personality_result(_Unwind_Action actions, const SFLandingInfo_t *info)
{
    if ((actions & _UA_SEARCH_PHASE) != 0) {
        return info->has_handler ? _URC_HANDLER_FOUND : _URC_CONTINUE_UNWIND;
    }
    if ((actions & _UA_CLEANUP_PHASE) == 0) {
        return _URC_CONTINUE_UNWIND;
    }
    if ((actions & _UA_HANDLER_FRAME) != 0) {
        if (not info->has_handler and not info->has_cleanup) {
            return _URC_CONTINUE_UNWIND;
        }
    } else if (not info->has_cleanup) {
        return _URC_CONTINUE_UNWIND;
    }
    return _URC_INSTALL_CONTEXT;
}

_Unwind_Reason_Code sf_runtime_test_exception_personality_result(_Unwind_Action actions, int has_cleanup,
                                                                 int has_handler)
{
    SFLandingInfo_t info;
    memset(&info, 0, sizeof(info));
    info.has_cleanup = has_cleanup != 0;
    info.has_handler = has_handler != 0;
    return personality_result(actions, &info);
}

#if not defined(_WIN32)
static _Unwind_Reason_Code sf_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                                  struct _Unwind_Exception *exception_object,
                                                  struct _Unwind_Context *context, int returns_object)
{
    (void)version;
    (void)exception_class;

    SFLandingInfo_t info;
    if (not parse_lsda_for_ip(context, exception_object, &info))
        return _URC_CONTINUE_UNWIND;

    _Unwind_Reason_Code decision = personality_result(actions, &info);
    if (decision != _URC_INSTALL_CONTEXT) {
        return decision;
    }

    SFException_t *exc = sf_exception_resolve(exception_object);
    uintptr_t exception_value = (uintptr_t)exception_object;
    if (returns_object and exc != NULL) {
        g_gnu_current_exception = exc;
        exception_value = (uintptr_t)exc->object;
    }
    _Unwind_SetGR(context, __builtin_eh_return_data_regno(0), exception_value);
    _Unwind_SetGR(context, __builtin_eh_return_data_regno(1), (uintptr_t)info.selector);
    _Unwind_SetIP(context, info.landing_pad);
    return _URC_INSTALL_CONTEXT;
}

_Unwind_Reason_Code __gnustep_objc_personality_v0(int version, _Unwind_Action actions,
                                                  uint64_t exception_class,
                                                  struct _Unwind_Exception *exception_object,
                                                  struct _Unwind_Context *context)
{
    return sf_objc_personality_v0(version, actions, exception_class, exception_object, context, 0);
}

_Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                              struct _Unwind_Exception *exception_object,
                                              struct _Unwind_Context *context)
{
    return sf_objc_personality_v0(version, actions, exception_class, exception_object, context, 1);
}
#else
static _Unwind_Reason_Code sf_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                                  struct _Unwind_Exception *exception_object,
                                                  struct _Unwind_Context *context, int returns_object)
{
    (void)version;
    (void)actions;
    (void)exception_class;
    (void)exception_object;
    (void)context;
    (void)returns_object;
    abort();
}

_Unwind_Reason_Code __gnustep_objc_personality_v0(int version, _Unwind_Action actions,
                                                  uint64_t exception_class,
                                                  struct _Unwind_Exception *exception_object,
                                                  struct _Unwind_Context *context)
{
    return sf_objc_personality_v0(version, actions, exception_class, exception_object, context, 0);
}

_Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                              struct _Unwind_Exception *exception_object,
                                              struct _Unwind_Context *context)
{
    return sf_objc_personality_v0(version, actions, exception_class, exception_object, context, 1);
}
#endif

#else

size_t sf_exception_backtrace_count(id obj)
{
    (void)obj;
    return 0;
}

const void *sf_exception_backtrace_frame(id obj, size_t index)
{
    (void)obj;
    (void)index;
    return NULL;
}

void sf_exception_clear_metadata(id obj)
{
    (void)obj;
}

void objc_exception_throw(id obj)
{
    (void)obj;
    abort();
}

id objc_begin_catch(void *exception)
{
    (void)exception;
    abort();
}

void objc_end_catch(void)
{
    abort();
}

void objc_exception_rethrow(void *exception)
{
    (void)exception;
    abort();
}

_Unwind_Reason_Code __gnustep_objc_personality_v0(int version, _Unwind_Action actions,
                                                  uint64_t exception_class,
                                                  struct _Unwind_Exception *exception_object,
                                                  struct _Unwind_Context *context)
{
    (void)version;
    (void)actions;
    (void)exception_class;
    (void)exception_object;
    (void)context;
    abort();
}

_Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                              struct _Unwind_Exception *exception_object,
                                              struct _Unwind_Context *context)
{
    (void)version;
    (void)actions;
    (void)exception_class;
    (void)exception_object;
    (void)context;
    abort();
}

#endif

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
