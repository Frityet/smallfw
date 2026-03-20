# SmallFW

Objective-C runtime for the C programmer.

## What and why?

Current Objective-C runtimes and frameworks are designed to take a way quite a lot of control from the programmer, and are tightly coupled with their frameworks. This is great for ease of use and safety, but it can be a problem for people who want to write their own frameworks, or who want to have more control over the runtime. SmallFW is an attempt to make a very minimal, configurable, and VERY FLEXIBLE Objective-C runtime that can be used to write ObjC in your way.

[Example of SmallFW code here](./examples/particle-sim/main.m)

## Features

### **NO HIDDEN ALLOCATION**

SmallFW makes it so YOU control where and how memory is allocated:

```objc
struct MyAllocatorContext alloc_ctx = {...};

SFAllocator_t allocator = {
    .alloc = my_alloc_function,
    .free = my_free_function,
    .ctx = &alloc_ctx
};

MyClass *mc = [[MyClass allocWithAllocator: &allocator] init];
...

// with the power of ARC, your allocator will be automatically used
```

Furthermore, unlike in regular ObjC frameworks, the fields of your classes can be allocated with the same allocator as the instance itself:

```objc

@interface MyClass : Object

@property(nonatomic) MyOtherClass *c1;
@property(nonatomic) MyOtherClass *c2;

@end

@implementation MyClass

- (instancetype)init
{
    self = [super init];

    self->_c1 = [[MyOtherClass allocWithParent: self] init];
    self->_c2 = [[MyOtherClass allocWithParent: self] init];

    return self;
}

@end

```

These allocations will use the parent allocator, and if you reference the children from other objects, it will be ensured that the parent is kept alive as long as the children are referenced (you may also of course, not use this behaviour at all and just use regular allocWithAllocator:).

## **BUILD YOUR OWN FRAMEWORK**

SmallFW isn't very much a "Framework" at all, all it provides to you for classes is Object and ValueObject. You can use these as base classes to write your own framework customised to your needs and desires!

## **CONFIGURABLE**

SmallFW is EXTREMLEY configurable!

```sh

        --runtime-sanitize=[y|n]                Enable AddressSanitizer and UndefinedBehaviorSanitizer for runtime analysis builds
        --analysis-symbols=[y|n]                Internal: keep symbols in analysis/profile builds

        --runtime-thinlto=[y|n]                 Enable ThinLTO for runtime targets.
        --runtime-full-lto=[y|n]                Enable full LTO for runtime targets.
        --runtime-native-tuning=[y|n]           Enable -march=native and -mtune=native on supported Linux x86_64 builds.

        --objc-runtime=OBJC-RUNTIME            Select Objective-C runtime ABI/compiler mode (default: gnustep-2.3)
        --dispatch-backend=DISPATCH-BACKEND     Select objc_msgSend backend (default: asm)
        --runtime-forwarding=[y|n]              Enable message forwarding and runtime selector resolution support
        --runtime-validation=[y|n]              Enable defensive runtime object validation (recommended for debug/tests, disable for fastest
                                                release)
        --runtime-tagged-pointers=[y|n]         Enable tagged pointer runtime support for user-defined classes
        --runtime-exceptions=[y|n]              Enable Objective-C exceptions support in runtime (default: y)
        --runtime-reflection=[y|n]              Enable Objective-C reflection support in runtime (default: y)

        --runtime-inline-value-storage=[y|n]    Use compact inline prefixes for embedded ValueObjects.
        --runtime-inline-group-state=[y|n]      Store non-threadsafe parent/group bookkeeping inline in the root allocation.
        --runtime-compact-headers=[y|n]         Use a compact runtime header with cold state stored out-of-line.
        --runtime-generic-metadata=[y|n]        Enable the SmallFW generics compiler/plugin and per-instance generic type encoding.
```

## Generic Metadata Plugin

SmallFW can optionally attach the written generic specialization to each constructed object instance. This feature is disabled by default and is only supported on Linux with Clang/LLVM 21 tooling available on `PATH` such as `clang-21`, `opt-21`, and `llvm-config-21`. If those requirements are not met, `xmake` will automatically disable the option.

### Enable it

