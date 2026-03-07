#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import <smallfw/Object.h>

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpre-c23-compat"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#pragma clang diagnostic ignored "-Wimplicit-void-ptr-cast"
#pragma clang diagnostic ignored "-Wobjc-interface-ivars"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#pragma clang diagnostic ignored "-Wdirect-ivar-access"
#pragma clang diagnostic ignored "-Wpadded"
#endif

#ifndef nil
#define nil ((id)0)
#endif

char *processRequest(char *request /* NOLINT(readability-non-const-parameter) */);

typedef struct {
    uint32_t start_ip;
    uint32_t end_ip;
    uint16_t start_port;
    uint16_t end_port;
} SFWRuleSpec_t;

typedef struct {
    uint32_t ip;
    uint16_t port;
} SFWQueryEntry_t;

static char *sfw_strdup(const char *value) {
    size_t length = 0U;
    char *out = NULL;

    if (value == NULL) {
        out = (char *)malloc(1U);
        if (out != NULL) {
            out[0] = '\0';
        }
        return out;
    }

    length = strlen(value);
    out = (char *)malloc(length + 1U);
    if (out == NULL) {
        return NULL;
    }

    memcpy(out, value, length);
    out[length] = '\0';
    return out;
}

static char *sfw_response(const char *message) {
    char *result = sfw_strdup(message);
    if (result == NULL) {
        result = sfw_strdup("Internal error");
    }
    return result;
}

static bool sfw_is_digit(char c) {
    return c >= '0' && c <= '9';
}

static bool sfw_parse_uint_token(const char *text, size_t length, unsigned int max_value, unsigned int *out_value) {
    unsigned int value = 0U;

    if (text == NULL || out_value == NULL || length == 0U) {
        return false;
    }

    for (size_t i = 0U; i < length; ++i) {
        unsigned int digit = 0U;

        if (!sfw_is_digit(text[i])) {
            return false;
        }

        digit = (unsigned int)(text[i] - '0');
        if (value > (max_value / 10U)) {
            return false;
        }

        value = (value * 10U) + digit;
        if (value > max_value) {
            return false;
        }
    }

    *out_value = value;
    return true;
}

static bool sfw_parse_ipv4_token(const char *text, size_t length, uint32_t *out_ip) {
    size_t offset = 0U;
    uint32_t ip = 0U;

    if (text == NULL || out_ip == NULL || length == 0U) {
        return false;
    }

    for (size_t octet_index = 0U; octet_index < 4U; ++octet_index) {
        size_t start = offset;
        unsigned int octet = 0U;

        while (offset < length && sfw_is_digit(text[offset])) {
            offset += 1U;
        }

        if (offset == start) {
            return false;
        }
        if (!sfw_parse_uint_token(text + start, offset - start, 255U, &octet)) {
            return false;
        }

        ip = (ip << 8U) | (uint32_t)octet;

        if (octet_index < 3U) {
            if (offset >= length || text[offset] != '.') {
                return false;
            }
            offset += 1U;
        }
    }

    if (offset != length) {
        return false;
    }

    *out_ip = ip;
    return true;
}

static bool sfw_parse_port_token(const char *text, size_t length, uint16_t *out_port) {
    unsigned int parsed = 0U;

    if (!sfw_parse_uint_token(text, length, 65535U, &parsed)) {
        return false;
    }

    *out_port = (uint16_t)parsed;
    return true;
}

static bool sfw_parse_ip_part(const char *text, size_t length, uint32_t *out_start, uint32_t *out_end) {
    const char *dash = NULL;

    if (text == NULL || out_start == NULL || out_end == NULL || length == 0U) {
        return false;
    }

    dash = memchr(text, '-', length);
    if (dash == NULL) {
        if (!sfw_parse_ipv4_token(text, length, out_start)) {
            return false;
        }
        *out_end = *out_start;
        return true;
    }

    size_t left_len = (size_t)(dash - text);
    size_t right_len = length - left_len - 1U;

    if (left_len == 0U || right_len == 0U) {
        return false;
    }
    if (memchr(dash + 1, '-', right_len) != NULL) {
        return false;
    }
    if (!sfw_parse_ipv4_token(text, left_len, out_start)) {
        return false;
    }
    if (!sfw_parse_ipv4_token(dash + 1, right_len, out_end)) {
        return false;
    }

    return *out_start < *out_end;
}

