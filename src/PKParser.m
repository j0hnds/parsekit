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

#import <ParseKit/PKParser.h>
#import <ParseKit/PKAssembly.h>
#import <ParseKit/PKTokenAssembly.h>
#import <ParseKit/PKTokenizer.h>

@interface PKAssembly ()
- (BOOL)hasMore;
@property (nonatomic, readonly) NSUInteger objectsConsumed;
@end

@interface PKParser ()
- (NSSet *)matchAndAssemble:(NSSet *)inAssemblies;
- (PKAssembly *)best:(NSSet *)inAssemblies;
@end

@interface PKParser (PKParserFactoryAdditionsFriend)
- (void)setTokenizer:(PKTokenizer *)t;
@end

@implementation PKParser

+ (PKParser *)parser {
#if __has_feature(objc_arc)
    return [[self alloc] init];
#else
    return [[[self alloc] init] autorelease];
#endif
}


- (void)dealloc {
    self.assemblerBlock = nil;
    self.preassemblerBlock = nil;
    self.assembler = nil;
    self.assemblerSelector = nil;
    self.preassembler = nil;
    self.preassemblerSelector = nil;
    self.name = nil;
    self.tokenizer = nil;
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}


- (void)setAssembler:(id)a selector:(SEL)sel {
    self.assembler = a;
    self.assemblerSelector = sel;
}


- (void)setPreassembler:(id)a selector:(SEL)sel {
    self.preassembler = a;
    self.preassemblerSelector = sel;
}


- (PKParser *)parserNamed:(NSString *)s {
    if ([name isEqualToString:s]) {
        return self;
    }
    return nil;
}


- (NSSet *)allMatchesFor:(NSSet *)inAssemblies {
    NSAssert1(0, @"%s must be overriden", __PRETTY_FUNCTION__);
    return nil;
}


- (PKAssembly *)bestMatchFor:(PKAssembly *)a {
    NSParameterAssert(a);
    NSSet *initialState = [NSSet setWithObject:a];
    NSSet *finalState = [self matchAndAssemble:initialState];
    return [self best:finalState];
}


- (PKAssembly *)completeMatchFor:(PKAssembly *)a {
    NSParameterAssert(a);
    PKAssembly *best = [self bestMatchFor:a];
    if (best && ![best hasMore]) {
        return best;
    }
    return nil;
}


- (NSSet *)matchAndAssemble:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    
#define CONCURRENT 0

    if (preassemblerBlock) {
        for (PKAssembly *a in inAssemblies) {
            preassemblerBlock(self, a);
        }
    } else if (preassembler) {
        NSAssert2([preassembler respondsToSelector:preassemblerSelector], @"provided preassembler %@ should respond to %@", preassembler, NSStringFromSelector(preassemblerSelector));
        for (PKAssembly *a in inAssemblies) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [preassembler performSelector:preassemblerSelector withObject:self withObject:a];
#pragma clang diagnostic pop
        }
    }
    
    // get current input string offset
    
    // lookup offset in -memo ivar and return assemblies if present.
    
    // else…
    
    NSSet *outAssemblies = [self allMatchesFor:inAssemblies];

    // memoize outAssemblies in -memo ivar {offset=>outAssemblies}

    if (assemblerBlock) {
        for (PKAssembly *a in outAssemblies) {
            assemblerBlock(self, a);
        }
    } else if (assembler) {
        NSAssert2([assembler respondsToSelector:assemblerSelector], @"provided assembler %@ should respond to %@", assembler, NSStringFromSelector(assemblerSelector));
#if CONCURRENT
        dispatch_group_t myGroup = dispatch_group_create();
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
#endif
        for (PKAssembly *a in outAssemblies) {
#if CONCURRENT
            dispatch_group_async(myGroup, queue, ^{
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [assembler performSelector:assemblerSelector withObject:self withObject:a];
#pragma clang diagnostic pop
#if CONCURRENT
            });
            dispatch_group_wait(myGroup, DISPATCH_TIME_FOREVER);
#endif
        }
#if CONCURRENT
        dispatch_release(myGroup);
#endif
    }
    return outAssemblies;
}


- (PKAssembly *)best:(NSSet *)inAssemblies {
    NSParameterAssert(inAssemblies);
    PKAssembly *best = nil;
    
    for (PKAssembly *a in inAssemblies) {
        if (![a hasMore]) {
            best = a;
            break;
        }
        if (!best || a.objectsConsumed > best.objectsConsumed) {
            best = a;
        }
    }
    
    return best;
}


- (NSString *)description {
    NSString *className = [NSStringFromClass([self class]) substringFromIndex:2];
    if ([name length]) {
        return [NSString stringWithFormat:@"%@ (%@)", className, name];
    } else {
        return [NSString stringWithFormat:@"%@", className];
    }
}

@synthesize assemblerBlock;
@synthesize preassemblerBlock;
@synthesize assembler;
@synthesize assemblerSelector;
@synthesize preassembler;
@synthesize preassemblerSelector;
@synthesize name;
@end

@implementation PKParser (PKParserFactoryAdditions)

- (id)parse:(NSString *)s error:(NSError **)outError {
    id result = nil;
    
    @try {
        
        PKTokenizer *t = self.tokenizer;
        if (!t) {
            t = [PKTokenizer tokenizer];
        }
        t.string = s;
        PKAssembly *a = [self completeMatchFor:[PKTokenAssembly assemblyWithTokenizer:t]];
        if (a.target) {
            result = a.target;
        } else {
            result = [a pop];
        }

        return result;
    }
    @catch (NSException *ex) {
        if (outError) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[ex userInfo]];
            
            // get reason
            NSString *reason = [ex reason];
            if ([reason length]) [userInfo setObject:reason forKey:NSLocalizedFailureReasonErrorKey];
            
            // get domain
            NSString *exName = [ex name];
            NSString *domain = exName ? exName : @"PKParseException";
            
            // convert to NSError
#if __has_feature(objc_arc)
            NSError *err = [NSError errorWithDomain:domain code:47 userInfo:[userInfo copy]];
#else
            NSError *err = [NSError errorWithDomain:domain code:47 userInfo:[[userInfo copy] autorelease]];
#endif
            *outError = err;
        } else {
            [ex raise];
        }
    }
}


- (PKTokenizer *)tokenizer {
#if __has_feature(objc_arc)
    return tokenizer;
#else
    return [[tokenizer retain] autorelease];
#endif
}


- (void)setTokenizer:(PKTokenizer *)t {
    if (tokenizer != t) {
#if __has_feature(objc_arc)
        tokenizer = t;
#else
        [tokenizer autorelease];
        tokenizer = [t retain];
#endif
    }
}

@end
