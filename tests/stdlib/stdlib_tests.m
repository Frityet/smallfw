#include "StandardLibrary/Array.h"
#include "StandardLibrary/Block.h"
#include "StandardLibrary/Exception.h"
#include "StandardLibrary/List.h"
#include "StandardLibrary/Map.h"
#include "StandardLibrary/Number.h"
#include "StandardLibrary/String.h"
#include "runtime/objc/runtime_exports.h"

#include <iso646.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

typedef struct StdlibTestAllocatorState {
    size_t alloc_calls;
    size_t free_calls;
} StdlibTestAllocatorState_t;

#if SF_RUNTIME_GENERIC_METADATA
__attribute__((sf_encode_generics))
@interface StdlibGenericBox<T> : Object
@end

@implementation StdlibGenericBox
@end

@interface StdlibPlainGenericBox<T> : Object
@end

@implementation StdlibPlainGenericBox
@end

__attribute__((sf_encode_generics))
@interface StdlibInlineGenericValue<T> : ValueObject {
  @public
    int _payload;
}
@end

@implementation StdlibInlineGenericValue
@end

@interface StdlibInlineGenericHolder : Object {
  @public
    StdlibInlineGenericValue<String *> *_value;
}
@end

@implementation StdlibInlineGenericHolder
@end
#endif

static void *stdlib_test_alloc(void *ctx, size_t size, size_t align)
{
    StdlibTestAllocatorState_t *state = (StdlibTestAllocatorState_t *)ctx;
    void *ptr = NULL;
    size_t use_align = align < sizeof(void *) ? sizeof(void *) : align;

    if (posix_memalign(&ptr, use_align, size) != 0) {
        return NULL;
    }
    state->alloc_calls += 1U;
    return ptr;
}

static void stdlib_test_free(void *ctx, void *ptr, size_t size, size_t align)
{
    StdlibTestAllocatorState_t *state = (StdlibTestAllocatorState_t *)ctx;
    (void)size;
    (void)align;
    state->free_calls += 1U;
    free(ptr);
}

static int expect_utf8_equal(const char *label, const char *actual, const char *expected)
{
    if (actual == NULL || expected == NULL) {
        fprintf(stderr, "%s string pointer mismatch\n", label);
        return 0;
    }
    if (strcmp(actual, expected) != 0) {
        fprintf(stderr, "%s string mismatch: expected '%s', got '%s'\n", label, expected, actual);
        return 0;
    }
    return 1;
}

static int test_short_string_literal(void)
{
    String *short_literal = @"hello";
    String *heap_copy = [[String allocWithAllocator: nullptr] initWithUTF8String: "hello"];
    if (short_literal == nullptr) {
        fprintf(stderr, "short literal was nullptr\n");
        return 0;
    }
    if (heap_copy == nullptr) {
        fprintf(stderr, "heap copy was nullptr\n");
        return 0;
    }
    if (short_literal.length != 5U) {
        fprintf(stderr, "short literal length mismatch: %zu\n", short_literal.length);
        return 0;
    }
    if ([short_literal characterAtIndex: 1U] != (unsigned short)'e') {
        fprintf(stderr, "short literal character mismatch: %hu\n", [short_literal characterAtIndex: 1U]);
        return 0;
    }
    if (strcmp(short_literal.UTF8String, "hello") != 0) {
        fprintf(stderr, "short literal utf8 mismatch: %s\n", short_literal.UTF8String);
        return 0;
    }
    if ([short_literal isEqual: heap_copy] == 0) {
        fprintf(stderr, "short literal equality failed\n");
        return 0;
    }
    if (short_literal.hash != heap_copy.hash) {
        fprintf(stderr, "short literal hash mismatch: %lu vs %lu\n", short_literal.hash, heap_copy.hash);
        return 0;
    }
    return 1;
}

static int test_long_and_unicode_strings(void)
{
    String *long_literal = @"abcdefghi";
    String *unicode_literal = @"\u2603";
    String *unicode_heap = [[String allocWithAllocator: nullptr] initWithUTF8String: "\xE2\x98\x83"];

    return long_literal != nullptr and
           long_literal.length == 9U and
           [long_literal characterAtIndex: 8U] == (unsigned short)'i' and
           strcmp(long_literal.UTF8String, "abcdefghi") == 0 and
           unicode_literal != nullptr and
           unicode_heap != nullptr and
           unicode_literal.length == 1U and
           [unicode_literal characterAtIndex: 0U] == (unsigned short)0x2603U and
           strcmp(unicode_literal.UTF8String, "\xE2\x98\x83") == 0 and
           [unicode_literal isEqual: unicode_heap] != 0;
}