static bool sfw_parse_port_part(const char *text, size_t length, uint16_t *out_start, uint16_t *out_end) {
    const char *dash = NULL;

    if (text == NULL || out_start == NULL || out_end == NULL || length == 0U) {
        return false;
    }

    dash = memchr(text, '-', length);
    if (dash == NULL) {
        if (!sfw_parse_port_token(text, length, out_start)) {
            return false;
        }
        *out_end = *out_start;
        return true;
    }

    size_t left_len = (size_t)(dash - text);
    size_t right_len = length - left_len - 1U;

    if (left_len == 0U || right_len == 0U) {
        return false;
    }
    if (memchr(dash + 1, '-', right_len) != NULL) {
        return false;
    }
    if (!sfw_parse_port_token(text, left_len, out_start)) {
        return false;
    }
    if (!sfw_parse_port_token(dash + 1, right_len, out_end)) {
        return false;
    }

    return *out_start < *out_end;
}

static bool sfw_split_single_space(const char *text,
                                   const char **out_left,
                                   size_t *out_left_length,
                                   const char **out_right,
                                   size_t *out_right_length) {
    size_t length = 0U;
    size_t separator = SIZE_MAX;

    if (text == NULL || out_left == NULL || out_left_length == NULL || out_right == NULL || out_right_length == NULL) {
        return false;
    }

    length = strlen(text);
    if (length < 3U) {
        return false;
    }

    for (size_t i = 0U; i < length; ++i) {
        char c = text[i];

        if (c == ' ') {
            if (separator != SIZE_MAX) {
                return false;
            }
            separator = i;
            continue;
        }

        if (c == '\t' || c == '\n' || c == '\r') {
            return false;
        }
    }

    if (separator == SIZE_MAX || separator == 0U || separator + 1U >= length) {
        return false;
    }

    *out_left = text;
    *out_left_length = separator;
    *out_right = text + separator + 1U;
    *out_right_length = length - separator - 1U;
    return true;
}

static bool sfw_parse_rule_spec(const char *rule_text, SFWRuleSpec_t *out_spec) {
    const char *ip_part = NULL;
    const char *port_part = NULL;
    size_t ip_part_length = 0U;
    size_t port_part_length = 0U;

    if (out_spec == NULL) {
        return false;
    }

    memset(out_spec, 0, sizeof(*out_spec));
    if (!sfw_split_single_space(rule_text, &ip_part, &ip_part_length, &port_part, &port_part_length)) {
        return false;
    }
    if (!sfw_parse_ip_part(ip_part, ip_part_length, &out_spec->start_ip, &out_spec->end_ip)) {
        return false;
    }
    if (!sfw_parse_port_part(port_part, port_part_length, &out_spec->start_port, &out_spec->end_port)) {
        return false;
    }

    return true;
}

static bool sfw_parse_endpoint(const char *endpoint_text, uint32_t *out_ip, uint16_t *out_port) {
    const char *ip_part = NULL;
    const char *port_part = NULL;
    size_t ip_part_length = 0U;
    size_t port_part_length = 0U;

    if (out_ip == NULL || out_port == NULL) {
        return false;
    }

    if (!sfw_split_single_space(endpoint_text, &ip_part, &ip_part_length, &port_part, &port_part_length)) {
        return false;
    }
    if (!sfw_parse_ipv4_token(ip_part, ip_part_length, out_ip)) {
        return false;
    }
    if (!sfw_parse_port_token(port_part, port_part_length, out_port)) {
        return false;
    }

    return true;
}

