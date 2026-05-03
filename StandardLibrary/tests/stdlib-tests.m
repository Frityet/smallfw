@import SFRuntime;
@import SFStdLib;
@import SFStdLib.Collections;
@import SFStdLib.Exceptions;
@import SFStdLib.Reflection;

#include <iso646.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

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

@interface StdlibReflectionBase : Object {
  @public
    int _baseValue;
}
- (int)basePing;
@end

@implementation StdlibReflectionBase
- (int)basePing
{
    return 7;
}
@end

@interface StdlibReflectionProbe : StdlibReflectionBase {
  @public
    String *_name;
    Number *_count;
}
+ (int)classPing;
- (int)instancePing;
- (String *)namedValue;
@end

@implementation StdlibReflectionProbe
+ (int)classPing
{
    return 11;
}
- (int)instancePing
{
    return 13;
}
- (String *)namedValue
{
    return @"reflection";
}
@end

static bool expect_utf8_equal(const char *label, const char *actual, const char *expected)
{
    if (actual == NULL or expected == NULL) {
        fprintf(stderr, "%s string pointer mismatch\n", label);
        return 0;
    }
    if (strcmp(actual, expected) != 0) {
        fprintf(stderr, "%s string mismatch: expected '%s', got '%s'\n", label, expected, actual);
        return 0;
    }
    return 1;
}

static bool test_short_string_literal(void)
{
    String *short_literal = @"hello";
    auto heap_copy = [[String allocWithAllocator:nullptr] initWithUTF8String:"hello"];
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
    if ([short_literal characterAtIndex:1U] != (unsigned short)'e') {
        fprintf(stderr, "short literal character mismatch: %hu\n", [short_literal characterAtIndex:1U]);
        return 0;
    }
    if (strcmp(short_literal.UTF8String, "hello") != 0) {
        fprintf(stderr, "short literal utf8 mismatch: %s\n", short_literal.UTF8String);
        return 0;
    }
    if ([short_literal isEqual:heap_copy] == 0) {
        fprintf(stderr, "short literal equality failed\n");
        return 0;
    }
    if (short_literal.hash != heap_copy.hash) {
        fprintf(stderr, "short literal hash mismatch: %lu vs %lu\n", short_literal.hash, heap_copy.hash);
        return 0;
    }
    return 1;
}

static bool test_long_and_unicode_strings(void)
{
    String *long_literal = @"abcdefghi";
    String *unicode_literal = @"\u2603";
    auto unicode_heap = [[String allocWithAllocator:nullptr] initWithUTF8String:"\xE2\x98\x83"];

    return long_literal != nullptr and
           [long_literal isMemberOfClass:ConstantString.class] != 0 and
           long_literal.length == 9U and
           [long_literal characterAtIndex:8U] == (unsigned short)'i' and
           strcmp(long_literal.UTF8String, "abcdefghi") == 0 and
           unicode_literal != nullptr and
           [unicode_literal isMemberOfClass:ConstantString.class] != 0 and
           unicode_heap != nullptr and
           unicode_literal.length == 1U and
           [unicode_literal characterAtIndex:0U] == (unsigned short)0x2603U and
           strcmp(unicode_literal.UTF8String, "\xE2\x98\x83") == 0 and
           [unicode_literal isEqual:unicode_heap] != 0;
}

