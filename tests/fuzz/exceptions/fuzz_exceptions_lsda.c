#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "runtime/internal.h"

#define DW_EH_PE_PTR 0x00
#define DW_EH_PE_ULEB128 0x01
#define DW_EH_PE_UDATA2 0x02
#define DW_EH_PE_UDATA4 0x03
#define DW_EH_PE_UDATA8 0x04
#define DW_EH_PE_SLEB128 0x09
#define DW_EH_PE_SDATA2 0x0A
#define DW_EH_PE_SDATA4 0x0B
#define DW_EH_PE_SDATA8 0x0C

#define DW_EH_PE_PCREL 0x10
#define DW_EH_PE_OMIT 0xFF

static uint8_t fuzz_supported_encoding(uint8_t value, int allow_omit)
{
    static const uint8_t k_supported[] = {
        DW_EH_PE_PTR,   DW_EH_PE_ULEB128, DW_EH_PE_UDATA2, DW_EH_PE_UDATA4, DW_EH_PE_UDATA8,
        DW_EH_PE_SLEB128, DW_EH_PE_SDATA2, DW_EH_PE_SDATA4, DW_EH_PE_SDATA8,
    };
    uint8_t encoding = k_supported[value % (sizeof(k_supported) / sizeof(k_supported[0]))];

    if (allow_omit and ((value >> 4U) & 1U) != 0U) {
        return DW_EH_PE_OMIT;
    }
    if ((value & DW_EH_PE_PCREL) != 0U) {
        encoding |= DW_EH_PE_PCREL;
    }
    return encoding;
}

static size_t fuzz_write_uleb(uint8_t *dst, size_t cap, uint64_t value)
{
    size_t written = 0U;

    do {
        uint8_t byte = (uint8_t)(value & 0x7FU);
        value >>= 7U;
        if (value != 0U) {
            byte |= 0x80U;
        }
        if (written < cap) {
            dst[written] = byte;
        }
        written += 1U;
    } while (value != 0U and written < 10U);

    return written <= cap ? written : cap;
}

static size_t fuzz_write_sleb(uint8_t *dst, size_t cap, int64_t value)
{
    size_t written = 0U;
    int more = 1;

    while (more != 0 and written < 10U) {
        uint8_t byte = (uint8_t)(value & 0x7FU);
        int sign_bit = (byte & 0x40U) != 0U;
        value >>= 7U;
        more = not ((value == 0 and not sign_bit) or (value == -1 and sign_bit));
        if (more != 0) {
            byte |= 0x80U;
        }
        if (written < cap) {
            dst[written] = byte;
        }
        written += 1U;
    }

    return written <= cap ? written : cap;
}

static size_t fuzz_write_encoded(uint8_t *dst, size_t cap, uint8_t encoding, uintptr_t value)
{
    switch (encoding & 0x0F) {
        case DW_EH_PE_PTR:
        case DW_EH_PE_UDATA8:
        case DW_EH_PE_SDATA8:
            if (cap >= sizeof(uint64_t)) {
                uint64_t encoded = (uint64_t)value;
                memcpy(dst, &encoded, sizeof(encoded));
                return sizeof(encoded);
            }
            break;
        case DW_EH_PE_UDATA4:
        case DW_EH_PE_SDATA4:
            if (cap >= sizeof(uint32_t)) {
                uint32_t encoded = (uint32_t)value;
                memcpy(dst, &encoded, sizeof(encoded));
                return sizeof(encoded);
            }
            break;
        case DW_EH_PE_UDATA2:
        case DW_EH_PE_SDATA2:
            if (cap >= sizeof(uint16_t)) {
                uint16_t encoded = (uint16_t)value;
                memcpy(dst, &encoded, sizeof(encoded));
                return sizeof(encoded);
            }
            break;
        case DW_EH_PE_ULEB128:
            return fuzz_write_uleb(dst, cap, (uint64_t)value);
        case DW_EH_PE_SLEB128:
            return fuzz_write_sleb(dst, cap, (int64_t)value);
        default:
            break;
    }
    return 0U;
}

