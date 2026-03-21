#import "runtime/objc/runtime_exports.h"
#import "smallfw/Object.h"

#include <stdio.h>

static void wasm_example_print_bool(const char *label, int value)
{
    printf("%-16s %s\n", label, value ? "yes" : "no");
}

static void wasm_example_print_text(const char *label, const char *value)
{
    printf("%-16s %s\n", label, value);
}

int main(void)
{
    Object *root = [[Object allocWithAllocator:nullptr] init];
    Object *child = [[Object allocWithParent:root] init];

    if (root == nil || child == nil) {
        fprintf(stderr, "failed to boot wasm runtime smoke example\n");
        return 1;
    }

    puts("SmallFW plain WASM smoke");
    wasm_example_print_text("rootClass", class_getName(root.class));
    wasm_example_print_text("childClass", class_getName(child.class));
    wasm_example_print_bool("parentLinked", child.parent == root);
    wasm_example_print_bool("sharedAlloc", child.allocator == root.allocator);
    wasm_example_print_bool("kindOfObject", [child isKindOfClass:Object.class]);

    objc_release(child);
    objc_release(root);
    return 0;
}
