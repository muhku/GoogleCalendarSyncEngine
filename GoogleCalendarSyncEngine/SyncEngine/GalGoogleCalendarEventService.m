/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalGoogleCalendarEventService.h"

#import "GalDAO.h"
#import "GalGoogleCalendar.h"
#import "GalGoogleAccount.h"
#import "GalEventFetch.h"
#import "GalGoogleCalendarServiceProvider.h"
#import "GalGoogleCalendarEvent.h"
#import "GalUtils.h"
#import "GalEventList.h"

#import "GData.h"

//#define GAL_DEBUG_FETCH 1

@interface GalGoogleCalendarEventService ()
- (void)saveEventFeed:(GDataFeedCalendarEvent *)feed googleCalendar:(GalGoogleCalendar *)googleCalendar;
- (NSDate *)startOfMonth:(int)month year:(int)year;
- (NSDate *)endOfMonth:(int)month year:(int)year;
- (unsigned int)numberOfDaysInMonth:(int)month year:(int)year;
@end

@implementation GalGoogleCalendarEventService

- (id)init
{
    if (self = [super init]) {
        _dao = [[GalDAO alloc] init];
		_eventFetch = nil;
		_cancelled = NO;
        _pastDaysToSync = 7;
        _futureDaysToSync = 90;
    }
    return self;
}

- (void)triggerOriginalEventFetchForEvent:(GalGoogleCalendarEvent *)originalCalendarEvent delegate:(id)delegate didFinishSelector:(SEL)finishedSelector
{
	GalGoogleCalendar *googleCalendar = [_dao googleCalendarWithIdentifier:originalCalendarEvent.googleCalendarIdentifier];
	GalGoogleAccount *googleAccount = [_dao googleAccountWithCalendar:googleCalendar];
	GDataServiceGoogleCalendar *service = [GalGoogleCalendarServiceProvider googleCalendarServiceForGoogleAccount:googleAccount];
	NSURL *eventURL = [originalCalendarEvent eventFeedUrl];	
	GDataServiceTicket *ticket = [service fetchEntryWithURL:eventURL delegate:delegate didFinishSelector:finishedSelector];
	if (ticket) {
		[ticket setProperty:originalCalendarEvent forKey:@"originalCalendarEvent"];
		[ticket setProperty:googleCalendar forKey:@"googleCalendar"];
	}
}

- (void)triggerRemoteEventFetchFromDate:(NSDate *)date
{
	NSMutableArray *enabledCalendars = [_dao enabledGoogleCalendars];
	[self triggerRemoteEventFetchFromDate:date calendarsToFetch:enabledCalendars];
}

- (void)triggerRemoteEventFetchFromDate:(NSDate *)date calendarsToFetch:(NSMutableArray *)calendarsToFetch
{
	@synchronized (self) {
		if (_eventFetch) {
#if GAL_DEBUG_FETCH
			NSLog(@"CalGoogleCalendarEventService: triggerRemoteEventFetchFromDate. already in progress Return.");
#endif
			[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteEventFetchInProgress" object:nil];
			return;
		} else {
			
			_eventFetch = [[GalEventFetch alloc] initWithDate:date pastDays:[self pastDaysToSync]
												   futureDays:[self futureDaysToSync]
											 calendarsToFetch:calendarsToFetch];
			_cancelled = NO;
		}
	}

	if (![_eventFetch startEventFetchForDelegate:self]) {
		// No calendars to sync
		_eventFetch = nil;
        
#if GAL_DEBUG_FETCH
        NSLog(@"CalGoogleCalendarEventService: no calendars to fetch! Done.");
#endif
        
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteEventFetchDone" object:nil];
	}
}

- (BOOL)hasOnGoingSync
{
	BOOL onGoing = NO;
	
	if (_eventFetch) {
		onGoing = YES;
	}
	
	return onGoing;
}

- (NSDate *)currentSyncDate
{
	NSDate *date = nil;
	
	if (_eventFetch) {
		date = [_eventFetch date];
	}
	
	return date;
}

- (void)stopRemoteEventFetch
{
	if ([self hasOnGoingSync]) {
		[_eventFetch cancelTickets];
		_eventFetch = nil;
        
#if GAL_DEBUG_FETCH
        NSLog(@"CalGoogleCalendarEventService: fetching stopped. Done.");
#endif
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteEventFetchDone"
															object:nil
														  userInfo:nil];
	}
	_cancelled = YES;
	
#if GAL_DEBUG_FETCH
	NSLog(@"CalGoogleCalendarEventService: all requests canceled");
#endif		
}

