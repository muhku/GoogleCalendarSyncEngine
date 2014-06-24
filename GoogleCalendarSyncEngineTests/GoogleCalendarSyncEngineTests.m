/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <XCTest/XCTest.h>
#import "GalUtils.h"
#import "GalGoogleCalendarEvent.h"
#import "GalDAO.h"
#import "GalGoogleAccount.h"
#import "GalGoogleCalendarEventService.h"
#import "GalEventList.h"
#import "GalGoogleCalendarService.h"
#import "GalGoogleCalendar.h"
#import "GalGoogleCalendarEvent.h"
#import "GalSynchronizationCenter.h"

/*
 * You must have a Google Account for testing. Do not use
 * your own account but create a test account in order
 * to prevent possible data loss.
 *
 * Create some events (recurring events are good) so that
 * there's some data for default to fetch.
 *
 * Please note that 2-factor authentication is not currently
 * supported so disable it from the account.
 */

#define TEST_GOOGLE_ACCOUNT_USERNAME    "REPLACETHIS@google.com"
#define TEST_GOOGLE_ACCOUNT_PASSWORD    "REPLACEWITHPASSWORD"

@interface GoogleCalendarSyncEngineTests : XCTestCase {
    GalDAO *_dao;
    GalGoogleCalendarService *_calendarService;
    GalGoogleCalendarEventService *_eventService;
}

@property (readonly) GalDAO *dao;
@property (readonly) GalGoogleCalendarService *calendarService;
@property (readonly) GalGoogleCalendarEventService *eventService;
@property (nonatomic,assign) BOOL keepRunning;
@property (nonatomic,assign) BOOL checkState;

- (void)fetchRemoteGoogleCalendars;

@end

@implementation GoogleCalendarSyncEngineTests

- (GalDAO *)dao
{
    if (!_dao) {
        _dao = [[GalDAO alloc] init];
    }
    return _dao;
}

- (GalGoogleCalendarService *)calendarService
{
    if (!_calendarService) {
        _calendarService = [[GalGoogleCalendarService alloc] init];
    }
    return _calendarService;
}

- (GalGoogleCalendarEventService *)eventService
{
    if (!_eventService) {
        _eventService = [[GalGoogleCalendarEventService alloc] init];
    }
    return _eventService;
}

- (void)fetchRemoteGoogleCalendars
{
    _checkState = NO;
    _keepRunning = YES;
    
    [self.calendarService triggerRemoteGoogleCalendarsFetch];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"kGalRemoteCalendarFetchDone"
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *notification) {
                                                      
                                                      NSLog(@"kGalRemoteCalendarFetchDone received!");
                                                      
                                                      _checkState = YES;
                                                  }];
    
    NSTimeInterval timeout = 60.0;
    NSTimeInterval idle = 0.1;
    BOOL timedOut = NO;
    
    NSDate *timeoutDate = [[NSDate alloc] initWithTimeIntervalSinceNow:timeout];
    while (!timedOut && _keepRunning) {
        NSDate *tick = [[NSDate alloc] initWithTimeIntervalSinceNow:idle];
        [[NSRunLoop currentRunLoop] runUntilDate:tick];
        timedOut = ([tick compare:timeoutDate] == NSOrderedDescending);
        
        if (_checkState) {
            // Fetch completed
            
            NSMutableArray *calendars = [self.dao googleCalendars];
            
            XCTAssertTrue([calendars count] > 0);
            
            for (GalGoogleCalendar *calendar in calendars) {
                NSLog(@"Calendar found: %@", calendar.title);
            }
            
            return;
        }
    }
    
    XCTAssertFalse(timedOut, @"Timed out - failed to fetch the calendars");
}

