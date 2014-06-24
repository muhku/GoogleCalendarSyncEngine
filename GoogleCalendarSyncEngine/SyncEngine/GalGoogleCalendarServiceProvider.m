/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalGoogleCalendarServiceProvider.h"
#import "GData.h"
#import "GalGoogleAccount.h"

static NSString *kGalendarUserAgent = @"GalGoogleCalendarSyncEngine %@ (iPhone OS %@)";
static NSMutableDictionary *services = nil;

@implementation GalGoogleCalendarServiceProvider

+ (GDataServiceGoogleCalendar *)googleCalendarServiceForGoogleAccount:(GalGoogleAccount *)googleAccount
{
	if (!services) {
		services = [[NSMutableDictionary alloc] init];
	}
	
	GDataServiceGoogleCalendar *existingService = nil;
	@synchronized (services) {
		existingService = services[googleAccount.username];
	}
	
	NSString *authToken = nil;
	if (existingService) {
		authToken = [existingService authToken];
	}
	
	GDataServiceGoogleCalendar *service = [[GDataServiceGoogleCalendar alloc] init];
	[service setUserCredentialsWithUsername:googleAccount.username password:googleAccount.password];
			
	NSString *appVersion = @"1.0";
	NSString *osVersion = [[UIDevice currentDevice] systemVersion];
	NSString *userAgent = [NSString stringWithFormat:kGalendarUserAgent, appVersion, osVersion];
			
	[service setUserAgent:userAgent];
			
    [service setShouldCacheResponseData:NO];
    [service setResponseDataCacheCapacity:0];
    [service clearResponseDataCache];
	
	// Construct a complete feed, if necessary
	[service setServiceShouldFollowNextLinks:YES];
	// For updates to work correctly
	[service setShouldServiceFeedsIgnoreUnknowns:NO];
	
	if (authToken) {
		[service setAuthToken:authToken];
	}
	
	@synchronized (services) {
		services[googleAccount.username] = service;
	}

	return service;
}

+ (void)clearCache
{
	@synchronized (services) {
		[services removeAllObjects];
	}
}

@end
