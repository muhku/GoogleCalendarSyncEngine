/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalDAO.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

#import "GalGoogleAccount.h"
#import "GalUtils.h"
#import "GalGoogleCalendar.h"
#import "GalGoogleCalendarEvent.h"
#import "GalEventList.h"
#import "SFHFKeychainUtils.h"

//#define DEBUG_GAL_DAO 1

@interface GalDAO ()
/* Private interface */
- (NSString *)passwordFromKeychain:(NSString *)username;
- (void)storeUsernameToKeychain:(NSString *)username keychainPassword:(NSString *)password;
- (void)deleteUsernameFromKeychain:(NSString *)username;
@end

@implementation GalDAO

- (NSString *)passwordFromKeychain:(NSString *)username
{
	NSError *error = nil;
	return [SFHFKeychainUtils getPasswordForUsername:username andServiceName:@"GoogleCalendarSyncEngine" error:&error];
}

- (void)storeUsernameToKeychain:(NSString *)username keychainPassword:(NSString *)password
{
	NSError *error = nil;
	[SFHFKeychainUtils storeUsername:username andPassword:password forServiceName:@"GoogleCalendarSyncEngine" updateExisting:YES error:&error];
}

- (void)deleteUsernameFromKeychain:(NSString *)username
{
	NSError *error = nil;
	[SFHFKeychainUtils deleteItemForUsername:username andServiceName:@"GoogleCalendarSyncEngine" error:&error];
}

static FMDatabase *db = nil;

- (id)init
{
    if (self = [super init]) {
		if (!db) {
			/* Store the database in the Documents directory.
			 * The Documents directory is backed up every time the user
			 * synchronizes the device with iTunes.
			 */
			NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			NSString *documentsDirectory = paths[0];
			NSString *dbName = [documentsDirectory stringByAppendingPathComponent:@"goocal.db"];
		
			#ifdef DEBUG_GAL_DAO
				NSLog(@"db %@", dbName);
				NSLog(@"GalDAO: performing a full database reset. Removing the old database");
				NSFileManager *fileManager = [NSFileManager defaultManager];
				[fileManager removeItemAtPath:dbName error:NULL];
			#endif
		
			db = [FMDatabase databaseWithPath:dbName];
			[db setShouldCacheStatements:NO];
		
			if ([db open]) {
				BOOL success = NO;
			
				#ifdef DEBUG_GAL_DAO
				[db setTraceExecution:YES];
				
				success = [db executeUpdate:@"DROP TABLE IF EXISTS gal_google_account"];
				if (!success) {
					[GalUtils showFatalErrorMessageAndTerminate:@"Failed to drop gal_google_account"];
					return self;
				}
				success = [db executeUpdate:@"DROP TABLE IF EXISTS gal_google_calendar"];
				if (!success) {
					[GalUtils showFatalErrorMessageAndTerminate:@"Failed to drop gal_google_calendar"];
					return self;
				}
				success = [db executeUpdate:@"DROP TABLE IF EXISTS gal_google_event"];
				if (!success) {
					[GalUtils showFatalErrorMessageAndTerminate:@"Failed to drop gal_google_event"];
					return self;
				}
				success = [db executeUpdate:@"DROP TABLE IF EXISTS gal_app_prop"];
				if (!success) {
					[GalUtils showFatalErrorMessageAndTerminate:@"Failed to drop gal_app_prop"];
					return self;
				}
				#endif
			
				// Create tables if not already there
				success = [db executeUpdate:@"CREATE TABLE IF NOT EXISTS gal_google_account (ac_identifier UNSIGNED INTEGER, username VARCHAR(128))"];
				if (!success) {
					return self;
				}
			
				success = [db executeUpdate:@"CREATE TABLE IF NOT EXISTS gal_google_calendar (cal_identifier UNSIGNED INTEGER, ac_identifier UNSIGNED INTEGER, google_cal_id VARCHAR(64), cal_title TEXT, cal_enabled BOOLEAN, can_modify BOOLEAN, color VARCHAR(8), feed_url TEXT, timezone VARCHAR(128), sync_time UNSIGNED INTEGER, FOREIGN KEY(ac_identifier) REFERENCES gal_google_account(ac_identifier))"];
				if (!success) {
					return self;
				}
			
				success = [db executeUpdate:@"CREATE TABLE IF NOT EXISTS gal_google_event (ev_identifier UNSIGNED INTEGER, cal_identifier UNSIGNED INTEGER, sts UNSIGNED INTEGER, ets UNSIGNED INTEGER, sync_time UNSIGNED INTEGER, sync_status INTEGER, local_update_time UNSIGNED INTEGER, remote_update_time UNSIGNED INTEGER, google_ev_id VARCHAR(64), feed_url TEXT, orig_feed_url TEXT, title TEXT, description TEXT, location TEXT, recurrence TEXT, color VARCHAR(8), all_day BOOLEAN, FOREIGN KEY(cal_identifier) REFERENCES gal_google_calendar(cal_identifier))"];
				if (!success) {
					return self;
				}
			}
		}
    }
    return self;
}