- (void)fetchRemoteEvents
{
    _checkState = NO;
    _keepRunning = YES;
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"kGalRemoteEventFetchDone"
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *notification) {
                                                      
                                                      NSLog(@"kGalRemoteEventFetchDone received!");
                                                      
                                                      _checkState = YES;
                                                  }];
    
    NSDate *start = [[NSDate alloc] init];
    
    [self.eventService setPastDaysToSync:7];
    [self.eventService  setFutureDaysToSync:30];
    
    NSLog(@"Calling triggerRemoteEventFetchFromDate");
    
    [self.eventService triggerRemoteEventFetchFromDate:start];
    
    NSTimeInterval timeout = 60.0;
    NSTimeInterval idle = 0.1;
    BOOL timedOut = NO;
    
    NSDate *timeoutDate = [[NSDate alloc] initWithTimeIntervalSinceNow:timeout];
    while (!timedOut && _keepRunning) {
        NSDate *tick = [[NSDate alloc] initWithTimeIntervalSinceNow:idle];
        [[NSRunLoop currentRunLoop] runUntilDate:tick];
        timedOut = ([tick compare:timeoutDate] == NSOrderedDescending);
        
        if (_checkState) {
            // Fetch completed
            NSDateComponents *components = [[NSDateComponents alloc] init];
            [components setDay:30];
            
            NSDate *end = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:start options:0];
            
            GalEventList *eventList = [self.dao googleCalendarEventsStartingAt:start endingAt:end];
            
            XCTAssertTrue([eventList.events count] > 0);
            
            return;
        }
    }
    XCTAssertFalse(timedOut, @"Timed out - failed to fetch the data");
}

- (void)executeLocalToRemoteSync
{
    _checkState = NO;
    _keepRunning = YES;
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"kGalRemoteSyncFinished"
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *notification) {
                                                      
                                                      NSLog(@"kGalRemoteSyncFinished received!");
                                                      
                                                      _checkState = YES;
                                                  }];
    
    NSLog(@"Calling triggerLocalToRemoteSynchronization");
    
    [[GalSynchronizationCenter sharedSynchronizationCenter] triggerLocalToRemoteSynchronization];
    
    NSTimeInterval timeout = 60.0;
    NSTimeInterval idle = 0.1;
    BOOL timedOut = NO;
    
    NSDate *timeoutDate = [[NSDate alloc] initWithTimeIntervalSinceNow:timeout];
    while (!timedOut && _keepRunning) {
        NSDate *tick = [[NSDate alloc] initWithTimeIntervalSinceNow:idle];
        [[NSRunLoop currentRunLoop] runUntilDate:tick];
        timedOut = ([tick compare:timeoutDate] == NSOrderedDescending);
        
        if (_checkState) {
            // Sync completed
            
            return;
        }
    }
    
    XCTAssertFalse(timedOut, @"Timed out - failed the local to remote sync");
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    _keepRunning = YES;
    _checkState  = NO;
    
    NSMutableArray *accounts = [self.dao googleAccounts];
    
    if ([accounts count] == 0) {
        // No accounts, create one
        GalGoogleAccount *testAccount = [[GalGoogleAccount alloc] init];
        
        testAccount.username = @TEST_GOOGLE_ACCOUNT_USERNAME;
        testAccount.password = @TEST_GOOGLE_ACCOUNT_PASSWORD;
        
        [self.dao saveGoogleAccount:testAccount];
    }
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    
    _keepRunning = NO;
    _checkState = NO;
    
    // Remove any accounts we have
    for (GalGoogleAccount *account in [self.dao googleAccounts]) {
        [self.dao removeGoogleAccount:account];
    }
}

- (void)testEventFetching
{
    // Fetch the calendars first of we have no further data to fetch
    [self fetchRemoteGoogleCalendars];
    
    [self fetchRemoteEvents];
}

