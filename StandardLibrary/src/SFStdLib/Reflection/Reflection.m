@import SFRuntime;

#include "Reflection.h"

#include <iso646.h>
#include <stdlib.h>
#include <string.h>

#if SF_RUNTIME_EXCEPTIONS
@interface AllocationFailedException (SmallFWInternal)
+ (instancetype)allocationFailedException;
@end
#endif

static String *reflection_string_from_cstr(const char *nillable bytes)
{
    if (bytes == nullptr) {
        return nullptr;
    }
    auto string = [[String allocWithAllocator:nullptr] initWithUTF8String:bytes];
    return [string autorelease];
}

static bool reflection_append_owned_item(id *nillable *nonnil items_io, size_t *nonnil count_io, size_t *nonnil capacity_io, id nillable item)
{
    if (item == nullptr) {
        return false;
    }
    if (*count_io == *capacity_io) {
        auto next_capacity = (*capacity_io == 0U) ? 8U : (*capacity_io * 2U);
        auto next_items = (id *)realloc(*items_io, next_capacity * sizeof(id));
        if (next_items == nullptr) {
            [(Object *)item release];
            return false;
        }
        *items_io = next_items;
        *capacity_io = next_capacity;
    }
    (*items_io)[*count_io] = item;
    *count_io += 1U;
    return true;
}

static void reflection_release_owned_items(id *nillable items, size_t count)
{
    for (size_t i = 0U; i < count; ++i) {
        [(Object *)items[i] release];
    }
}

static Array *nillable reflection_array_from_owned_items(id *nillable items, size_t count)
{
    auto array = [[Array allocWithAllocator:nullptr] initWithObjects:(const id nonnil *nillable)items count:count];
    reflection_release_owned_items(items, count);
    free((void *)items);
    return [array autorelease];
}

static Map *nillable reflection_method_map_from_array(Array *nillable methods)
{
    if (methods == nullptr or methods.count == 0U) {
        return [Map dictionaryWithObjects:nullptr forKeys:nullptr count:0U];
    }

    auto keys = (id *)malloc(methods.count * sizeof(id));
    auto values = (id *)malloc(methods.count * sizeof(id));
    if (keys == nullptr or values == nullptr) {
        free((void *)keys);
        free((void *)values);
        return nullptr;
    }

    size_t count = 0U;
    for (size_t i = 0U; i < methods.count; ++i) {
        auto method = (ReflectionMethod *)methods[i];
        auto name = method.nameString;
        if (name == nullptr) {
            continue;
        }
        keys[count] = name;
        values[count] = method;
        ++count;
    }

    auto map = [[Map allocWithAllocator:nullptr] initWithObjects:(const id nonnil *nillable)values forKeys:(const id nonnil *nillable)keys count:count];
    free((void *)keys);
    free((void *)values);
    return [map autorelease];
}

static Map *nillable reflection_ivar_map_from_array(Array *nillable ivars)
{
    if (ivars == nullptr or ivars.count == 0U) {
        return [Map dictionaryWithObjects:nullptr forKeys:nullptr count:0U];
    }

    auto keys = (id *)malloc(ivars.count * sizeof(id));
    auto values = (id *)malloc(ivars.count * sizeof(id));
    if (keys == nullptr or values == nullptr) {
        free((void *)keys);
        free((void *)values);
        return nullptr;
    }

    size_t count = 0U;
    for (size_t i = 0U; i < ivars.count; ++i) {
        auto ivar = (ReflectionIvar *)ivars[i];
        auto name = ivar.nameString;
        if (name == nullptr) {
            continue;
        }
        keys[count] = name;
        values[count] = ivar;
        ++count;
    }

    auto map = [[Map allocWithAllocator:nullptr] initWithObjects:(const id nonnil *nillable)values forKeys:(const id nonnil *nillable)keys count:count];
    free((void *)keys);
    free((void *)values);
    return [map autorelease];
}

static Class nillable reflection_meta_class_for_class(Class nillable cls)
{
    auto name = class_getName(cls);
    return name != nullptr ? objc_getMetaClass(name) : nullptr;
}

