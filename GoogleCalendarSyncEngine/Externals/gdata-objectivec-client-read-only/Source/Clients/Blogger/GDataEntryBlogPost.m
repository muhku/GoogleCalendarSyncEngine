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
//  GDataEntryBlogPost.m
//

#if !GDATA_REQUIRE_SERVICE_INCLUDES || GDATA_INCLUDE_BLOGGER_SERVICE

#import "GDataEntryBlogPost.h"
#import "GDataBloggerConstants.h"
#import "GDataThreadingElements.h"
#import "GDataMediaThumbnail.h"

@implementation GDataEntryBlogPost

+ (GDataEntryBlogPost *)postEntry {

  GDataEntryBlogPost *obj = [self object];

  [obj setNamespaces:[GDataBloggerConstants bloggerNamespaces]];

  return obj;
}

#pragma mark -

//+ (NSString *)standardEntryKind {
//  return kGDataCategoryBloggerPost;
//}
//
//+ (void)load {
//  [self registerEntryClass];
//}

- (void)addExtensionDeclarations {
  [super addExtensionDeclarations];

  [self addExtensionDeclarationForParentClass:[self class]
                                 childClasses:
   [GDataMediaThumbnail class],
   [GDataThreadingTotal class],
   nil];

}

#if !GDATA_SIMPLE_DESCRIPTIONS
- (NSMutableArray *)itemsForDescription {

  static struct GDataDescriptionRecord descRecs[] = {
    { @"thumbnail", @"thumbnail", kGDataDescValueLabeled },
    { @"total",     @"total",     kGDataDescValueLabeled },
    { nil, nil, (GDataDescRecTypes)0 }
  };

  NSMutableArray *items = [super itemsForDescription];
  [self addDescriptionRecords:descRecs toItems:items];
  return items;
}
#endif

+ (NSString *)defaultServiceVersion {
  return kGDataBloggerDefaultServiceVersion;
}

#pragma mark -

- (GDataMediaThumbnail *)thumbnail {
  GDataMediaThumbnail *obj;

  obj = [self objectForExtensionClass:[GDataMediaThumbnail class]];
  return obj;
}

- (void)setThumbnail:(GDataMediaThumbnail *)obj {
  [self setObject:obj forExtensionClass:[GDataMediaThumbnail class]];
}

- (NSNumber *)total {
  GDataThreadingTotal *obj;

  obj = [self objectForExtensionClass:[GDataThreadingTotal class]];
  return [obj intNumberValue];
}

- (void)setTotal:(NSNumber *)num {
  GDataThreadingTotal *obj = [GDataThreadingTotal valueWithNumber:num];
  [self setObject:obj forExtensionClass:[GDataThreadingTotal class]];
}

#pragma mark -

- (GDataLink *)enclosureLink {
  return [self linkWithRelAttributeValue:kGDataLinkBloggerEnclosure];
}

- (GDataLink *)repliesAtomLink {
  return [self linkWithRelAttributeValue:kGDataLinkBloggerReplies
                                    type:kGDataLinkTypeAtom];
}

- (GDataLink *)repliesHTMLLink {
  return [self linkWithRelAttributeValue:kGDataLinkBloggerReplies
                                    type:kGDataLinkTypeHTML];
}
@end

#endif // !GDATA_REQUIRE_SERVICE_INCLUDES || GDATA_INCLUDE_BLOGGER_SERVICE
