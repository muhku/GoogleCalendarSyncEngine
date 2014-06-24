/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalGoogleCalendar.h"
#import "GalGoogleAccount.h"
#import "GData.h"
#import "GalUtils.h"

@implementation GalGoogleCalendar

- (id)init
{
    if (self = [super init]) {
		_identifier = 0;
		_googleAccountIdentifier = 0;
		_title = @"";
		_enabled = NO;
		_canModify = NO;
		_color = @"";
		_feedUrl = @"";
		_googleCalendarId = @"";
		_syncTime = 0;
		
		NSString *localTimeZoneName = [[GalUtils localTimeZone] name];
		_timeZone =  [[NSString alloc] initWithString:localTimeZoneName]; // copy
    }
    return self;
}

- (id)initWithCalendar:(GDataEntryCalendar *)calendar googleAccount:(GalGoogleAccount *)googleAccount
{
    if (self = [super init]) {
		_identifier = 0;
		_googleAccountIdentifier = [googleAccount identifier];
		
		NSString *titleString = [calendar.title stringValue];
		if (titleString) {
			_title = [[NSString alloc] initWithString:titleString]; // copy
		} else {
			_title = @"";
		}

		_enabled = YES;
		
		NSString *colorString = [calendar.color stringValue];
		if (colorString) {
			_color = [[NSString alloc] initWithString:colorString]; // copy
		} else {
			_color = @"";
		}

		NSString *feedURL = [[calendar.alternateLink URL] absoluteString];
		if (feedURL) {
			_feedUrl = [[NSString alloc] initWithString:feedURL]; // copy
		} else {
			_feedUrl = @"";
		}
		
		// Google's calendar ID is not feasible for searching. It's a long URL string which
		// can exceed 100 characters (or much more). For this reason, generate a SHA-1 hash
		// for an ID.		
		_googleCalendarId = [[NSString alloc] initWithString:[GalUtils sha1hash:calendar.identifier]]; // copy
		
		_syncTime = [GalUtils currentUnixTime]; // store timestamp in UTC
		
		NSString *accessLevel = [[calendar accessLevel] stringValue];
		
		 if ([kGDataCalendarAccessEditor isEqualToString:accessLevel] ||
			 [kGDataCalendarAccessOwner isEqualToString:accessLevel] ||
			 [kGDataCalendarAccessRoot isEqualToString:accessLevel]) {
			 _canModify = YES;
		} else {
			_canModify = NO;
		}
		
		NSString *calendarTimeZone = [[calendar timeZoneName] stringValue];
		if (calendarTimeZone) {
			_timeZone =  [[NSString alloc] initWithString:calendarTimeZone]; // copy
		} else {
			NSString *localTimeZoneName = [[GalUtils localTimeZone] name];
			_timeZone =  [[NSString alloc] initWithString:localTimeZoneName]; // copy
		}
    }
    return self;
}

- (NSURL *)calendarFeedUrl
{
	return [NSURL URLWithString:_feedUrl];
}

- (NSString *)timeZoneNameGMT
{
	NSTimeZone *calendarTimeZone = [NSTimeZone timeZoneWithName:_timeZone];
	if (!calendarTimeZone) {
		return @"Unknown";
	}
	int hours = [calendarTimeZone secondsFromGMTForDate:[NSDate date]] / 3600;
	
	NSString *tz;
	if (hours < 0) {
		tz = [NSString stringWithFormat:@"GMT%i", hours];
	} else {
		tz = [NSString stringWithFormat:@"GMT+%i", hours];
	}
	
	return tz;
}

- (GDataQueryCalendar *)queryForEventsStartingAt:(GDataDateTime *)minimumStartTime maximumStartTime:(GDataDateTime *)maximumStartTime
{
	GDataQueryCalendar *query = [GDataQueryCalendar calendarQueryWithFeedURL:[self calendarFeedUrl]];		
	[query setMinimumStartTime:minimumStartTime];
	[query setMaximumStartTime:maximumStartTime];
	[query setOrderBy:@"starttime"];  // http://code.google.com/apis/calendar/docs/2.0/reference.html#Parameters
	[query setIsAscendingOrder:YES];
	[query setShouldExpandRecurrentEvents:YES];
	// The start index for query results. This is a 1-based index.
	[query setStartIndex:1];
	// Sets the maximum number of results to return for the query.
	// Note: a GData server may choose to provide fewer results, but will never
	// provide more than the requested maximum.
	[query setMaxResults:1000];
	return query;
}

@end
