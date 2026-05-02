@import SFRuntime;

int main(void)
{
    Object *obj = [[Object allocWithAllocator:nullptr] init];
    return obj == nullptr;
}