static Array *nillable reflection_copy_methods_for_class(Class nillable cls, bool include_superclasses, bool class_methods)
{
    id *items = nullptr;
    size_t count = 0U, capacity = 0U;

    for (auto cursor = cls; cursor != nullptr; cursor = include_superclasses ? class_getSuperclass(cursor) : nullptr) {
        auto source_class = class_methods ? reflection_meta_class_for_class(cursor) : cursor;
        if (source_class == nullptr) {
            if (not include_superclasses) {
                break;
            }
            continue;
        }

        unsigned int method_count = 0U;
        auto methods = class_copyMethodList(source_class, &method_count);
        if (methods == nullptr or method_count == 0U) {
            free((void *)methods);
            if (not include_superclasses) {
                break;
            }
            continue;
        }

        auto owner = [[ReflectionClass allocWithAllocator:nullptr] initWithClass:cursor];
        if (owner == nullptr) {
            free((void *)methods);
            reflection_release_owned_items(items, count);
            free((void *)items);
            return nullptr;
        }

        for (unsigned int i = 0U; i < method_count; ++i) {
            auto method = [[ReflectionMethod allocWithAllocator:nullptr] initWithMethod:methods[i] ownerClass:owner classMethod:class_methods];
            if (not reflection_append_owned_item(&items, &count, &capacity, method)) {
                [owner release];
                free((void *)methods);
                reflection_release_owned_items(items, count);
                free((void *)items);
                return nullptr;
            }
        }

        [owner release];
        free((void *)methods);
        if (not include_superclasses) {
            break;
        }
    }

    return reflection_array_from_owned_items(items, count);
}

static Array *nillable reflection_copy_ivars_for_class(Class nillable cls, bool include_superclasses)
{
    id *items = nullptr;
    size_t count = 0U, capacity = 0U;

    for (auto cursor = cls; cursor != nullptr; cursor = include_superclasses ? class_getSuperclass(cursor) : nullptr) {
        unsigned int ivar_count = 0U;
        auto ivars = class_copyIvarList(cursor, &ivar_count);
        if (ivars == nullptr or ivar_count == 0U) {
            free((void *)ivars);
            if (not include_superclasses) {
                break;
            }
            continue;
        }

        auto owner = [[ReflectionClass allocWithAllocator:nullptr] initWithClass:cursor];
        if (owner == nullptr) {
            free((void *)ivars);
            reflection_release_owned_items(items, count);
            free((void *)items);
            return nullptr;
        }

        for (unsigned int i = 0U; i < ivar_count; ++i) {
            auto ivar = [[ReflectionIvar allocWithAllocator:nullptr] initWithIvar:ivars[i] ownerClass:owner];
            if (not reflection_append_owned_item(&items, &count, &capacity, ivar)) {
                [owner release];
                free((void *)ivars);
                reflection_release_owned_items(items, count);
                free((void *)items);
                return nullptr;
            }
        }

        [owner release];
        free((void *)ivars);
        if (not include_superclasses) {
            break;
        }
    }

    return reflection_array_from_owned_items(items, count);
}

@implementation Reflection

+ (ReflectionClass *nillable)classWithClass:(Class nillable)cls
{
    return [ReflectionClass classWithClass:cls];
}

+ (ReflectionClass *nillable)classNamed:(const char *nillable)name
{
    return [ReflectionClass classNamed:name];
}

+ (ReflectionClass *nillable)classOfObject:(Object *nillable)object
{
    return object != nullptr ? [ReflectionClass classWithClass:object.class] : nullptr;
}

+ (SF_ERRORABLE(Array<ReflectionClass *> *))allClasses
{
    unsigned int class_count = 0U;
    auto classes = objc_copyClassList(&class_count);
    if (classes == nullptr or class_count == 0U) {
        free((void *)classes);
        return [Array arrayWithObjects:nullptr count:0U];
    }

    id *items = nullptr;
    size_t count = 0U, capacity = 0U;
    for (unsigned int i = 0U; i < class_count; ++i) {
        auto reflected_class = [[ReflectionClass allocWithAllocator:nullptr] initWithClass:classes[i]];
        if (not reflection_append_owned_item(&items, &count, &capacity, reflected_class)) {
            free((void *)classes);
            reflection_release_owned_items(items, count);
            free((void *)items);
            SF_THROW([AllocationFailedException allocationFailedException]);
        }
    }

    free((void *)classes);
    auto reflected_classes = reflection_array_from_owned_items(items, count);
    if (reflected_classes == nullptr) {
        SF_THROW([AllocationFailedException allocationFailedException]);
    }
#if SF_RUNTIME_EXCEPTIONS
    __builtin_assume(reflected_classes != nullptr);
    return (Array<ReflectionClass *> *nonnil)reflected_classes;
#else
    return reflected_classes;
#endif
}