static uintptr_t fuzz_word_prefix(const uint8_t *data, size_t size, uintptr_t fallback)
{
    uintptr_t value = fallback;
    size_t limit = size < sizeof(uintptr_t) ? size : sizeof(uintptr_t);

    for (size_t i = 0; i < limit; ++i) {
        value = (value << 8U) ^ (uintptr_t)data[i];
    }
    return value;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    enum { kScratchSize = 512U };
    uint8_t scratch[kScratchSize];
    const uint8_t *cursor = scratch;
    SFRuntimeTestLandingInfo_t info;
    uintptr_t func_start = fuzz_word_prefix(data, size, (uintptr_t)128U);
    uintptr_t ip = func_start + fuzz_word_prefix(data + (size > 0U ? 1U : 0U),
                                                 size > 0U ? size - 1U : 0U,
                                                 (uintptr_t)16U);
    size_t copied = size < sizeof(scratch) ? size : sizeof(scratch);
    size_t out = 0U;
    size_t call_site_len_offset = 0U;
    size_t call_site_table_start = 0U;
    uint8_t read_encoding = 0U;
    uint8_t lpstart_encoding = 0U;
    uint8_t ttype_encoding = 0U;
    uint8_t call_site_encoding = 0U;

    if (data == nullptr) {
        return 0;
    }

    memset(scratch, 0, sizeof(scratch));
    if (copied > 0U) {
        memcpy(scratch, data, copied);
    }

    memset(&info, 0, sizeof(info));
    read_encoding = fuzz_supported_encoding((size > 0U) ? scratch[0] : 0U, 0);
    (void)sf_runtime_test_exception_encoding_size(read_encoding);
    if (size > 1U) {
        cursor = scratch + 1U;
        (void)sf_runtime_test_exception_read_encoded(&cursor, read_encoding);
    }

    memset(scratch, 0, sizeof(scratch));
    lpstart_encoding = fuzz_supported_encoding((size > 0U) ? data[0] : 0U, 1);
    ttype_encoding = fuzz_supported_encoding((size > 1U) ? data[1] : 0U, 1);
    call_site_encoding = fuzz_supported_encoding((size > 2U) ? data[2] : 0U, 0);

    scratch[out++] = lpstart_encoding;
    if (lpstart_encoding != DW_EH_PE_OMIT) {
        out += fuzz_write_encoded(scratch + out, sizeof(scratch) - out, lpstart_encoding,
                                  fuzz_word_prefix(data + (size > 3U ? 3U : 0U),
                                                   size > 3U ? size - 3U : 0U,
                                                   func_start + (uintptr_t)16U));
    }
    if (out >= sizeof(scratch)) {
        return 0;
    }

    scratch[out++] = ttype_encoding;
    if (ttype_encoding != DW_EH_PE_OMIT) {
        out += fuzz_write_uleb(scratch + out, sizeof(scratch) - out, 0U);
    }
    if (out >= sizeof(scratch)) {
        return 0;
    }

    scratch[out++] = call_site_encoding;
    call_site_len_offset = out++;
    call_site_table_start = out;

    out += fuzz_write_encoded(scratch + out, sizeof(scratch) - out, call_site_encoding,
                              (size > 3U) ? (uintptr_t)(data[3] & 0x1FU) : (uintptr_t)0U);
    out += fuzz_write_encoded(scratch + out, sizeof(scratch) - out, call_site_encoding,
                              (size > 4U) ? (uintptr_t)((data[4] & 0x1FU) + 1U) : (uintptr_t)1U);
    out += fuzz_write_encoded(scratch + out, sizeof(scratch) - out, call_site_encoding,
                              (size > 5U) ? (uintptr_t)(data[5] & 0x1FU) : (uintptr_t)0U);
    out += fuzz_write_uleb(scratch + out, sizeof(scratch) - out, 0U);
    if ((size > 6U) and ((data[6] & 1U) != 0U)) {
        out += fuzz_write_encoded(scratch + out, sizeof(scratch) - out, call_site_encoding,
                                  (uintptr_t)(data[6] & 0x1FU));
        out += fuzz_write_encoded(scratch + out, sizeof(scratch) - out, call_site_encoding,
                                  (size > 7U) ? (uintptr_t)((data[7] & 0x1FU) + 1U) : (uintptr_t)1U);
        out += fuzz_write_encoded(scratch + out, sizeof(scratch) - out, call_site_encoding,
                                  (size > 8U) ? (uintptr_t)(data[8] & 0x1FU) : (uintptr_t)0U);
        out += fuzz_write_uleb(scratch + out, sizeof(scratch) - out, 0U);
    }
    if (out >= sizeof(scratch) or out - call_site_table_start >= 0x80U) {
        return 0;
    }
    scratch[call_site_len_offset] = (uint8_t)(out - call_site_table_start);

    (void)sf_runtime_test_exception_parse_lsda(scratch, func_start, ip, nullptr, &info);
    return 0;
}
