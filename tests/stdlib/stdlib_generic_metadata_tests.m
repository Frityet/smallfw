#include "StandardLibrary/Array.h"
#include "StandardLibrary/Block.h"
#include "StandardLibrary/List.h"
#include "StandardLibrary/Map.h"
#include "StandardLibrary/Number.h"
#include "StandardLibrary/String.h"
#include "runtime/abi.h"

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

__attribute__((sf_encode_generics))
@interface LocalBox<T> : Object
@end

@implementation LocalBox
@end

@interface PlainBox<T> : Object
@end

@implementation PlainBox
@end

__attribute__((sf_encode_generics))
@interface EmbeddedBox<T> : ValueObject {
  @public
    int _payload;
}
@end

@implementation EmbeddedBox
@end

@interface EmbeddedHolder : Object {
  @public
    EmbeddedBox<String *> *_value;
}
@end

@implementation EmbeddedHolder
@end

static const char *class_name_or_nil(Class cls)
{
    return cls != nullptr ? class_getName(cls) : "(nil)";
}

static int expect_generic_class(const char *label, Object *object, Class expected)
{
    Class actual = nullptr;

    if (object == nullptr) {
        fprintf(stderr, "%s object was nullptr\n", label);
        return 0;
    }

    actual = object.genericTypeClass;
    if (actual != expected) {
        fprintf(stderr,
                "%s generic class mismatch: expected %s, got %s\n",
                label,
                class_name_or_nil(expected),
                class_name_or_nil(actual));
        return 0;
    }
    return 1;
}

static int test_single_argument_stdlib_generics(void)
{
    Array<String *> *array =
        [[Array<String *> allocWithAllocator: nullptr] initWithObjects: (id[]){@"value"} count: 1U];
    List<Number *> *list = [[List<Number *> allocWithAllocator: nullptr] initWithCapacity: 1U];

    if (list == nullptr) {
        fprintf(stderr, "list construction failed\n");
        return 0;
    }
#if SF_RUNTIME_EXCEPTIONS
    [list addObject: @1];
#else
    if (![list addObject: @1]) {
        fprintf(stderr, "list add failed\n");
        return 0;
    }
#endif

    return expect_generic_class("array", (Object *)array, String.class) &&
           expect_generic_class("list", (Object *)list, Number.class);
}

static int test_unsupported_stdlib_generics_are_nil(void)
{
    Map<String *, Number *> *map =
        [[Map<String *, Number *> allocWithAllocator: nullptr] initWithObjects: (id[]){@1}
                                                                       forKeys: (id[]){@"key"}
                                                                         count: 1U];
    Block<int (^)(int, int)> *block =
        [[Block<int (^)(int, int)> allocWithAllocator: nullptr] initWithBlock:^int(int lhs, int rhs) {
            return lhs + rhs;
        }];

    return expect_generic_class("map", (Object *)map, nullptr) &&
           expect_generic_class("block", (Object *)block, nullptr);
}

static int test_local_generic_interfaces(void)
{
    LocalBox<String *> *marked = [[LocalBox<String *> allocWithAllocator: nullptr] init];
    PlainBox<String *> *plain = [[PlainBox<String *> allocWithAllocator: nullptr] init];

    return expect_generic_class("marked local box", (Object *)marked, String.class) &&
           expect_generic_class("plain local box", (Object *)plain, nullptr);
}

static int test_alloc_in_place_generic_class(void)
{
    size_t storage_size = sizeof(SFObjHeader_t) + class_getInstanceSize(LocalBox.class);
    void *storage = calloc(1U, storage_size);
    LocalBox<String *> *placed = nullptr;
    int ok = 0;

    if (storage == nullptr) {
        fprintf(stderr, "alloc-in-place backing storage allocation failed\n");
        return 0;
    }

    placed = [[LocalBox<String *> allocInPlace: storage size: storage_size] init];
    ok = expect_generic_class("alloc in place", (Object *)placed, String.class);
    free(storage);
    return ok;
}

static int test_alloc_with_parent_embedded_value(void)
{
    EmbeddedHolder *holder = [[EmbeddedHolder allocWithAllocator: nullptr] init];
    EmbeddedBox<String *> *child = [[EmbeddedBox<String *> allocWithParent: holder] init];

    return expect_generic_class("embedded child", (Object *)child, String.class);
}

int main(void)
{
    if (!test_single_argument_stdlib_generics()) {
        return 1;
    }
    if (!test_unsupported_stdlib_generics_are_nil()) {
        return 1;
    }
    if (!test_local_generic_interfaces()) {
        return 1;
    }
    if (!test_alloc_in_place_generic_class()) {
        return 1;
    }
    if (!test_alloc_with_parent_embedded_value()) {
        return 1;
    }
    return 0;
}
