/* Copyright (c) 2009 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  GDataAnalyticsCustomVariable.m
//

#if !GDATA_REQUIRE_SERVICE_INCLUDES || GDATA_INCLUDE_ANALYTICS_SERVICE

#import "GDataAnalyticsCustomVariable.h"
#import "GDataAnalyticsConstants.h"

static NSString *const kIndexAttr = @"index";
static NSString *const kNameAttr = @"name";
static NSString *const kScopeAttr = @"scope";

@implementation GDataAnalyticsCustomVariable

+ (NSString *)extensionElementURI       { return kGDataNamespaceAnalyticsGA; }
+ (NSString *)extensionElementPrefix    { return kGDataNamespaceAnalyticsGAPrefix; }
+ (NSString *)extensionElementLocalName { return @"customVariable"; }

- (void)addParseDeclarations {

  NSArray *attrs = [NSArray arrayWithObjects:
                    kIndexAttr, kNameAttr, kScopeAttr, nil];

  [self addLocalAttributeDeclarations:attrs];
}

#pragma mark -

- (NSNumber *)index {
  NSNumber *num = [self intNumberForAttribute:kIndexAttr];
  return num;
}

- (void)setIndex:(NSNumber *)num {
  [self setStringValue:[num stringValue] forAttribute:kIndexAttr];
}

- (NSString *)name {
  NSString *str = [self stringValueForAttribute:kNameAttr];
  return str;
}

- (void)setName:(NSString *)str {
  [self setStringValue:str forAttribute:kNameAttr];
}

- (NSString *)scope {
  NSString *str = [self stringValueForAttribute:kScopeAttr];
  return str;
}

- (void)setScope:(NSString *)str {
  [self setStringValue:str forAttribute:kScopeAttr];
}
@end

#endif // !GDATA_REQUIRE_SERVICE_INCLUDES || GDATA_INCLUDE_ANALYTICS_SERVICE
