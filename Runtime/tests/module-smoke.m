@import SFRuntime;
@import SFBlocksRuntime;

int main(void)
{
    if (Object.class != objc_getClass("Object")) {
        return 1;
    }
    auto objectEncoding = Object.encoding;
    if (objectEncoding == NULL or not objectEncoding->type.valid or objectEncoding->type.kind != SF_ENCODING_KIND_OBJECT or not sf_encoding_text_equal_cstr(objectEncoding->name, "Object")) {
        return 2;
    }
    auto object = [Object allocWithAllocator:NULL];
    if (object == nil) {
        return 3;
    }
    auto instanceEncoding = object.encoding;
    if (instanceEncoding == NULL or not instanceEncoding->type.valid or instanceEncoding->type.kind != SF_ENCODING_KIND_OBJECT or not sf_encoding_text_equal_cstr(instanceEncoding->name, "Object")) {
        [object release];
        return 4;
    }
    [object release];

    auto pointerEncoding = sf_encoding_parse("r^{Pair=ii}");
    if (pointerEncoding == NULL or not pointerEncoding->type.valid or pointerEncoding->type.kind != SF_ENCODING_KIND_POINTER or pointerEncoding->type.pointerDepth != 1U or (pointerEncoding->type.qualifiers & SF_ENCODING_QUALIFIER_CONST) == 0U) {
        return 5;
    }
    auto methodEncoding = sf_method_encoding_parse("i16@?0i8");
    if (methodEncoding == NULL or not methodEncoding->state.valid or methodEncoding->signature.returnType.type.kind != SF_ENCODING_KIND_INT or methodEncoding->signature.argumentCount != 2U or methodEncoding->signature.arguments[0].value.type.type.kind != SF_ENCODING_KIND_BLOCK or methodEncoding->signature.arguments[1].value.type.type.kind != SF_ENCODING_KIND_INT) {
        return 6;
    }
    auto propertyEncoding = sf_property_encoding_parse("T@\"Object\",&,N,V_object");
    if (propertyEncoding == NULL or not propertyEncoding->state.valid or propertyEncoding->value.type.type.kind != SF_ENCODING_KIND_OBJECT or propertyEncoding->value.ownership != SF_PROPERTY_ENCODING_OWNERSHIP_STRONG or not propertyEncoding->state.nonatomic or not sf_encoding_text_equal_cstr(propertyEncoding->ivarName, "_object")) {
        return 7;
    }

    int captured = 41;
    int (^stackBlock)(void) = ^{
        return captured + 1;
    };
    int (^globalBlock)(int) = ^(int value) {
        return value + 1;
    };

    auto global = (Block *)(id)globalBlock;
    if (![global isKindOfClass:GlobalBlock.class]) {
        return 8;
    }
    if (object_getClass((id)globalBlock) != GlobalBlock.class) {
        return 9;
    }
    if (![global isKindOfClass:Block.class] or global.size == 0U or global.descriptorPointer == NULL or global.invokePointer == NULL) {
        return 10;
    }
    if (global.copyHelperPointer != NULL or global.disposeHelperPointer != NULL or global.capturedVariablesPointer != NULL or global.capturedVariablesSize != 0U) {
        return 11;
    }
    auto blockEncoding = global.methodEncoding;
    if (blockEncoding == NULL or not blockEncoding->state.valid or blockEncoding->signature.returnType.type.kind != SF_ENCODING_KIND_INT or blockEncoding->signature.argumentCount != 2U or blockEncoding->signature.arguments[0].value.type.type.kind != SF_ENCODING_KIND_BLOCK or blockEncoding->signature.arguments[1].value.type.type.kind != SF_ENCODING_KIND_INT) {
        return 12;
    }

    auto stack = (Block *)(id)stackBlock;
    if (![stack isKindOfClass:StackBlock.class] or stack.capturedVariablesPointer == NULL or stack.capturedVariablesSize == 0U) {
        return 13;
    }

    int (^heapBlock)(void) = Block_copy(stackBlock);
    auto heap = (HeapBlock *)(id)heapBlock;
    if (![heap isKindOfClass:HeapBlock.class] or object_getClass((id)heapBlock) != HeapBlock.class) {
        Block_release(heapBlock);
        return 14;
    }
    if (![heap isKindOfClass:Block.class] or heap.size != stack.size or heap.allocationSize < heap.size or heap.allocator == NULL) {
        Block_release(heapBlock);
        return 15;
    }
    if (heapBlock() != 42 or globalBlock(8) != 9) {
        Block_release(heapBlock);
        return 16;
    }
    Block_release(heapBlock);
    return 0;
}
