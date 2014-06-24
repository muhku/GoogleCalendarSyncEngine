/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GDataServiceGoogleCalendar;
@class GalGoogleAccount;

@interface GalGoogleCalendarServiceProvider : NSObject {
}

+ (GDataServiceGoogleCalendar *)googleCalendarServiceForGoogleAccount:(GalGoogleAccount *)googleAccount;
+ (void)clearCache;

@end
