@import SFRuntime;
@import SFBlocksRuntime;

int main(void)
{
    if (Object.class != objc_getClass("Object")) {
        return 1;
    }
    auto objectEncoding = Object.encoding;
    if (objectEncoding == NULL || !objectEncoding->type.valid || objectEncoding->type.kind != SF_ENCODING_KIND_OBJECT || !sf_encoding_text_equal_cstr(objectEncoding->name, "Object")) {
        return 2;
    }
    auto object = [Object allocWithAllocator:NULL];
    if (object == nil) {
        return 3;
    }
    auto instanceEncoding = object.encoding;
    if (instanceEncoding == NULL || !instanceEncoding->type.valid || instanceEncoding->type.kind != SF_ENCODING_KIND_OBJECT || !sf_encoding_text_equal_cstr(instanceEncoding->name, "Object")) {
        [object release];
        return 4;
    }
    [object release];

    auto pointerEncoding = sf_encoding_parse("r^{Pair=ii}");
    if (pointerEncoding == NULL || !pointerEncoding->type.valid || pointerEncoding->type.kind != SF_ENCODING_KIND_POINTER || pointerEncoding->type.pointerDepth != 1U || (pointerEncoding->type.qualifiers & SF_ENCODING_QUALIFIER_CONST) == 0U) {
        return 5;
    }
    auto methodEncoding = sf_method_encoding_parse("i16@?0i8");
    if (methodEncoding == NULL || !methodEncoding->state.valid || methodEncoding->signature.returnType.type.kind != SF_ENCODING_KIND_INT || methodEncoding->signature.argumentCount != 2U || methodEncoding->signature.arguments[0].value.type.type.kind != SF_ENCODING_KIND_BLOCK || methodEncoding->signature.arguments[1].value.type.type.kind != SF_ENCODING_KIND_INT) {
        return 6;
    }
    auto propertyEncoding = sf_property_encoding_parse("T@\"Object\",&,N,V_object");
    if (propertyEncoding == NULL || !propertyEncoding->state.valid || propertyEncoding->value.type.type.kind != SF_ENCODING_KIND_OBJECT || propertyEncoding->value.ownership != SF_PROPERTY_ENCODING_OWNERSHIP_STRONG || !propertyEncoding->state.nonatomic || !sf_encoding_text_equal_cstr(propertyEncoding->ivarName, "_object")) {
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
    if (![global isKindOfClass:Block.class] || global.size == 0U || global.descriptorPointer == NULL || global.invokePointer == NULL) {
        return 10;
    }
    if (global.copyHelperPointer != NULL || global.disposeHelperPointer != NULL || global.capturedVariablesPointer != NULL || global.capturedVariablesSize != 0U) {
        return 11;
    }
    auto blockEncoding = global.methodEncoding;
    if (blockEncoding == NULL || !blockEncoding->state.valid || blockEncoding->signature.returnType.type.kind != SF_ENCODING_KIND_INT || blockEncoding->signature.argumentCount != 2U || blockEncoding->signature.arguments[0].value.type.type.kind != SF_ENCODING_KIND_BLOCK || blockEncoding->signature.arguments[1].value.type.type.kind != SF_ENCODING_KIND_INT) {
        return 12;
    }

    auto stack = (Block *)(id)stackBlock;
    if (![stack isKindOfClass:StackBlock.class] || stack.capturedVariablesPointer == NULL || stack.capturedVariablesSize == 0U) {
        return 13;
    }

    int (^heapBlock)(void) = Block_copy(stackBlock);
    auto heap = (HeapBlock *)(id)heapBlock;
    if (![heap isKindOfClass:HeapBlock.class] || object_getClass((id)heapBlock) != HeapBlock.class) {
        Block_release(heapBlock);
        return 14;
    }
    if (![heap isKindOfClass:Block.class] || heap.size != stack.size || heap.allocationSize < heap.size || heap.allocator == NULL) {
        Block_release(heapBlock);
        return 15;
    }
    if (heapBlock() != 42 || globalBlock(8) != 9) {
        Block_release(heapBlock);
        return 16;
    }
    Block_release(heapBlock);
    return 0;
}