- (void)testLocalEventSynchronization
{
    // Fetch the calendars first of we have no further data to fetch
    [self fetchRemoteGoogleCalendars];
    
    NSMutableArray *accounts = [self.dao googleAccounts];
    
    XCTAssertTrue([accounts count] > 0);
    
    GalGoogleAccount *account = [accounts firstObject];
    
    NSMutableArray *calendars = [self.dao googleCalendarsForAccount:account];
    
    XCTAssertTrue([calendars count] > 0);
    
    GalGoogleCalendar *calendar = [calendars firstObject];
    
    NSDate *now = [[NSDate alloc] init];
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setHour:3];
    
    NSDate *end = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:now options:0];
    
    // Create a new event to the local database as a test
    GalGoogleCalendarEvent *event = [[GalGoogleCalendarEvent alloc] init];
    event.googleCalendarIdentifier = calendar.identifier; // We must identify the event with a calendar
    event.title = [NSString stringWithFormat:@"Test %@", [now description]];
    event.startDate = now;
    event.endDate   = end;
    
    [[GalSynchronizationCenter sharedSynchronizationCenter] addEvent:event];
    
    // Re-fetch the event to update its status correctly
    event = [self.dao googleCalendarEventWithIdentifier:event.identifier];
    XCTAssertTrue(event.syncStatus == kGalSyncStatusEventAddedLocally);
    
    // We should have the event now as a locally modified event
    NSMutableArray *locallyModifiedEvents = [self.dao locallyModifiedEventsForGoogleAccount:account];
    
    XCTAssertTrue([locallyModifiedEvents count] > 0);
    
    // Now the event is in the database, synchronize it to Google
    [self executeLocalToRemoteSync];
    
    // Re-fetch the event to update its status correctly
    event = [self.dao googleCalendarEventWithIdentifier:event.identifier];
    XCTAssertTrue(event.syncStatus == kGalSyncStatusEventSynchronized);
    
    // Modify the event
    event.title = [NSString stringWithFormat:@"Test 2 %@", [now description]];
    
    [[GalSynchronizationCenter sharedSynchronizationCenter] modifyEvent:event];
    
    // Re-fetch the event to update its status correctly
    event = [self.dao googleCalendarEventWithIdentifier:event.identifier];
    XCTAssertTrue(event.syncStatus == kGalSyncStatusEventModifiedLocally);
    
    locallyModifiedEvents = [self.dao locallyModifiedEventsForGoogleAccount:account];
    XCTAssertTrue([locallyModifiedEvents count] > 0);
    
    [self executeLocalToRemoteSync];
    
    // Re-fetch the event to update its status correctly
    event = [self.dao googleCalendarEventWithIdentifier:event.identifier];
    XCTAssertTrue(event.syncStatus == kGalSyncStatusEventSynchronized);
    
    // And delete the event
    [[GalSynchronizationCenter sharedSynchronizationCenter] deleteEvent:event];
    
    event = [self.dao googleCalendarEventWithIdentifier:event.identifier];
    XCTAssertTrue(event.syncStatus == kGalSyncStatusEventDeletedLocally);
    
    locallyModifiedEvents = [self.dao locallyModifiedEventsForGoogleAccount:account];
    XCTAssertTrue([locallyModifiedEvents count] > 0);
    
    [self executeLocalToRemoteSync];
    
    locallyModifiedEvents = [self.dao locallyModifiedEventsForGoogleAccount:account];
    XCTAssertTrue([locallyModifiedEvents count] == 0);
}