+ (SEL nillable)selectorNamed:(const char *nillable)name
{
    return name != nullptr ? sel_registerName(name) : nullptr;
}

@end

@implementation ReflectionClass

+ (instancetype nillable)classWithClass:(Class nillable)cls
{
    auto reflected_class = [[self allocWithAllocator:nullptr] initWithClass:cls];
    return [reflected_class autorelease];
}

+ (instancetype nillable)classNamed:(const char *nillable)name
{
    return name != nullptr ? [self classWithClass:(Class)objc_getClass(name)] : nullptr;
}

- (instancetype nillable)initWithClass:(Class nillable)cls
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }
    if (cls == nullptr) {
        [self release];
        return nullptr;
    }
    _reflectedClass = cls;
    return self;
}

- (Class)reflectedClass
{
    return _reflectedClass;
}

- (const char *nillable)name
{
    return class_getName(_reflectedClass);
}

- (String *nillable)nameString
{
    return reflection_string_from_cstr(self.name);
}

- (Class nillable)reflectedSuperclass
{
    return class_getSuperclass(_reflectedClass);
}

- (ReflectionClass *nillable)superclassReflection
{
    return [ReflectionClass classWithClass:self.reflectedSuperclass];
}

- (size_t)instanceSize
{
    return class_getInstanceSize(_reflectedClass);
}

- (Array<ReflectionMethod *> *nillable)instanceMethods
{
    return reflection_copy_methods_for_class(_reflectedClass, false, false);
}

- (Array<ReflectionMethod *> *nillable)allInstanceMethods
{
    return reflection_copy_methods_for_class(_reflectedClass, true, false);
}

- (Array<ReflectionMethod *> *nillable)classMethods
{
    return reflection_copy_methods_for_class(_reflectedClass, false, true);
}

- (Array<ReflectionMethod *> *nillable)allClassMethods
{
    return reflection_copy_methods_for_class(_reflectedClass, true, true);
}

- (Array<ReflectionIvar *> *nillable)instanceVariables
{
    return reflection_copy_ivars_for_class(_reflectedClass, false);
}

- (Array<ReflectionIvar *> *nillable)allInstanceVariables
{
    return reflection_copy_ivars_for_class(_reflectedClass, true);
}

- (Map<String *, ReflectionMethod *> *nillable)instanceMethodsByName
{
    return reflection_method_map_from_array(self.instanceMethods);
}

- (Map<String *, ReflectionMethod *> *nillable)allInstanceMethodsByName
{
    return reflection_method_map_from_array(self.allInstanceMethods);
}

- (Map<String *, ReflectionMethod *> *nillable)classMethodsByName
{
    return reflection_method_map_from_array(self.classMethods);
}

- (Map<String *, ReflectionMethod *> *nillable)allClassMethodsByName
{
    return reflection_method_map_from_array(self.allClassMethods);
}

- (Map<String *, ReflectionIvar *> *nillable)instanceVariablesByName
{
    return reflection_ivar_map_from_array(self.instanceVariables);
}

- (Map<String *, ReflectionIvar *> *nillable)allInstanceVariablesByName
{
    return reflection_ivar_map_from_array(self.allInstanceVariables);
}

- (bool)isSubclassOfClass:(Class nillable)cls
{
    if (cls == nullptr) {
        return false;
    }
    for (auto cursor = _reflectedClass; cursor != nullptr; cursor = class_getSuperclass(cursor)) {
        if (cursor == cls) {
            return true;
        }
    }
    return false;
}

- (bool)isSubclassOfReflectedClass:(ReflectionClass *nillable)cls
{
    return cls != nullptr and [self isSubclassOfClass:cls.reflectedClass];
}

- (ReflectionMethod *nillable)instanceMethodForSelector:(SEL nillable)selector
{
    return [ReflectionMethod methodWithMethod:class_getInstanceMethod(_reflectedClass, selector) ownerClass:self classMethod:false];
}

- (ReflectionMethod *nillable)instanceMethodNamed:(const char *nillable)name
{
    return [self instanceMethodForSelector:[Reflection selectorNamed:name]];
}

