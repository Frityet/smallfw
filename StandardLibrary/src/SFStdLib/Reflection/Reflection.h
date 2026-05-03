#pragma once

#import "SFStdLib/Collections/Array.h"
#import "SFStdLib/Collections/Map.h"
#import "SFStdLib/String.h"

#include <stdbool.h>
#include <stddef.h>

#pragma clang assume_nonnull begin

@class ReflectionClass;
@class ReflectionMethod;
@class ReflectionIvar;

@interface Reflection : Object
+ (ReflectionClass *nillable)classWithClass:(Class nillable)cls;
+ (ReflectionClass *nillable)classNamed:(const char *nillable)name;
+ (ReflectionClass *nillable)classOfObject:(Object *nillable)object;
+ (SF_ERRORABLE(Array<ReflectionClass *> *))allClasses;
+ (SEL nillable)selectorNamed:(const char *nillable)name;
@end

@interface ReflectionClass : Object {
  @private
    Class _reflectedClass;
}

@property(nonatomic, readonly) Class reflectedClass;
@property(nonatomic, readonly) const char *nillable name;
@property(nonatomic, readonly) String *nillable nameString;
@property(nonatomic, readonly) Class nillable reflectedSuperclass;
@property(nonatomic, readonly) ReflectionClass *nillable superclassReflection;
@property(nonatomic, readonly) size_t instanceSize;
@property(nonatomic, readonly) Array<ReflectionMethod *> *nillable instanceMethods;
@property(nonatomic, readonly) Array<ReflectionMethod *> *nillable allInstanceMethods;
@property(nonatomic, readonly) Array<ReflectionMethod *> *nillable classMethods;
@property(nonatomic, readonly) Array<ReflectionMethod *> *nillable allClassMethods;
@property(nonatomic, readonly) Array<ReflectionIvar *> *nillable instanceVariables;
@property(nonatomic, readonly) Array<ReflectionIvar *> *nillable allInstanceVariables;
@property(nonatomic, readonly) Map<String *, ReflectionMethod *> *nillable instanceMethodsByName;
@property(nonatomic, readonly) Map<String *, ReflectionMethod *> *nillable allInstanceMethodsByName;
@property(nonatomic, readonly) Map<String *, ReflectionMethod *> *nillable classMethodsByName;
@property(nonatomic, readonly) Map<String *, ReflectionMethod *> *nillable allClassMethodsByName;
@property(nonatomic, readonly) Map<String *, ReflectionIvar *> *nillable instanceVariablesByName;
@property(nonatomic, readonly) Map<String *, ReflectionIvar *> *nillable allInstanceVariablesByName;

+ (instancetype nillable)classWithClass:(Class nillable)cls;
+ (instancetype nillable)classNamed:(const char *nillable)name;
- (instancetype nillable)initWithClass:(Class nillable)cls;
- (bool)isSubclassOfClass:(Class nillable)cls;
- (bool)isSubclassOfReflectedClass:(ReflectionClass *nillable)cls;
- (ReflectionMethod *nillable)instanceMethodForSelector:(SEL nillable)selector;
- (ReflectionMethod *nillable)instanceMethodNamed:(const char *nillable)name;
- (ReflectionMethod *nillable)classMethodForSelector:(SEL nillable)selector;
- (ReflectionMethod *nillable)classMethodNamed:(const char *nillable)name;
- (ReflectionIvar *nillable)instanceVariableNamed:(const char *nillable)name;
@end

@interface ReflectionMethod : Object {
  @private
    Method _method;
    ReflectionClass *nillable _ownerClass;
    bool _classMethod;
}

@property(nonatomic, readonly) Method method;
@property(nonatomic, readonly) ReflectionClass *nillable ownerClass;
@property(nonatomic, readonly, getter=isClassMethod) bool classMethod;
@property(nonatomic, readonly, getter=isInstanceMethod) bool instanceMethod;
@property(nonatomic, readonly) SEL nillable selector;
@property(nonatomic, readonly) const char *nillable name;
@property(nonatomic, readonly) String *nillable nameString;
@property(nonatomic, readonly) IMP nillable implementation;
@property(nonatomic, readonly) const char *nillable typeEncoding;
@property(nonatomic, readonly) String *nillable typeEncodingString;

+ (instancetype nillable)methodWithMethod:(Method nillable)method;
+ (instancetype nillable)methodWithMethod:(Method nillable)method ownerClass:(ReflectionClass *nillable)ownerClass classMethod:(bool)classMethod;
- (instancetype nillable)initWithMethod:(Method nillable)method ownerClass:(ReflectionClass *nillable)ownerClass classMethod:(bool)classMethod;
- (bool)matchesSelector:(SEL nillable)selector;
- (bool)matchesName:(const char *nillable)name;
@end

@interface ReflectionIvar : Object {
  @private
    Ivar _ivar;
    ReflectionClass *nillable _ownerClass;
}

@property(nonatomic, readonly) Ivar ivar;
@property(nonatomic, readonly) ReflectionClass *nillable ownerClass;
@property(nonatomic, readonly) const char *nillable name;
@property(nonatomic, readonly) String *nillable nameString;
@property(nonatomic, readonly) const char *nillable typeEncoding;
@property(nonatomic, readonly) String *nillable typeEncodingString;
@property(nonatomic, readonly) ptrdiff_t offset;

+ (instancetype nillable)ivarWithIvar:(Ivar nillable)ivar;
+ (instancetype nillable)ivarWithIvar:(Ivar nillable)ivar ownerClass:(ReflectionClass *nillable)ownerClass;
- (instancetype nillable)initWithIvar:(Ivar nillable)ivar ownerClass:(ReflectionClass *nillable)ownerClass;
- (bool)matchesName:(const char *nillable)name;
@end

#pragma clang assume_nonnull end
