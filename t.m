#include <stdio.h>

__attribute__((objc_root_class, objc_direct_members))
@interface Math

+ (int)add:(int)a to:(int)b;

@end

@implementation Math

+ (int)add:(int)a to:(int)b
{
    return a + b;
}

@end

int main(void)
{
    int result = [Math add:2 to:3];
    printf("Result: %d\n", result);
    return 0;
}