- (ReflectionMethod *nillable)classMethodForSelector:(SEL nillable)selector
{
    return [ReflectionMethod methodWithMethod:class_getClassMethod(_reflectedClass, selector) ownerClass:self classMethod:true];
}

- (ReflectionMethod *nillable)classMethodNamed:(const char *nillable)name
{
    return [self classMethodForSelector:[Reflection selectorNamed:name]];
}

- (ReflectionIvar *nillable)instanceVariableNamed:(const char *nillable)name
{
    return [ReflectionIvar ivarWithIvar:class_getInstanceVariable(_reflectedClass, name) ownerClass:self];
}

@end

@implementation ReflectionMethod

+ (instancetype nillable)methodWithMethod:(Method nillable)method
{
    return [self methodWithMethod:method ownerClass:nullptr classMethod:false];
}

+ (instancetype nillable)methodWithMethod:(Method nillable)method ownerClass:(ReflectionClass *nillable)ownerClass classMethod:(bool)classMethod
{
    auto reflected_method = [[self allocWithAllocator:nullptr] initWithMethod:method ownerClass:ownerClass classMethod:classMethod];
    return [reflected_method autorelease];
}

- (instancetype nillable)initWithMethod:(Method nillable)method ownerClass:(ReflectionClass *nillable)ownerClass classMethod:(bool)classMethod
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }
    if (method == nullptr) {
        [self release];
        return nullptr;
    }
    _method = method;
    _ownerClass = [ownerClass retain];
    _classMethod = classMethod;
    return self;
}

- (void)dealloc
{
    [_ownerClass release];
    [super dealloc];
}

- (Method)method
{
    return _method;
}

- (ReflectionClass *nillable)ownerClass
{
    return _ownerClass;
}

- (bool)isClassMethod
{
    return _classMethod;
}

- (bool)isInstanceMethod
{
    return not _classMethod;
}

- (SEL nillable)selector
{
    return method_getName(_method);
}

- (const char *nillable)name
{
    return sel_getName(self.selector);
}

- (String *nillable)nameString
{
    return reflection_string_from_cstr(self.name);
}

- (IMP nillable)implementation
{
    return method_getImplementation(_method);
}

- (const char *nillable)typeEncoding
{
    return method_getTypeEncoding(_method);
}

- (String *nillable)typeEncodingString
{
    return reflection_string_from_cstr(self.typeEncoding);
}

- (bool)matchesSelector:(SEL nillable)selector
{
    return selector != nullptr and sel_isEqual(self.selector, selector) != 0;
}

- (bool)matchesName:(const char *nillable)name
{
    auto method_name = self.name;
    return method_name != nullptr and name != nullptr and strcmp(method_name, name) == 0;
}

@end

@implementation ReflectionIvar

+ (instancetype nillable)ivarWithIvar:(Ivar nillable)ivar
{
    return [self ivarWithIvar:ivar ownerClass:nullptr];
}

+ (instancetype nillable)ivarWithIvar:(Ivar nillable)ivar ownerClass:(ReflectionClass *nillable)ownerClass
{
    auto reflected_ivar = [[self allocWithAllocator:nullptr] initWithIvar:ivar ownerClass:ownerClass];
    return [reflected_ivar autorelease];
}

- (instancetype nillable)initWithIvar:(Ivar nillable)ivar ownerClass:(ReflectionClass *nillable)ownerClass
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }
    if (ivar == nullptr) {
        [self release];
        return nullptr;
    }
    _ivar = ivar;
    _ownerClass = [ownerClass retain];
    return self;
}

- (void)dealloc
{
    [_ownerClass release];
    [super dealloc];
}

- (Ivar)ivar
{
    return _ivar;
}

- (ReflectionClass *nillable)ownerClass
{
    return _ownerClass;
}

- (const char *nillable)name
{
    return ivar_getName(_ivar);
}

- (String *nillable)nameString
{
    return reflection_string_from_cstr(self.name);
}

- (const char *nillable)typeEncoding
{
    return ivar_getTypeEncoding(_ivar);
}

- (String *nillable)typeEncodingString
{
    return reflection_string_from_cstr(self.typeEncoding);
}

- (ptrdiff_t)offset
{
    return ivar_getOffset(_ivar);
}

- (bool)matchesName:(const char *nillable)name
{
    auto ivar_name = self.name;
    return ivar_name != nullptr and name != nullptr and strcmp(ivar_name, name) == 0;
}

@end