static void sfw_format_ipv4(uint32_t ip, char out[16]) {
    unsigned int a = (ip >> 24U) & 0xFFU;
    unsigned int b = (ip >> 16U) & 0xFFU;
    unsigned int c = (ip >> 8U) & 0xFFU;
    unsigned int d = ip & 0xFFU;

    (void)snprintf(out, 16U, "%u.%u.%u.%u", a, b, c, d);
}

@interface SFWRequestParser : Object
+ (bool)parseRuleSpecFromText:(const char *)text outSpec:(SFWRuleSpec_t *)out_spec;
+ (bool)parseEndpointFromText:(const char *)text outIP:(uint32_t *)out_ip outPort:(uint16_t *)out_port;
+ (bool)parseRequestHeader:(const char *)request command:(char *)out_command payload:(const char *_Nullable *_Nullable)out_payload;
@end

@implementation SFWRequestParser

+ (bool)parseRuleSpecFromText:(const char *)text outSpec:(SFWRuleSpec_t *)out_spec {
    return sfw_parse_rule_spec(text, out_spec);
}

+ (bool)parseEndpointFromText:(const char *)text outIP:(uint32_t *)out_ip outPort:(uint16_t *)out_port {
    return sfw_parse_endpoint(text, out_ip, out_port);
}

+ (bool)parseRequestHeader:(const char *)request command:(char *)out_command payload:(const char **_Nullable)out_payload {
    if (request == NULL || out_command == NULL || out_payload == NULL) {
        return false;
    }

    *out_command = request[0];
    if (*out_command == '\0') {
        return false;
    }

    if (request[1] == '\0') {
        *out_payload = NULL;
        return true;
    }

    if (request[1] != ' ') {
        return false;
    }

    *out_payload = &request[2];
    return true;
}

@end

@interface SFWResponseBuilder : Object {
@private
    char *_data;
    size_t _length;
    size_t _capacity;
}

- (bool)appendBytes:(const char *)bytes length:(size_t)length;
- (bool)appendCString:(const char *)text;
- (bool)appendChar:(char)c;
- (char *)takeCString;

@end

@implementation SFWResponseBuilder

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _data = NULL;
    _length = 0U;
    _capacity = 0U;
    return self;
}

- (void)dealloc {
    free(_data);
    [super dealloc];
}

- (bool)reserveCapacity:(size_t)needed {
    char *next = NULL;
    size_t target = 0U;

    if (_capacity >= needed) {
        return true;
    }

    target = _capacity == 0U ? 128U : _capacity;
    while (target < needed) {
        if (target > (SIZE_MAX / 2U)) {
            target = needed;
            break;
        }
        target *= 2U;
    }

    next = (char *)realloc(_data, target);
    if (next == NULL) {
        return false;
    }

    _data = next;
    _capacity = target;
    return true;
}

- (bool)appendBytes:(const char *)bytes length:(size_t)length {
    if (length == 0U) {
        return true;
    }

    if (bytes == NULL) {
        return false;
    }

    if (![self reserveCapacity:_length + length + 1U]) {
        return false;
    }

    memcpy(_data + _length, bytes, length);
    _length += length;
    _data[_length] = '\0';
    return true;
}

- (bool)appendCString:(const char *)text {
    if (text == NULL) {
        return [self appendBytes:"" length:0U];
    }
    return [self appendBytes:text length:strlen(text)];
}

- (bool)appendChar:(char)c {
    return [self appendBytes:&c length:1U];
}

- (char *)takeCString {
    char *out = NULL;

    if (_data == NULL) {
        out = (char *)malloc(1U);
        if (out != NULL) {
            out[0] = '\0';
        }
        return out;
    }

    out = _data;
    _data = NULL;
    _length = 0U;
    _capacity = 0U;
    return out;
}

@end