+ (void)closeDatabase
{
	[db close];
}

- (void)saveGoogleAccount:(GalGoogleAccount *)googleAccount
{
	// Check if there already is an account with the given username. In that
	// case, merge the current account with the existing one. The case might be
	// there are accounts like (x,y,z) and the user renames the account z as x.
	// We would end up with duplicate accounts.
	int existingAccountId = 0;
	if ((existingAccountId = [db intForQuery:@"SELECT ac_identifier FROM gal_google_account WHERE username=?", googleAccount.username]) > 0) {
		// OK, in fact, there is an already an account with the given username.
		// Update the password of that account.
		[self storeUsernameToKeychain:[GalGoogleAccount keychainStringWithAccountIdentifier:existingAccountId] keychainPassword:googleAccount.password];
		
		// Is the account different than the current one?
		// If so, we need to delete the old account if the old account was saved.
		if (!([googleAccount identifier] == existingAccountId) && [googleAccount identifier] > 0) {
			[self removeGoogleAccount:googleAccount];
			
			// Merge the instance with the existing instance
			googleAccount.identifier = existingAccountId;
		}
		
		// No more work to do!
		return;
	}
	
	// If the account has been persisted (identifier > 0) update the existing account.
	if ([googleAccount identifier] > 0) {
		[db executeUpdate:@"UPDATE gal_google_account SET username=? WHERE ac_identifier=?",
							 googleAccount.username, @(googleAccount.identifier)];
	} else {
		// Find an ID for the account
		int accountId = [db intForQuery:@"SELECT MAX(ac_identifier) FROM gal_google_account"] + 1;		
		[db executeUpdate:@"INSERT INTO gal_google_account(ac_identifier,username) VALUES(?,?)",
						[NSNumber numberWithUnsignedInt:accountId],  googleAccount.username];
		googleAccount.identifier = accountId;
	}
	[self storeUsernameToKeychain:[googleAccount usernameForKeychain] keychainPassword:googleAccount.password];
}

- (GalGoogleAccount *)googleAccountWithUsername:(NSString *)username
{
	FMResultSet *rs = [db executeQuery:@"SELECT ac_identifier,username FROM gal_google_account WHERE username=?", username];
    if ([rs next]) {
		GalGoogleAccount *ga = [[GalGoogleAccount alloc] init];
		[self mapGoogleAccountResultSet:rs googleAccount:ga];
		return ga;
	}
	return nil;
}

- (GalGoogleAccount *)googleAccountWithCalendar:(GalGoogleCalendar *)calendar
{
	FMResultSet *rs = [db executeQuery:@"SELECT ac_identifier,username FROM gal_google_account WHERE ac_identifier=?",
					   @(calendar.googleAccountIdentifier)];
    if ([rs next]) {
		GalGoogleAccount *ga = [[GalGoogleAccount alloc] init];
		[self mapGoogleAccountResultSet:rs googleAccount:ga];
		return ga;
	}
	return nil;
}

- (NSMutableArray *)googleAccounts
{
	NSMutableArray *googleAccounts = [[NSMutableArray alloc] init];
	FMResultSet *rs = [db executeQuery:@"SELECT ac_identifier,username FROM gal_google_account ORDER BY username"];
	while ([rs next]) {
		GalGoogleAccount *ga = [[GalGoogleAccount alloc] init];
		[self mapGoogleAccountResultSet:rs googleAccount:ga];
		[googleAccounts addObject:ga];
	}
	return googleAccounts;
}

