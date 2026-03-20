#include "smallfw/Object.h"
#include "StandardLibrary/String.h"
#include "StandardLibrary/Number.h"

#include <stdio.h>

[[sf_encode_generics]]
@interface Box<T> : Object

@property(readonly, nonatomic) T data;

- (instancetype)initWithValue: (T)x;

@end

@implementation Box

- (instancetype)initWithValue: (id)x
{
    self = [super init];
    _data = x;
    if ([x class] != self.genericTypeClass)
        @throw [InvalidArgumentException exception];
    return self;
}

@end

int main(void)
{
    @try {
        auto x = [[Box<String *> allocWithAllocator: nullptr] initWithValue: @"hello"];
        printf("%s\n", x.data.UTF8String);

        auto invalid = [[Box<String *> allocWithAllocator: nullptr] initWithValue: (String *)@0];
        printf("%s\n", invalid.data.UTF8String);
    } @catch (id) {
        printf("Caught exception");
    }
}