@interface SFWRule : Object {
@private
    SFWRuleSpec_t _spec;
    char *_rule_text;
    SFWQueryEntry_t *_queries;
    size_t _query_count;
    size_t _query_capacity;
}

- (instancetype)initWithRuleSpec:(const SFWRuleSpec_t *)spec sourceText:(const char *)source_text;
- (bool)matchesIP:(uint32_t)ip port:(uint16_t)port;
- (bool)isSemanticallyEqualTo:(const SFWRuleSpec_t *)spec;
- (bool)appendQueryIP:(uint32_t)ip port:(uint16_t)port;
- (const char *)ruleText;
- (size_t)queryCount;
- (SFWQueryEntry_t)queryAtIndex:(size_t)index;

@end

@implementation SFWRule

- (instancetype)initWithRuleSpec:(const SFWRuleSpec_t *)spec sourceText:(const char *)source_text {
    if (spec == NULL || source_text == NULL) {
        return nil;
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _spec = *spec;
    _rule_text = sfw_strdup(source_text);
    if (_rule_text == NULL) {
        [self release];
        return nil;
    }

    _queries = NULL;
    _query_count = 0U;
    _query_capacity = 0U;
    return self;
}

- (void)dealloc {
    free(_rule_text);
    free(_queries);
    [super dealloc];
}

- (bool)matchesIP:(uint32_t)ip port:(uint16_t)port {
    return ip >= _spec.start_ip && ip <= _spec.end_ip && port >= _spec.start_port && port <= _spec.end_port;
}

- (bool)isSemanticallyEqualTo:(const SFWRuleSpec_t *)spec {
    if (spec == NULL) {
        return false;
    }

    return _spec.start_ip == spec->start_ip &&
           _spec.end_ip == spec->end_ip &&
           _spec.start_port == spec->start_port &&
           _spec.end_port == spec->end_port;
}

- (bool)appendQueryIP:(uint32_t)ip port:(uint16_t)port {
    if (_query_count == _query_capacity) {
        size_t next_capacity = _query_capacity == 0U ? 4U : (_query_capacity * 2U);
        SFWQueryEntry_t *next = (SFWQueryEntry_t *)realloc(_queries, next_capacity * sizeof(SFWQueryEntry_t));
        if (next == NULL) {
            return false;
        }

        _queries = next;
        _query_capacity = next_capacity;
    }

    _queries[_query_count].ip = ip;
    _queries[_query_count].port = port;
    _query_count += 1U;
    return true;
}

- (const char *)ruleText {
    return _rule_text != NULL ? _rule_text : "";
}

- (size_t)queryCount {
    return _query_count;
}

- (SFWQueryEntry_t)queryAtIndex:(size_t)index {
    if (index >= _query_count) {
        return (SFWQueryEntry_t){0U, 0U};
    }
    return _queries[index];
}

@end

@interface SFWServer : Object {
@private
    pthread_rwlock_t _rules_lock;
    pthread_mutex_t _requests_lock;

    SFWRule **_rules;
    size_t _rule_count;
    size_t _rule_capacity;

    char **_requests;
    size_t _request_count;
    size_t _request_capacity;
}

+ (instancetype)sharedServer;
- (char *)processCString:(const char *)request;

@end

@interface SFWServer ()
- (bool)reserveRulesLocked:(size_t)minimum_capacity;
- (bool)reserveRequestsLocked:(size_t)minimum_capacity;
- (void)recordRequest:(const char *)request;
- (bool)addRuleSpec:(const SFWRuleSpec_t *)spec sourceText:(const char *)source_text;
- (bool)checkConnectionIP:(uint32_t)ip port:(uint16_t)port;
- (bool)deleteRuleSpec:(const SFWRuleSpec_t *)spec;
- (char *)listRequests;
- (char *)listRules;
- (void)resetAll;

- (char *)handleCommand:(char)command payload:(const char *)payload;
- (char *)handleListRequestsPayload:(const char *)payload;
- (char *)handleListRulesPayload:(const char *)payload;
- (char *)handleFlushPayload:(const char *)payload;
- (char *)handleAddPayload:(const char *)payload;
- (char *)handleDeletePayload:(const char *)payload;
- (char *)handleCheckPayload:(const char *)payload;
@end

@implementation SFWServer

static pthread_once_t g_server_once = PTHREAD_ONCE_INIT;
static SFWServer *g_server_singleton = nil;

static void sfw_create_server_singleton(void) {
    g_server_singleton = [[SFWServer allocWithAllocator:sf_default_allocator()] init];
}

+ (instancetype)sharedServer {
    (void)pthread_once(&g_server_once, sfw_create_server_singleton);
    return g_server_singleton;
}

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    (void)pthread_rwlock_init(&_rules_lock, NULL);
    (void)pthread_mutex_init(&_requests_lock, NULL);

    _rules = NULL;
    _rule_count = 0U;
    _rule_capacity = 0U;

    _requests = NULL;
    _request_count = 0U;
    _request_capacity = 0U;

    return self;
}

