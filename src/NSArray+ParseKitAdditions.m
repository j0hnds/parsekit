//
//  NSArray+ParseKitAdditions.m
//  ParseKit
//
//  Created by Todd Ditchendorf on 12/16/08.
//  Copyright 2009 Todd Ditchendorf. All rights reserved.
//

#import "NSArray+ParseKitAdditions.h"

@implementation NSArray (ParseKitAdditions)

- (NSArray *)reversedArray {
#if __has_feature(objc_arc)
    return [[self reversedMutableArray] copy];
#else
    return [[[self reversedMutableArray] copy] autorelease];
#endif
}


- (NSMutableArray *)reversedMutableArray {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self count]];
    for (id obj in [self reverseObjectEnumerator]) {
        [result addObject:obj];
    }
    return result;
}

@end
