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

#import <ParseKit/PKReader.h>

@implementation PKReader

- (id)init {
    return [self initWithString:nil];
}


- (id)initWithString:(NSString *)s {
    if (self = [super init]) {
        self.string = s;
    }
    return self;
}


- (void)dealloc {
    self.string = nil;
    //if (buff) free(buff);
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}


- (NSString *)string {
#if __has_feature(objc_arc)
    return string;
#else
    return [[string retain] autorelease];
#endif
}


- (void)setString:(NSString *)s {
    if (string != s) {
#if !__has_feature(objc_arc)
        [string autorelease];
#endif
        string = [s copy];
        length = [string length];

//        if (buff) free(buff);
//        buff = malloc(sizeof(unichar)*length + 1);
//        [s getCharacters:buff range:NSMakeRange(0, length)];
    }
    // reset cursor
    offset = 0;
}


- (PKUniChar)read {
    if (0 == length || offset > length - 1) {
        return PKEOF;
    }
    return [string characterAtIndex:offset++];
    //return buff[offset++];
}


- (void)unread {
    offset = (0 == offset) ? 0 : offset - 1;
}


- (void)unread:(NSUInteger)count {
    NSUInteger i = 0;
    for ( ; i < count; i++) {
        [self unread];
    }
}

@synthesize offset;
@end
