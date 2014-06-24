/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalSynchronizationCenter.h"

#import "GData.h"

#import "GalDAO.h"
#import "GalGoogleAccount.h"
#import "GalGoogleCalendarEvent.h"
#import "GalGoogleCalendar.h"
#import "GalUtils.h"
#import "GalSynchronizationJob.h"
#import "GalSyncSession.h"

//#define GAL_DEBUG_SYNC 1

static GalSynchronizationCenter *_sharedSynchronizationCenter = nil;

@interface GalSynchronizationCenter ()
- (void)didFinishSynchronization;
- (void)didFailSynchronization;
@end

@implementation GalSynchronizationCenter

- (id)init
{
    if (self = [super init]) {
#if GAL_DEBUG_SYNC
		NSLog(@"GalSynchronizationCenter.init called");
#endif
        _dao = [[GalDAO alloc] init];
		_session = nil;
		_syncState = kGalSyncStateServiceStarted;
		
		// Listen to events
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishSynchronization)
													 name:@"kGalSyncJobsSuccessfullyFinished" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFailSynchronization)
													 name:@"kGalSyncJobsFailedToFinish" object:nil];
    }
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (GalSynchronizationCenter *)sharedSynchronizationCenter
{
	if (!_sharedSynchronizationCenter) {
		_sharedSynchronizationCenter = [[GalSynchronizationCenter alloc] init];
	}
	return _sharedSynchronizationCenter;
}

- (BOOL)synchronizationNeeded
{
	return [_dao hasLocallyModifiedEvents];
}

- (void)resetFailedSynchronization
{
	@synchronized (self) {
		assert(_syncState == kGalSyncStateLastSyncFailed);
		
		if (_syncState != kGalSyncStateLastSyncFailed) {
			return;
		}
		
		_syncState = kGalSyncStateServiceStarted;
	}
}

- (NSMutableArray *)failedJobs
{
	NSMutableArray *arr = [[NSMutableArray alloc] init];
	
	if (_syncState != kGalSyncStateLastSyncFailed) {
		goto JOB_FAIL_EXIT;
	}
	
	for (id job in _session.synchronizationJobs) {
		if ([job error]) {
			[arr addObject:job];
		}
	}
	
JOB_FAIL_EXIT:	
	return arr;
}

- (NSMutableArray *)synchronizedCalendars
{
	NSMutableArray *arr = [[NSMutableArray alloc] init];
	
	if (!_session ||
		_syncState != kGalSyncStateServiceStarted) {
		goto done;
	}
	
	for (id g in _session.googleCalendars) {
		[arr addObject:g];
	}
	
done:	
	return arr;
}

