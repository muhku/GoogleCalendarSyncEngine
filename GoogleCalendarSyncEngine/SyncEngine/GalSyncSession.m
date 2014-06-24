/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalSyncSession.h"
#import "GalDAO.h"
#import "GalGoogleAccount.h"
#import "GalGoogleCalendar.h"
#import "GalGoogleCalendarEvent.h"
#import "GalSynchronizationJob.h"
#import "GalGoogleCalendarServiceProvider.h"

//#define GAL_DEBUG_SYNC 1

@implementation GalSyncSession

- (id)init
{
	if (self = [super init]) {
		_dao = [[GalDAO alloc] init];
		_synchronizationJobs = [[NSMutableArray alloc] init];
		_googleCalendars = [[NSMutableArray alloc] init];
		
		// Synchronization must be done per Google Account basis
		NSMutableArray *googleAccounts = [_dao googleAccounts];
		NSMutableArray *eventsNotInSync;
		
		// Create a new set of synchronization jobs
		for (id g in googleAccounts) {
			GalGoogleAccount *googleAccount = g;
			// Get events for that particular account
			eventsNotInSync = [_dao locallyModifiedEventsForGoogleAccount:googleAccount];
#ifdef GAL_DEBUG_SYNC
			NSLog(@"init GalRemoteSynchronization. eventsNotInSync, %i events", [eventsNotInSync count]);
#endif
			
			for (id e in eventsNotInSync) {
				GalGoogleCalendarEvent *event = e;
				
				GalGoogleCalendar *googleCalendar = [_dao googleCalendarWithIdentifier:event.googleCalendarIdentifier];
				
				BOOL calendarAddedToSession = NO;
				for (id g in _googleCalendars) {
					GalGoogleCalendar *cal = g;
					if (cal.identifier == googleCalendar.identifier) {
						calendarAddedToSession = YES;
						break;
					}
				}
				if (!calendarAddedToSession) {
					[_googleCalendars addObject:googleCalendar];
				}
				
				GalSynchronizationJob *job = [[GalSynchronizationJob alloc] init];
				job.parent = self;
				job.calendarEvent = event;
				job.syncStatus = event.syncStatus;
				job.service = [GalGoogleCalendarServiceProvider googleCalendarServiceForGoogleAccount:googleAccount];
				job.googleAccount = googleAccount;
				job.googleCalendar = googleCalendar;
				
				[_synchronizationJobs addObject:job];
				 // Balance retain count
			}
		}
		
#ifdef GAL_DEBUG_SYNC
		NSLog(@"init GalRemoteSynchronization. _synchronizationJobs, %i jobs", [_synchronizationJobs count]);
#endif		
    }
    return self;
}

- (void)startSynchronization
{
	GalSynchronizationJob *pendingJob = [self pendingJob];
	[pendingJob synchronizeToGoogle];
}

- (GalSynchronizationJob *)pendingJob
{
	GalSynchronizationJob *pending = nil;
	for (id j in _synchronizationJobs) {
		GalSynchronizationJob *job = j;
		if (!job.started) {		
			pending = job;
			goto EXIT_PENDING_JOB;
		}
	}
EXIT_PENDING_JOB:
	return pending;
}

- (BOOL)failed
{
	BOOL failed = NO;
	for (id j in _synchronizationJobs) {
		GalSynchronizationJob *job = j;
		if (job.error) {
#ifdef GAL_DEBUG_SYNC
			NSLog(@"GalRemoteSynchronization: %@ has failed because of %@", job.calendarEvent.title, [job.error localizedDescription]);
#endif			
			failed = YES;
			goto EXIT_SYNC_FAILED;
		}
	}
	
EXIT_SYNC_FAILED:
	
	return failed;
}

- (void)jobFinished:(GalSynchronizationJob *)job
{
#ifdef GAL_DEBUG_SYNC
	NSLog(@"jobFinished called. Checking if all jobs have finished.");
#endif
	
	@synchronized (self) {
		for (id j in _synchronizationJobs) {
			GalSynchronizationJob *job = j;
#ifdef GAL_DEBUG_SYNC
			NSLog(@"Checking if %@ has finished", job.calendarEvent.title);
#endif
			if (!job.finished) {
#ifdef GAL_DEBUG_SYNC
				NSLog(@"Job %@ has not finished. Starting sync.", job.calendarEvent.title);
#endif
				[job synchronizeToGoogle];
				return;
			}
		}	
				
		if ([self failed]) {
#ifdef GAL_DEBUG_SYNC
			NSLog(@"one or many synchronization jobs failed. Sending a notification");
			NSLog(@"synchronization jobs contains %i jobs", [_synchronizationJobs count]);
#endif
			[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalSyncJobsFailedToFinish"
																object:nil
															  userInfo:nil];		
		} else {
			// All jobs succesfully finished.
			[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalSyncJobsSuccessfullyFinished"
																object:nil
															  userInfo:nil];
		}
#ifdef GAL_DEBUG_SYNC
		NSLog(@"Notification sent.");
#endif		
	}
}

@end
