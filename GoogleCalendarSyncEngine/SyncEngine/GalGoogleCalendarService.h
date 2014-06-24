/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GalDAO;
@class GalGoogleAccount;
@class GDataServiceTicket;
@class GDataFeedCalendar;
@class GalGoogleCalendar;

@interface GalGoogleCalendarService : NSObject {
	GalDAO *_dao;
	NSError *_lastError;
	NSMutableSet *_tickets;
	BOOL _cancelled;
	NSMutableArray *_queryQueue;
}

- (NSArray*)googleAccounts;
- (void)saveGoogleAccount:(GalGoogleAccount*)googleAccount;
- (NSArray *)googleCalendars;
- (NSArray *)modifiableGoogleCalendars;
- (void)triggerRemoteGoogleCalendarsFetch;
- (void)stopRemoteGoogleCalendarsFetch;
- (void)removeGoogleAccount:(GalGoogleAccount *)googleAccount;
- (void)saveGoogleCalendarEnabledState:(GalGoogleCalendar *)googleCalendar enabled:(BOOL)enabled;
- (BOOL)hasOnGoingSync;

@end
