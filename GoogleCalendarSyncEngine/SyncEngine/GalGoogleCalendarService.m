/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalGoogleCalendarService.h"

#import "GalDAO.h"
#import "GalGoogleAccount.h"
#import "GalGoogleCalendar.h"
#import "GData.h"
#import "GalGoogleCalendarServiceProvider.h"
#import "GalUtils.h"

@interface CalendarQuery : NSObject {
	GalGoogleAccount *_googleAccount;
	NSNumber *_updateBeginTimeStamp;
}

@property (strong,nonatomic) GalGoogleAccount *googleAccount;
@property (readonly) NSNumber *updateBeginTimestamp;

@end

@implementation CalendarQuery

- (id)init
{
	if (self = [super init]) {
        _updateBeginTimeStamp = [NSNumber numberWithUnsignedInt:[GalUtils currentUnixTime]];
    }
    return self;
}

@end

@interface GalGoogleCalendarService ()
- (void)didReceiveCalendarFeed:(GDataServiceTicket *)ticket finishedWithFeed:(GDataFeedCalendar *)feed error:(NSError *)error;
- (void)saveCalendarFeed:(GDataFeedCalendar *)feed googleAccount:(GalGoogleAccount *)googleAccount;
- (void)executeQuery;
- (BOOL)hasPendingQueries;
@end

@implementation GalGoogleCalendarService

- (id)init
{
    if (self = [super init]) {
        _dao = [[GalDAO alloc] init];
		_tickets = [[NSMutableSet alloc] init];
		_queryQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray *)googleAccounts
{
	return [_dao googleAccounts];
}

- (NSArray *)googleCalendars
{
	return [_dao googleCalendars];
}

- (void)triggerRemoteGoogleCalendarsFetch
{
#if TARGET_IPHONE_SIMULATOR || defined(DEBUG) || (!defined(NS_BLOCK_ASSERTIONS) && !defined(NDEBUG))
	NSLog(@"CalGoogleCalendarService: triggerRemoteGoogleCalendarsFetch called");
#endif	
	
	_cancelled = NO;
	
	// Check if there's an ongoing fetch. If so, post a notification
	// and return as simultaneous requests are not allowed
	@synchronized (self) {
		if ([_queryQueue count] > 0) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteCalendarFetchInProgress" object:nil];
			return;
		}
	}
	
	NSMutableArray *googleAccounts = [_dao googleAccounts];
		
	if ([googleAccounts count] > 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteCalendarFetchInProgress" object:nil];
	}
	
	for (int i=0, count=[googleAccounts count]; i < count; i++) {
		CalendarQuery *q = [[CalendarQuery alloc] init];
		q.googleAccount = googleAccounts[i];
		[_queryQueue addObject:q];
	}
	
	[self executeQuery];
}

- (void)executeQuery
{
	if ([_queryQueue count] == 0) {
		return;
	}
	
	CalendarQuery *query = [_queryQueue lastObject];
	GDataServiceGoogleCalendar *service = [GalGoogleCalendarServiceProvider googleCalendarServiceForGoogleAccount:query.googleAccount];
	GDataServiceTicket *ticket = [service fetchCalendarFeedForUsername:query.googleAccount.username
															  delegate:self didFinishSelector:@selector(didReceiveCalendarFeed:finishedWithFeed:error:)];
	if (ticket) {
		NSString *message = [NSString stringWithFormat:@"Get calendars: %@", query.googleAccount.username];
        
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setObject:message forKey:@"syncStatusMessage"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteSyncStatusUpdate"
                                                            object:nil
                                                          userInfo:userInfo];
        
		[ticket setProperty:query.googleAccount forKey:@"galGoogleAccount"];
		[ticket setProperty:query.updateBeginTimestamp forKey:@"galUpdateBeginTimestamp"];
        
		@synchronized (self) {
			[_tickets addObject:ticket];
		}
	}
	
	[_queryQueue removeLastObject];
}

- (BOOL)hasPendingQueries
{
	return ([_queryQueue count] > 0);
}

- (BOOL)hasOnGoingSync
{
	BOOL onGoing = NO;
	
	if ([_tickets count] > 0) {
		onGoing = YES;
	}
	
	return onGoing;
}

- (void)stopRemoteGoogleCalendarsFetch
{
	_cancelled = YES;
	
	[_tickets makeObjectsPerformSelector:@selector(cancelTicket)];
	
	@synchronized (self) {
		[_tickets removeAllObjects];
	}
	
#if TARGET_IPHONE_SIMULATOR || defined(DEBUG) || (!defined(NS_BLOCK_ASSERTIONS) && !defined(NDEBUG))
	NSLog(@"CalGoogleCalendarService: all requests canceled");
#endif		
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteCalendarFetchDone" object:nil];
}

- (void)didReceiveCalendarFeed:(GDataServiceTicket *)ticket finishedWithFeed:(GDataFeedCalendar *)feed error:(NSError *)error
{
	assert(ticket);
	
	GalGoogleAccount *googleAccount = nil;
	BOOL failed = NO;
	
	if (error) {
		failed = YES;
		
		NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
		userInfo[@"error"] = error;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteCalendarFetchFail" object:nil userInfo:userInfo];
		goto REMOVE_TICKET;
	}
	
	googleAccount = [ticket propertyForKey:@"galGoogleAccount"];
	
	if (!googleAccount || _cancelled) {
		goto REMOVE_TICKET;
	}
	
	[self saveCalendarFeed:feed googleAccount:googleAccount];

REMOVE_TICKET:	
	@synchronized (self) {
		NSNumber *updateBeginTimestamp = [ticket propertyForKey:@"galUpdateBeginTimestamp"];
		[_tickets removeObject:ticket];
	
		if ([_tickets count] == 0) {
			if (updateBeginTimestamp && !failed) {
				[_dao removeCalendarsOlderThan:[updateBeginTimestamp unsignedIntValue]];
			}
		}
	}
	
	if ([self hasPendingQueries]) {
		[self executeQuery];
	} else {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteCalendarFetchDone" object:nil];
	}	
}

- (void)saveCalendarFeed:(GDataFeedCalendar *)feed googleAccount:(GalGoogleAccount *)googleAccount
{
	// The feed seems to be OK, parse
	int count = [[feed entries] count];
	for (int i=0; !_cancelled && i<count; i++) {
		GDataEntryCalendar *calendarEntry = [feed entries][i];
		GalGoogleCalendar *calendar = [[GalGoogleCalendar alloc] initWithCalendar:calendarEntry
																	googleAccount:googleAccount];
		
		GalGoogleCalendar *existingCalendar = [_dao googleCalendarWithGoogleCalendarId:calendar.googleCalendarId];
		if (existingCalendar) {
			calendar.identifier = existingCalendar.identifier;
			calendar.enabled = existingCalendar.enabled;
		}
		[_dao saveGoogleCalendar:calendar];
	}
}

- (NSArray *)modifiableGoogleCalendars
{
	return [_dao modifiableGoogleCalendars];
}

- (void)saveGoogleCalendarEnabledState:(GalGoogleCalendar *)googleCalendar enabled:(BOOL)enabled
{
	[_dao saveGoogleCalendarEnabledState:googleCalendar enabled:enabled];
}

- (void)saveGoogleAccount:(GalGoogleAccount *)googleAccount
{
	[_dao saveGoogleAccount:googleAccount];
}

- (void)removeGoogleAccount:(GalGoogleAccount *)googleAccount
{
	[_dao removeGoogleAccount:googleAccount];
}

@end