#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "smallfw/Object.h"
#include "runtime/objc/runtime_exports.h"

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-objc-pointer-introspection"
#pragma clang diagnostic ignored "-Wdollar-in-identifier-extension"
#pragma clang diagnostic ignored "-Wdirect-ivar-access"
#pragma clang diagnostic ignored "-Wobjc-interface-ivars"
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#endif

#if !SF_RUNTIME_FORWARDING
#error "Build this example with runtime forwarding enabled (for example: xmake f --runtime_forwarding=y)."
#endif

#ifndef nil
#define nil ((id)0)
#endif

@interface NSArray : Object {
@public
    unsigned long _count;
    id *_objects;
}
+ (instancetype)arrayWithObjects:(const id [])objects count:(unsigned long)count;
- (unsigned long)count;
- (id)objectAtIndex:(unsigned long)index;
@end

@interface NSConstantString : Object {
@public
    uint32_t _flags;
    uint32_t _length;
    uint32_t _size;
    uint32_t _hash;
    const char *_data;
}
@end

@class HTMLNode;

@interface HTMLTagEmitter : Object {
@public
    const char *_tag_name;
}
- (instancetype)initWithTagName:(const char *)tagName;
- (HTMLNode *)children:(NSArray *)children;
- (HTMLNode *)id:(id)nodeId children:(NSArray *)children;
- (HTMLNode *)class:(id)className children:(NSArray *)children;
- (HTMLNode *)id:(id)nodeId class:(id)className children:(NSArray *)children;
- (HTMLNode *)id:(id)nodeId class:(id)className some_other_property:(id)value children:(NSArray *)children;
@end

@interface HTMLTagProxy : Object {
@public
    __unsafe_unretained HTMLTagEmitter *_emitter;
}
- (instancetype)initWithTagName:(const char *)tagName;
@end

@interface HTMLTagProxy (DSL)
- (HTMLNode *)children:(NSArray *)children;
- (HTMLNode *)id:(id)nodeId children:(NSArray *)children;
- (HTMLNode *)class:(id)className children:(NSArray *)children;
- (HTMLNode *)id:(id)nodeId class:(id)className children:(NSArray *)children;
- (HTMLNode *)id:(id)nodeId class:(id)className some_other_property:(id)value children:(NSArray *)children;
@end

@interface HTMLNode : Object {
@public
    const char *_tag_name;
    __unsafe_unretained id _node_id;
    __unsafe_unretained id _class_name;
    __unsafe_unretained id _some_other_property;
    __unsafe_unretained NSArray *_children;
}
- (instancetype)initWithTagName:(const char *)tagName
                         nodeId:(id)nodeId
                       className:(id)className
               someOtherProperty:(id)value
                        children:(NSArray *)children;
- (void)renderToFile:(FILE *)file;
@end

static Object *sf_html_alloc(Class cls) {
    return [cls allocWithAllocator:sf_default_allocator()];
}

static HTMLTagProxy *sf_html_tag(const char *tagName) {
    HTMLTagProxy *proxy = [(HTMLTagProxy *)sf_html_alloc((Class)objc_getClass("HTMLTagProxy"))
        initWithTagName:tagName];
    return (HTMLTagProxy *)objc_autoreleaseReturnValue(proxy);
}

#define $(tag_name) sf_html_tag((tag_name))

static int sf_html_is_small_ascii_string(id value) {
    return value != nil && ((((uintptr_t)value) & (uintptr_t)7U) == (uintptr_t)4U);
}

static unsigned long sf_html_small_ascii_length(id value) {
    return (unsigned long)((((uintptr_t)value) >> 3U) & (uintptr_t)0xfU);
}

static int sf_html_is_constant_string(id value) {
    return value != nil &&
           !sf_html_is_small_ascii_string(value) &&
           *(Class *)value == (Class)objc_getClass("NSConstantString");
}

static const char *sf_html_cstring(id value, char scratch[9]) {
    if (value == nil) {
        return "";
    }
    if (sf_html_is_small_ascii_string(value)) {
        uintptr_t bits = (uintptr_t)value;
        unsigned long length = sf_html_small_ascii_length(value);
        for (unsigned long i = 0; i < length; ++i) {
            unsigned long shift = 57U - (unsigned long)(i * 7U);
            scratch[i] = (char)((bits >> shift) & (uintptr_t)0x7fU);
        }
        scratch[length] = '\0';
        return scratch;
    }
    if (sf_html_is_constant_string(value)) {
        return ((NSConstantString *)value)->_data;
    }
    return "";
}

static void sf_html_write_escaped(FILE *file, const char *text) {
    for (const unsigned char *p = (const unsigned char *)text; *p != '\0'; ++p) {
        switch (*p) {
            case '&':
                (void)fputs("&amp;", file);
                break;
            case '<':
                (void)fputs("&lt;", file);
                break;
            case '>':
                (void)fputs("&gt;", file);
                break;
            case '"':
                (void)fputs("&quot;", file);
                break;
            default:
                (void)fputc((int)*p, file);
                break;
        }
    }
}

static void sf_html_render_attr(FILE *file, const char *name, id value) {
    char scratch[9];
    if (value == nil) {
        return;
    }
    (void)fprintf(file, " %s=\"", name);
    sf_html_write_escaped(file, sf_html_cstring(value, scratch));
    (void)fputc('"', file);
}

