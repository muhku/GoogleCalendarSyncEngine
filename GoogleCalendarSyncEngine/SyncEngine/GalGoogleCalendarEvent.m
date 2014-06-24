/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalGoogleCalendarEvent.h"

#import "GalGoogleCalendar.h"
#import "GData.h"
#import "GalUtils.h"

@implementation GalGoogleCalendarEvent

static NSDateFormatter *dateFormatDate = nil;
static NSDateFormatter *dateFormatDateTime = nil;

- (id)initWithGoogleCalendar:(GalGoogleCalendar *)googleCalendar
{
	if (self = [super init]) {
		_identifier = 0;
		_googleCalendarIdentifier = [googleCalendar identifier];
		
		// Create a random Google Event ID which does not collide
		// with Google's ID space
		int randValue = 0;
		while (0 == randValue) {
			randValue = arc4random() / 31;
		}
		
		_googleEventId = [NSString stringWithFormat:@"loc.%i.%i", [GalUtils currentUnixTime], randValue];
		
		NSDate *now = [NSDate date];
		
		_startTimestamp = [GalUtils unixTimeFromDate:now];
		_endTimestamp = [GalUtils unixTimeFromDate:now] + 3600; // +1h
		_syncTime = 0;	
		_localUpdateTime = 0;
		_remoteUpdateTime = 0;
		_syncStatus = kGalSyncStatusEventSynchronized;
		
		_feedUrl = @"";
		_originalFeedUrl = @"";
		_title = @"";
		_description = @"";
		_location = @"";
		
		NSString *colorString = googleCalendar.color;
		if (colorString) {
			_color = [[NSString alloc] initWithString:colorString]; // copy
		} else {
			_color = @"";
		}
		
		_recurrence = @"";
		
		_allDayEvent = NO;
	}
	return self;
}