static bool test_number_literals(void)
{
    Number *boxed = @123;
    auto wide = [Number numberWithLongLong:-7LL];
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

static bool test_exception_message(void)
{
    auto with_message = [Exception exceptionWithMessage:@"boom"];
    auto without_message = [Exception exceptionWithMessage:nullptr];

    return with_message != nullptr and
           with_message.message != nullptr and
           strcmp(with_message.message.UTF8String, "boom") == 0 and
           without_message != nullptr and
           without_message.message == nullptr;
}

#if SF_RUNTIME_EXCEPTIONS
    static bool test_framework_exceptions(void)
    {
        int caught_array = 0;
        int caught_map = 0;
        int caught_string = 0;

        @try {
            (void)[Array arrayWithObjects:NULL count:1U];
        }
        @catch (InvalidArgumentException *e) {
            caught_array = e != NULL;
        }

        @
        try {
            (void)[Map dictionaryWithObjects:(id[]) { @1 } forKeys:NULL count:1U];
        }
        @catch (InvalidArgumentException *e) {
            caught_map = e != NULL;
        }

        @
        try {
            (void)[[String allocWithAllocator:nullptr] initWithBytes:"\xC0" length:1U];
        }
        @catch (InvalidArgumentException *e) {
            caught_string = e != NULL;
        }

        return caught_array != 0 and caught_map != 0 and caught_string != 0;
    }

    static bool test_list_bounds_exception(void)
    {
        auto list = [[List<Number *> allocWithAllocator:nullptr] initWithCapacity:1U];
        int caught = 0;

        if (list == nullptr) {
            fprintf(stderr, "list construction failed\n");
            return 0;
        }

        @try {
            (void)[list objectAtIndex:0U];
        }
        @catch (IndexOutOfBoundsException *e) {
            caught = (e != nullptr);
        }

        return caught != 0;
    }
#endif

static bool test_object_runtime_api(void)
{
    auto plain = [[Object allocWithAllocator:NULL] init];
    auto other = [[Object allocWithAllocator:NULL] init];
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
    if ([plain isKindOfClass:Object.class] == 0) {
        fprintf(stderr, "plain kindOf Object failed\n");
        return 0;
    }
    if ([plain isMemberOfClass:Object.class] == 0) {
        fprintf(stderr, "plain memberOf Object failed\n");
        return 0;
    }
    if ([plain isEqual:plain] == 0) {
        fprintf(stderr, "plain self equality failed\n");
        return 0;
    }
    if ([plain isEqual:other] != 0) {
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
    if ([array isKindOfClass:Array.class] == 0) {
        fprintf(stderr, "array kindOf Array failed\n");
        return 0;
    }
    if ([array isKindOfClass:Object.class] == 0) {
        fprintf(stderr, "array kindOf Object failed\n");
        return 0;
    }
    if ([array isMemberOfClass:Array.class] == 0) {
        fprintf(stderr, "array memberOf Array failed\n");
        return 0;
    }
    if ([array isMemberOfClass:Object.class] != 0) {
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
    if ([number isKindOfClass:Number.class] == 0) {
        fprintf(stderr, "number kindOf Number failed\n");
        return 0;
    }
    if ([number isKindOfClass:Object.class] == 0) {
        fprintf(stderr, "number kindOf Object failed\n");
        return 0;
    }
    if ([number isMemberOfClass:Number.class] == 0) {
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
    if ([string isKindOfClass:String.class] == 0) {
        fprintf(stderr, "string kindOf String failed\n");
        return 0;
    }
    if ([string isKindOfClass:Object.class] == 0) {
        fprintf(stderr, "string kindOf Object failed\n");
        return 0;
    }
    return 1;
}

static bool test_array_literal(void)
{
    Array *array = @[ @"one", @2, @"three" ];
    auto same = [Array arrayWithObjects:(id[]) { @"one", @2, @"three" } count:3U];

    return array != NULL and
           same != NULL and
           array.count == 3U and
           strcmp(((String *)array[0]).UTF8String, "one") == 0 and
           ((Number *)array[1]).intValue == 2 and
           [array isEqual:same] != 0 and
           array.hash == same.hash;
}

static bool test_map_literal(void)
{
    Map *map = @{@"alpha" : @1,
                 @"beta" : @2};
    auto deduped = [Map dictionaryWithObjects:(id[]) { @1, @2, @3 }
                                      forKeys:(id[]){@"alpha", @"beta", @"alpha"}
                                        count:3U];

    return map != NULL and
           deduped != NULL and
           map.count == 2U and
           ((Number *)map[@"alpha"]).intValue == 1 and
           ((Number *)[map objectForKey:@"beta"]).intValue == 2 and
           deduped.count == 2U and
           ((Number *)deduped[@"alpha"]).intValue == 3 and
           ((Number *)[deduped objectForKey:@"beta"]).intValue == 2;
}

static bool test_reflection_library(void)
{
    auto info = [Reflection classNamed:"StdlibReflectionProbe"];
    auto named_again = [ReflectionClass classNamed:"StdlibReflectionProbe"];
    auto object = [[StdlibReflectionProbe allocWithAllocator:nullptr] init];
    auto object_info = [Reflection classOfObject:object];
    auto instance_sel = [Reflection selectorNamed:"instancePing"];
    auto class_sel = [Reflection selectorNamed:"classPing"];
    int found_class = 0;

    if (info == nullptr or named_again == nullptr or object == nullptr or object_info == nullptr) {
        fprintf(stderr, "reflection basic construction failed\n");
        return 0;
    }

    if (info.reflectedClass != StdlibReflectionProbe.class or named_again.reflectedClass != info.reflectedClass or object_info.reflectedClass != info.reflectedClass) {
        fprintf(stderr, "reflection class identity mismatch\n");
        return 0;
    }
    if (info.name == nullptr or strcmp(info.name, "StdlibReflectionProbe") != 0 or info.nameString == nullptr or strcmp(info.nameString.UTF8String, "StdlibReflectionProbe") != 0) {
        fprintf(stderr, "reflection class name mismatch\n");
        return 0;
    }
    if (info.reflectedSuperclass != StdlibReflectionBase.class or info.superclassReflection == nullptr or info.superclassReflection.reflectedClass != StdlibReflectionBase.class) {
        fprintf(stderr, "reflection superclass mismatch\n");
        return 0;
    }
    if (not[info isSubclassOfClass:StdlibReflectionBase.class] or not[info isSubclassOfReflectedClass:info.superclassReflection] or [info isSubclassOfClass:Number.class]) {
        fprintf(stderr, "reflection subclass relationship mismatch\n");
        return 0;
    }
    if (info.instanceSize < sizeof(void *)) {
        fprintf(stderr, "reflection instance size mismatch\n");
        return 0;
    }

    auto instance_method = [info instanceMethodForSelector:instance_sel];
    auto instance_by_name = [info instanceMethodNamed:"instancePing"];
    auto class_method = [info classMethodForSelector:class_sel];
    auto class_by_name = [info classMethodNamed:"classPing"];
    if (instance_method == nullptr or instance_by_name == nullptr or class_method == nullptr or class_by_name == nullptr) {
        fprintf(stderr, "reflection method lookup failed\n");
        return 0;
    }
    if (not instance_method.instanceMethod or instance_method.classMethod or instance_method.selector == nullptr or not[instance_method matchesSelector:instance_sel] or not[instance_method matchesName:"instancePing"]) {
        fprintf(stderr, "reflection instance method metadata mismatch\n");
        return 0;
    }
    if (instance_method.nameString == nullptr or strcmp(instance_method.nameString.UTF8String, "instancePing") != 0 or instance_method.typeEncoding == nullptr or instance_method.typeEncodingString == nullptr or instance_method.implementation == nullptr) {
        fprintf(stderr, "reflection instance method strings mismatch\n");
        return 0;
    }
    if (not class_method.classMethod or class_method.instanceMethod or not[class_method matchesName:"classPing"]) {
        fprintf(stderr, "reflection class method metadata mismatch\n");
        return 0;
    }

    auto methods = info.instanceMethods;
    auto all_methods = info.allInstanceMethods;
    auto method_map = info.instanceMethodsByName;
    auto all_method_map = info.allInstanceMethodsByName;
    if (methods == nullptr or methods.count == 0U or all_methods == nullptr or all_methods.count < methods.count or method_map == nullptr or all_method_map == nullptr) {
        fprintf(stderr, "reflection method collections failed\n");
        return 0;
    }
    if (method_map[@"instancePing"] == nullptr or all_method_map[@"basePing"] == nullptr) {
        fprintf(stderr, "reflection method map lookup failed\n");
        return 0;
    }

    auto ivar = [info instanceVariableNamed:"_name"];
    auto inherited_ivar_map = info.allInstanceVariablesByName;
    auto local_ivar_map = info.instanceVariablesByName;
    if (ivar == nullptr or not[ivar matchesName:"_name"] or ivar.nameString == nullptr or strcmp(ivar.nameString.UTF8String, "_name") != 0 or ivar.typeEncoding == nullptr or ivar.typeEncodingString == nullptr or ivar.offset < 0) {
        fprintf(stderr, "reflection ivar metadata mismatch\n");
        return 0;
    }
    if (local_ivar_map == nullptr or local_ivar_map[@"_count"] == nullptr or inherited_ivar_map == nullptr or inherited_ivar_map[@"_baseValue"] == nullptr) {
        fprintf(stderr, "reflection ivar map lookup failed\n");
        return 0;
    }

    auto classes = [Reflection allClasses];
    if (classes == nullptr or classes.count == 0U) {
        fprintf(stderr, "reflection allClasses failed\n");
        return 0;
    }
    for (size_t i = 0U; i < classes.count; ++i) {
        auto cls = (ReflectionClass *)classes[i];
        if (cls.reflectedClass == StdlibReflectionProbe.class) {
            found_class = 1;
            break;
        }
    }
    if (not found_class) {
        fprintf(stderr, "reflection allClasses missing probe\n");
        return 0;
    }

    return 1;
}

#if SF_RUNTIME_GENERIC_METADATA
    static const char *generic_class_name_or_nil(Class cls)
    {
        return cls != NULL ? class_getName(cls) : "(nil)";
    }

    static bool expect_generic_class(const char *label, Object *obj, Class expected)
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

    static bool test_runtime_generic_metadata(void)
    {
        auto array = [[Array<String *> allocWithAllocator:nullptr]
            initWithObjects:(id[]){@"one"}
                      count:1U];
        auto list = [[List<Number *> allocWithAllocator:nullptr] initWithCapacity:2U];
        auto map = [[Map<String *, Number *> allocWithAllocator:nullptr]
            initWithObjects:(id[]) { @1 }
                    forKeys:(id[]){@"one"}
                      count:1U];
        auto box = [[StdlibGenericBox<String *> allocWithAllocator:nullptr] init];
        auto plain = [[StdlibPlainGenericBox<String *> allocWithAllocator:nullptr] init];
        auto holder = [[StdlibInlineGenericHolder allocWithAllocator:nullptr] init];
        StdlibInlineGenericValue<String *> *inline_value =
            [[StdlibInlineGenericValue<String *> allocWithParent:holder] init];

#    if SF_RUNTIME_EXCEPTIONS
            [list addObject:@1];
#    else
            if (![list addObject:@1]) {
                fprintf(stderr, "list addObject failed\n");
                return 0;
            }
#    endif

        if (not expect_generic_class("array", (Object *)array, String.class)) {
            return 0;
        }
        if (not expect_generic_class("list", (Object *)list, Number.class)) {
            return 0;
        }
        auto first = [list objectAtIndex:0U];
        if (first == nullptr or first.intValue != 1) {
            fprintf(stderr, "generic list element mismatch\n");
            return 0;
        }
        if (not expect_generic_class("map", (Object *)map, NULL)) {
            return 0;
        }
        if (not expect_generic_class("box", (Object *)box, String.class)) {
            return 0;
        }
        if (not expect_generic_class("inline value", (Object *)inline_value, String.class)) {
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
    if (not test_reflection_library()) {
        fprintf(stderr, "reflection library test failed\n");
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