- (void)dealloc {
    [self resetAll];
    (void)pthread_rwlock_destroy(&_rules_lock);
    (void)pthread_mutex_destroy(&_requests_lock);
    [super dealloc];
}

- (bool)reserveRulesLocked:(size_t)minimum_capacity {
    SFWRule **next = NULL;
    size_t target_capacity = 0U;

    if (_rule_capacity >= minimum_capacity) {
        return true;
    }

    target_capacity = _rule_capacity == 0U ? 8U : _rule_capacity;
    while (target_capacity < minimum_capacity) {
        if (target_capacity > (SIZE_MAX / 2U)) {
            target_capacity = minimum_capacity;
            break;
        }
        target_capacity *= 2U;
    }

    next = (SFWRule **)realloc(_rules, target_capacity * sizeof(SFWRule *));
    if (next == NULL) {
        return false;
    }

    _rules = next;
    _rule_capacity = target_capacity;
    return true;
}

- (bool)reserveRequestsLocked:(size_t)minimum_capacity {
    char **next = NULL;
    size_t target_capacity = 0U;

    if (_request_capacity >= minimum_capacity) {
        return true;
    }

    target_capacity = _request_capacity == 0U ? 16U : _request_capacity;
    while (target_capacity < minimum_capacity) {
        if (target_capacity > (SIZE_MAX / 2U)) {
            target_capacity = minimum_capacity;
            break;
        }
        target_capacity *= 2U;
    }

    next = (char **)realloc((void *)_requests, target_capacity * sizeof(char *));
    if (next == NULL) {
        return false;
    }

    _requests = next;
    _request_capacity = target_capacity;
    return true;
}

- (void)recordRequest:(const char *)request {
    char *copied_request = NULL;

    if (request == NULL) {
        return;
    }

    copied_request = sfw_strdup(request);
    if (copied_request == NULL) {
        return;
    }

    (void)pthread_mutex_lock(&_requests_lock);
    if (![self reserveRequestsLocked:_request_count + 1U]) {
        (void)pthread_mutex_unlock(&_requests_lock);
        free(copied_request);
        return;
    }

    _requests[_request_count] = copied_request;
    _request_count += 1U;
    (void)pthread_mutex_unlock(&_requests_lock);
}

- (bool)addRuleSpec:(const SFWRuleSpec_t *)spec sourceText:(const char *)source_text {
    SFWRule *rule = nil;

    rule = [[SFWRule allocWithAllocator:sf_default_allocator()] initWithRuleSpec:spec sourceText:source_text];
    if (rule == nil) {
        return false;
    }

    (void)pthread_rwlock_wrlock(&_rules_lock);
    if (![self reserveRulesLocked:_rule_count + 1U]) {
        (void)pthread_rwlock_unlock(&_rules_lock);
        [rule release];
        return false;
    }

    _rules[_rule_count] = rule;
    _rule_count += 1U;
    (void)pthread_rwlock_unlock(&_rules_lock);

    return true;
}

