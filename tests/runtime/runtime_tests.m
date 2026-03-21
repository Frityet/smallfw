#include <stdio.h>
#include <string.h>

#include "runtime_test_support.h"

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wused-but-marked-unused"
#endif

static const char *g_hidden_case_prefix = "__child_";

#if defined(SF_TEST_SUITE_LABEL) && defined(SF_TEST_SUITE_PROVIDER)
#define SF_TEST_STRINGIFY_IMPL(x) #x
#define SF_TEST_STRINGIFY(x) SF_TEST_STRINGIFY_IMPL(x)

static const SFTestSuite g_suites[] = {
    {SF_TEST_STRINGIFY(SF_TEST_SUITE_LABEL), SF_TEST_SUITE_PROVIDER},
};
#else
static const SFTestSuite g_suites[] = {
#ifdef SF_TEST_ENABLE_SUITE_ARC
    {"arc", sf_runtime_arc_cases},
#endif
#ifdef SF_TEST_ENABLE_SUITE_PARENT
    {"parent", sf_runtime_parent_cases},
#endif
#ifdef SF_TEST_ENABLE_SUITE_DISPATCH
    {"dispatch", sf_runtime_dispatch_cases},
#endif
#ifdef SF_TEST_ENABLE_SUITE_LOADER
    {"loader", sf_runtime_loader_cases},
#endif
#ifdef SF_TEST_ENABLE_SUITE_TAGGED
    {"tagged", sf_runtime_tagged_cases},
#endif
#ifdef SF_TEST_ENABLE_SUITE_EXCEPTIONS
    {"exceptions", sf_runtime_exception_cases},
#endif
};
#endif

static int is_hidden_case_name(const char *case_name)
{
    size_t prefix_len = strlen(g_hidden_case_prefix);
    return strncmp(case_name, g_hidden_case_prefix, prefix_len) == 0;
}

static int case_name_matches(const char *requested_name, const char *suite_name, const char *case_name)
{
    size_t suite_name_len = strlen(suite_name);

    if (requested_name == nullptr) {
        return 0;
    }
    if (strcmp(requested_name, case_name) == 0) {
        return 1;
    }
    return strncmp(requested_name, suite_name, suite_name_len) == 0 and
           requested_name[suite_name_len] == '/' and
           strcmp(requested_name + suite_name_len + 1, case_name) == 0;
}

static const SFTestSuite *find_suite_named(const char *suite_name)
{
    if (suite_name == nullptr) {
        return nullptr;
    }

    for (size_t suite_index = 0; suite_index < sizeof(g_suites) / sizeof(g_suites[0]); ++suite_index) {
        if (strcmp(g_suites[suite_index].name, suite_name) == 0) {
            return &g_suites[suite_index];
        }
    }
    return nullptr;
}

static void print_case_result(const char *suite_name, const char *case_name, int ok)
{
    printf("GROUP %s\n", suite_name);
    printf("CASE %s/%s %s\n", suite_name, case_name, ok ? "PASS" : "FAIL");
    fflush(stdout);
}

static int run_case_from_suite(const SFTestSuite *suite, const char *requested_name)
{
    size_t count = 0;
    const SFTestCase *cases = suite->fn(&count);

    for (size_t case_index = 0; case_index < count; ++case_index) {
        if (case_name_matches(requested_name, suite->name, cases[case_index].name)) {
            int ok = cases[case_index].fn();
            print_case_result(suite->name, cases[case_index].name, ok);
            return ok ? 0 : 1;
        }
    }
    return -1;
}

static int run_case_named(const char *case_name)
{
    for (size_t suite_index = 0; suite_index < sizeof(g_suites) / sizeof(g_suites[0]); ++suite_index) {
        int status = run_case_from_suite(&g_suites[suite_index], case_name);
        if (status >= 0) {
            return status;
        }
    }

    (void)fprintf(stderr, "unknown case: %s\n", case_name);
    return 3;
}

static int run_suite_cases(const SFTestSuite *suite)
{
    size_t count = 0;
    const SFTestCase *cases = suite->fn(&count);
    int failed = 0;
    size_t visible_count = 0;

    printf("GROUP %s START\n", suite->name);
    fflush(stdout);

    for (size_t case_index = 0; case_index < count; ++case_index) {
        int ok = 0;
        if (is_hidden_case_name(cases[case_index].name)) {
            continue;
        }

        visible_count += 1U;
        ok = cases[case_index].fn();
        printf("CASE %s/%s %s\n", suite->name, cases[case_index].name, ok ? "PASS" : "FAIL");
        fflush(stdout);
        if (not ok) {
            failed = 1;
        }
    }

    if (visible_count == 0U) {
        printf("GROUP %s EMPTY\n", suite->name);
    } else {
        printf("GROUP %s %s\n", suite->name, failed ? "FAIL" : "PASS");
    }
    fflush(stdout);
    return failed ? 1 : 0;
}

static int run_suite_named(const char *suite_name)
{
    const SFTestSuite *suite = find_suite_named(suite_name);
    if (suite == nullptr) {
        (void)fprintf(stderr, "unknown suite: %s\n", suite_name);
        return 3;
    }
    return run_suite_cases(suite);
}

static int run_all_cases(void)
{
    int failed = 0;

    for (size_t suite_index = 0; suite_index < sizeof(g_suites) / sizeof(g_suites[0]); ++suite_index) {
        if (run_suite_cases(&g_suites[suite_index]) != 0) {
            failed = 1;
        }
    }
    return failed ? 1 : 0;
}

static int list_cases(void)
{
    for (size_t suite_index = 0; suite_index < sizeof(g_suites) / sizeof(g_suites[0]); ++suite_index) {
        size_t count = 0;
        const SFTestCase *cases = g_suites[suite_index].fn(&count);

        printf("GROUP %s\n", g_suites[suite_index].name);
        for (size_t case_index = 0; case_index < count; ++case_index) {
            if (is_hidden_case_name(cases[case_index].name)) {
                continue;
            }
            printf("CASE %s/%s\n", g_suites[suite_index].name, cases[case_index].name);
        }
    }
    fflush(stdout);
    return 0;
}

static void print_usage(const char *program_name)
{
    (void)fprintf(stderr,
                  "usage: %s [--all] [--suite <name>] [--case <name|suite/name>] [--list]\n",
                  program_name != nullptr ? program_name : "runtime-tests");
}

int main(int argc, char **argv)
{
    const char *case_name = nullptr;
    const char *suite_name = nullptr;
    int list_only = 0;
    int run_all = 0;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--case") == 0 and (i + 1) < argc) {
            case_name = argv[i + 1];
            ++i;
        } else if (strcmp(argv[i], "--suite") == 0 and (i + 1) < argc) {
            suite_name = argv[i + 1];
            ++i;
        } else if (strcmp(argv[i], "--all") == 0) {
            run_all = 1;
        } else if (strcmp(argv[i], "--list") == 0) {
            list_only = 1;
        }
    }

    if (list_only) {
        return list_cases();
    }
    if (case_name != nullptr) {
        return run_case_named(case_name);
    }
    if (suite_name != nullptr) {
        return run_suite_named(suite_name);
    }
    if (run_all or argc == 1) {
        return run_all_cases();
    }

    print_usage(argv != nullptr ? argv[0] : "runtime-tests");
    return 2;
}

#ifdef __clang__
#pragma clang diagnostic pop
#endif
