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
```

## **FAST**

SmallFW is designed to be as fast as possible. See [benchmarks](./docs/PERFORMANCE.md) for details.

## **PORTABLE**

Unless you use the `asm` dispatch backend, SmallFW should be portable to any platform that Clang supports. The `asm` backend is currently only implemented for x86_64 Linux, but the non-asm backends should work on any platform (well... we are getting there...).

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
