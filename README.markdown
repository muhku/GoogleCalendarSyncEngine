Introduction
====================

GoogleCalendarSyncEngine is a local event storage for Google Calendar, which supports synchronizing the local and remote events between Google Calendar. The idea is that the calendar events are stored in a local SQLite database. Data is displayed and modified in the local database. Whenever there are changes, it is possible to synchronize the changes to Google Calendar. Respectively, the sync works two ways: also events added to Google Calendar are synchronized to the local database.

The engine was born for a very practical need: a calendar application for iOS, called GooCal. The application ended being downloaded about 700,000 times so the code has received some testing. Of course, I cannot guarantee that the code is bug-free, so you will be of course using the code on your own responsibility. I have shared the code in hopes that it will be useful to somebody and there are already some problems solved, which take time to get right.

Dependencies
====================

The engine is based on the [gdata-objectivec-client](https://code.google.com/p/gdata-objectivec-client/) which source code is included in the project. There are no modifications done to Google's code.

Furthermore, you will need [SQLite](http://www.sqlite.org) as a build dependency. The database handling uses the [fmdb](https://github.com/ccgus/fmdb) library.

First run
====================

Clone the sources. All the dependencies should be already included in the project. Unfortunately due to the structure of gdata-objectivec-client you need to include the gdata-objectivec-client headers manually to the project after the first compilation. Do the following:

1. Build the code (you will get an error of GData.h missing)
2. Open Window -> Organizer and click the GoogleCalendarSyncEngine project from the list
3. Click on the "Derived Data" (arrow at the end of the menu). Finder opens.
4. Navigate to Build -> Products -> Debug-iphonesimulator -> Headers in Finder
5. Drag the Headers folder under GoogleCalendarSyncEngine target in Xcode

The code should now compile fine. If you need more help in the setup, please see this [blog post](http://hoishing.wordpress.com/2011/08/23/gdata-objective-c-client-setup-in-xcode-4/)

Open the [unit test](https://github.com/muhku/GoogleCalendarSyncEngine/blob/master/GoogleCalendarSyncEngineTests/GoogleCalendarSyncEngineTests.m#L33) and change your test Google Account details.

Now when you execute Product -> Test the unit test should execute successfully. You are in business!

Usage
====================

The sync engine is very bare bones for a reason. I have not included any user interface or demonstrations. The reference is the unit test (GoogleCalendarSyncEngineTests) bundled in the project. Documentation is an area I would like to improve in the future but I have tried to document the basic use cases here. Hopefully that is enough to get started. 

Retrieving remote events
---------------------

The most basic task is to retrieve events from a remote calendar. Firstly, you need to have at least a single Google account stored in the database. This is required for all use cases to work.

```
GalGoogleAccount *account = [[GalGoogleAccount alloc] init];
        
account.username = @"myaccount@google.com";
account.password = @"myaccountpassword";
        
[self.dao saveGoogleAccount:account];
```

Next, you need to retrieve the calendars for the given account:

```
GalGoogleCalendarService *calendarService = [[GalGoogleCalendarService alloc] init];
[calendarService triggerRemoteGoogleCalendarsFetch];
```

After this, you should have the Google Calendars for the given account stored in the local database. Now retrieve the events to the local database with GalGoogleCalendarEventService:

```
GalGoogleCalendarEventService *eventService = [[GalGoogleCalendarEventService alloc] init];

[eventService setPastDaysToSync:7];
[eventService  setFutureDaysToSync:30];

NSDate *start = [[NSDate alloc] init];

[self.eventService triggerRemoteEventFetchFromDate:start];
```

CRUD operations for events
---------------------

Firstly, create an event. Each event needs to be associated to a calendar so retrieve the calendar object:

```
GalDAO *dao = [[GalDAO alloc] init];
NSMutableArray *accounts = [dao googleAccounts];
NSMutableArray *calendars = [self.dao googleCalendarsForAccount:[accounts firstObject]];
GalGoogleCalendar *calendar = [calendars firstObject];
```

Create an event:

```
NSDate *now = [[NSDate alloc] init];

NSDateComponents *components = [[NSDateComponents alloc] init];
[components setHour:1];

NSDate *end = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:now options:0];

GalGoogleCalendarEvent *event = [[GalGoogleCalendarEvent alloc] init];
event.googleCalendarIdentifier = calendar.identifier;
event.title = [NSString stringWithFormat:@"Test %@", [now description]];
event.startDate = now;
event.endDate   = end;
```

Store the event to the local database and synchronize it to Google:

```
[[GalSynchronizationCenter sharedSynchronizationCenter] addEvent:event];
[[GalSynchronizationCenter sharedSynchronizationCenter] triggerLocalToRemoteSynchronization];
```

To modify existing events, use the following:

```
[[GalSynchronizationCenter sharedSynchronizationCenter] modifyEvent:event];
[[GalSynchronizationCenter sharedSynchronizationCenter] triggerLocalToRemoteSynchronization];
```

To delete events:

```
[[GalSynchronizationCenter sharedSynchronizationCenter] deleteEvent:event];
[[GalSynchronizationCenter sharedSynchronizationCenter] triggerLocalToRemoteSynchronization];
```

Reporting bugs and contributing
====================

For code contributions, please create a pull request in Github.

For bugs, please create a Github issue. I don't have time for private email support, so usually the best way to get help is to interact in [Github](https://github.com/muhku/GoogleCalendarSyncEngine).

Please understand that this code has been written in the author's free time, so don't get upset if you don't get response for every question and request.

License
====================

The BSD license which the files are licensed under allows is as follows:

    Copyright (c) 2010-2014 Matias Muhonen <mmu@iki.fi>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:
    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
    3. The name of the author may not be used to endorse or promote products
       derived from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
    IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
    OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
    IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
    NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
    THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