- (bool)checkConnectionIP:(uint32_t)ip port:(uint16_t)port {
    bool matched = false;

    (void)pthread_rwlock_rdlock(&_rules_lock);
    for (size_t i = 0U; i < _rule_count; ++i) {
        SFWRule *rule = _rules[i];
        if ([rule matchesIP:ip port:port]) {
            matched = true;
            break;
        }
    }
    (void)pthread_rwlock_unlock(&_rules_lock);

    if (!matched) {
        return false;
    }

    (void)pthread_rwlock_wrlock(&_rules_lock);
    for (size_t i = 0U; i < _rule_count; ++i) {
        SFWRule *rule = _rules[i];
        if ([rule matchesIP:ip port:port]) {
            (void)[rule appendQueryIP:ip port:port];
            (void)pthread_rwlock_unlock(&_rules_lock);
            return true;
        }
    }
    (void)pthread_rwlock_unlock(&_rules_lock);

    return false;
}

- (bool)deleteRuleSpec:(const SFWRuleSpec_t *)spec {
    (void)pthread_rwlock_wrlock(&_rules_lock);

    for (size_t i = 0U; i < _rule_count; ++i) {
        SFWRule *rule = _rules[i];

        if (![rule isSemanticallyEqualTo:spec]) {
            continue;
        }

        [rule release];
        if (i + 1U < _rule_count) {
            memmove(&_rules[i], &_rules[i + 1U], (_rule_count - i - 1U) * sizeof(SFWRule *));
        }
        _rule_count -= 1U;
        (void)pthread_rwlock_unlock(&_rules_lock);
        return true;
    }

    (void)pthread_rwlock_unlock(&_rules_lock);
    return false;
}

- (char *)listRequests {
    SFWResponseBuilder *builder = [[SFWResponseBuilder allocWithAllocator:sf_default_allocator()] init];
    char *out = NULL;

    if (builder == nil) {
        return sfw_response("Internal error");
    }

    (void)pthread_mutex_lock(&_requests_lock);
    for (size_t i = 0U; i < _request_count; ++i) {
        if (![builder appendCString:_requests[i]]) {
            (void)pthread_mutex_unlock(&_requests_lock);
            [builder release];
            return sfw_response("Internal error");
        }
        if (i + 1U < _request_count && ![builder appendChar:'\n']) {
            (void)pthread_mutex_unlock(&_requests_lock);
            [builder release];
            return sfw_response("Internal error");
        }
    }
    (void)pthread_mutex_unlock(&_requests_lock);

    out = [builder takeCString];
    [builder release];
    return out != NULL ? out : sfw_response("Internal error");
}

- (char *)listRules {
    SFWResponseBuilder *builder = [[SFWResponseBuilder allocWithAllocator:sf_default_allocator()] init];
    char *out = NULL;

    if (builder == nil) {
        return sfw_response("Internal error");
    }

    (void)pthread_rwlock_rdlock(&_rules_lock);
    for (size_t i = 0U; i < _rule_count; ++i) {
        SFWRule *rule = _rules[i];

        if (![builder appendCString:"Rule: "] ||
            ![builder appendCString:[rule ruleText]] ||
            ![builder appendChar:'\n']) {
            (void)pthread_rwlock_unlock(&_rules_lock);
            [builder release];
            return sfw_response("Internal error");
        }

        for (size_t j = 0U; j < [rule queryCount]; ++j) {
            SFWQueryEntry_t query = [rule queryAtIndex:j];
            char ip_text[16] = {0};
            char line[64] = {0};

            sfw_format_ipv4(query.ip, ip_text);
            (void)snprintf(line, sizeof(line), "Query: %s %u", ip_text, (unsigned int)query.port);

            if (![builder appendCString:line] || ![builder appendChar:'\n']) {
                (void)pthread_rwlock_unlock(&_rules_lock);
                [builder release];
                return sfw_response("Internal error");
            }
        }
    }
    (void)pthread_rwlock_unlock(&_rules_lock);

    out = [builder takeCString];
    [builder release];
    return out != NULL ? out : sfw_response("Internal error");
}

