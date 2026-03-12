#include <stddef.h>

static int trigger_null_dereference(int *value) {
    if (value == NULL) {
        return value[0];
    }
    return value[0];
}

int main(void) {
    return trigger_null_dereference(NULL);
}
