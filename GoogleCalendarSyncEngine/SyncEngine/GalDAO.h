/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class FMDatabase;
@class FMResultSet;
@class GalGoogleAccount;
@class GalGoogleCalendar;
@class GalGoogleCalendarEvent;
@class GalEventList;

@interface GalDAO : NSObject {
}

+ (void)closeDatabase;
- (void)saveGoogleAccount:(GalGoogleAccount *)googleAccount;
- (GalGoogleAccount *)googleAccountWithUsername:(NSString *)username;
- (GalGoogleAccount *)googleAccountWithCalendar:(GalGoogleCalendar *)calendar;
- (NSMutableArray *)googleAccounts;
- (NSMutableArray *)googleCalendars;
- (NSMutableArray *)enabledGoogleCalendars;
- (NSMutableArray *)modifiableGoogleCalendars;
- (NSMutableArray *)googleCalendarsForAccount:(GalGoogleAccount *)googleAccount;
- (NSMutableArray *)locallyModifiedEventsForGoogleAccount:(GalGoogleAccount *)googleAccount;
- (GalEventList *)googleCalendarEventsStartingAt:(NSDate *)start endingAt:(NSDate *)end;
- (NSMutableArray *)searchEventsByTitleAndLocation:(NSString *)searchTerm;
- (GalGoogleCalendar *)googleCalendarWithGoogleCalendarId:(NSString *)googleCalendarId;
- (GalGoogleCalendar *)googleCalendarWithIdentifier:(unsigned int)calendarIdenfier;
- (GalGoogleCalendarEvent *)googleCalendarEventWithGoogleEventId:(NSString *)googleEventId;
- (GalGoogleCalendarEvent *)googleCalendarEventWithIdentifier:(unsigned int)eventIdentifier;
- (BOOL)hasLocallyModifiedEvents;
- (void)saveGoogleCalendar:(GalGoogleCalendar *)googleCalendar;
- (void)saveGoogleCalendarEnabledState:(GalGoogleCalendar *)googleCalendar enabled:(BOOL)enabled;
- (void)saveGoogleCalendarEvent:(GalGoogleCalendarEvent *)googleCalendarEvent;
- (void)touchEvent:(GalGoogleCalendarEvent *)event;
- (void)removeEventsOlderThan:(unsigned int)itemUpdateTime startTime:(int)startTime endTime:(int)endTime googleCalendar:(GalGoogleCalendar *)googleCalendar;
- (void)removeGoogleAccount:(GalGoogleAccount *)googleAccount;
- (void)removeGoogleCalendarEvent:(GalGoogleCalendarEvent *)calendarEvent;
- (void)removeGoogleCalendar:(GalGoogleCalendar *)googleCalendar;
- (void)removeCalendarsOlderThan:(unsigned int)itemUpdateTime;
- (void)updateSyncStatusForEvent:(GalGoogleCalendarEvent *)event status:(int)status;

- (void)mapGoogleAccountResultSet:(FMResultSet *)rs googleAccount:(GalGoogleAccount *)googleAccount;
- (void)mapGoogleCalendarResultSet:(FMResultSet *)rs googleCalendar:(GalGoogleCalendar *)googleCalendar;
- (void)mapGoogleCalendarEventResultSet:(FMResultSet *)rs googleCalendarEvent:(GalGoogleCalendarEvent *)googleCalendarEvent;

@end
