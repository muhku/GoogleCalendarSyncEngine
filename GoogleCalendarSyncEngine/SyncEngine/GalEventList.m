/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalEventList.h"
#import "GalGoogleCalendarEvent.h"

#import "GalGoogleCalendarEvent.h"
#import "GalUtils.h"

@implementation GalEventList

- (id)initWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
	if (self = [super init]) {
		_events = [[NSMutableArray alloc] init];
		_start = [startDate copy];
		_end = [endDate copy];
	}
	return self;
}

/* Public */
- (void)addEvent:(GalGoogleCalendarEvent *)event
{
	[_events addObject:event];
}

- (BOOL)hasEventsOnDay:(NSDate *)day
{
	GalDateInformation info = [GalUtils dateInformationFromDate:day];
	
	for (id e in _events) {
		GalGoogleCalendarEvent *event = e;
		if ([event eventOccursAtDay:info.day month:info.month year:info.year]) {
			return YES;
		}
	}
	return NO;
}

- (NSMutableArray *)eventsForDate:(NSDate *)eventDate
{
	NSMutableArray *newEvents = [[NSMutableArray alloc] init];
	
	GalDateInformation info = [GalUtils dateInformationFromDate:eventDate];
		
	for (id e in _events) {
		GalGoogleCalendarEvent *event = e;
		if ([event eventOccursAtDay:info.day month:info.month year:info.year]) {
			[newEvents addObject:event];
		}
	}
	return newEvents;
}

- (NSArray *)events
{
	return _events;
}

@end
