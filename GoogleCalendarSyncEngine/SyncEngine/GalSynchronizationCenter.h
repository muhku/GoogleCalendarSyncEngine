/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GalDAO;
@class GalSyncSession;
@class GalGoogleCalendarEvent;

typedef enum {
	kGalSyncStateServiceStarted = 0,  // Started and free to synchronize
	kGalSyncStateSyncRunning = 1,     // Synchronization is running
	kGalSyncStateLastSyncFailed = 2,  // The last synchronization failed 
	kGalSyncStateServiceStopped = 3   // Stopped and do not accept synchronization requests
} GalSynchronizationState;

@interface GalSynchronizationCenter : NSObject {
	GalDAO *_dao;
	GalSyncSession *_session;
	GalSynchronizationState _syncState;
}

+ (GalSynchronizationCenter *)sharedSynchronizationCenter;

- (BOOL)synchronizationNeeded;
- (void)triggerLocalToRemoteSynchronization;
- (void)resetFailedSynchronization;
- (void)disableSynchronization;
- (void)enableSynchronization;
- (BOOL)isSynchronizationDisabled;
- (NSMutableArray *)failedJobs;
- (NSMutableArray *)synchronizedCalendars;
- (BOOL)hasOnGoingSync;

- (void)addEvent:(GalGoogleCalendarEvent *)event;
- (void)modifyEvent:(GalGoogleCalendarEvent *)event;
- (void)deleteEvent:(GalGoogleCalendarEvent *)event;

@end