- (id)initWithEvent:(GDataEntryCalendarEvent *)event googleCalendar:(GalGoogleCalendar *)googleCalendar
{
    if (self = [super init]) {
		_identifier = 0;
		_googleCalendarIdentifier = [googleCalendar identifier];
		// Google's event ID is not feasible for searching. It's a long URL string which
		// can exceed 100 characters (or much more). For this reason, generate a SHA-1 hash
		// for an ID.
		_googleEventId = [[NSString alloc] initWithString:[GalUtils sha1hash:event.identifier]]; // copy
		
		NSArray *times = [event times];
		if ([times count] > 0) {			
			GDataWhen *firstTime = times[0];
			
			GDataDateTime *startDateTime = [firstTime startTime];
			NSDate *startTime = [startDateTime date];
			
			GDataDateTime *endDateTime = [firstTime endTime];
			NSDate *endTime = [endDateTime date];
			
			_startTimestamp = [GalUtils unixTimeFromDate:startTime]; // store timestamp in UTC
			_endTimestamp = [GalUtils unixTimeFromDate:endTime];  // store timestamp in UTC
			
			_allDayEvent = (![startDateTime hasTime]);
		}
		
		_syncTime = [GalUtils currentUnixTime]; // store timestamp in UTC
		_localUpdateTime = 0; // No local updates to the event!
		GDataDateTime *updatedDate = [event updatedDate];
		if (updatedDate) {
			_remoteUpdateTime = [GalUtils unixTimeFromDate:[updatedDate date]];
		} else {
			_remoteUpdateTime = 0;
		}
		
		_syncStatus = kGalSyncStatusEventSynchronized;
		
		// Feed URL for events is called selfLink for some reason
		_feedUrl = [[NSString alloc] initWithString:[[event.selfLink URL] absoluteString]]; // copy
		
		GDataOriginalEvent *originalEvent = [event originalEvent];
		if (originalEvent) {
			_originalFeedUrl = [[NSString alloc] initWithString:[originalEvent href]]; // copy
		} else {
			_originalFeedUrl = @"";
		}

		NSString *titleString = [event.title stringValue];
		if (titleString) {
			_title = [[NSString alloc] initWithString:titleString]; // copy
		} else {
			_title = @"";
		}
		
		NSString *descriptionString = [event.content stringValue];
		if (descriptionString) {
			_description = [[NSString alloc] initWithString:descriptionString]; // copy
		} else {
			_description = @"";
		}
		
		GDataWhere *where = [event locations][0];
		if (where) {
			NSString *whereString = [where stringValue];
			if (whereString) {
				_location = [[NSString alloc] initWithString:whereString]; // copy
			} else {
				_location = @"";
			}
		} else {
			_location = @"";
		}
		
		// Recurrence
		GDataRecurrence *recurrence = [event recurrence];
		if (recurrence) {
			NSString *recurrenceString = [recurrence stringValue];
			if (recurrenceString) {
				_recurrence = [[NSString alloc] initWithString:recurrenceString]; // copy
			} else {
				_recurrence = @"";
			}
		} else {
			_recurrence = @"";
		}
		
		NSString *colorString = googleCalendar.color;
		if (colorString) {
			_color = [[NSString alloc] initWithString:colorString]; // copy
		} else {
			_color = @"";
		}
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	GalGoogleCalendarEvent *newEvent = [GalGoogleCalendarEvent allocWithZone:zone];
	
	if ([self feedUrl])
		[newEvent setFeedUrl:[[self feedUrl] copyWithZone:zone]];
	else
		[newEvent setFeedUrl:@""];
	
	if ([self originalFeedUrl])
		[newEvent setOriginalFeedUrl:[[self originalFeedUrl] copyWithZone:zone]];
	else
		[newEvent setOriginalFeedUrl:@""];
	
	if ([self title])
		[newEvent setTitle:[[self title] copyWithZone:zone]];
	else
		[newEvent setTitle:@""];
	
	if ([self description])
		[newEvent setDescription:[[self description] copyWithZone:zone]];
	else
		[newEvent setDescription:@""];
	
	if ([self location])
		[newEvent setLocation:[[self location] copyWithZone:zone]];
	else
		[newEvent setLocation:@""];
	
	if ([self color])
		[newEvent setColor:[[self color] copyWithZone:zone]];
	else
		[newEvent setColor:@""];
	
	if ([self recurrence])
		[newEvent setRecurrence:[[self recurrence] copyWithZone:zone]];
	else
		[newEvent setRecurrence:@""];
	
	[newEvent setIdentifier:[self identifier]];
	[newEvent setGoogleCalendarIdentifier:[self googleCalendarIdentifier]];
	[newEvent setStartTimestamp:[self startTimestamp]];
	[newEvent setEndTimestamp:[self endTimestamp]];
	[newEvent setSyncTime:[self syncTime]];
	[newEvent setLocalUpdateTime:[self localUpdateTime]];
	[newEvent setRemoteUpdateTime:[self remoteUpdateTime]];
	[newEvent setSyncStatus:[self syncStatus]];
	
	[newEvent setAllDayEvent:[self allDayEvent]];
	
	return newEvent;
}

#define HALF_DAY 43200

- (int)eventTimeSpanForDay:(int)day month:(int)month year:(int)year
{
	register unsigned int ds;
	register unsigned int de;
	int flags = 0x0;
    
	if (_allDayEvent) {
		ds = [GalUtils unixTimeAtBeginningOfDay:day month:month year:year] + HALF_DAY;
		de = [GalUtils unixTimeAtEndOfDay:day month:month year:year] + HALF_DAY;
	} else {
		ds = [GalUtils localUnixTimeAtBeginningOfDay:day month:month year:year];
		de = [GalUtils localUnixTimeAtEndOfDay:day month:month year:year];
	}
	
	flags |= TIME_SPAN_NONE;
	
	// One-day events
	if (_startTimestamp >= ds && _endTimestamp <= de) {
		flags |= TIME_SPAN_TODAY;
	}
	
	// Multi-day events
	if (_startTimestamp <= ds && _endTimestamp > ds) {
		flags |= TIME_SPAN_TODAY_AND_YESTERDAY;
	}
	
	if (_startTimestamp < de && _endTimestamp >= de) {
		flags |= TIME_SPAN_TODAY_AND_TOMORROW;
	}
	
	return flags;
}

#undef HALF_DAY

- (BOOL)eventOccursAtDay:(int)day month:(int)month year:(int)year
{
	int flags = [self eventTimeSpanForDay:day month:month year:year];
	
	return (flags & TIME_SPAN_TODAY) ||
	       (flags & TIME_SPAN_TODAY_AND_YESTERDAY) ||
	       (flags & TIME_SPAN_TODAY_AND_TOMORROW);
}

#define GAL_DATE_FORMAT_INIT \
if (!dateFormatDateTime) { \
dateFormatDateTime = [[NSDateFormatter alloc] init]; \
[dateFormatDateTime setDateStyle:NSDateFormatterShortStyle]; \
[dateFormatDateTime setTimeStyle:NSDateFormatterShortStyle]; \
[dateFormatDate setTimeZone:[GalUtils localTimeZone]]; \
} \
if (!dateFormatDate) { \
dateFormatDate = [[NSDateFormatter alloc] init]; \
[dateFormatDate setDateStyle:NSDateFormatterMediumStyle]; \
[dateFormatDate setTimeZone:[GalUtils localTimeZone]]; \
}

- (NSDate *)startDate
{
	NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:_startTimestamp];
	if (_allDayEvent) {
		/* All-day events are very tricky. Google interprets 
		 * the timestamp for an all-day event by assuming the timestamps are in UTC.
		 * Say there is an all-day event for 17.11.2010.
		 * Therefore, the start timestamp must be 17.11.2010 00:00 UTC.
		 * However, when handling the date in the local timezone,
		 * this can be 16.11.2010, 17.11.2010 or 18.11.2010.
		 * So, we always return a timestamp which
		 * is correct in the local timezone.
		 */
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]]; // Format in UTC
		[dateFormatter setDateFormat:@"yyyy"];
		int year = [[dateFormatter stringFromDate:startDate] intValue];
		[dateFormatter setDateFormat:@"MM"];
		int month = [[dateFormatter stringFromDate:startDate] intValue];
		[dateFormatter setDateFormat:@"dd"];
		int day = [[dateFormatter stringFromDate:startDate] intValue];
		
		int timestamp = [GalUtils localUnixTimeAtBeginningOfDay:day month:month year:year];
		
		// The date picker control doesn't like timestamps at midnight because rounding
		// the time by the accuracy of 5 minutes. Therefore, the time can jump
		// between days randomly. Better add one hour to make sure we stay in this day.
		timestamp += 3600;
		
		startDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
	}
	return startDate;
}

