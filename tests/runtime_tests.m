#include <stdio.h>
#include <string.h>

#include "runtime_test_support.h"

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wused-but-marked-unused"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#endif

typedef const SFTestCase *(*SFTestSuiteFn)(size_t *count);
static const char *g_hidden_case_prefix = "__child_";

static const SFTestSuiteFn g_suites[] = {
    sf_runtime_arc_cases,
    sf_runtime_parent_cases,
    sf_runtime_dispatch_cases,
    sf_runtime_loader_cases,
    sf_runtime_exception_cases,
};

static int run_case_named(const char *case_name) {
    for (size_t suite_index = 0; suite_index < sizeof(g_suites) / sizeof(g_suites[0]); ++suite_index) {
        size_t count = 0;
        const SFTestCase *cases = g_suites[suite_index](&count);
        for (size_t case_index = 0; case_index < count; ++case_index) {
            if (strcmp(cases[case_index].name, case_name) == 0) {
                int ok = cases[case_index].fn();
                printf("CASE %s %s\n", case_name, ok ? "PASS" : "FAIL");
                fflush(stdout);
                return ok ? 0 : 1;
            }
        }
    }

    (void)fprintf(stderr, "unknown case: %s\n", case_name);
    return 3;
}

static int run_all_cases(void) {
    int failed = 0;

    for (size_t suite_index = 0; suite_index < sizeof(g_suites) / sizeof(g_suites[0]); ++suite_index) {
        size_t count = 0;
        const SFTestCase *cases = g_suites[suite_index](&count);
        for (size_t case_index = 0; case_index < count; ++case_index) {
            int ok = 0;
            if (strncmp(cases[case_index].name, g_hidden_case_prefix, strlen(g_hidden_case_prefix)) == 0) {
                continue;
            }
            ok = cases[case_index].fn();
            printf("CASE %s %s\n", cases[case_index].name, ok ? "PASS" : "FAIL");
            fflush(stdout);
            if (!ok) {
                failed = 1;
            }
        }
    }

    return failed ? 1 : 0;
}

int main(int argc, char **argv) {
    const char *case_name = NULL;
    int run_all = 0;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--case") == 0 && (i + 1) < argc) {
            case_name = argv[i + 1];
            ++i;
        } else if (strcmp(argv[i], "--all") == 0) {
            run_all = 1;
        }
    }

    if (case_name != NULL) {
        return run_case_named(case_name);
    }
    if (run_all) {
        return run_all_cases();
    }

    (void)fprintf(stderr, "missing --case <name> or --all\n");
    return 2;
}

#ifdef __clang__
#pragma clang diagnostic pop
#endif