- (void)testUnixTime
{
	GalDateInformation info;
	
	int ts1 = [GalUtils unixTimeAtBeginningOfMonth:1 year:2010];
	XCTAssertTrue(ts1 == 1262304000);  // Fri, 01 Jan 2010 00:00:00 GMT
	
	int ts2 = [GalUtils unixTimeAtEndOfMonth:12 year:2009];
	XCTAssertTrue(ts2 == ts1);
	
	int ts3 = [GalUtils unixTimeAtBeginningOfDay:1 month:1 year:2010];
	XCTAssertTrue(ts3 == 1262304000);
	
	int ts4 = [GalUtils unixTimeAtEndOfDay:31 month:12 year:2009];
	XCTAssertTrue(ts4 == ts3);
	
	int ts5 = [GalUtils unixTimeAtEndOfMonth:2 year:2008]; // a leap year
	XCTAssertTrue(ts5 == 1204329600);  // Sat, 01 Mar 2008 00:00:00 GMT
	
	XCTAssertTrue(ts2 == [GalUtils unixTimeFromDate:[NSDate dateWithTimeIntervalSince1970:ts2]]);
	
	// Check local times
	
	int lts1 = [GalUtils localUnixTimeAtBeginningOfMonth:1 year:2010];
	NSDate *d1 = [NSDate dateWithTimeIntervalSince1970:lts1];
	info = [GalUtils dateInformationFromDate:d1];
	XCTAssertTrue(2010 == info.year);
	XCTAssertTrue(1 == info.month);
	XCTAssertTrue(1 == info.day);
	XCTAssertTrue(0 == info.hour);
	XCTAssertTrue(0 == info.minute);
	
	int lts2 = [GalUtils localUnixTimeAtEndOfMonth:12 year:2009];
	NSDate *d2 = [NSDate dateWithTimeIntervalSince1970:lts2];
	info = [GalUtils dateInformationFromDate:d2];
	XCTAssertTrue(2010 == info.year);
	XCTAssertTrue(1 == info.month);
	XCTAssertTrue(1 == info.day);
	XCTAssertTrue(0 == info.hour);
	XCTAssertTrue(0 == info.minute);
	
	int lts3 = [GalUtils localUnixTimeAtBeginningOfDay:1 month:1 year:2010];
	NSDate *d3 = [NSDate dateWithTimeIntervalSince1970:lts3];
	info = [GalUtils dateInformationFromDate:d3];
	XCTAssertTrue(2010 == info.year);
	XCTAssertTrue(1 == info.month);
	XCTAssertTrue(1 == info.day);
	XCTAssertTrue(0 == info.hour);
	XCTAssertTrue(0 == info.minute);
	
	int lts4 = [GalUtils localUnixTimeAtEndOfDay:31 month:12 year:2009];
	NSDate *d4 = [NSDate dateWithTimeIntervalSince1970:lts4];
	info = [GalUtils dateInformationFromDate:d4];
	XCTAssertTrue(2010 == info.year);
	XCTAssertTrue(1 == info.month);
	XCTAssertTrue(1 == info.day);
	XCTAssertTrue(0 == info.hour);
	XCTAssertTrue(0 == info.minute);
}