```sh
xmake f --cc=clang-21 --cxx=clang++-21 --mm=clang-21 --mxx=clang++-21 --runtime-generic-metadata=y
xmake
```

When `runtime-generic-metadata` is enabled, `xmake` builds the shared `smallfw-generics-plugin` target and injects both the Clang frontend plugin and LLVM pass plugin flags automatically. You do not need to add `-fplugin`, `-Xclang`, or `-fpass-plugin` flags yourself.

### Mark a generic interface

```objc
#if SF_RUNTIME_GENERIC_METADATA
[[clang::sf_encode_generics]]
#endif
@interface MyBox<T> : Object
@end
```

`sf_encode_generics` only applies to generic Objective-C interfaces. It is only available when `runtime-generic-metadata` is enabled, so code that uses the attribute or reads the runtime metadata API should usually be wrapped in `#if SF_RUNTIME_GENERIC_METADATA`.

The plugin accepts all of these spellings:

```objc
__attribute__((sf_encode_generics))
[[sf_encode_generics]]
[[clang::sf_encode_generics]]
```

`[[clang::sf_encode_generics]]` is the recommended bracket form. If you want strict standard C23 parsing rather than extension mode, compile the translation unit with a C23 language mode such as `-std=c23` or `-std=gnu23`.

### Read the class from an instance

```objc
#if SF_RUNTIME_GENERIC_METADATA
MyBox<String *> *box = [[MyBox<String *> allocWithAllocator: nullptr] init];
printf("%s\n", class_getName(box.genericTypeClass)); // prints "String"
#endif
```

When a marked interface is constructed, the runtime stores the specialized class in `genericTypeClass`. That value is available inside supported `init...` methods and after construction. Typical values are `String.class`, `Number.class`, or `nullptr` for unmarked interfaces.

The current plugin only matches direct construction rooted in:

- `[T allocWithAllocator: ...]`
- `[T allocWithParent: ...]`
- `[T allocInPlace:size: ...]`
- the outer `init...` send directly wrapped around one of those alloc calls

If allocation is hidden behind another helper or factory function, no generic metadata is attached in this first version.

### Verify it

```sh
xmake test
```

With the option enabled, the repository includes coverage for:

- exact `genericTypeClass` values on marked stdlib and test-local generic interfaces
- `NULL` metadata for unmarked generic interfaces
- `allocWithParent:` and inline `ValueObject` storage cases
- compile-fail checks for invalid `sf_encode_generics` placement
- IR checks that confirm the marker call is lowered to `sf_object_set_generic_type_class`

## **FAST**

SmallFW is designed to be as fast as possible. See [benchmarks](./docs/PERFORMANCE.md) for details.

## **PORTABLE**

Unless you use the `asm` dispatch backend, SmallFW should be portable to any platform that Clang supports. The `asm` backend is currently only implemented for x86_64 Linux, but the non-asm backends should work on any platform (well... we are getting there...).

SmallFW also vendors the upstream Blocks runtime sources in `src/blocksruntime`, so `-fblocks` code can link cleanly on non-Apple toolchains without requiring a separate system package. `StandardLibrary/Block.h` wraps those blocks as `Block<T>` objects where `T` is the block signature itself, and `[[Block<T> allocWithAllocator:&alloc] initWithBlock:^...]` copies the heap block through the same SmallFW allocator.

## **COOL UTILITIES AND FEATURES**

### ValueObject

ValueObject is a class type that allows you to create objects that are stored inline in their parent object, rather than another allocation using the allocator. This way you can keep your allocations tightly grouped and have better cache locality for your objects!

```objc
@interface MyValue : ValueObject
@property(nonatomic) int x;
@property(nonatomic) int y;
@property(nonatomic) int z;
@end

...

@interface MyClass : Object

@property(nonatomic) MyValue *val1, *val2, *val3;

@end

@implementation MyClass

- (instancetype)init
{
    self = [super init];

    // you must allocWithParent to use the inline storage!
    self->_val1 = [[MyValue allocWithParent: self] init];
    self->_val2 = [[MyValue allocWithParent: self] init];
    self->_val3 = [[MyValue allocWithParent: self] init];

    return self;
}
```

This will only do 1 allocation for all of the storage the entire class needs.
