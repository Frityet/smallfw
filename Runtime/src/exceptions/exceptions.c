#include "internal.h"

#include <stdlib.h>
#include <string.h>
#include <unwind.h>
#if defined(_WIN32) and not defined(_WIN32_WINNT)
#    define _WIN32_WINNT 0x0600
#endif
#if defined(_WIN32)
#    include <windows.h>
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-noreturn"
#pragma clang diagnostic ignored "-Wunused-macros"

#pragma clang assume_nonnull begin

#if SF_RUNTIME_EXCEPTIONS

#    define SF_EXCEPTION_CLASS UINT64_C(0x5346574f424a4300)
#    define SF_EXCEPTION_BACKTRACE_LIMIT 32

    typedef struct SFException {
        struct _Unwind_Exception unwind;
        id nillable object;
        uint32_t catch_depth;
        uint32_t reserved;
        struct SFException *nillable next_active;
    } SFException_t;

    typedef struct SFExceptionMetadata {
        struct SFExceptionMetadata *nillable next;
        id nillable object;
        size_t count;
        const void *nillable frames[SF_EXCEPTION_BACKTRACE_LIMIT];
    } SFExceptionMetadata_t;

#    if not defined(_WIN32)
        typedef struct SFBacktraceCapture {
            const void **frames;
            size_t count;
            size_t limit;
            size_t skip;
        } SFBacktraceCapture_t;
#    endif

#    if not defined(_WIN32)
        static thread_local SFException_t *nillable g_catch_stack[32];
        static thread_local size_t g_catch_stack_size;
        static thread_local SFException_t *nillable g_gnu_current_exception;
#    endif
    static SFRuntimeMutex_t g_exception_metadata_lock = SF_RUNTIME_MUTEX_INITIALIZER;
    static SFExceptionMetadata_t *nillable g_exception_metadata;
    static SFRuntimeMutex_t g_exception_active_lock = SF_RUNTIME_MUTEX_INITIALIZER;
    static SFException_t *nillable g_exception_active;

    static SFException_t *nillable sf_exception_from_unwind(struct _Unwind_Exception *nillable exception_object)
    {
        if (exception_object == nullptr or exception_object->exception_class != SF_EXCEPTION_CLASS) {
            return nullptr;
        }
        return (SFException_t *)exception_object;
    }

    static void sf_exception_register_active(SFException_t *nillable exc)
    {
        if (exc == nullptr) {
            return;
        }

        sf_runtime_mutex_lock(&g_exception_active_lock);
        exc->next_active = g_exception_active;
        g_exception_active = exc;
        sf_runtime_mutex_unlock(&g_exception_active_lock);
    }

    static void sf_exception_unregister_active(SFException_t *nillable exc)
    {
        if (exc == nullptr) {
            return;
        }

        sf_runtime_mutex_lock(&g_exception_active_lock);
        SFException_t **slot = &g_exception_active;
        while (*slot != nullptr and * slot != exc) {
            slot = &(*slot)->next_active;
        }
        if (*slot == exc) {
            *slot = exc->next_active;
            exc->next_active = nullptr;
        }
        sf_runtime_mutex_unlock(&g_exception_active_lock);
    }

    static SFException_t *nillable sf_exception_from_object(id nillable obj)
    {
        SFException_t *result = nullptr;

        if (obj == nullptr) {
            return nullptr;
        }

        sf_runtime_mutex_lock(&g_exception_active_lock);
        for (SFException_t *it = g_exception_active; it != nullptr; it = it->next_active) {
            if (it->object == obj) {
                result = it;
                break;
            }
        }
        sf_runtime_mutex_unlock(&g_exception_active_lock);
        return result;
    }

    static SFException_t *nillable sf_exception_resolve(void *nillable exception_or_object)
    {
        SFException_t *exc = nullptr;

        if (exception_or_object == nullptr) {
            return nullptr;
        }

        exc = sf_exception_from_unwind((struct _Unwind_Exception *)exception_or_object);
        if (exc != nullptr) {
            return exc;
        }
        return sf_exception_from_object((id)exception_or_object);
    }