- (NSMutableArray *)googleCalendars
{
	NSMutableArray *googleCalendars = [[NSMutableArray alloc] init];
	FMResultSet *rs = [db executeQuery:@"SELECT cal_identifier,ac_identifier,google_cal_id,cal_title,cal_enabled,can_modify,color,feed_url,timezone FROM gal_google_calendar ORDER BY cal_title"];
	while ([rs next]) {
		GalGoogleCalendar *gcal = [[GalGoogleCalendar alloc] init];
		[self mapGoogleCalendarResultSet:rs googleCalendar:gcal];
		[googleCalendars addObject:gcal];
	}
	return googleCalendars;
}

- (NSMutableArray *)modifiableGoogleCalendars
{
	NSMutableArray *googleCalendars = [[NSMutableArray alloc] init];
	FMResultSet *rs = [db executeQuery:@"SELECT cal_identifier,ac_identifier,google_cal_id,cal_title,cal_enabled,can_modify,color,feed_url,timezone FROM gal_google_calendar WHERE can_modify=1 AND cal_enabled=1 ORDER BY cal_title"];
	while ([rs next]) {
		GalGoogleCalendar *gcal = [[GalGoogleCalendar alloc] init];
		[self mapGoogleCalendarResultSet:rs googleCalendar:gcal];
		[googleCalendars addObject:gcal];
	}
	return googleCalendars;
}

- (NSMutableArray *)enabledGoogleCalendars
{
#ifdef DEBUG_GAL_DAO
	NSLog(@"enabledGoogleCalendars called");
#endif
	
	NSMutableArray *googleCalendars = [[NSMutableArray alloc] init];
	FMResultSet *rs = [db executeQuery:@"SELECT cal_identifier,ac_identifier,google_cal_id,cal_title,cal_enabled,can_modify,color,feed_url,timezone FROM gal_google_calendar WHERE cal_enabled=1 ORDER BY cal_title"];
	while ([rs next]) {
#ifdef DEBUG_GAL_DAO
		NSLog(@"enabledGoogleCalendars: a row found");
#endif
		GalGoogleCalendar *gcal = [[GalGoogleCalendar alloc] init];
		[self mapGoogleCalendarResultSet:rs googleCalendar:gcal];
		[googleCalendars addObject:gcal];
	}
	return googleCalendars;
}

- (NSMutableArray *)googleCalendarsForAccount:(GalGoogleAccount *)googleAccount
{
	NSMutableArray *googleCalendars = [[NSMutableArray alloc] init];
	FMResultSet *rs = [db executeQuery:@"SELECT cal_identifier,ac_identifier,google_cal_id,cal_title,cal_enabled,can_modify,color,feed_url,timezone FROM gal_google_calendar WHERE ac_identifier=?",
										@([googleAccount identifier])];
	while ([rs next]) {
		GalGoogleCalendar *gcal = [[GalGoogleCalendar alloc] init];
		[self mapGoogleCalendarResultSet:rs googleCalendar:gcal];
		[googleCalendars addObject:gcal];
	}
	return googleCalendars;
}

- (GalGoogleCalendar *)googleCalendarWithIdentifier:(unsigned int)calendarIdenfier
{
	FMResultSet *rs = [db executeQuery:@"SELECT cal_identifier,ac_identifier,google_cal_id,cal_title,cal_enabled,can_modify,color,feed_url,timezone FROM gal_google_calendar WHERE cal_identifier=?",
								@(calendarIdenfier)];
    if ([rs next]) {
		GalGoogleCalendar *gcal = [[GalGoogleCalendar alloc] init];
		[self mapGoogleCalendarResultSet:rs googleCalendar:gcal];
		return gcal;
	}
	return nil;
}