- (void)didReceiveEventFeed:(GDataServiceTicket *)ticket finishedWithEntries:(GDataFeedCalendarEvent *)feed error:(NSError *)error{
#if GAL_DEBUG_FETCH
	NSLog(@"CalGoogleCalendarEventService: finishedWithEntries called");
#endif	
	
	GalGoogleCalendar *googleCalendar = nil;
	BOOL failed = NO;
	
	if (error) {
#if GAL_DEBUG_FETCH
		NSLog(@"CalGoogleCalendarEventService: finishedWithEntries, error %@", [error localizedDescription]);
#endif
		
		NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
		[userInfo setObject:error forKey:@"error"];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteEventFetchFail" object:nil userInfo:userInfo];
		failed = YES;
		goto REMOVE_TICKET;
	}
	
	googleCalendar = [ticket propertyForKey:@"googleCalendar"];

#if GAL_DEBUG_FETCH
	NSLog(@"CalGoogleCalendarEventService: finishedWithEntries, googleCalendar %@", googleCalendar.title);
#endif	
	
	[self saveEventFeed:feed googleCalendar:googleCalendar];
	
REMOVE_TICKET:
	[_eventFetch removeTicket:ticket];
	
	if ([_eventFetch hasPendingQueries]) {
		[_eventFetch executeQuery];
	}
	
	if (![_eventFetch hasPendingTickets]) {
		// Purge events from the local database that are deleted from Google
		if (!_cancelled && !failed) {
			int startTime = [[_eventFetch minimumStartTime] timeIntervalSince1970];
			int endTime = [[_eventFetch maximumStartTime] timeIntervalSince1970];
			
			for (id calendar in _eventFetch.calendarsToFetch) {
				GalGoogleCalendar *g = calendar;
				
#if GAL_DEBUG_FETCH
				NSLog(@"CalGoogleCalendarEventService: finishedWithEntries, purging events for calendar %@, %i - %i", g.title, startTime, endTime);
#endif				
				
				[_dao removeEventsOlderThan:_eventFetch.syncBeginTimestamp
								  startTime:startTime
									endTime:endTime
							 googleCalendar:g];
			}
		}
		_eventFetch = nil;
        
#if GAL_DEBUG_FETCH
        NSLog(@"CalGoogleCalendarEventService: fetch done.");
#endif
        
		// Synchronization done!
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteEventFetchDone"
															object:nil
														  userInfo:nil];
	}
}

- (void)saveEventFeed:(GDataFeedCalendarEvent *)feed googleCalendar:(GalGoogleCalendar *)googleCalendar
{
	assert(googleCalendar);
	
	// The feed seems to be OK, parse
	int count = [[feed entries] count];
	
#if GAL_DEBUG_FETCH
	NSLog(@"CalGoogleCalendarEventService.saveEventFeed. feed entries count: %i", count);
#endif		
	
	for (int i=0; !_cancelled && i<count; i++) {
		GDataEntryCalendarEvent *eventEntry = [[feed entries] objectAtIndex:i];
		GalGoogleCalendarEvent *event = [[GalGoogleCalendarEvent alloc] initWithEvent:eventEntry googleCalendar:googleCalendar];
		GalGoogleCalendarEvent *existingEvent = [_dao googleCalendarEventWithGoogleEventId:event.googleEventId];
		
		if (existingEvent) {
			// Check if we can override the event from Google
			if (kGalSyncStatusEventHidden == existingEvent.syncStatus ||
				kGalSyncStatusEventDeletedLocally == existingEvent.syncStatus ||
				kGalSyncStatusEventAddedLocally == existingEvent.syncStatus) {
				// Do not modify the local event.
				goto CONTINUE_NEXT_EVENT;
			}
			
			if (kGalSyncStatusEventModifiedLocally == existingEvent.syncStatus &&
				existingEvent.localUpdateTime > event.remoteUpdateTime) {
				// We cannot override the event from Google if it has local
				// modifications which are newer than the modifications done in Google.
				goto CONTINUE_NEXT_EVENT;
			}
			
			if (existingEvent.remoteUpdateTime == event.remoteUpdateTime) {
				// The local event is already up to date. No need to update the whole event.
				// Just update the timestamp. This ensures that the event
				// won't get purged when the events deleted from Google
				// are deleted from the local database.
				[_dao touchEvent:existingEvent];
				goto CONTINUE_NEXT_EVENT;
			}
			
			// Set an identifier for the event so the existing
			// event is updated instead of creating a new event
			event.identifier = existingEvent.identifier;
		} // if existingEvent
		event.syncStatus = kGalSyncStatusEventSynchronized;
		[_dao saveGoogleCalendarEvent:event];
		
	CONTINUE_NEXT_EVENT:
		
		;
	}
}