- (NSDate *)endDate
{
	NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:_endTimestamp];
	if (_allDayEvent) {
		/* All-day events are very tricky. Google interprets 
		 * the timestamp for an all-day event by assuming the timestamps are in UTC.
		 * Say there is an all-day event for 17.11.2010.
		 * Therefore, the end timestamp must be 18.11.2010 00:00 UTC.
		 * However, when handling the date in the local timezone,
		 * this can be 16.11.2010, 17.11.2010 or 18.11.2010.
		 * 
		 * To make this even trickier, the user never wants
		 * to see the end day as "18.11.2010" but "17.11.2010".
		 * Therefore, we minus 1 second from the timestamp
		 * to get a "user-friendly" end timestamp.
		 */
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]]; // Format in UTC
		[dateFormatter setDateFormat:@"yyyy"];
		int year = [[dateFormatter stringFromDate:endDate] intValue];
		[dateFormatter setDateFormat:@"MM"];
		int month = [[dateFormatter stringFromDate:endDate] intValue];
		[dateFormatter setDateFormat:@"dd"];
		int day = [[dateFormatter stringFromDate:endDate] intValue];
		
		int timestamp = [GalUtils localUnixTimeAtBeginningOfDay:day month:month year:year] - 1;
		
		// The date picker control doesn't like timestamps at midnight because rounding
		// the time by the accuracy of 5 minutes. Therefore, the time can jump
		// between days randomly. Better remove one hour to make sure we stay in this day.
		timestamp -= 3600;
		
		endDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
	}
	return endDate;
}

- (void)setStartDate:(NSDate *)startDate
{
	if (_allDayEvent) {
		GalDateInformation info = [GalUtils dateInformationFromDate:startDate];
		_startTimestamp = [GalUtils unixTimeAtBeginningOfDay:info.day month:info.month year:info.year];
	} else {
		_startTimestamp = [GalUtils unixTimeFromDate:startDate];
	}
}

- (void)setEndDate:(NSDate *)endDate
{
	if (_allDayEvent) {
		GalDateInformation info = [GalUtils dateInformationFromDate:endDate];
		_endTimestamp = [GalUtils unixTimeAtEndOfDay:info.day month:info.month year:info.year];
	} else {
		_endTimestamp = [GalUtils unixTimeFromDate:endDate];
	}
}