- (GalGoogleCalendar *)googleCalendarWithGoogleCalendarId:(NSString *)googleCalendarId
{
	FMResultSet *rs = [db executeQuery:@"SELECT cal_identifier,ac_identifier,google_cal_id,cal_title,cal_enabled,can_modify,color,feed_url,timezone FROM gal_google_calendar WHERE google_cal_id=?", googleCalendarId];
    if ([rs next]) {
		GalGoogleCalendar *gcal = [[GalGoogleCalendar alloc] init];
		[self mapGoogleCalendarResultSet:rs googleCalendar:gcal];
		return gcal;
	}
	return nil;
}

- (GalGoogleCalendarEvent *)googleCalendarEventWithGoogleEventId:(NSString *)googleEventId
{
	FMResultSet *rs = [db executeQuery:@"SELECT ev_identifier, cal_identifier, sts, ets, sync_time, sync_status, local_update_time, remote_update_time, google_ev_id, feed_url, orig_feed_url, title, description, location, color, recurrence, all_day FROM gal_google_event WHERE google_ev_id=?", googleEventId];
    if ([rs next]) {
		GalGoogleCalendarEvent *event = [[GalGoogleCalendarEvent alloc] init];
		[self mapGoogleCalendarEventResultSet:rs googleCalendarEvent:event];
		return event;
	}
	return nil;
}

- (GalGoogleCalendarEvent *)googleCalendarEventWithIdentifier:(unsigned int)eventIdentifier
{
	FMResultSet *rs = [db executeQuery:@"SELECT ev_identifier, cal_identifier, sts, ets, sync_time, sync_status, local_update_time, remote_update_time, google_ev_id, feed_url, orig_feed_url, title, description, location, color, recurrence, all_day FROM gal_google_event WHERE ev_identifier=?", @(eventIdentifier)];
    if ([rs next]) {
		GalGoogleCalendarEvent *event = [[GalGoogleCalendarEvent alloc] init];
		[self mapGoogleCalendarEventResultSet:rs googleCalendarEvent:event];
		return event;
	}
	return nil;
}

- (NSMutableArray *)locallyModifiedEventsForGoogleAccount:(GalGoogleAccount *)googleAccount
{
	NSMutableArray *events = [[NSMutableArray alloc] init];
	FMResultSet *rs = [db executeQuery:@"SELECT ge.ev_identifier, ge.cal_identifier, ge.sts, ge.ets, ge.sync_time, ge.sync_status, ge.local_update_time, ge.remote_update_time, ge.google_ev_id, ge.feed_url, ge.orig_feed_url, ge.title, ge.description, ge.location, ge.color, ge.recurrence, ge.all_day FROM gal_google_event ge INNER JOIN gal_google_calendar gc ON gc.cal_identifier=ge.cal_identifier INNER JOIN gal_google_account ga ON ga.ac_identifier=gc.ac_identifier WHERE ga.ac_identifier=? AND (ge.sync_status IN(-1,1,2))",
					   @(googleAccount.identifier)];
    while ([rs next]) {
		GalGoogleCalendarEvent *event = [[GalGoogleCalendarEvent alloc] init];
		[self mapGoogleCalendarEventResultSet:rs googleCalendarEvent:event];
		[events addObject:event];
	}
	return events;
}

- (BOOL)hasLocallyModifiedEvents
{
	FMResultSet *rs = [db executeQuery:@"SELECT ev_identifier FROM gal_google_event WHERE sync_status IN(-1,1,2)"];
	if ([rs next]) {
		return YES;
	}
	return NO;
}

