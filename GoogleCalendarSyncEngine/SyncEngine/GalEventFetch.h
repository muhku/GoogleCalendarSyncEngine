/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GDataDateTime;
@class GDataServiceTicket;
@class GalDAO;

@interface GalEventFetch : NSObject {
	GalDAO *_dao;
	NSDate *_date;
	unsigned int _syncBeginTimestamp;
	NSMutableSet *_tickets;
	NSMutableArray *_queryQueue;
	NSMutableArray *_calendarsToFetch;
	unsigned int _pastDays;
	unsigned int _futureDays;
}

@property (weak, readonly) NSDate *date;
@property (readonly) unsigned int syncBeginTimestamp;
@property (readonly) NSMutableSet *tickets;
@property (readonly) NSMutableArray *calendarsToFetch;

- (void)executeQuery;
- (BOOL)startEventFetchForDelegate:(id)delegate;
- (id)initWithDate:(NSDate *)date pastDays:(unsigned int)pastDays futureDays:(unsigned int)futureDays calendarsToFetch:(NSMutableArray*)calendarsToFetch;
- (BOOL)hasPendingTickets;
- (BOOL)hasPendingQueries;
- (void)cancelTickets;
- (void)removeTicket:(GDataServiceTicket *)ticket;
- (NSDate *)minimumStartTime;
- (NSDate *)maximumStartTime;

@end
