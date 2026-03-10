__attribute__((objc_root_class))
@interface DemoRoot
+ (instancetype)alloc;
- (instancetype)init;
- (id)copy;
@end

@protocol DemoValueProviding
- (int)value;
@end

@interface DemoLeaf : DemoRoot <DemoValueProviding> {
    int _count;
}

@property (class, nonatomic, readonly) int magic;
@property (nonatomic, strong) id payload;

- (id)copy;
- (int)value;
@end

@implementation DemoLeaf
+ (int)magic {
    return 7;
}

- (id)copy {
    return self;
}

- (int)value {
    return _count;
}
@end

id makeLeaf(id value) {
    DemoLeaf *obj = [[DemoLeaf alloc] init];
    return value ? value : [obj copy];
}
