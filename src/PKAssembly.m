//  Copyright 2010 Todd Ditchendorf
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import <ParseKit/PKAssembly.h>

static NSString * const PKAssemblyDefaultDelimiter = @"/";

@interface PKAssembly ()
- (id)peek;
- (id)next;
- (BOOL)hasMore;
- (NSString *)consumedObjectsJoinedByString:(NSString *)delimiter;
- (NSString *)remainingObjectsJoinedByString:(NSString *)delimiter;

@property (nonatomic, readwrite, retain) NSMutableArray *stack;
@property (nonatomic) NSUInteger index;
@property (nonatomic, retain) NSString *string;
@property (nonatomic, readwrite, retain) NSString *defaultDelimiter;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly) NSUInteger objectsConsumed;
@property (nonatomic, readonly) NSUInteger objectsRemaining;
@end

@implementation PKAssembly

+ (PKAssembly *)assemblyWithString:(NSString *)s {
#if __has_feature(objc_arc)
    return [[self alloc] initWithString:s];
#else
    return [[[self alloc] initWithString:s] autorelease];
#endif
}


- (id)init {
    return [self initWithString:nil];
}


- (id)initWithString:(NSString *)s {
    if (self = [super init]) {
        self.stack = [NSMutableArray array];
        self.string = s;
    }
    return self;
}


- (void)dealloc {
    self.stack = nil;
    self.string = nil;
    self.target = nil;
    self.defaultDelimiter = nil;
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}


- (id)copyWithZone:(NSZone *)zone {
    // use of NSAllocateObject() below is a *massive* optimization over calling the designated initializer -initWithString: here.
    // this line (and this method in general) is *vital* to the overall performance of the framework. dont fuck with it.
#if __has_feature(objc_arc)
    PKAssembly *a = [[[self class] alloc] init];
#else
    PKAssembly *a = NSAllocateObject([self class], 0, zone);
#endif
    a->stack = [stack mutableCopyWithZone:zone];
#if __has_feature(objc_arc)
    a->string = string;
#else
    a->string = [string retain];
#endif
    if (defaultDelimiter) {
#if __has_feature(objc_arc)
        a->defaultDelimiter = defaultDelimiter;
#else
        a->defaultDelimiter = [defaultDelimiter retain];
#endif
    } else {
        a->defaultDelimiter = nil;
    }

    if (target) {
        if ([target conformsToProtocol:@protocol(NSMutableCopying)]) {
            a->target = [target mutableCopyWithZone:zone];
        } else {
            a->target = [target copyWithZone:zone];
        }
    } else {
        a->target = nil;
    }

    a->index = index;
    return a;
}


- (BOOL)isEqual:(id)obj {
    if (![obj isMemberOfClass:[self class]]) {
        return NO;
    }
    
    PKAssembly *a = (PKAssembly *)obj;
    if (a->index != index) {
        return NO;
    }
    
    if ([a length] != [self length]) {
        return NO;
    }

    if ([a.stack count] != [stack count]) {
        return NO;
    }
    
    return [[self description] isEqualToString:[obj description]];
}


- (id)next {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return nil;
}


- (BOOL)hasMore {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return NO;
}


- (NSString *)consumedObjectsJoinedByString:(NSString *)delimiter {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return nil;
}


- (NSString *)remainingObjectsJoinedByString:(NSString *)delimiter {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return nil;
}


- (NSUInteger)length {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return 0;
}


- (NSUInteger)objectsConsumed {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return 0;
}


- (NSUInteger)objectsRemaining {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return 0;
}


- (id)peek {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return nil;
}


- (id)pop {
    id result = nil;
    if (![self isStackEmpty]) {
#if __has_feature(objc_arc)
        result = [stack lastObject];
#else
        result = [[[stack lastObject] retain] autorelease];
#endif
        [stack removeLastObject];
    }
    return result;
}


- (void)push:(id)object {
    if (object) {
        [stack addObject:object];
    }
}


- (BOOL)isStackEmpty {
    return 0 == [stack count];
}


- (NSArray *)objectsAbove:(id)fence {
    NSMutableArray *result = [NSMutableArray array];
    
    while (![self isStackEmpty]) {        
        id obj = [self pop];
        
        if ([obj isEqual:fence]) {
            [self push:obj];
            break;
        } else {
            [result addObject:obj];
        }
    }
    
    return result;
}


- (NSString *)description {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"["];
    
    NSUInteger i = 0;
    NSUInteger len = [stack count];
    
    for (id obj in stack) {
        [s appendString:[obj description]];
        if (len - 1 != i++) {
            [s appendString:@", "];
        }
    }
    
    [s appendString:@"]"];
    
    NSString *d = defaultDelimiter ? defaultDelimiter : PKAssemblyDefaultDelimiter;
    [s appendString:[self consumedObjectsJoinedByString:d]];
    [s appendString:@"^"];
    [s appendString:[self remainingObjectsJoinedByString:d]];
    
#if __has_feature(objc_arc)
    return [s copy];
#else
    return [[s copy] autorelease];
#endif
}

@synthesize stack;
@synthesize target;
@synthesize index;
@synthesize string;
@synthesize defaultDelimiter;
@end
