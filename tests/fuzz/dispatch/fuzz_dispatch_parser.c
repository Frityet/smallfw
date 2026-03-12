#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "runtime/internal.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *types = NULL;
    char codes[32];
    int unsupported = 0;
    struct sf_objc_selector sel = {"fuzzDispatch", NULL};

    if (data == NULL) {
        return 0;
    }

    types = (char *)malloc(size + 1U);
    if (types == NULL) {
        return 0;
    }
    memcpy(types, data, size);
    types[size] = '\0';
    sel.types = types;

    memset(codes, 0, sizeof(codes));
    (void)sf_runtime_test_dispatch_is_digit_char((size > 0U) ? (char)data[0] : '\0');
    (void)sf_runtime_test_dispatch_is_type_qualifier((size > 0U) ? (char)data[0] : '\0');
    (void)sf_runtime_test_dispatch_skip_type_token(types);
    (void)sf_runtime_test_dispatch_primary_type_code(types);
    (void)sf_runtime_test_dispatch_collect_explicit_arg_codes((SEL)&sel, codes, &unsupported);
    (void)sf_runtime_test_dispatch_collect_explicit_arg_codes_cached((SEL)&sel, codes, &unsupported);

    free(types);
    return 0;
}