static int test_number_literals(void)
{
    Number *boxed = @123;
    Number *wide = [Number numberWithLongLong: -7LL];
    Number *real = @1.5;

    return boxed != NULL and
#if SF_RUNTIME_TAGGED_POINTERS
           boxed.isTaggedPointer != 0 and
#endif
           boxed.intValue == 123 and
           wide != NULL and
           wide.longLongValue == -7LL and
           real != NULL and
           real.doubleValue == 1.5;
}

static int test_exception_message(void)
{
    Exception *with_message = [Exception exceptionWithMessage: @"boom"];
    Exception *without_message = [Exception exceptionWithMessage: nullptr];

    return with_message != nullptr and
           with_message.message != nullptr and
           strcmp(with_message.message.UTF8String, "boom") == 0 and
           without_message != nullptr and
           without_message.message == nullptr;
}

#if SF_RUNTIME_EXCEPTIONS
static int test_framework_exceptions(void)
{
    int caught_array = 0;
    int caught_map = 0;
    int caught_string = 0;

    @try {
        (void)[Array arrayWithObjects: NULL count: 1U];
    }
    @catch (InvalidArgumentException *e) {
        caught_array = e != NULL;
    }

    @try {
        (void)[Map dictionaryWithObjects: (id[]){@1} forKeys: NULL count: 1U];
    }
    @catch (InvalidArgumentException *e) {
        caught_map = e != NULL;
    }

    @try {
        (void)[[String allocWithAllocator: nullptr] initWithBytes: "\xC0" length: 1U];
    }
    @catch (InvalidArgumentException *e) {
        caught_string = e != NULL;
    }

    return caught_array != 0 and caught_map != 0 and caught_string != 0;
}

static int test_list_bounds_exception(void)
{
    List<Number *> *list = [[List<Number *> allocWithAllocator: nullptr] initWithCapacity: 1U];
    int caught = 0;

    if (list == nullptr) {
        fprintf(stderr, "list construction failed\n");
        return 0;
    }

    @try {
        (void)[list objectAtIndex: 0U];
    }
    @catch (IndexOutOfBoundsException *e) {
        caught = (e != nullptr);
    }

    return caught != 0;
}
#endif

static int test_object_runtime_api(void)
{
    Object *plain = [[Object allocWithAllocator: NULL] init];
    Object *other = [[Object allocWithAllocator: NULL] init];
    Array *array = @[ @"one" ];
    Number *number = @123;
    String *string = @"hello";
    if (plain == NULL) {
        fprintf(stderr, "plain object was NULL\n");
        return 0;
    }
    if (other == NULL) {
        fprintf(stderr, "other object was NULL\n");
        return 0;
    }
    if (plain.class != Object.class) {
        fprintf(stderr, "plain class mismatch\n");
        return 0;
    }
    if (plain.superclass != NULL) {
        fprintf(stderr, "plain superclass mismatch\n");
        return 0;
    }
    if ([plain isKindOfClass: Object.class] == 0) {
        fprintf(stderr, "plain kindOf Object failed\n");
        return 0;
    }
    if ([plain isMemberOfClass: Object.class] == 0) {
        fprintf(stderr, "plain memberOf Object failed\n");
        return 0;
    }
    if ([plain isEqual: plain] == 0) {
        fprintf(stderr, "plain self equality failed\n");
        return 0;
    }
    if ([plain isEqual: other] != 0) {
        fprintf(stderr, "plain distinct equality failed\n");
        return 0;
    }
    if (Object.superclass != NULL) {
        fprintf(stderr, "Object superclass mismatch\n");
        return 0;
    }
    if (Array.superclass != Object.class) {
        fprintf(stderr, "Array superclass mismatch\n");
        return 0;
    }
    if (array == NULL) {
        fprintf(stderr, "array literal was NULL\n");
        return 0;
    }
    if (array.class != Array.class) {
        fprintf(stderr, "array class mismatch\n");
        return 0;
    }
    if (array.superclass != Object.class) {
        fprintf(stderr, "array superclass mismatch\n");
        return 0;
    }
    if ([array isKindOfClass: Array.class] == 0) {
        fprintf(stderr, "array kindOf Array failed\n");
        return 0;
    }
    if ([array isKindOfClass: Object.class] == 0) {
        fprintf(stderr, "array kindOf Object failed\n");
        return 0;
    }
    if ([array isMemberOfClass: Array.class] == 0) {
        fprintf(stderr, "array memberOf Array failed\n");
        return 0;
    }
    if ([array isMemberOfClass: Object.class] != 0) {
        fprintf(stderr, "array memberOf Object failed\n");
        return 0;
    }
    if (number == NULL) {
        fprintf(stderr, "number literal was NULL\n");
        return 0;
    }
    if (number.class != Number.class) {
        fprintf(stderr, "number class mismatch\n");
        return 0;
    }
    if (number.superclass != Object.class) {
        fprintf(stderr, "number superclass mismatch\n");
        return 0;
    }
    if ([number isKindOfClass: Number.class] == 0) {
        fprintf(stderr, "number kindOf Number failed\n");
        return 0;
    }
    if ([number isKindOfClass: Object.class] == 0) {
        fprintf(stderr, "number kindOf Object failed\n");
        return 0;
    }
    if ([number isMemberOfClass: Number.class] == 0) {
        fprintf(stderr, "number memberOf Number failed\n");
        return 0;
    }
    if (string == NULL) {
        fprintf(stderr, "string literal was NULL\n");
        return 0;
    }
    if (string.class == NULL) {
        fprintf(stderr, "string class was NULL\n");
        return 0;
    }
    if ([string isKindOfClass: String.class] == 0) {
        fprintf(stderr, "string kindOf String failed\n");
        return 0;
    }
    if ([string isKindOfClass: Object.class] == 0) {
        fprintf(stderr, "string kindOf Object failed\n");
        return 0;
    }
    return 1;
}