- (GalEventList *)googleCalendarEventsStartingAt:(NSDate *)start endingAt:(NSDate *)end
{
	#ifdef DEBUG_GAL_DAO
	unsigned int count = 0;
	#endif
	
	GalEventList *eventList = [[GalEventList alloc] initWithStartDate:start endDate:end];
	
	GalDateInformation startInfo = [GalUtils dateInformationFromDate:start];
	GalDateInformation endInfo = [GalUtils dateInformationFromDate:end];
	
	NSNumber *s = [NSNumber numberWithUnsignedInt:[GalUtils localUnixTimeAtBeginningOfDay:startInfo.day month:startInfo.month year:startInfo.year]];
	NSNumber *e = [NSNumber numberWithUnsignedInt:[GalUtils localUnixTimeAtEndOfDay:endInfo.day month:endInfo.month year:endInfo.year]];
	
	NSNumber *ss = [NSNumber numberWithUnsignedInt:[GalUtils unixTimeAtBeginningOfDay:startInfo.day month:startInfo.month year:startInfo.year]];
	NSNumber *ee = [NSNumber numberWithUnsignedInt:[GalUtils unixTimeAtEndOfDay:endInfo.day month:endInfo.month year:endInfo.year]];
	
	FMResultSet *rs = [db executeQuery:@"SELECT ev_identifier, cal_identifier, sts, ets, sync_time, sync_status, local_update_time, remote_update_time, google_ev_id, feed_url, orig_feed_url, title, description, location, color, recurrence, all_day FROM gal_google_event WHERE (sync_status >= 0) AND (((sts >= ? AND ets <= ?) OR (sts <= ? AND ets > ?) OR (sts < ? AND ets >= ?)) OR ((all_day=1) AND ((sts >= ? AND ets <= ?) OR (sts <= ? AND ets > ?) OR (sts < ? AND ets >= ?)))) ORDER BY sts",
					   s, e, s, s, e, e, ss, ee, ss, ss, ee, ee];

	while ([rs next]) {
		GalGoogleCalendarEvent *event = [[GalGoogleCalendarEvent alloc] init];
		[self mapGoogleCalendarEventResultSet:rs googleCalendarEvent:event];
		[eventList addEvent:event];
		#ifdef DEBUG_GAL_DAO
		NSLog(@"%@ %i %i", event.title, event.startTimestamp, event.endTimestamp);
		count++;
		#endif
	}
	#ifdef DEBUG_GAL_DAO
	NSLog(@"googleCalendarEventsForMonth, found %i events", count);
	#endif
	return eventList;
}

- (NSMutableArray *)searchEventsByTitleAndLocation:(NSString *)searchTerm
{
	NSMutableArray *events = [[NSMutableArray alloc] init];
	// Limit the number of search results: doubt if more than 50 is useful for anyone
	NSString *search = [NSString stringWithFormat:@"%%%@%%", [searchTerm stringByReplacingOccurrencesOfString:@"%" withString:@""]];
	FMResultSet *rs = [db executeQuery:@"SELECT ge.ev_identifier, ge.cal_identifier, ge.sts, ge.ets, ge.sync_time, ge.sync_status, ge.local_update_time, ge.remote_update_time, ge.google_ev_id, ge.feed_url, ge.orig_feed_url, ge.title, ge.description, ge.location, ge.color, ge.recurrence, ge.all_day FROM gal_google_event ge INNER JOIN gal_google_calendar gc ON gc.cal_identifier=ge.cal_identifier INNER JOIN gal_google_account ga ON ga.ac_identifier=gc.ac_identifier WHERE (sync_status >= 0) AND ((ge.title LIKE ?) OR (ge.location LIKE ?)) ORDER BY ge.sts LIMIT 50",
					   search, search];
    while ([rs next]) {
		GalGoogleCalendarEvent *event = [[GalGoogleCalendarEvent alloc] init];
		[self mapGoogleCalendarEventResultSet:rs googleCalendarEvent:event];
		[events addObject:event];
	}
	return events;
}

- (void)saveGoogleCalendarEnabledState:(GalGoogleCalendar *)googleCalendar enabled:(BOOL)enabled
{
	BOOL success = [db executeUpdate:@"UPDATE gal_google_calendar SET cal_enabled=? WHERE cal_identifier=?",
					@(enabled),
					@([googleCalendar identifier])];
	if (!success) {
		NSLog(@"Error: saveGoogleCalendarEnabledState: failed to update");
	}
	
	if (enabled) {
		// No more work to do here.
		return;
	}
	
	// If enabled=false we need to delete events which might be fetched for this calendar
	success = [db executeUpdate:@"DELETE FROM gal_google_event WHERE cal_identifier = ?",
					@(googleCalendar.identifier)];
	
	if (!success) {
		NSLog(@"Error: saveGoogleCalendarEnabledState: failed to delete events");
	}
}