- (NSString *)startDateStringValue
{
	GAL_DATE_FORMAT_INIT
	if (_allDayEvent) {
		// Format with date
		return [dateFormatDate stringFromDate:[self startDate]];
	} else {
		// Format with full date & time
		return [dateFormatDateTime stringFromDate:[self startDate]];
	}
}

- (NSString *)endDateStringValue
{
	GAL_DATE_FORMAT_INIT
	if (_allDayEvent) {
		// Format with date
		return [dateFormatDate stringFromDate:[self endDate]];
	} else {
		// Format with full date & time
		return [dateFormatDateTime stringFromDate:[self endDate]];
	}
}

#undef GAL_DATE_FORMAT_INIT

- (BOOL)originalEvent
{
	return [_originalFeedUrl length] == 0;
}

- (NSURL *)eventFeedUrl
{
	// If the event is an instance of a recurring event,
	// we need to get the feed of the original event.
	if (![self originalEvent]) {
		return [NSURL URLWithString:_originalFeedUrl];
	} else {
		return [NSURL URLWithString:_feedUrl];
	}
}

- (void)updateRemoteEntry:(GDataEntryCalendarEvent *)entry
{
	NSString *titleString = [_title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([titleString length] == 0) {
		[entry setTitleWithString:@"(untitled event)"];
	} else {
		[entry setTitleWithString:_title];
	}
	
	[entry setContentWithString:_description];
	
	NSMutableArray *locations = [[NSMutableArray alloc] initWithCapacity:1];
	GDataWhere *where = [GDataWhere whereWithString:_location];
	[locations addObject:where];
	[entry setLocations:locations];
	
	GDataDateTime *startTime = nil;
	GDataDateTime *endTime = nil;
	
	if (_allDayEvent) {
		// All day events must be added without time information
		startTime = [GDataDateTime dateTimeWithDate:[NSDate dateWithTimeIntervalSince1970:_startTimestamp]
										   timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		endTime = [GDataDateTime dateTimeWithDate:[NSDate dateWithTimeIntervalSince1970:_endTimestamp]
										 timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		[startTime setHasTime:NO];
		[endTime setHasTime:NO];
	} else {
		startTime = [GDataDateTime dateTimeWithDate:[NSDate dateWithTimeIntervalSince1970:_startTimestamp] timeZone:[GalUtils localTimeZone]];
		endTime = [GDataDateTime dateTimeWithDate:[NSDate dateWithTimeIntervalSince1970:_endTimestamp] timeZone:[GalUtils localTimeZone]];
		[startTime setHasTime:YES];
		[endTime setHasTime:YES];
	}
	
	GDataWhen *when = [GDataWhen whenWithStartTime:startTime endTime:endTime];
	
	NSMutableArray *times = [[NSMutableArray alloc] init];
	[times addObject:when];
	[entry setTimes:times];
}

- (NSString *)humanReadableTimeAtDay:(int)day month:(int)month year:(int)year timeFormat24:(BOOL)timeFormat24
{
	NSString *timeString;
	int flags = [self eventTimeSpanForDay:day month:month year:year];
	
	if (_allDayEvent || ((flags & TIME_SPAN_TODAY_AND_YESTERDAY) && (flags & TIME_SPAN_TODAY_AND_TOMORROW))) {
		timeString = @"All day";
	} else {
		GalDateInformation info = [GalUtils dateInformationFromDate:[self startDate]];
		
		int hour = info.hour;
		int minute = info.minute;
		
		NSString *remark = @"";
		
		if ((flags & TIME_SPAN_TODAY_AND_YESTERDAY)) {
			GalDateInformation endDate = [GalUtils dateInformationFromDate:[self endDate]];
			hour = endDate.hour;
			minute = endDate.minute;
			
			remark = @"(ends)";
		}
		
		if (timeFormat24) {
			timeString = [NSString stringWithFormat:@"%i:%02i %@", hour, minute, remark];
		} else {
			timeString = [NSString stringWithFormat:@"%i:%02i %@ %@", (hour > 12 ? hour - 12 : hour),
							  minute,
							  (hour >= 12 ? @"PM" : @"AM"),
							  remark];
		}
	}
	return timeString;
}

@end