static int test_array_literal(void)
{
    Array *array = @[ @"one", @2, @"three" ];
    Array *same = [Array arrayWithObjects: (id[]){@"one", @2, @"three"} count: 3U];

    return array != NULL and
           same != NULL and
           array.count == 3U and
           strcmp(((String *)array[0]).UTF8String, "one") == 0 and
           ((Number *)array[1]).intValue == 2 and
           [array isEqual: same] != 0 and
           array.hash == same.hash;
}

static int test_map_literal(void)
{
    Map *map = @{ @"alpha": @1, @"beta": @2 };
    Map *deduped = [Map dictionaryWithObjects: (id[]){@1, @2, @3}
                                      forKeys: (id[]){@"alpha", @"beta", @"alpha"}
                                        count: 3U];

    return map != NULL and
           deduped != NULL and
           map.count == 2U and
           ((Number *)map[@"alpha"]).intValue == 1 and
           ((Number *)[map objectForKey: @"beta"]).intValue == 2 and
           deduped.count == 2U and
           ((Number *)deduped[@"alpha"]).intValue == 3 and
           ((Number *)[deduped objectForKey: @"beta"]).intValue == 2;
}

static int test_block_allocator_wrapper(void)
{
    StdlibTestAllocatorState_t allocator_state = {0U, 0U};
    SFAllocator_t allocator = {
        .alloc = stdlib_test_alloc,
        .free = stdlib_test_free,
        .ctx = &allocator_state,
    };
    int answer = 0;

    {
        int captured = 21;
        Block<int (^)(int, int)> *adder =
            [[Block<int (^)(int, int)> allocWithAllocator: &allocator] initWithBlock:^int(int lhs, int rhs) {
                return lhs + rhs + captured;
            }];

        if (adder == NULL || adder.block == NULL) {
            fprintf(stderr, "block wrapper construction failed\n");
            return 0;
        }
        int (^native_adder)(int, int) = adder.block;
        answer = native_adder(10, 11);
        native_adder = NULL;
        adder = nullptr;
    }

    if (answer != 42) {
        fprintf(stderr, "block wrapper result mismatch: %d\n", answer);
        return 0;
    }
    if (allocator_state.alloc_calls < 2U) {
        fprintf(stderr, "custom allocator did not receive block copy: %zu\n", allocator_state.alloc_calls);
        return 0;
    }
    if (allocator_state.free_calls != allocator_state.alloc_calls) {
        fprintf(stderr, "custom allocator free mismatch: alloc=%zu free=%zu\n",
                allocator_state.alloc_calls,
                allocator_state.free_calls);
        return 0;
    }
    return 1;
}

#if SF_RUNTIME_GENERIC_METADATA
static const char *generic_class_name_or_nil(Class cls)
{
    return cls != NULL ? class_getName(cls) : "(nil)";
}

