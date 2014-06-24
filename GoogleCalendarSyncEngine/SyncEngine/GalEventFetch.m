/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalEventFetch.h"

#import "gdata.h"
#import "GalUtils.h"
#import "GalDAO.h"
#import "GalGoogleCalendar.h"
#import "GalGoogleCalendarServiceProvider.h"
#import "GalGoogleAccount.h"
#import "GalGoogleCalendarEventService.h"

@interface CalendarEventQuery : NSObject {

}

@property (strong,nonatomic) GalGoogleCalendar *googleCalendar;
@property (strong,nonatomic) GalGoogleAccount *googleAccount;
@property (strong,nonatomic) GDataQueryCalendar *query;
@property (readwrite,unsafe_unretained) id delegate;

@end

@implementation CalendarEventQuery

@end

@implementation GalEventFetch

@synthesize tickets=_tickets;
@synthesize syncBeginTimestamp=_syncBeginTimestamp;
@synthesize calendarsToFetch=_calendarsToFetch;

- (id)initWithDate:(NSDate *)date pastDays:(unsigned int)pastDays futureDays:(unsigned int)futureDays calendarsToFetch:(NSMutableArray*)calendarsToFetch
{
    if (self = [super init]) {		
		_date = [date copy];
		_dao = [[GalDAO alloc] init];
		
		_pastDays = pastDays;
		_futureDays = futureDays;
		
		assert(_pastDays >= 7);
		assert(_futureDays >= 7);
		
		_queryQueue = [[NSMutableArray alloc] init];
		_tickets = [[NSMutableSet alloc] init];
		_calendarsToFetch = calendarsToFetch;
		
		_syncBeginTimestamp = [GalUtils currentUnixTime];
    }
    return self;
}

- (BOOL)startEventFetchForDelegate:(id)delegate
{
	[_queryQueue removeAllObjects];
	_syncBeginTimestamp = [GalUtils currentUnixTime];
	
	if (0 == [_calendarsToFetch count]) {
		return NO;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteEventFetchInProgress" object:nil];
	
	NSDate *minStartTime = [self minimumStartTime];
	NSDate *maxStartTime = [self maximumStartTime];
	
	for (int i=0, count=[_calendarsToFetch count]; i < count; i++) {
		GalGoogleCalendar *googleCalendar = [_calendarsToFetch objectAtIndex:i];
		
		CalendarEventQuery *q = [[CalendarEventQuery alloc] init];
		q.googleCalendar = googleCalendar;
		q.googleAccount = [_dao googleAccountWithCalendar:googleCalendar];
		q.delegate = delegate;
		q.query = [googleCalendar queryForEventsStartingAt:[GDataDateTime dateTimeWithDate:minStartTime timeZone:[GalUtils localTimeZone]]
										  maximumStartTime:[GDataDateTime dateTimeWithDate:maxStartTime timeZone:[GalUtils localTimeZone]]];
		
		[_queryQueue addObject:q];
		
	}
	
	[self executeQuery];
	return YES;
}

- (void)executeQuery
{
	if ([_queryQueue count] == 0) {
		return;
	}
	
	CalendarEventQuery *query = [_queryQueue lastObject];
	
	GDataServiceGoogleCalendar *service = [GalGoogleCalendarServiceProvider googleCalendarServiceForGoogleAccount:query.googleAccount];
	
	GDataServiceTicket *ticket = [service fetchFeedWithQuery:query.query
													delegate:query.delegate
										   didFinishSelector:@selector(didReceiveEventFeed:finishedWithEntries:error:)];
	if (ticket) {
		NSString *message = [NSString stringWithFormat:@"Sync: %@ (%i days)", query.googleCalendar.title, _futureDays];
        
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        [userInfo setObject:message forKey:@"syncStatusMessage"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteSyncStatusUpdate"
                                                            object:nil
                                                          userInfo:userInfo];
        
		[ticket setProperty:query.googleCalendar forKey:@"googleCalendar"];
		[_tickets addObject:ticket];
	}
	
	[_queryQueue removeLastObject];
}

- (BOOL)hasPendingQueries
{
	return ([_queryQueue count] > 0);
}

- (BOOL)hasPendingTickets
{
	int count = 0;
	@synchronized (self) {
		count = [_tickets count];
	}
	return (count > 0);
}

- (void)removeTicket:(GDataServiceTicket *)ticket
{
	assert(ticket);
	@synchronized (self) {
		[_tickets removeObject:ticket];
	}
}

- (void)cancelTickets
{
	[_tickets makeObjectsPerformSelector:@selector(cancelTicket)];
	@synchronized (self) {
		[_tickets removeAllObjects];
	}
}

- (NSDate *)date
{
	NSDate *dateCopy = [_date copy];
	return dateCopy;
}

- (NSDate *)minimumStartTime
{
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setDay:-_pastDays];
	
	NSDate *date = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:_date options:0];
	return date;
}

- (NSDate *)maximumStartTime
{
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setDay:_futureDays];
	
	NSDate *date = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:_date options:0];
	return date;
}

@end
