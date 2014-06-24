/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GalGoogleCalendarEvent;

@interface GalEventList : NSObject {
	NSMutableArray *_events;
	NSDate *_start;
	NSDate *_end;
}

@property (weak, readonly) NSArray *events;

- (id)initWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate;
- (void)addEvent:(GalGoogleCalendarEvent *)event;
- (BOOL)hasEventsOnDay:(NSDate *)day;
- (NSMutableArray *)eventsForDate:(NSDate *)eventDate;

@end
