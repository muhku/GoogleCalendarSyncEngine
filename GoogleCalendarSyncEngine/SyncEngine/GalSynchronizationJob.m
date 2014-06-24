/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalSynchronizationJob.h"

#import "GalSyncSession.h"
#import "GalGoogleCalendarEvent.h"
#import "GalGoogleCalendar.h"
#import "GalUtils.h"
#import "GalDAO.h"
#import "GalGoogleAccount.h"

#import "GData.h"

@interface GalSynchronizationJob ()
- (void)cancelJob;
- (void)addTicket:(GDataServiceTicket *)ticket;
- (void)removeTicket:(GDataServiceTicket *)ticket;
- (void)didReceiveEventForUpdate:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error;
- (void)didFinishEventUpdate:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error;
- (void)didFinishEventAdd:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error;
- (void)didReceiveEventForDelete:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error;
- (void)didFinishEventDelete:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error;
- (void)notifySyncProgress:(NSString *)message;
@end

@implementation GalSynchronizationJob

- (id)init
{
    if (self = [super init]) {
		_dao = [[GalDAO alloc] init];
		_parent = nil;
		_calendarEvent = nil;
		_googleAccount = nil;
		_googleCalendar = nil;
		
		_syncStatus = 0;
		_started = NO;
		_finished = NO;
		_error = nil;
		
		_service = nil;
		_tickets = [[NSMutableSet alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelJob)
													 name:@"kGalRemoteSynchronizationCancelAllJobs" object:nil];
    }
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setFinished:(BOOL)finished
{
	if (_finished) {
		// If the job is once set as finished, prevent
		// any further state changes. If the finished
		// state is triggered twice it can cause signals
		// emitted twice. This can happen because the synchronization
		// methods here can set self.finished in case of errors twice. 
		return;
	}
	_finished = finished;
	if (_finished) {
		[_parent jobFinished:self];
	}
}

- (BOOL)finished
{
	return _finished;
}

- (void)synchronizeToGoogle
{
	_started = YES;
	
	NSString *status = @"";
	GDataServiceTicket *ticket = nil;
	
	if (kGalSyncStatusEventModifiedLocally == _syncStatus) {
		NSURL *eventURL = [_calendarEvent eventFeedUrl];
		ticket = [_service fetchEntryWithURL:eventURL
									delegate:self
							didFinishSelector:@selector(didReceiveEventForUpdate:finishedWithEntry:error:)];
		
		status = [NSString stringWithFormat:@"Get: %@", _calendarEvent.title];
	} else if (kGalSyncStatusEventAddedLocally == _syncStatus) {			
		GDataEntryCalendarEvent *newEvent = [GDataEntryCalendarEvent calendarEvent];
		[_calendarEvent updateRemoteEntry:newEvent];
		
		ticket = [_service fetchEntryByInsertingEntry:newEvent
										   forFeedURL:[_googleCalendar calendarFeedUrl]
											delegate:self
									didFinishSelector:@selector(didFinishEventAdd:finishedWithEntry:error:)];			
		
		status = [NSString stringWithFormat:@"Add: %@", _calendarEvent.title];
	} else if (kGalSyncStatusEventDeletedLocally == _syncStatus) {				
		NSURL *eventURL = [_calendarEvent eventFeedUrl];
		ticket = [_service fetchEntryWithURL:eventURL delegate:self
						   didFinishSelector:@selector(didReceiveEventForDelete:finishedWithEntry:error:)];
		
		status = [NSString stringWithFormat:@"Get: %@", _calendarEvent.title];
	}
	
	if (ticket) {
		[self addTicket:ticket];
		[self notifySyncProgress:status];
	} else {
		NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
		[errorDetail setValue:@"Unable to start synchronization" forKey:NSLocalizedDescriptionKey];
		self.error = [NSError errorWithDomain:@"goocal" code:100 userInfo:errorDetail];
		self.finished = YES;
	}
}

/* Private methods */

- (void)cancelJob
{
	if (_finished) {
		return;
	}
	
	[_tickets makeObjectsPerformSelector:@selector(cancelTicket)];
	@synchronized (self) {
		[_tickets removeAllObjects];
	}
	
	_error = nil;
	
	[self setFinished:YES];
}

- (void)addTicket:(GDataServiceTicket *)ticket
{
	@synchronized (self) {
		[_tickets addObject:ticket];
	}
}

- (void)removeTicket:(GDataServiceTicket *)ticket
{
	@synchronized (self) {
		[_tickets removeObject:ticket];
	}
}

/* Modify event */

- (void)didReceiveEventForUpdate:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error
{
#if GAL_DEBUG_SYNC
	NSLog(@"didReceiveEventForUpdate called");
#endif
	
	GDataServiceTicket *updateTicket = nil;
	
	if (error) {
		self.error = error;
		self.finished = YES;
		goto EXIT_EV_RECV_UPDATE;
	}
	
	[_calendarEvent updateRemoteEntry:completeEntry];
	
	updateTicket = [_service fetchEntryByUpdatingEntry:completeEntry
																	 delegate:self
															didFinishSelector:@selector(didFinishEventUpdate:finishedWithEntry:error:)];
	[self addTicket:updateTicket];
	
	[self notifySyncProgress:[NSString stringWithFormat:@"Update: %@", _calendarEvent.title]];
	
EXIT_EV_RECV_UPDATE:
	
	[self removeTicket:ticket];
}

- (void)didFinishEventUpdate:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error
{
#if GAL_DEBUG_SYNC
	NSLog(@"didFinishEventUpdate called");
#endif
	
	GalGoogleCalendarEvent *event = nil;
	GalGoogleCalendarEvent *existingEvent = nil;
	
	if (error) {
		self.error = error;
		self.finished = YES;
		goto EXIT_EV_FINISH_UPDATE;
	}
	
	event = [[GalGoogleCalendarEvent alloc] initWithEvent:completeEntry googleCalendar:_googleCalendar];
	existingEvent = [_dao googleCalendarEventWithGoogleEventId:event.googleEventId];
	
	if (existingEvent) {
		event.identifier = existingEvent.identifier;
	}
	
	event.syncStatus = kGalSyncStatusEventSynchronized;
	[_dao saveGoogleCalendarEvent:event];
	
	[self notifySyncProgress:[NSString stringWithFormat:@"Done: %@", _calendarEvent.title]];
	
EXIT_EV_FINISH_UPDATE:	
	
	self.finished = YES;
	[self removeTicket:ticket];
	
#if GAL_DEBUG_SYNC
	NSLog(@"didFinishEventUpdate finished");
#endif		
}

/* Add event */

- (void)didFinishEventAdd:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error
{
#if GAL_DEBUG_SYNC
	NSLog(@"didFinishEventAdd called");
#endif	
	
	GalGoogleCalendarEvent *event = nil;
	
	if (error) {
		self.error = error;
		self.finished = YES;
		goto EXIT_EV_FINISH_ADD;
	}
	
	event = [[GalGoogleCalendarEvent alloc] initWithEvent:completeEntry googleCalendar:_googleCalendar];
	event.identifier = _calendarEvent.identifier;
	event.syncStatus = kGalSyncStatusEventSynchronized;
	[_dao saveGoogleCalendarEvent:event];
	
EXIT_EV_FINISH_ADD:
	
	self.finished = YES;
	[self removeTicket:ticket];
	
#if GAL_DEBUG_SYNC
	NSLog(@"didFinishEventAdd finished");
#endif		
}

/* Delete event */

- (void)didReceiveEventForDelete:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error
{
#if GAL_DEBUG_SYNC
	NSLog(@"didReceiveEventForDelete called");
#endif
	
	GDataServiceTicket *deleteTicket = nil;
	
	if (error) {
		self.error = error;
		self.finished = YES;
		goto EXIT_EV_RECV_DELETE;
	}
	
	deleteTicket = [_service deleteEntry:completeEntry delegate:self didFinishSelector:@selector(didFinishEventDelete:finishedWithEntry:error:)];
	[self addTicket:deleteTicket];
	
	[self notifySyncProgress:[NSString stringWithFormat:@"Delete: %@", _calendarEvent.title]];
	
EXIT_EV_RECV_DELETE:	
	
	[self removeTicket:ticket];
	
#if GAL_DEBUG_SYNC
	NSLog(@"didReceiveEventForDelete finished");
#endif		
}

- (void)didFinishEventDelete:(GDataServiceTicket *)ticket finishedWithEntry:(GDataEntryCalendarEvent *)completeEntry error:(NSError *)error {
#if GAL_DEBUG_SYNC
	NSLog(@"didFinishEventDelete called");
#endif		
	
	if (error) {
		self.error = error;
		self.finished = YES;
		goto EXIT_EV_FINISH_DELETE;
	}
	
	[_dao removeGoogleCalendarEvent:_calendarEvent];
	
EXIT_EV_FINISH_DELETE:
	
	self.finished = YES;
	[self removeTicket:ticket];
	
#if GAL_DEBUG_SYNC
	NSLog(@"didFinishEventDelete finished");
#endif		
}

- (void)notifySyncProgress:(NSString *)message
{
	NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
	[userInfo setObject:message forKey:@"syncStatusMessage"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"kGalRemoteSyncStatusUpdate"
														object:nil
													  userInfo:userInfo];
}

@end
