#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "runtime/internal.h"

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#endif

static uintptr_t fuzz_word_prefix(const uint8_t *data, size_t size, uintptr_t fallback) {
    uintptr_t value = fallback;
    size_t limit = size < sizeof(uintptr_t) ? size : sizeof(uintptr_t);

    for (size_t i = 0; i < limit; ++i) {
        value = (value << 8U) ^ (uintptr_t)data[i];
    }
    return value;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    const uint8_t *cursor = data;
    SFRuntimeTestLandingInfo_t info;
    uintptr_t func_start = fuzz_word_prefix(data, size, (uintptr_t)128U);
    uintptr_t ip = func_start + fuzz_word_prefix(data + (size > 0U ? 1U : 0U),
                                                 size > 0U ? size - 1U : 0U,
                                                 (uintptr_t)16U);

    if (data == NULL) {
        return 0;
    }

    memset(&info, 0, sizeof(info));
    (void)sf_runtime_test_exception_encoding_size((size > 0U) ? data[0] : 0U);
    if (size > 1U) {
        cursor = data + 1U;
        (void)sf_runtime_test_exception_read_encoded(&cursor, data[0]);
    }
    (void)sf_runtime_test_exception_parse_lsda(data, func_start, ip, NULL, &info);
    return 0;
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
