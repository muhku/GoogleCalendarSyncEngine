/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GalDAO;
@class GalEventFetch;
@class GDataServiceTicket;
@class GDataFeedCalendarEvent;
@class GDataDateTime;
@class GalGoogleCalendarEvent;
@class GDataEntryCalendarEvent;
@class GalGoogleCalendar;
@class GalEventList;

@interface GalGoogleCalendarEventService : NSObject {
	GalDAO *_dao;
	BOOL _cancelled;
	GalEventFetch *_eventFetch;
}

@property (readwrite,assign) unsigned int pastDaysToSync;
@property (readwrite,assign) unsigned int futureDaysToSync;

- (void)didReceiveEventFeed:(GDataServiceTicket *)ticket finishedWithEntries:(GDataFeedCalendarEvent *)feed error:(NSError *)error;
- (void)triggerOriginalEventFetchForEvent:(GalGoogleCalendarEvent *)originalCalendarEvent delegate:(id)delegate didFinishSelector:(SEL)finishedSelector;
- (void)triggerRemoteEventFetchFromDate:(NSDate *)date;
- (void)triggerRemoteEventFetchFromDate:(NSDate *)date calendarsToFetch:(NSMutableArray *)calendarsToFetch;
- (void)stopRemoteEventFetch;
- (GalEventList *)googleCalendarEventsForMonth:(NSDate *)month;
- (void)saveGoogleCalendarEvent:(GalGoogleCalendarEvent *)googleCalendarEvent;
- (GalGoogleCalendar *)googleCalendarForEvent:(GalGoogleCalendarEvent *)event;
- (GalGoogleCalendarEvent *)googleCalendarEventWithIdentifier:(unsigned int)eventIdentifier;
- (BOOL)hasOnGoingSync;
- (NSDate *)currentSyncDate;

@end