- (void)resetAll {
    (void)pthread_rwlock_wrlock(&_rules_lock);
    for (size_t i = 0U; i < _rule_count; ++i) {
        [_rules[i] release];
    }
    free(_rules);
    _rules = NULL;
    _rule_count = 0U;
    _rule_capacity = 0U;
    (void)pthread_rwlock_unlock(&_rules_lock);

    (void)pthread_mutex_lock(&_requests_lock);
    for (size_t i = 0U; i < _request_count; ++i) {
        free(_requests[i]);
    }
    free((void *)_requests);
    _requests = NULL;
    _request_count = 0U;
    _request_capacity = 0U;
    (void)pthread_mutex_unlock(&_requests_lock);
}

- (char *)handleListRequestsPayload:(const char *)payload {
    if (payload != NULL) {
        return sfw_response("Illegal request");
    }
    return [self listRequests];
}

- (char *)handleListRulesPayload:(const char *)payload {
    if (payload != NULL) {
        return sfw_response("Illegal request");
    }
    return [self listRules];
}

- (char *)handleFlushPayload:(const char *)payload {
    if (payload != NULL) {
        return sfw_response("Illegal request");
    }

    [self resetAll];
    return sfw_response("All rules deleted");
}

- (char *)handleAddPayload:(const char *)payload {
    SFWRuleSpec_t spec;

    if (payload == NULL || ![SFWRequestParser parseRuleSpecFromText:payload outSpec:&spec]) {
        return sfw_response("Invalid rule");
    }

    if (![self addRuleSpec:&spec sourceText:payload]) {
        return sfw_response("Internal error");
    }

    return sfw_response("Rule added");
}

- (char *)handleDeletePayload:(const char *)payload {
    SFWRuleSpec_t spec;

    if (payload == NULL || ![SFWRequestParser parseRuleSpecFromText:payload outSpec:&spec]) {
        return sfw_response("Invalid rule");
    }

    if (![self deleteRuleSpec:&spec]) {
        return sfw_response("Rule not found");
    }

    return sfw_response("Rule deleted");
}

- (char *)handleCheckPayload:(const char *)payload {
    uint32_t ip = 0U;
    uint16_t port = 0U;

    if (payload == NULL || ![SFWRequestParser parseEndpointFromText:payload outIP:&ip outPort:&port]) {
        return sfw_response("Illegal IP address or port specified");
    }

    if ([self checkConnectionIP:ip port:port]) {
        return sfw_response("Connection accepted");
    }

    return sfw_response("Connection rejected");
}

- (char *)handleCommand:(char)command payload:(const char *)payload {
    switch (command) {
        case 'R':
            return [self handleListRequestsPayload:payload];
        case 'L':
            return [self handleListRulesPayload:payload];
        case 'F':
            return [self handleFlushPayload:payload];
        case 'A':
            return [self handleAddPayload:payload];
        case 'D':
            return [self handleDeletePayload:payload];
        case 'C':
            return [self handleCheckPayload:payload];
        default:
            return sfw_response("Illegal request");
    }
}

- (char *)processCString:(const char *)request {
    char command = '\0';
    const char *payload = NULL;

    if (request == NULL || request[0] == '\0') {
        return sfw_response("Illegal request");
    }

    [self recordRequest:request];

    if (![SFWRequestParser parseRequestHeader:request command:&command payload:&payload]) {
        return sfw_response("Illegal request");
    }

    return [self handleCommand:command payload:payload];
}

@end

char *processRequest(char *request /* NOLINT(readability-non-const-parameter) */) {
    SFWServer *server = [SFWServer sharedServer];
    if (server == nil) {
        return sfw_response("Internal error");
    }
    return [server processCString:request];
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