- (void)saveGoogleCalendar:(GalGoogleCalendar *)googleCalendar
{
	if (googleCalendar.identifier > 0) {
		BOOL success = [db executeUpdate:@"UPDATE gal_google_calendar SET ac_identifier=?,cal_title=?,color=?,cal_enabled=?,can_modify=?,feed_url=?,timezone=?,sync_time=? WHERE cal_identifier=?",
								@([googleCalendar googleAccountIdentifier]), 
								googleCalendar.title,
								googleCalendar.color,
								@(googleCalendar.enabled),
								@(googleCalendar.canModify),
								googleCalendar.feedUrl,
								googleCalendar.timeZone,
								@(googleCalendar.syncTime),
								 @(googleCalendar.identifier)];
		if (!success) {
			NSLog(@"Error: failed to update gal_google_calendar with an existing calendar");
		}
	} else {
		// Save the calendar as a new calendar instance.
		// Find an ID for the calendar
		int calendarId = [db intForQuery:@"SELECT MAX(cal_identifier) FROM gal_google_calendar"] + 1;
		BOOL success = [db executeUpdate:@"INSERT INTO gal_google_calendar(cal_identifier,ac_identifier,google_cal_id,cal_title,cal_enabled,can_modify,color,feed_url,timezone,sync_time) VALUES(?,?,?,?,?,?,?,?,?,?)",
			[NSNumber numberWithUnsignedInt:calendarId],
			@(googleCalendar.googleAccountIdentifier),
			googleCalendar.googleCalendarId,
			googleCalendar.title,
			@(googleCalendar.enabled),
			@(googleCalendar.canModify),
			googleCalendar.color,
			googleCalendar.feedUrl,
			googleCalendar.timeZone,
			@(googleCalendar.syncTime)];
		if (!success) {
			NSLog(@"Error: failed to insert gal_google_calendar a new calendar");
		}
		[googleCalendar setIdentifier:calendarId];
	}
}

- (void)saveGoogleCalendarEvent:(GalGoogleCalendarEvent *)googleCalendarEvent
{
	if (googleCalendarEvent.identifier > 0) {
		// Save the existing calendar
		BOOL success = [db executeUpdate:@"UPDATE gal_google_event SET cal_identifier=?,sts=?,ets=?,sync_time=?,sync_status=?,local_update_time=?,remote_update_time=?,google_ev_id=?,feed_url=?,orig_feed_url=?,title=?,description=?,location=?,color=?,recurrence=?,all_day=? WHERE ev_identifier=?",
			@(googleCalendarEvent.googleCalendarIdentifier), // cal_identifier
			@(googleCalendarEvent.startTimestamp), // sts
			@(googleCalendarEvent.endTimestamp), // ets
			@(googleCalendarEvent.syncTime), // sync_time
			@(googleCalendarEvent.syncStatus), // sync_status
			@(googleCalendarEvent.localUpdateTime), // local_update_time
			@(googleCalendarEvent.remoteUpdateTime), // remote_update_time
			googleCalendarEvent.googleEventId, // google_ev_id
			googleCalendarEvent.feedUrl, // feed_url
			googleCalendarEvent.originalFeedUrl, // orig_feed_url
			googleCalendarEvent.title, // title
			googleCalendarEvent.description, // description
			googleCalendarEvent.location, // location
			googleCalendarEvent.color, // color
			googleCalendarEvent.recurrence, // recurrence
			@(googleCalendarEvent.allDayEvent),
			@(googleCalendarEvent.identifier)]; // ev_identifier;
		if (!success) {
			NSLog(@"Error: failed to update gal_google_event with an existing event");
		}
	} else {
		// Save a new event instance.
		int eventId = [db intForQuery:@"SELECT MAX(ev_identifier) FROM gal_google_event"] + 1;
		BOOL success = [db executeUpdate:@"INSERT INTO gal_google_event(ev_identifier, cal_identifier, sts, ets, sync_time, sync_status, local_update_time, remote_update_time, google_ev_id, feed_url, orig_feed_url, title, description, location, color, recurrence, all_day) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
			[NSNumber numberWithUnsignedInt:eventId], // ev_identifier
			@(googleCalendarEvent.googleCalendarIdentifier), // cal_identifier
			@(googleCalendarEvent.startTimestamp), // sts
			@(googleCalendarEvent.endTimestamp), // ets
			@(googleCalendarEvent.syncTime), // sync_time
			@(googleCalendarEvent.syncStatus), // sync_status
			@(googleCalendarEvent.localUpdateTime), // local_update_time
			@(googleCalendarEvent.remoteUpdateTime), // remote_update_time
			googleCalendarEvent.googleEventId, // google_ev_id
			googleCalendarEvent.feedUrl, // feed_url
			googleCalendarEvent.originalFeedUrl, // orig_feed_url	
			googleCalendarEvent.title, // title
			googleCalendarEvent.description, // description
			googleCalendarEvent.location, // location		
			googleCalendarEvent.color,  // color
			googleCalendarEvent.recurrence, // recurrence
			@(googleCalendarEvent.allDayEvent)]; // all_day
		if (!success) {
			NSLog(@"Error: failed to insert gal_google_event a new event");
			return;
		}
		[googleCalendarEvent setIdentifier:eventId];
		#ifdef DEBUG_GAL_DAO
		NSLog(@"Created a new event with title %@, id %i", googleCalendarEvent.title, eventId);
		#endif
	}
}

