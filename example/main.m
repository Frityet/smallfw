#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern char *processRequest(char *request);

static int g_failures = 0;

static char *call_process_request(const char *request) {
    size_t len = strlen(request);
    char *mutable_request = (char *)malloc(len + 1U);
    char *response = NULL;

    if (mutable_request == NULL) {
        return NULL;
    }

    memcpy(mutable_request, request, len + 1U);
    response = processRequest(mutable_request);
    free(mutable_request);
    return response;
}

static void expect_response_equals(int part_no, const char *request, const char *expected) {
    char *response = call_process_request(request);

    printf("Part %d: Request is %s\n", part_no, request);
    if (response == NULL) {
        printf("Expected response \"%s\", got null pointer\n", expected);
        g_failures += 1;
        printf("Part %d failed\n", part_no);
    } else if (strcmp(response, expected) != 0) {
        printf("Expected response \"%s\", got \"%s\"\n", expected, response);
        g_failures += 1;
        printf("Part %d failed\n", part_no);
    } else {
        printf("Part %d passed\n", part_no);
    }

    free(response);
}

static void expect_response_contains(int part_no, const char *request, const char *must_contain) {
    char *response = call_process_request(request);

    printf("Part %d: Request is %s (contains check)\n", part_no, request);
    if (response == NULL) {
        printf("Expected response to contain \"%s\", got null pointer\n", must_contain);
        g_failures += 1;
        printf("Part %d failed\n", part_no);
    } else if (strstr(response, must_contain) == NULL) {
        printf("Expected response to contain \"%s\", got \"%s\"\n", must_contain, response);
        g_failures += 1;
        printf("Part %d failed\n", part_no);
    } else {
        printf("Part %d passed\n", part_no);
    }

    free(response);
}

int main(void) {
    expect_response_equals(1, "F", "All rules deleted");
    expect_response_equals(2, "A 147.188.192.43 22", "Rule added");
    expect_response_equals(3, "C 147.188.192.43 22", "Connection accepted");
    expect_response_equals(4, "C 147.188.192.43 23", "Connection rejected");
    expect_response_contains(5, "L", "Rule: 147.188.192.43 22");
    expect_response_contains(6, "L", "Query: 147.188.192.43 22");
    expect_response_equals(7, "D 147.188.192.43 22", "Rule deleted");
    expect_response_equals(8, "C 147.188.192.43 22", "Connection rejected");
    expect_response_equals(9, "A 001.002.003.004 00080", "Rule added");
    expect_response_equals(10, "D 1.2.3.4 80", "Rule deleted");
    expect_response_equals(11, "D 1.2.3.4 80", "Rule not found");
    expect_response_equals(12, "A bad 22", "Invalid rule");
    expect_response_equals(13, "C 1.2.3.4 nope", "Illegal IP address or port specified");
    expect_response_equals(14, "Z foo", "Illegal request");
    expect_response_contains(15, "R", "A bad 22");
    expect_response_contains(16, "R", "Z foo");
    expect_response_equals(17, "F", "All rules deleted");
    expect_response_equals(18, "L", "");

    if (g_failures == 0) {
        printf("Test passed\n");
        return 0;
    }

    printf("Test failed (%d failures)\n", g_failures);
    return 1;
}