static void sf_html_render_value(FILE *file, id value) {
    char scratch[9];

    if (value == nil || sf_html_is_small_ascii_string(value) || sf_html_is_constant_string(value)) {
        sf_html_write_escaped(file, sf_html_cstring(value, scratch));
        return;
    }
    if (*(Class *)value == (Class)objc_getClass("HTMLNode")) {
        [(HTMLNode *)value renderToFile:file];
    }
}

@implementation NSArray
+ (instancetype)arrayWithObjects:(const id [])objects count:(unsigned long)count {
    NSArray *array = (NSArray *)[sf_html_alloc((Class)self) init];
    array->_count = count;
    if (count == 0) {
        array->_objects = NULL;
        return array;
    }
    array->_objects = (id *)calloc((size_t)count, sizeof(id));
    if (array->_objects == NULL) {
        return array;
    }
    for (unsigned long i = 0; i < count; ++i) {
        array->_objects[i] = objc_retain(objects[i]);
    }
    return array;
}

- (void)dealloc {
    if (_objects != NULL) {
        for (unsigned long i = 0; i < _count; ++i) {
            objc_release(_objects[i]);
        }
        free(_objects);
        _objects = NULL;
    }
    _count = 0;
}

- (unsigned long)count {
    return _count;
}

- (id)objectAtIndex:(unsigned long)index {
    if (index >= _count || _objects == NULL) {
        return nil;
    }
    return _objects[index];
}
@end

@implementation NSConstantString
@end

@interface HTMLTagEmitter (Builder)
- (HTMLNode *)nodeWithId:(id)nodeId className:(id)className someOtherProperty:(id)value children:(NSArray *)children;
@end

@implementation HTMLTagEmitter
- (instancetype)initWithTagName:(const char *)tagName {
    self = [super init];
    if (self != nil) {
        _tag_name = tagName;
    }
    return self;
}

- (HTMLNode *)nodeWithId:(id)nodeId className:(id)className someOtherProperty:(id)value children:(NSArray *)children {
    HTMLNode *node = (HTMLNode *)sf_html_alloc((Class)objc_getClass("HTMLNode"));
    return [node initWithTagName:_tag_name
                          nodeId:nodeId
                        className:className
                someOtherProperty:value
                         children:children];
}

- (HTMLNode *)children:(NSArray *)children {
    return [self nodeWithId:nil className:nil someOtherProperty:nil children:children];
}

- (HTMLNode *)id:(id)nodeId children:(NSArray *)children {
    return [self nodeWithId:nodeId className:nil someOtherProperty:nil children:children];
}

- (HTMLNode *)class:(id)className children:(NSArray *)children {
    return [self nodeWithId:nil className:className someOtherProperty:nil children:children];
}

- (HTMLNode *)id:(id)nodeId class:(id)className children:(NSArray *)children {
    return [self nodeWithId:nodeId className:className someOtherProperty:nil children:children];
}

- (HTMLNode *)id:(id)nodeId class:(id)className some_other_property:(id)value children:(NSArray *)children {
    return [self nodeWithId:nodeId className:className someOtherProperty:value children:children];
}
@end

@implementation HTMLTagProxy
- (instancetype)initWithTagName:(const char *)tagName {
    self = [super init];
    if (self != nil) {
        _emitter = objc_retain([(HTMLTagEmitter *)sf_html_alloc((Class)objc_getClass("HTMLTagEmitter"))
            initWithTagName:tagName]);
    }
    return self;
}

- (void)dealloc {
    objc_release(_emitter);
}

- (id)forwardingTargetForSelector:(SEL)selector {
    (void)selector;
    return _emitter;
}
@end

@implementation HTMLNode
- (instancetype)initWithTagName:(const char *)tagName
                         nodeId:(id)nodeId
                       className:(id)className
               someOtherProperty:(id)value
                        children:(NSArray *)children {
    self = [super init];
    if (self != nil) {
        _tag_name = tagName;
        _node_id = objc_retain(nodeId);
        _class_name = objc_retain(className);
        _some_other_property = objc_retain(value);
        _children = objc_retain(children);
    }
    return self;
}

- (void)dealloc {
    objc_release(_node_id);
    objc_release(_class_name);
    objc_release(_some_other_property);
    objc_release(_children);
}

- (void)renderToFile:(FILE *)file {
    (void)fprintf(file, "<%s", _tag_name);
    sf_html_render_attr(file, "id", _node_id);
    sf_html_render_attr(file, "class", _class_name);
    sf_html_render_attr(file, "some_other_property", _some_other_property);
    (void)fputc('>', file);
    if (_children != nil) {
        for (unsigned long i = 0; i < [_children count]; ++i) {
            sf_html_render_value(file, [_children objectAtIndex:i]);
        }
    }
    (void)fprintf(file, "</%s>", _tag_name);
}
@end

int main(void) {
    void *pool = objc_autoreleasePoolPush();

    HTMLNode *page = [$("div") id:@"test" class:@"whatever" some_other_property:@"..." children:@[
        @"hello",
        [$("span") class:@"chip" children:@[@"world"]],
        [$("ul") children:@[
            [$("li") children:@[@"one"]],
            [$("li") children:@[@"two"]],
        ]],
    ]];

    [page renderToFile:stdout];
    (void)fputc('\n', stdout);

    objc_autoreleasePoolPop(pool);
    return 0;
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