#    if not defined(_WIN32)
        static _Unwind_Reason_Code capture_backtrace_frame(struct _Unwind_Context *context, void *arg)
        {
            auto capture = (SFBacktraceCapture_t *)arg;
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
#    endif

    static size_t capture_backtrace(const void **frames, size_t limit)
    {
#    if defined(_WIN32)
            void *captured[SF_EXCEPTION_BACKTRACE_LIMIT];
            USHORT count = 0;

            if (limit > SF_EXCEPTION_BACKTRACE_LIMIT) {
                limit = SF_EXCEPTION_BACKTRACE_LIMIT;
            }
            count = CaptureStackBackTrace(2, (ULONG)limit, captured, nullptr);
            for (USHORT i = 0; i < count; ++i) {
                frames[i] = captured[i];
            }
            return (size_t)count;
#    else
            SFBacktraceCapture_t capture = {
                .frames = frames,
                .count = 0,
                .limit = limit,
                .skip = 2,
            };
            (void)_Unwind_Backtrace(capture_backtrace_frame, &capture);
            return capture.count;
#    endif
    }

    static SFExceptionMetadata_t *nillable *nonnil find_exception_metadata_slot(id nillable obj)
    {
        SFExceptionMetadata_t **slot = &g_exception_metadata;
        while (*slot != nullptr and(*slot)->object != obj)
            slot = &(*slot)->next;
        return slot;
    }

    void sf_exception_capture_metadata(id nillable obj)
    {
        SFObjHeader_t *hdr = nullptr;

        if (obj == nullptr)
            return;

        const void *nillable frames[SF_EXCEPTION_BACKTRACE_LIMIT];
        size_t count = capture_backtrace(frames, SF_EXCEPTION_BACKTRACE_LIMIT);

        sf_runtime_mutex_lock(&g_exception_metadata_lock);
        SFExceptionMetadata_t **slot = find_exception_metadata_slot(obj);
        SFExceptionMetadata_t *meta = *slot;
        if (meta == nullptr) {
            meta = (SFExceptionMetadata_t *)sf_runtime_test_calloc(1, sizeof(*meta));
            if (meta != nullptr) {
                meta->object = obj;
                *slot = meta;
            }
        }
        if (meta != nullptr) {
            meta->count = count;
            if (count > 0)
                memcpy((void *)meta->frames, (const void *)frames, count * sizeof(frames[0]));
        }
        sf_runtime_mutex_unlock(&g_exception_metadata_lock);

        hdr = sf_header_from_object(obj);
        if (hdr != nullptr) {
            sf_header_or_aux_flags(hdr, SF_OBJ_AUX_FLAG_HAS_EXCEPTION_METADATA);
        }
    }

    size_t sf_exception_backtrace_count(id nillable obj)
    {
        size_t count = 0;
        if (obj == nullptr)
            return 0;

        sf_runtime_mutex_lock(&g_exception_metadata_lock);
        SFExceptionMetadata_t *meta = *find_exception_metadata_slot(obj);
        if (meta != nullptr)
            count = meta->count;
        sf_runtime_mutex_unlock(&g_exception_metadata_lock);
        return count;
    }

    const void *nillable sf_exception_backtrace_frame(id nillable obj, size_t index)
    {
        const void *frame = nullptr;
        if (obj == nullptr)
            return nullptr;

        sf_runtime_mutex_lock(&g_exception_metadata_lock);
        SFExceptionMetadata_t *meta = *find_exception_metadata_slot(obj);
        if (meta != nullptr and index < meta->count)
            frame = meta->frames[index];
        sf_runtime_mutex_unlock(&g_exception_metadata_lock);
        return frame;
    }

    void sf_exception_clear_metadata(id nillable obj)
    {
        SFExceptionMetadata_t *meta = nullptr;
        SFObjHeader_t *hdr = nullptr;
        if (obj == nullptr)
            return;

        hdr = sf_header_from_object(obj);
        if (hdr != nullptr) {
            sf_header_clear_aux_flags(hdr, SF_OBJ_AUX_FLAG_HAS_EXCEPTION_METADATA);
        }

        sf_runtime_mutex_lock(&g_exception_metadata_lock);
        SFExceptionMetadata_t **slot = find_exception_metadata_slot(obj);
        meta = *slot;
        if (meta != nullptr)
            *slot = meta->next;
        sf_runtime_mutex_unlock(&g_exception_metadata_lock);
        free(meta);
    }

#    if not defined(_WIN32)
        static void sf_exception_cleanup(_Unwind_Reason_Code code, struct _Unwind_Exception *exception_object)
        {
            (void)code;
            auto exc = (SFException_t *)exception_object;
            sf_exception_unregister_active(exc);
            if (g_gnu_current_exception == exc) {
                g_gnu_current_exception = nullptr;
            }
            if (exc->object != nullptr) {
                objc_release(exc->object);
            }
            free(exc);
        }

        void objc_exception_throw(id nillable obj)
        {
            SFException_t *rethrow_exc = nullptr;
            if (g_gnu_current_exception != nullptr and obj != nullptr) {
                SFException_t *active_exc = sf_exception_from_object(obj);
                if (active_exc == g_gnu_current_exception and g_gnu_current_exception->object == obj and g_gnu_current_exception->catch_depth > 0U) {
                    rethrow_exc = g_gnu_current_exception;
                }
            }
            if (rethrow_exc != nullptr) {
                rethrow_exc->reserved = 1U;
                _Unwind_Resume_or_Rethrow(&rethrow_exc->unwind);
                abort();
            }

            auto exc = (SFException_t *)sf_runtime_test_calloc(1, sizeof(SFException_t));
            if (exc == nullptr) {
                abort();
            }
            exc->object = objc_retain(obj);
            sf_exception_capture_metadata(exc->object);
            exc->unwind.exception_class = SF_EXCEPTION_CLASS;
            exc->unwind.exception_cleanup = sf_exception_cleanup;
            sf_exception_register_active(exc);

            _Unwind_Reason_Code rc = _Unwind_RaiseException(&exc->unwind);
            sf_exception_cleanup(rc, &exc->unwind);
            abort();
        }

        id nillable objc_begin_catch(void *nillable exception)
        {
            SFException_t *exc = sf_exception_resolve(exception);
            if (exc == nullptr) {
                return (id)exception;
            }
            exc->catch_depth += 1;
            exc->reserved = 0U;
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
                g_gnu_current_exception = (g_catch_stack_size > 0) ? g_catch_stack[g_catch_stack_size - 1U] : nullptr;
            }
            if (exc->catch_depth > 0) {
                exc->catch_depth -= 1;
            }
            if (exc->catch_depth == 0) {
                if (exc->reserved != 0U) {
                    exc->reserved = 0U;
                    return;
                }
                _Unwind_DeleteException(&exc->unwind);
            }
        }

        void objc_exception_rethrow(void *nillable exception)
        {
            SFException_t *exc = sf_exception_resolve(exception);
            if (exc == nullptr and g_catch_stack_size > 0) {
                exc = g_catch_stack[g_catch_stack_size - 1];
            }
            if (exc == nullptr) {
                exc = g_gnu_current_exception;
            }
            if (exc != nullptr) {
                exc->reserved = 1U;
                _Unwind_Resume_or_Rethrow(&exc->unwind);
            }
            abort();
        }
