/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

@class GalDAO;
@class GalSynchronizationJob;
@class GalSynchronizationCenter;

@interface GalSyncSession : NSObject {
	GalDAO *_dao;
	NSMutableArray *_synchronizationJobs;
	NSMutableArray *_googleCalendars;
}

@property (readonly) NSMutableArray *synchronizationJobs;
@property (readonly) NSMutableArray *googleCalendars;

- (void)startSynchronization;
- (GalSynchronizationJob *)pendingJob;
- (void)jobFinished:(GalSynchronizationJob *)job;
- (BOOL)failed;

@end