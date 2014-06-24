/* Copyright (c) 2008 Google Inc.
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
//  GDataServiceGoogleFinance.m
//

#if !GDATA_REQUIRE_SERVICE_INCLUDES || GDATA_INCLUDE_FINANCE_SERVICE

#define GDATASERVICEGOOGLEFINANCE_DEFINE_GLOBALS 1

#import "GDataServiceGoogleFinance.h"

#import "GDataEntryFinancePortfolio.h"
#import "GDataQueryFinance.h"

@implementation GDataServiceGoogleFinance

+ (NSURL *)portfolioFeedURLForUserID:(NSString *)userID {
    
  NSString *const templateStr = @"%@%@/portfolios";
  
  NSString *encodedUserID = [GDataUtilities stringByURLEncodingForURI:userID];
  
  NSString *rootURLStr = [self serviceRootURLString];

  NSString *urlString = [NSString stringWithFormat:templateStr, 
                           rootURLStr, encodedUserID];
  
  return [NSURL URLWithString:urlString];
}

#pragma mark -

+ (NSString *)serviceID {
  return @"finance";
}

+ (NSString *)serviceRootURLString {
  return @"https://finance.google.com/finance/feeds/"; 
}

+ (NSString *)defaultServiceVersion {
  return kGDataFinanceDefaultServiceVersion;
}

+ (NSDictionary *)standardServiceNamespaces {
  return [GDataEntryFinancePortfolio financeNamespaces];
}

@end

#endif // !GDATA_REQUIRE_SERVICE_INCLUDES || GDATA_INCLUDE_FINANCE_SERVICE
