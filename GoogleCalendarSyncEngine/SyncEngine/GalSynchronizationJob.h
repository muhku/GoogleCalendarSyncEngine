/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GalGoogleCalendarEvent;
@class GalGoogleAccount;
@class GalGoogleCalendar;
@class GDataServiceGoogleCalendar;
@class GDataServiceTicket;
@class GalSyncSession;
@class GalDAO;

@interface GalSynchronizationJob : NSObject {
	GalDAO *_dao;
	
	GalSyncSession *__weak _parent;
	
	GalGoogleCalendarEvent *_calendarEvent;
	GalGoogleAccount *_googleAccount;
	GalGoogleCalendar *_googleCalendar;
	
	int _syncStatus;
	BOOL _started;
	BOOL _finished;
	NSError *_error;
	
	GDataServiceGoogleCalendar *_service;
	NSMutableSet *_tickets;
}

@property (nonatomic, weak) GalSyncSession *parent;
@property (strong,nonatomic) GalGoogleCalendarEvent *calendarEvent;
@property (strong,nonatomic) GalGoogleAccount *googleAccount;
@property (strong,nonatomic) GalGoogleCalendar *googleCalendar;
@property (strong,nonatomic) GDataServiceGoogleCalendar *service;
@property (readwrite, assign) BOOL started;
@property (readwrite, assign) BOOL finished;
@property (readwrite, assign) int syncStatus;
@property (strong,nonatomic) NSError *error;

- (void)synchronizeToGoogle;

@end