static int expect_generic_class(const char *label, Object *obj, Class expected)
{
    Class actual = NULL;

    if (obj == NULL) {
        fprintf(stderr, "%s object was NULL\n", label);
        return 0;
    }

    actual = obj.genericTypeClass;
    if (actual != expected) {
        fprintf(stderr,
                "%s genericTypeClass mismatch: expected %s, got %s\n",
                label,
                generic_class_name_or_nil(expected),
                generic_class_name_or_nil(actual));
        return 0;
    }
    return 1;
}

static int test_runtime_generic_metadata(void)
{
    Array<String *> *array = [[Array<String *> allocWithAllocator: nullptr]
        initWithObjects: (id[]){@"one"}
                  count: 1U];
    List<Number *> *list = [[List<Number *> allocWithAllocator: nullptr] initWithCapacity: 2U];
    Map<String *, Number *> *map = [[Map<String *, Number *> allocWithAllocator: nullptr]
        initWithObjects: (id[]){@1}
                forKeys: (id[]){@"one"}
                  count: 1U];
    Block<int (^)(int, int)> *block =
        [[Block<int (^)(int, int)> allocWithAllocator: nullptr] initWithBlock:^int(int lhs, int rhs) {
            return lhs + rhs;
        }];
    StdlibGenericBox<String *> *box = [[StdlibGenericBox<String *> allocWithAllocator: nullptr] init];
    StdlibPlainGenericBox<String *> *plain = [[StdlibPlainGenericBox<String *> allocWithAllocator: nullptr] init];
    StdlibInlineGenericHolder *holder = [[StdlibInlineGenericHolder allocWithAllocator: nullptr] init];
    StdlibInlineGenericValue<String *> *inline_value =
        [[StdlibInlineGenericValue<String *> allocWithParent: holder] init];

#if SF_RUNTIME_EXCEPTIONS
    [list addObject: @1];
#else
    if (![list addObject: @1]) {
        fprintf(stderr, "list addObject failed\n");
        return 0;
    }
#endif

    if (!expect_generic_class("array", (Object *)array, String.class)) {
        return 0;
    }
    if (!expect_generic_class("list", (Object *)list, Number.class)) {
        return 0;
    }
    Number *first = [list objectAtIndex: 0U];
    if (first == nullptr or first.intValue != 1) {
        fprintf(stderr, "generic list element mismatch\n");
        return 0;
    }
    if (!expect_generic_class("map", (Object *)map, NULL)) {
        return 0;
    }
    if (!expect_generic_class("block", (Object *)block, NULL)) {
        return 0;
    }
    if (!expect_generic_class("box", (Object *)box, String.class)) {
        return 0;
    }
    if (!expect_generic_class("inline value", (Object *)inline_value, String.class)) {
        return 0;
    }
    if (plain == NULL) {
        fprintf(stderr, "plain generic box was NULL\n");
        return 0;
    }
    if (plain.genericTypeClass != NULL) {
        fprintf(stderr,
                "plain generic box unexpectedly had metadata: %s\n",
                generic_class_name_or_nil(plain.genericTypeClass));
        return 0;
    }
    return 1;
}
#endif

int main(void)
{
    if (not test_object_runtime_api()) {
        fprintf(stderr, "object runtime api test failed\n");
        return 1;
    }
    if (not test_exception_message()) {
        fprintf(stderr, "exception message test failed\n");
        return 1;
    }
#if SF_RUNTIME_EXCEPTIONS
    if (not test_framework_exceptions()) {
        fprintf(stderr, "framework exceptions test failed\n");
        return 1;
    }
    if (not test_list_bounds_exception()) {
        fprintf(stderr, "list bounds exception test failed\n");
        return 1;
    }
#endif
    if (not test_short_string_literal()) {
        fprintf(stderr, "short string literal test failed\n");
        return 1;
    }
    if (not test_long_and_unicode_strings()) {
        fprintf(stderr, "long/unicode string test failed\n");
        return 1;
    }
    if (not test_number_literals()) {
        fprintf(stderr, "number literal test failed\n");
        return 1;
    }
    if (not test_array_literal()) {
        fprintf(stderr, "array literal test failed\n");
        return 1;
    }
    if (not test_map_literal()) {
        fprintf(stderr, "map literal test failed\n");
        return 1;
    }
    if (not test_block_allocator_wrapper()) {
        fprintf(stderr, "block allocator wrapper test failed\n");
        return 1;
    }
#if SF_RUNTIME_GENERIC_METADATA
    if (not test_runtime_generic_metadata()) {
        fprintf(stderr, "runtime generic metadata test failed\n");
        return 1;
    }
#endif
    return 0;
}