- (void)updateSyncStatusForEvent:(GalGoogleCalendarEvent *)event status:(int)status
{
	BOOL success = [db executeUpdate:@"UPDATE gal_google_event SET sync_status = ? WHERE ev_identifier = ?",
					@(status), @(event.identifier)];
	if (!success) {
		NSLog(@"Error: updateSyncStatusForEvent failed");
	}
}

- (void)touchEvent:(GalGoogleCalendarEvent *)event
{
	int t = [GalUtils currentUnixTime];
	BOOL success = [db executeUpdate:@"UPDATE gal_google_event SET sync_time = ? WHERE ev_identifier = ?",
					[NSNumber numberWithUnsignedInt:t], @(event.identifier)];
	if (!success) {
		NSLog(@"Error: touchEvent failed");
	}
}

- (void)removeEventsOlderThan:(unsigned int)itemUpdateTime startTime:(int)startTime endTime:(int)endTime googleCalendar:(GalGoogleCalendar *)googleCalendar
{
	BOOL success = [db executeUpdate:@"DELETE FROM gal_google_event WHERE sync_status = 0 AND sync_time < ? AND sts >= ? AND ets <= ? AND cal_identifier = ?",
					@(itemUpdateTime),
					[NSNumber numberWithUnsignedInt:startTime],
					[NSNumber numberWithUnsignedInt:endTime],
					@(googleCalendar.identifier)];
	if (!success) {
		NSLog(@"Error: removeEventsOlderThan failed");
	}
}

- (void)removeCalendarsOlderThan:(unsigned int)itemUpdateTime
{
	FMResultSet *rs = [db executeQuery:@"SELECT google_cal_id FROM gal_google_calendar WHERE sync_time < ?",
					   @(itemUpdateTime)];
	while ([rs next]) {
		GalGoogleCalendar *calendar = [self googleCalendarWithGoogleCalendarId:[rs stringForColumn:@"google_cal_id"]];
		[self removeGoogleCalendar:calendar];
	}
}

- (void)removeGoogleAccount:(GalGoogleAccount *)googleAccount
{
	if (!(googleAccount.identifier > 0)) {
		NSLog(@"Error: removeGoogleAccount: unable to remove. Account has not been saved");
		return;
	}
	NSMutableArray *googleCalendars = [self googleCalendarsForAccount:googleAccount];
	for (id obj in googleCalendars) {
		GalGoogleCalendar *calendar = obj;
		[self removeGoogleCalendar:calendar];
	}
	
	BOOL success = [db executeUpdate:@"DELETE FROM gal_google_account WHERE ac_identifier = ?",
					@(googleAccount.identifier)];
    [self deleteUsernameFromKeychain:[GalGoogleAccount keychainStringWithAccountIdentifier:googleAccount.identifier]];
	if (!success) {
		NSLog(@"Error: removeGoogleAccount: delete account failed");
	} else {
		googleAccount.identifier = 0;
	}
}

