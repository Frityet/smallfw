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
{
  @public
    Class _initObservedClass;
}

- (Class)observedClass;
@end

@implementation LocalBox
- (instancetype)init
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    _initObservedClass = self.genericTypeClass;
    return self;
}

- (Class)observedClass
{
    return _initObservedClass;
}
@end

@interface PlainBox<T> : Object
@end

@implementation PlainBox
@end

__attribute__((sf_encode_generics))
@interface EmbeddedBox<T> : ValueObject {
  @public
    int _payload;
    Class _initObservedClass;
}
- (Class)observedClass;
@end

@implementation EmbeddedBox
- (instancetype)init
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    _initObservedClass = self.genericTypeClass;
    return self;
}

- (Class)observedClass
{
    return _initObservedClass;
}
@end

@class ReplacementBox;

static Class g_replacement_outer_observed_class = nullptr;
static Class g_replacement_inner_observed_class = nullptr;
static ReplacementBox *g_replacement_box = nullptr;

static ReplacementBox *replacement_box_for_init(void);

__attribute__((sf_encode_generics))
@interface ReplacementBox<T> : Object {
  @public
    int _replacementTag;
    Class _initObservedClass;
}

- (instancetype)initWithReplacementTag:(int)tag;
- (Class)observedClass;
- (int)replacementTag;
@end

@implementation ReplacementBox
- (instancetype)init
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    g_replacement_outer_observed_class = self.genericTypeClass;
    return replacement_box_for_init();
}

- (instancetype)initWithReplacementTag:(int)tag
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }

    g_replacement_inner_observed_class = self.genericTypeClass;
    _initObservedClass = self.genericTypeClass;
    _replacementTag = tag;
    return self;
}

- (Class)observedClass
{
    return _initObservedClass;
}

- (int)replacementTag
{
    return _replacementTag;
}
@end

static ReplacementBox *replacement_box_for_init(void)
{
    if (g_replacement_box == nullptr) {
        g_replacement_box = [[ReplacementBox<String *> allocWithAllocator: nullptr] initWithReplacementTag: 1];
    }
    return g_replacement_box;
}

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
           expect_generic_class("plain local box", (Object *)plain, nullptr) &&
           (marked.observedClass == String.class);
}

static int test_replacement_initializer_generic_metadata(void)
{
    ReplacementBox<String *> *replacement = [[ReplacementBox<String *> allocWithAllocator: nullptr] init];

    if (replacement == nullptr) {
        fprintf(stderr, "replacement box construction failed\n");
        return 0;
    }
    if (!expect_generic_class("replacement box", (Object *)replacement, String.class)) {
        return 0;
    }
    if (replacement.observedClass != String.class) {
        fprintf(stderr,
                "replacement box inner init observed class mismatch: expected %s, got %s\n",
                class_name_or_nil(String.class),
                class_name_or_nil(replacement.observedClass));
        return 0;
    }
    if (replacement.replacementTag != 1) {
        fprintf(stderr, "replacement box tag mismatch: expected 1, got %d\n", replacement.replacementTag);
        return 0;
    }
    if (g_replacement_outer_observed_class != String.class) {
        fprintf(stderr,
                "replacement outer init observed class mismatch: expected %s, got %s\n",
                class_name_or_nil(String.class),
                class_name_or_nil(g_replacement_outer_observed_class));
        return 0;
    }
    if (g_replacement_inner_observed_class != String.class) {
        fprintf(stderr,
                "replacement inner init observed class mismatch: expected %s, got %s\n",
                class_name_or_nil(String.class),
                class_name_or_nil(g_replacement_inner_observed_class));
        return 0;
    }
    return 1;
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

    return expect_generic_class("embedded child", (Object *)child, String.class) &&
           (child.observedClass == String.class);
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
    if (!test_replacement_initializer_generic_metadata()) {
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