#    endif

#    define DW_EH_PE_PTR 0x00
#    define DW_EH_PE_ULEB128 0x01
#    define DW_EH_PE_UDATA2 0x02
#    define DW_EH_PE_UDATA4 0x03
#    define DW_EH_PE_UDATA8 0x04
#    define DW_EH_PE_SLEB128 0x09
#    define DW_EH_PE_SDATA2 0x0A
#    define DW_EH_PE_SDATA4 0x0B
#    define DW_EH_PE_SDATA8 0x0C

#    define DW_EH_PE_ABSPTR 0x00
#    define DW_EH_PE_PCREL 0x10
#    define DW_EH_PE_OMIT 0xFF
#    define DW_EH_PE_INDIRECT 0x80

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
            shift = (shift <= 56U) ? (shift + 7U) : 64U;
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
            shift = (shift <= 56U) ? (shift + 7U) : 64U;
            if ((b & 0x80) == 0) {
                break;
            }
        }
        if ((shift < 64U) and((b & 0x40U) != 0U)) {
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

    static bool class_name_matches(id nillable object, const char *nillable wanted)
    {
        if (object == nullptr or wanted == nullptr) {
            return false;
        }

        auto cls = (SFObjCClass_t *)sf_object_class(object);
        while (cls != nullptr) {
            if (cls->name and strcmp(cls->name, wanted) == 0) {
                return true;
            }
            cls = cls->superclass;
        }
        return false;
    }

    static bool exception_matches_type(struct _Unwind_Exception *nillable exception_object, const char *nillable type_name)
    {
        if (exception_object == nullptr or type_name == nullptr) {
            return false;
        }

        SFException_t *exc = sf_exception_resolve(exception_object);
        if (exc == nullptr) {
            return false;
        }

        if (strcmp(type_name, "@id") == 0) {
            return true;
        }

        return class_name_matches(exc->object, type_name);
    }

    typedef struct SFLandingInfo {
        uintptr_t landing_pad;
        int selector;
        bool has_cleanup;
        bool has_handler;
    } SFLandingInfo_t;

    static bool parse_lsda_for_ip_raw(const uint8_t *nillable lsda, uintptr_t func_start, uintptr_t ip,
                                     struct _Unwind_Exception *nillable exception_object, SFLandingInfo_t *nonnil out)
    {
        if (lsda == nullptr) {
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
        const uint8_t *class_info = nullptr;
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
            out->has_cleanup = false;
            out->has_handler = false;

            if (cs_action == 0) {
                out->has_cleanup = true;
                return 1;
            }

            const uint8_t *record = action_table + cs_action - 1;
            while (record != nullptr) {
                const uint8_t *cursor = record;
                int64_t tti = read_sleb(&cursor);
                const uint8_t *next_field = cursor;
                int64_t next_offset = read_sleb(&cursor);

                if (tti > 0 and class_info != nullptr) {
                    size_t entry_size = encoding_size(ttype_encoding);
                    const uint8_t *type_entry = class_info - (size_t)tti * entry_size;
                    const uint8_t *type_cursor = type_entry;
                    uintptr_t type_info_ptr = read_encoded(&type_cursor, ttype_encoding);
                    auto type_name = (const char *)type_info_ptr;
                    if (exception_matches_type(exception_object, type_name)) {
                        out->selector = (int)tti;
                        out->has_handler = true;
                        return 1;
                    }
                } else if (tti == 0) {
                    out->has_cleanup = true;
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

#    if not defined(_WIN32)
        static bool parse_lsda_for_ip(struct _Unwind_Context *nonnil context, struct _Unwind_Exception *nillable exception_object,
                                     SFLandingInfo_t *nonnil out)
        {
            auto lsda = (const uint8_t *)_Unwind_GetLanguageSpecificData(context);
            uintptr_t func_start = (uintptr_t)_Unwind_GetRegionStart(context);
            uintptr_t ip = (uintptr_t)_Unwind_GetIP(context);
            return parse_lsda_for_ip_raw(lsda, func_start, ip, exception_object, out);
        }
#    endif

    bool sf_runtime_test_exception_matches_type(struct _Unwind_Exception *nillable exception_object, const char *nillable type_name)
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

    bool sf_runtime_test_exception_parse_lsda(const uint8_t *nillable lsda, uintptr_t func_start, uintptr_t ip,
                                             struct _Unwind_Exception *nillable exception_object,
                                             SFRuntimeTestLandingInfo_t *nonnil out)
    {
        SFLandingInfo_t info;
        memset(&info, 0, sizeof(info));
        bool ok = parse_lsda_for_ip_raw(lsda, func_start, ip, exception_object, &info);
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

    _Unwind_Reason_Code sf_runtime_test_exception_personality_result(_Unwind_Action actions, bool has_cleanup,
                                                                     bool has_handler)
    {
        SFLandingInfo_t info;
        memset(&info, 0, sizeof(info));
        info.has_cleanup = has_cleanup;
        info.has_handler = has_handler;
        return personality_result(actions, &info);
    }

#    if not defined(_WIN32)
        static _Unwind_Reason_Code sf_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                                          struct _Unwind_Exception *nillable exception_object,
                                                          struct _Unwind_Context *nillable context, int returns_object)
        {
            (void)version;
            (void)exception_class;
            if (exception_object == nullptr or context == nullptr) {
                abort();
            }

            SFLandingInfo_t info;
            if (not parse_lsda_for_ip((struct _Unwind_Context *nonnil)context, exception_object, &info))
                return _URC_CONTINUE_UNWIND;

            _Unwind_Reason_Code decision = personality_result(actions, &info);
            if (decision != _URC_INSTALL_CONTEXT) {
                return decision;
            }

            SFException_t *exc = sf_exception_resolve(exception_object);
            uintptr_t exception_value = (uintptr_t)exception_object;
            if (returns_object and exc != nullptr) {
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
                                                          struct _Unwind_Exception *nillable exception_object,
                                                          struct _Unwind_Context *nillable context)
        {
            return sf_objc_personality_v0(version, actions, exception_class, exception_object, context, 0);
        }

        _Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                                      struct _Unwind_Exception *nillable exception_object,
                                                      struct _Unwind_Context *nillable context)
        {
            return sf_objc_personality_v0(version, actions, exception_class, exception_object, context, 1);
        }
#    else
        static _Unwind_Reason_Code sf_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                                          struct _Unwind_Exception *nillable exception_object,
                                                          struct _Unwind_Context *nillable context, int returns_object)
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
                                                          struct _Unwind_Exception *nillable exception_object,
                                                          struct _Unwind_Context *nillable context)
        {
            return sf_objc_personality_v0(version, actions, exception_class, exception_object, context, 0);
        }

        _Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                                      struct _Unwind_Exception *nillable exception_object,
                                                      struct _Unwind_Context *nillable context)
        {
            return sf_objc_personality_v0(version, actions, exception_class, exception_object, context, 1);
        }
#    endif

#else

    size_t sf_exception_backtrace_count(id nillable obj)
    {
        (void)obj;
        return 0;
    }

    const void *nillable sf_exception_backtrace_frame(id nillable obj, size_t index)
    {
        (void)obj;
        (void)index;
        return nullptr;
    }

    void sf_exception_clear_metadata(id nillable obj)
    {
        (void)obj;
    }

    void objc_exception_throw(id nillable obj)
    {
        (void)obj;
        abort();
    }

    id nillable objc_begin_catch(void *nillable exception)
    {
        (void)exception;
        abort();
    }

    void objc_end_catch(void)
    {
        abort();
    }

    void objc_exception_rethrow(void *nillable exception)
    {
        (void)exception;
        abort();
    }

    _Unwind_Reason_Code __gnustep_objc_personality_v0(int version, _Unwind_Action actions,
                                                      uint64_t exception_class,
                                                      struct _Unwind_Exception *nillable exception_object,
                                                      struct _Unwind_Context *nillable context)
    {
        (void)version;
        (void)actions;
        (void)exception_class;
        (void)exception_object;
        (void)context;
        abort();
    }

    _Unwind_Reason_Code __gnu_objc_personality_v0(int version, _Unwind_Action actions, uint64_t exception_class,
                                                  struct _Unwind_Exception *nillable exception_object,
                                                  struct _Unwind_Context *nillable context)
    {
        (void)version;
        (void)actions;
        (void)exception_class;
        (void)exception_object;
        (void)context;
        abort();
    }

#endif

#pragma clang diagnostic pop
#pragma clang assume_nonnull end