- (void)removeGoogleCalendarEvent:(GalGoogleCalendarEvent *)calendarEvent
{
	if (!(calendarEvent.identifier > 0)) {
		NSLog(@"Error: removeGoogleCalendarEvent: unable to remove. Event has not been saved");
		return;
	}
	BOOL success = [db executeUpdate:@"DELETE FROM gal_google_event WHERE ev_identifier = ?",
					@(calendarEvent.identifier)];
	if (!success) {
		NSLog(@"Error: removeGoogleCalendarEvent: delete event failed");
	} else {
		calendarEvent.identifier = 0;
	}
}

- (void)removeGoogleCalendar:(GalGoogleCalendar *)googleCalendar
{
	if (!(googleCalendar.identifier > 0)) {
		NSLog(@"Error: removeGoogleCalendar: unable to remove. Calendar has not been saved");
		return;
	}
	
	BOOL success = [db executeUpdate:@"DELETE FROM gal_google_event WHERE cal_identifier = ?",
					@(googleCalendar.identifier)];
	if (!success) {
		NSLog(@"Error: removeGoogleCalendar: delete related events failed");
	}
	
	success = [db executeUpdate:@"DELETE FROM gal_google_calendar WHERE cal_identifier = ?",
				@(googleCalendar.identifier)];
	
	if (!success) {
		NSLog(@"Error: removeGoogleCalendar: delete calendar failed");
	} else {
		googleCalendar.identifier = 0;
	}

}

- (void)mapGoogleAccountResultSet:(FMResultSet *)rs googleAccount:(GalGoogleAccount *)googleAccount
{
	googleAccount.identifier = [rs intForColumn:@"ac_identifier"];
	googleAccount.username = [rs stringForColumn:@"username"];
	googleAccount.password = [self passwordFromKeychain:[googleAccount usernameForKeychain]];
}

- (void)mapGoogleCalendarResultSet:(FMResultSet *)rs googleCalendar:(GalGoogleCalendar *)googleCalendar
{
	googleCalendar.identifier = [rs intForColumn:@"cal_identifier"];
	googleCalendar.googleAccountIdentifier = [rs intForColumn:@"ac_identifier"];
	googleCalendar.googleCalendarId = [rs stringForColumn:@"google_cal_id"];
	googleCalendar.title = [rs stringForColumn:@"cal_title"];
	googleCalendar.enabled = [rs boolForColumn:@"cal_enabled"];
	googleCalendar.canModify = [rs boolForColumn:@"can_modify"];
	googleCalendar.color = [rs stringForColumn:@"color"];
	googleCalendar.feedUrl = [rs stringForColumn:@"feed_url"];
	googleCalendar.timeZone = [rs stringForColumn:@"timezone"];
}

- (void)mapGoogleCalendarEventResultSet:(FMResultSet *)rs googleCalendarEvent:(GalGoogleCalendarEvent *)googleCalendarEvent
{
	googleCalendarEvent.identifier = [rs intForColumn:@"ev_identifier"];
	googleCalendarEvent.googleCalendarIdentifier = [rs intForColumn:@"cal_identifier"];
	googleCalendarEvent.startTimestamp = [rs intForColumn:@"sts"];
	googleCalendarEvent.endTimestamp = [rs intForColumn:@"ets"];
	googleCalendarEvent.syncTime = [rs intForColumn:@"sync_time"];
	googleCalendarEvent.syncStatus = [rs intForColumn:@"sync_status"];
	googleCalendarEvent.localUpdateTime = [rs intForColumn:@"local_update_time"];
	googleCalendarEvent.remoteUpdateTime = [rs intForColumn:@"remote_update_time"];
	googleCalendarEvent.googleEventId = [rs stringForColumn:@"google_ev_id"];
	googleCalendarEvent.feedUrl = [rs stringForColumn:@"feed_url"];
	googleCalendarEvent.originalFeedUrl = [rs stringForColumn:@"orig_feed_url"];
	googleCalendarEvent.title = [rs stringForColumn:@"title"];
	googleCalendarEvent.description = [rs stringForColumn:@"description"];
	googleCalendarEvent.location = [rs stringForColumn:@"location"];	
	googleCalendarEvent.color = [rs stringForColumn:@"color"];
	googleCalendarEvent.recurrence = [rs stringForColumn:@"recurrence"];
	googleCalendarEvent.allDayEvent = [rs boolForColumn:@"all_day"];
}

@end
