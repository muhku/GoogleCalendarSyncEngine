/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

struct GalDateInformation {
	int day;
	int month;
	int year;
	
	int weekday;
	
	int minute;
	int hour;
	int second;
};
typedef struct GalDateInformation GalDateInformation;

@interface GalUtils : NSObject {

}

+ (NSString *)sha1hash:(NSString *)string;
+ (GalDateInformation)dateInformationFromDate:(NSDate *)date;

+ (int)unixTimeAtBeginningOfMonth:(unsigned int)month year:(unsigned int)year;
+ (int)unixTimeAtEndOfMonth:(unsigned int)month year:(unsigned int)year;
+ (int)unixTimeAtBeginningOfDay:(unsigned int)day month:(unsigned int)month year:(unsigned int)year;
+ (int)unixTimeAtEndOfDay:(unsigned int)day month:(unsigned int)month year:(unsigned int)year;

+ (int)localUnixTimeAtBeginningOfMonth:(unsigned int)month year:(unsigned int)year;
+ (int)localUnixTimeAtEndOfMonth:(unsigned int)month year:(unsigned int)year;
+ (int)localUnixTimeAtBeginningOfDay:(unsigned int)day month:(unsigned int)month year:(unsigned int)year;
+ (int)localUnixTimeAtEndOfDay:(unsigned int)day month:(unsigned int)month year:(unsigned int)year;

+ (int)currentUnixTime;
+ (NSTimeZone *)localTimeZone;
+ (int)localTimeZoneOffset:(unsigned int)day month:(unsigned int)month year:(unsigned int)year;

+ (unsigned int)unixTimeFromDate:(NSDate *)date;

+ (unsigned int)numberOfDaysInMonth:(unsigned int)month year:(unsigned int)year;

@end