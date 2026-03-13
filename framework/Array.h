#import <smallfw/Object.h>

#pragma clang assume_nonnull begin

@protocol Indexable

- (id)objectAtIndexedSubscript: (size_t)idx;

@end

@interface Array<T> : Object<Indexable> {
    @private T *_Nonnull _items;
}

@property (nonatomic, readonly) size_t count;

- (instancetype)initWithItems: (const _Nonnull T [])val count: (size_t)count;

- (T)objectAtIndexedSubscript:(size_t)idx;

@end

@compatibility_alias NSArray Array; //for @[]

#pragma clang assume_nonnull end
