/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GDataEntryCalendar;
@class GalGoogleAccount;
@class GDataQueryCalendar;
@class GDataDateTime;

@interface GalGoogleCalendar : NSObject {
	// Identifies this object in the database. If identifier > 0, persisted, otherwise not.
	unsigned int _identifier;

	// Reference to a GalGoogleAccount object. if identifer > 0, there is a reference.
	unsigned int _googleAccountIdentifier;
	
	unsigned int _syncTime;
	
	// The calendar ID assigned by Google.
	NSString *_googleCalendarId;
	NSString *_title;
	BOOL _enabled;
	BOOL _canModify;
	
	NSString *_color;
	NSString *_feedUrl;
	
	NSString *_timeZone;
}

@property (readwrite, assign) unsigned int identifier;
@property (readwrite, assign) unsigned int googleAccountIdentifier;
@property (readwrite, assign) unsigned int syncTime;
@property (strong,nonatomic) NSString *googleCalendarId;
@property (strong,nonatomic) NSString *title;
@property (readwrite, assign) BOOL enabled;
@property (readwrite, assign) BOOL canModify;
@property (strong,nonatomic) NSString *color;
@property (strong,nonatomic) NSString *feedUrl;
@property (strong,nonatomic) NSString *timeZone;

- (id)initWithCalendar:(GDataEntryCalendar *)calendar googleAccount:(GalGoogleAccount *)googleAccount;
- (NSURL *)calendarFeedUrl;
- (NSString *)timeZoneNameGMT;
- (GDataQueryCalendar *)queryForEventsStartingAt:(GDataDateTime *)minimumStartTime maximumStartTime:(GDataDateTime *)maximumStartTime;

@end
