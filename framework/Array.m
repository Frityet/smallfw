#include "Array.h"
#include <string.h>

@implementation Array

- (instancetype)initWithItems: (const id [])val count: (size_t)count
{
    if ((self = [super init])) {
        _count = count;
        id *tmp = [self allocateMemoryWithSize: sizeof(id) * count alignment: _Alignof(id)];
        if (tmp == NULL)
            return NULL;

        for (size_t i = 0; i < count; i++) {
            tmp[i] = [val[i] retain];
        }

        _items = (id *)tmp;
    }
    return self;
}

- (id)objectAtIndexedSubscript:(size_t)idx
{
    return _items[idx];
}

- (void)dealloc
{
    for (size_t i = 0; i < _count; i++) {
        if (_items[i]) {
            [_items[i] release];
        }
    }
    [super dealloc];
}

@end
