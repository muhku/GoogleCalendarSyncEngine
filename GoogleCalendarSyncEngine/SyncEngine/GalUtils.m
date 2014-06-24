/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalUtils.h"

#import <CommonCrypto/CommonDigest.h>

#define CF_UNIX_EPOCH 978307200
#define UXUTIL_DATE_COMPONENTS (NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit)

static NSCalendar *UXUTIL_GREGORIAN_CALENDAR;

@implementation GalUtils

+ (NSString *)sha1hash:(NSString *)string
{
	const char *s = [string UTF8String];
	NSData *keyData = [NSData dataWithBytes:s length:strlen(s)];
	
	uint8_t digest[CC_SHA1_DIGEST_LENGTH] = {0};
    
	CC_SHA1(keyData.bytes, keyData.length, digest);
	
	NSString *hash = [[NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH] description];
	hash = [hash stringByReplacingOccurrencesOfString:@" " withString:@""];
	hash = [hash stringByReplacingOccurrencesOfString:@"<" withString:@""];
	hash = [hash stringByReplacingOccurrencesOfString:@">" withString:@""];
	return hash;
}

+ (GalDateInformation)dateInformationFromDate:(NSDate *)date
{
	GalDateInformation info;
	
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDateComponents *comp = [gregorian components:(NSMonthCalendarUnit |
                                                    NSMinuteCalendarUnit |
                                                    NSYearCalendarUnit |
													NSDayCalendarUnit |
                                                    NSWeekdayCalendarUnit |
                                                    NSHourCalendarUnit |
                                                    NSSecondCalendarUnit)
										  fromDate:date];
	info.day = [comp day];
	info.month = [comp month];
	info.year = [comp year];
	
	info.hour = [comp hour];
	info.minute = [comp minute];
	info.second = [comp second];
	
	info.weekday = [comp weekday];
    
	return info;
}

+ (unsigned int)numberOfDaysInMonth:(unsigned int)month year:(unsigned int)year
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

+ (int)unixTimeAtBeginningOfMonth:(unsigned int)month year:(unsigned int)year
{
	CFGregorianDate gt;
	gt.year = year;
	gt.month = month;
	gt.day = 1;
	gt.hour = 0;
	gt.minute = 0;
	gt.second = 0;
	NSTimeInterval result = CFGregorianDateGetAbsoluteTime(gt, NULL);
	int uxtime = CF_UNIX_EPOCH + (int) result;
	return uxtime;
}

+ (int)unixTimeAtEndOfMonth:(unsigned int)month year:(unsigned int)year
{
	if (12 == month) {
		year = year + 1;
		month = 1;
	} else {
		month = month + 1;
	}
	int uxtime = [GalUtils unixTimeAtBeginningOfMonth:month year:year];
	return uxtime;
}

+ (int)unixTimeAtBeginningOfDay:(unsigned int)day month:(unsigned int)month year:(unsigned int)year
{
	CFGregorianDate gt;
	gt.year = year;
	gt.month = month;
	gt.day = day;
	gt.hour = 0;
	gt.minute = 0;
	gt.second = 0;
	NSTimeInterval result = CFGregorianDateGetAbsoluteTime(gt, NULL);
	int uxtime = CF_UNIX_EPOCH + (int) result;
	return uxtime;
}

+ (int)unixTimeAtEndOfDay:(unsigned int)day month:(unsigned int)month year:(unsigned int)year
{
	if ([GalUtils numberOfDaysInMonth:month year:year] == day) {
		day = 1;
		if (12 == month) {
			year = year + 1;
			month = 1;
		} else {
			month = month + 1;
		}
	} else {
		day = day + 1;
	}
	int uxtime = [GalUtils unixTimeAtBeginningOfDay:day month:month year:year];
	return uxtime;
}

+ (int)localUnixTimeAtBeginningOfMonth:(unsigned int)month year:(unsigned int)year
{
	int uxtime = [GalUtils unixTimeAtBeginningOfMonth:month year:year];
	int offset = [GalUtils localTimeZoneOffset:1 month:month year:year];
	return (uxtime - offset);
}

+ (int)localUnixTimeAtEndOfMonth:(unsigned int)month year:(unsigned int)year
{
	int uxtime = [GalUtils unixTimeAtEndOfMonth:month year:year];
	int offset = [GalUtils localTimeZoneOffset:[GalUtils numberOfDaysInMonth:month year:year]
											 month:month year:year];
	return (uxtime - offset);
}

+ (int)localUnixTimeAtBeginningOfDay:(unsigned int)day month:(unsigned int)month year:(unsigned int)year
{
	int uxtime = [GalUtils unixTimeAtBeginningOfDay:day month:month year:year];
	int offset = [GalUtils localTimeZoneOffset:day month:month year:year];
	return (uxtime - offset);
}

+ (int)localUnixTimeAtEndOfDay:(unsigned int)day month:(unsigned int)month year:(unsigned int)year
{
	int uxtime = [GalUtils unixTimeAtEndOfDay:day month:month year:year];
	int offset = [GalUtils localTimeZoneOffset:day month:month year:year];
	return (uxtime - offset);
}

+ (int)localTimeZoneOffset:(unsigned int)day month:(unsigned int)month year:(unsigned int)year
{
	if (!UXUTIL_GREGORIAN_CALENDAR) {
		UXUTIL_GREGORIAN_CALENDAR = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	}
	NSDateComponents *components = [UXUTIL_GREGORIAN_CALENDAR components:UXUTIL_DATE_COMPONENTS
																fromDate:[NSDate date]];
	[components setDay:day];
	[components setMonth:month];
	[components setYear:year];
	[components setHour:1];
	[components setMinute:0];
	NSDate *date = [UXUTIL_GREGORIAN_CALENDAR dateFromComponents:components];
	
	NSTimeZone *tz = [GalUtils localTimeZone];
	return [tz secondsFromGMTForDate:date];
}

+ (NSTimeZone *)localTimeZone
{
	return [NSTimeZone systemTimeZone];
}

+ (int)currentUnixTime
{
	return [GalUtils unixTimeFromDate:[NSDate date]];
}

+ (unsigned int)unixTimeFromDate:(NSDate *)date
{
	double t = (double) [date timeIntervalSince1970];
	unsigned int ts = (unsigned int) t;
	return ts;
}

@end