- (void)disableSynchronization
{
	@synchronized (self) {
		if (kGalSyncStateServiceStopped == _syncState) {
			return;
		}
		_syncState = kGalSyncStateServiceStopped;
		
#if TARGET_IPHONE_SIMULATOR || defined(DEBUG) || (!defined(NS_BLOCK_ASSERTIONS) && !defined(NDEBUG))
		NSLog(@"GalSynchronizionCenter: stopped");
#endif		
	}
	// If any existing jobs are running, terminate them
	[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteSynchronizationCancelAllJobs" object:nil];
}

- (BOOL)isSynchronizationDisabled
{
	BOOL disabled = NO;
	@synchronized (self) {
		disabled = (kGalSyncStateServiceStopped == _syncState);
	}
	return disabled;
}

- (void)enableSynchronization
{
	@synchronized (self) {
		if (kGalSyncStateServiceStopped != _syncState) {
			return;
		}
		_syncState = kGalSyncStateServiceStarted;
		
#if TARGET_IPHONE_SIMULATOR || defined(DEBUG) || (!defined(NS_BLOCK_ASSERTIONS) && !defined(NDEBUG))
		NSLog(@"GalSynchronizionCenter: started");
#endif
	}
}

- (void)triggerLocalToRemoteSynchronization
{
#if TARGET_IPHONE_SIMULATOR || defined(DEBUG) || (!defined(NS_BLOCK_ASSERTIONS) && !defined(NDEBUG))
	NSLog(@"GalSynchronizationCenter: triggerLocalToRemoteSynchronization called");
#endif	
	
	@synchronized (self) {
		if (!(kGalSyncStateServiceStarted == _syncState)) {
#if GAL_DEBUG_SYNC
			NSString *state = @"unknown";
			if (_syncState == kGalSyncStateServiceStarted)
				state = @"idle";
			else if (_syncState == kGalSyncStateSyncRunning)
				state = @"running";
			else if (_syncState == kGalSyncStateLastSyncFailed)
				state = @"sync failed";
			else if (_syncState == kGalSyncStateServiceStopped)
				state = @"sync disabled";
			NSLog(@"GalSynchronizationCenter.triggerLocalToRemoteSynchronization: Cannot start synchronization: syncState == %@", state);
#endif
			return;
		} else {
			_syncState = kGalSyncStateSyncRunning;
		}
	}
	
	assert(kGalSyncStateSyncRunning == _syncState);
	
	if (![self synchronizationNeeded]) {
		@synchronized (self) {
			_syncState = kGalSyncStateServiceStarted;
		}

#if GAL_DEBUG_SYNC
        NSLog(@"GalSynchronizationCenter, no sync needed, return.");
#endif
        
		return;
	}
	
	_session = [[GalSyncSession alloc] init];
	
	if ([_session.synchronizationJobs count] == 0) {
		@synchronized (self) {
			_syncState = kGalSyncStateServiceStarted;
		}
        
#if GAL_DEBUG_SYNC
        NSLog(@"GalSynchronizationCenter, no sync jobs, return.");
#endif
        
		return;
	}
	
#if GAL_DEBUG_SYNC
    NSLog(@"GalSynchronizationCenter, sync in progress!");
#endif
    
	[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteSyncInProgress"
														object:nil
													  userInfo:nil];
	
	[_session startSynchronization];
}

- (void)addEvent:(GalGoogleCalendarEvent *)event
{
	event.syncStatus = kGalSyncStatusEventAddedLocally;
	event.localUpdateTime = [GalUtils currentUnixTime];
	[_dao saveGoogleCalendarEvent:event];
}

- (void)modifyEvent:(GalGoogleCalendarEvent *)event
{
	GalGoogleCalendarEvent *existingEvent = [_dao googleCalendarEventWithIdentifier:event.identifier];
	existingEvent.title = event.title;
	existingEvent.location = event.location;
	existingEvent.description = event.description;
	existingEvent.startTimestamp = event.startTimestamp;
	existingEvent.endTimestamp = event.endTimestamp;
	existingEvent.allDayEvent = event.allDayEvent;
	existingEvent.recurrence = event.recurrence;
	existingEvent.localUpdateTime = [GalUtils currentUnixTime];
	
	if (kGalSyncStatusEventAddedLocally != existingEvent.syncStatus) {
		// If modifying a locally added event which has not been yet
		// syncronized to Google, keep the sync status as "added locally".
		// Otherwise the state change to "modified" is valid.
		existingEvent.syncStatus = kGalSyncStatusEventModifiedLocally;
	}
	
	[_dao saveGoogleCalendarEvent:existingEvent];
}

- (void)deleteEvent:(GalGoogleCalendarEvent *)event
{
    GalGoogleCalendarEvent *existingEvent = [_dao googleCalendarEventWithIdentifier:event.identifier];
    
	if (kGalSyncStatusEventDeletedLocally == existingEvent.syncStatus) {
		// This event has been already marked for deletion
		return;
	}
	
	// Check if the event can be deleted locally without deleting it from the
	// remote service.
	if (kGalSyncStatusEventHidden == existingEvent.syncStatus ||
		kGalSyncStatusEventAddedLocally == existingEvent.syncStatus) {
		[_dao removeGoogleCalendarEvent:existingEvent];
		return;
	}
	
	[_dao updateSyncStatusForEvent:existingEvent status:kGalSyncStatusEventDeletedLocally];
}

/* Private implementation */

- (void)didFailSynchronization
{
#if GAL_DEBUG_SYNC
	NSLog(@"GalSynchronizationCenter.didFailSynchronization called");
#endif	
	
	// Called upon the "kGalSyncJobsFailedToFinish" signal.
	@synchronized (self) {
		assert(_syncState != kGalSyncStateLastSyncFailed);
		assert(_syncState != kGalSyncStateServiceStarted);
		assert(_syncState == kGalSyncStateSyncRunning);
		
		// Leave the current GalRemoteSynchronization in memory
		// so the failure can be handled.
		_syncState = kGalSyncStateLastSyncFailed;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteSyncFailed"
														object:nil
													  userInfo:nil];
}

- (void)didFinishSynchronization
{
#if GAL_DEBUG_SYNC
	NSLog(@"GalSynchronizationCenter.didFinishSynchronization called");
#endif
	
	// Called upon the "didFinishSynchronization" signal.
	@synchronized (self) {
		assert(_syncState != kGalSyncStateLastSyncFailed);
		assert(_syncState != kGalSyncStateServiceStarted);
		assert((_syncState == kGalSyncStateSyncRunning) || (_syncState == kGalSyncStateServiceStopped));
		
		if (kGalSyncStateSyncRunning == _syncState) {
			_syncState = kGalSyncStateServiceStarted;
		} else if (kGalSyncStateServiceStopped == _syncState) {
			// Keep the service disabled.
			;
		}
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteSyncFinished"
														object:nil
													  userInfo:nil];
}

- (BOOL)hasOnGoingSync
{
	BOOL onGoing = NO;
	
	if (_syncState == kGalSyncStateSyncRunning) {
		onGoing = YES;
	}
	
	return onGoing;
}

@end