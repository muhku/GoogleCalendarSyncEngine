/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GDataEntryCalendarEvent;
@class GalGoogleCalendar;

typedef enum {
	kGalSyncStatusEventHidden = -2,
	kGalSyncStatusEventDeletedLocally = -1,
	kGalSyncStatusEventSynchronized = 0,
	kGalSyncStatusEventAddedLocally = 1,
	kGalSyncStatusEventModifiedLocally = 2
} GalEventSyncStatus;

typedef enum {
	TIME_SPAN_NONE                 = 0x1, // 2^^0    000...00000001
	TIME_SPAN_TODAY                = 0x2, // 2^^1    000...00000010
	TIME_SPAN_TODAY_AND_YESTERDAY  = 0x4, // 2^^2    000...00000100
	TIME_SPAN_TODAY_AND_TOMORROW   = 0x8  // 2^^3    000...00001000
} GalEventTimeSpan;

@interface GalGoogleCalendarEvent : NSObject<NSCopying> {
	// Identifies this object in the database. If identifier > 0, persisted, otherwise not.
	unsigned int _identifier;
	
	// Reference to a GalGoogleCalendar object. if identifer > 0, there is a reference.
	unsigned int _googleCalendarIdentifier;
	
	// The event ID assigned by Google.
	NSString *_googleEventId;
	
	unsigned int _startTimestamp;
	unsigned int _endTimestamp;
	unsigned int _syncTime;
	unsigned int _localUpdateTime;
	unsigned int _remoteUpdateTime;
	
	int _syncStatus;
	
	NSString *_feedUrl;
	NSString *_originalFeedUrl;
	NSString *_title;
	NSString *_description;
	NSString *_location;
	NSString *_color;
	NSString *_recurrence;
	
	BOOL _allDayEvent;
}

@property (readwrite, assign) unsigned int identifier;
@property (readwrite, assign) unsigned int googleCalendarIdentifier;
@property (strong,nonatomic) NSString *googleEventId;

@property (readwrite, assign) unsigned int startTimestamp;
@property (readwrite, assign) unsigned int endTimestamp;
@property (readwrite, assign) unsigned int syncTime;
@property (readwrite, assign) unsigned int localUpdateTime;
@property (readwrite, assign) unsigned int remoteUpdateTime;

@property (readwrite, assign) int syncStatus;

@property (strong,nonatomic) NSString *feedUrl;
@property (strong,nonatomic) NSString *originalFeedUrl;
@property (strong,nonatomic) NSString *title;
@property (strong,nonatomic) NSString *description;
@property (strong,nonatomic) NSString *location;
@property (strong,nonatomic) NSString *color;
@property (strong,nonatomic) NSString *recurrence;

@property (readwrite, assign) BOOL allDayEvent;

- (id)initWithGoogleCalendar:(GalGoogleCalendar *)googleCalendar;
- (id)initWithEvent:(GDataEntryCalendarEvent *)event googleCalendar:(GalGoogleCalendar *)googleCalendar;
- (NSDate *)startDate;
- (NSDate *)endDate;
- (void)setStartDate:(NSDate *)startDate;
- (void)setEndDate:(NSDate *)endDate;
- (int)eventTimeSpanForDay:(int)day month:(int)month year:(int)year;
- (BOOL)eventOccursAtDay:(int)day month:(int)month year:(int)year;
- (BOOL)originalEvent;
- (NSURL *)eventFeedUrl;
- (NSString *)startDateStringValue;
- (NSString *)endDateStringValue;
- (void)updateRemoteEntry:(GDataEntryCalendarEvent *)entry;
- (NSString *)humanReadableTimeAtDay:(int)day month:(int)month year:(int)year timeFormat24:(BOOL)timeFormat24;

@end