- (void)saveGoogleCalendarEvent:(GalGoogleCalendarEvent *)googleCalendarEvent
{
	GalGoogleCalendarEvent *existingEvent = [_dao googleCalendarEventWithGoogleEventId:googleCalendarEvent.googleEventId];
	
	if (existingEvent) {
		googleCalendarEvent.identifier = existingEvent.identifier;
	}
	
	[_dao saveGoogleCalendarEvent:googleCalendarEvent];
}

- (GalGoogleCalendar *)googleCalendarForEvent:(GalGoogleCalendarEvent *)event
{
	return [_dao googleCalendarWithIdentifier:event.googleCalendarIdentifier];
}

- (GalGoogleCalendarEvent *)googleCalendarEventWithIdentifier:(unsigned int)eventIdentifier
{
	return [_dao googleCalendarEventWithIdentifier:eventIdentifier];
}

- (GalEventList *)googleCalendarEventsForMonth:(NSDate *)month
{
    GalDateInformation info = [GalUtils dateInformationFromDate:month];
    
	NSDate *start = [self startOfMonth:info.month year:info.year];
	NSDate *end = [self endOfMonth:info.month year:info.year];
	
	return [_dao googleCalendarEventsStartingAt:start endingAt:end];
}

#define CF_UNIX_EPOCH 978307200

- (NSDate *)startOfMonth:(int)month year:(int)year
{
	CFTimeZoneRef tz = CFTimeZoneCopySystem();
	CFCalendarRef currentCalendar = CFCalendarCopyCurrent();
	
	CFGregorianDate gt = {
		.year = year, .month = month, .day = 1, .hour = 0, .minute = 0, .second = 0
	};
	
	CFAbsoluteTime at = CFGregorianDateGetAbsoluteTime(gt, tz);
	
	int dayDelta = CFAbsoluteTimeGetDayOfWeek(at, tz) - CFCalendarGetFirstWeekday(currentCalendar) + 1;
	
	CFGregorianUnits kGregorianUnits_firstWeekday = {0, 0, -dayDelta, 0, 0, 0.0};
	
	CFTimeInterval at2 = CFAbsoluteTimeAddGregorianUnits(at, tz, kGregorianUnits_firstWeekday);
	
	int uxtime = CF_UNIX_EPOCH + (int)at2;
	
	CFRelease(currentCalendar);
	CFRelease(tz);
	
	// Calculate the beginning of the first day of the first full week of the month.
	// Rationale: we cannot display partial weeks in the week view.
	return [NSDate dateWithTimeIntervalSince1970:uxtime];
}

- (NSDate *)endOfMonth:(int)month year:(int)year
{
	CFTimeZoneRef tz = CFTimeZoneCopySystem();
	CFCalendarRef currentCalendar = CFCalendarCopyCurrent();
	
	CFGregorianDate gt = {
		.year = year, .month = month, .day = [self numberOfDaysInMonth:month year:year], .hour = 0, .minute = 0, .second = 0
	};
	
	CFAbsoluteTime at = CFGregorianDateGetAbsoluteTime(gt, tz);
	
	int dayDelta = (7 - CFAbsoluteTimeGetDayOfWeek(at, tz)) + (CFCalendarGetFirstWeekday(currentCalendar) - 1);
	
	CFGregorianUnits kGregorianUnits_firstWeekday = {0, 0, dayDelta, 0, 0, 0.0};
	
	CFTimeInterval at2 = CFAbsoluteTimeAddGregorianUnits(at, tz, kGregorianUnits_firstWeekday);
	
	int uxtime = CF_UNIX_EPOCH + (int)at2;
	
	CFRelease(currentCalendar);
	CFRelease(tz);
	
	return [NSDate dateWithTimeIntervalSince1970:uxtime];
}

- (unsigned int)numberOfDaysInMonth:(int)month year:(int)year
{
	BOOL isLeapYear = (year % 400 == 0 || (year % 100 != 0 && year % 4 == 0));
	switch (month) {
		case 1: case 3: case 5: case 7: case 8: case 10: case 12:
			return 31;
		case 2:
			if (isLeapYear)
				return 29;
			else
				return 28;
		default:
			return 30;
	}
}

#undef CF_UNIX_EPOCH

@end
