#include "smallfw/Object.h"
#include "StandardLibrary/String.h"
#include "StandardLibrary/Number.h"

#include <stdio.h>

[[clang::sf_encode_generics]]
@interface Box<T> : Object

@property(readonly, nonatomic) T data;

- (instancetype)initWithValue: (T)x;

@end

@implementation Box

- (instancetype)initWithValue: (id)x
{
    self = [super init];
    if (self == nullptr) {
        return nullptr;
    }
    _data = x;
    return self;
}

- (void)validate
{
    if ([_data class] != self.genericTypeClass)
        @throw [[InvalidArgumentException allocWithParent: self] init];
}

@end

int main(void)
{
    @try {
        auto x = [[Box<String *> allocWithAllocator: nullptr] initWithValue: @"hello"];
        [x validate];
        printf("%s\n", x.data.UTF8String);

        auto invalid = [[Box<String *> allocWithAllocator: nullptr] initWithValue: (String *)@0];
        [invalid validate];
        printf("%s\n", invalid.data.UTF8String);
    } @catch (id) {
        printf("Caught exception");
    }
}