- (void)testTimeBoundaries
{
	GalGoogleCalendarEvent *e1 = [[GalGoogleCalendarEvent alloc] init];
	e1.title = @"All-day 14.11.2011-19.11.2011";
	e1.startTimestamp = 1321272000;
	e1.endTimestamp = 1321790400;
	e1.allDayEvent = YES;
	
    XCTAssertTrue([e1 eventOccursAtDay:13 month:11 year:2011] == NO);
	XCTAssertTrue([e1 eventOccursAtDay:14 month:11 year:2011] == YES);
	XCTAssertTrue([e1 eventOccursAtDay:15 month:11 year:2011] == YES);
	XCTAssertTrue([e1 eventOccursAtDay:16 month:11 year:2011] == YES);
	XCTAssertTrue([e1 eventOccursAtDay:17 month:11 year:2011] == YES);
    XCTAssertTrue([e1 eventOccursAtDay:18 month:11 year:2011] == YES);
    XCTAssertTrue([e1 eventOccursAtDay:19 month:11 year:2011] == YES);
    XCTAssertTrue([e1 eventOccursAtDay:20 month:11 year:2011] == NO);
	
	GalGoogleCalendarEvent *e2 = [[GalGoogleCalendarEvent alloc] init];
	e2.title = @"Apr30-May1";
	e2.startTimestamp = 1272603600;
	e2.endTimestamp = 1272693600;
	e2.allDayEvent = NO;
	
	XCTAssertTrue([e2 eventOccursAtDay:29 month:4 year:2010] == NO);
	XCTAssertTrue([e2 eventOccursAtDay:30 month:4 year:2010] == YES);
	XCTAssertTrue([e2 eventOccursAtDay:1 month:5 year:2010] == YES);
	XCTAssertTrue([e2 eventOccursAtDay:2 month:5 year:2010] == NO);
	
	GalGoogleCalendarEvent *e3 = [[GalGoogleCalendarEvent alloc] init];
	e3.title = @"Month start May";
	e3.startTimestamp = 1272661200;
	e3.endTimestamp = 1272664800;
	e3.allDayEvent = NO;
	
	XCTAssertTrue([e3 eventOccursAtDay:30 month:4 year:2010] == NO);
	XCTAssertTrue([e3 eventOccursAtDay:1 month:5 year:2010] == YES);
	XCTAssertTrue([e3 eventOccursAtDay:2 month:5 year:2010] == NO);
	
	GalGoogleCalendarEvent *e4 = [[GalGoogleCalendarEvent alloc] init];
	e4.title = @"May29-Jun2";
	e4.startTimestamp = 1275134400;
	e4.endTimestamp = 1275483600;
	e4.allDayEvent = NO;
	
	XCTAssertTrue([e4 eventOccursAtDay:28 month:5 year:2010] == NO);
	XCTAssertTrue([e4 eventOccursAtDay:29 month:5 year:2010] == YES);
	XCTAssertTrue([e4 eventOccursAtDay:30 month:5 year:2010] == YES);
	XCTAssertTrue([e4 eventOccursAtDay:31 month:5 year:2010] == YES);
	XCTAssertTrue([e4 eventOccursAtDay:1 month:6 year:2010] == YES);
	XCTAssertTrue([e4 eventOccursAtDay:2 month:6 year:2010] == YES);
	XCTAssertTrue([e4 eventOccursAtDay:3 month:6 year:2010] == NO);
	
	GalGoogleCalendarEvent *e5 = [[GalGoogleCalendarEvent alloc] init];
	e5.title = @"End of May";
	e5.startTimestamp = 1275336000;
	e5.endTimestamp = 1275339600;
	e5.allDayEvent = NO;
	
	XCTAssertTrue([e5 eventOccursAtDay:30 month:5 year:2010] == NO);
	XCTAssertTrue([e5 eventOccursAtDay:31 month:5 year:2010] == YES);
	XCTAssertTrue([e5 eventOccursAtDay:1 month:6 year:2010] == NO);
	
	GalGoogleCalendarEvent *e6 = [[GalGoogleCalendarEvent alloc] init];
	e6.title = @"Beginning of June";
	e6.startTimestamp = 1275339600;
	e6.endTimestamp = 1275343200;
	e6.allDayEvent = NO;
	
	XCTAssertTrue([e6 eventOccursAtDay:31 month:5 year:2010] == NO);
	XCTAssertTrue([e6 eventOccursAtDay:1 month:6 year:2010] == YES);
	XCTAssertTrue([e6 eventOccursAtDay:2 month:6 year:2010] == NO);
	
	GalGoogleCalendarEvent *e8 = [[GalGoogleCalendarEvent alloc] init];
	e8.title = @"All-day 13.11.2011";
	e8.startTimestamp = 1321185600;
	e8.endTimestamp = 1321272000;
	e8.allDayEvent = YES;
	
	XCTAssertTrue([e8 eventOccursAtDay:12 month:11 year:2011] == NO);
	XCTAssertTrue([e8 eventOccursAtDay:13 month:11 year:2011] == YES);
	XCTAssertTrue([e8 eventOccursAtDay:14 month:11 year:2011] == NO);
}

- (void)testShaHash
{
    NSString *hash = [GalUtils sha1hash:@"foobar"];
    
    XCTAssertTrue([hash isEqualToString:@"8843d7f92416211de9ebb963ff4ce28125932878"]);
}

@end