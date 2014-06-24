/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import <Foundation/Foundation.h>

// Represents a Google Account with an username (such as john.doe@google.com)
@interface GalGoogleAccount : NSObject {
	// Identifies this object in the database. If identifier > 0, persisted, otherwise not.
	unsigned int _identifier;
	NSString *_username;
	NSString *_password;
}

@property (readwrite,assign) unsigned int identifier;
@property (strong,nonatomic) NSString *username;
@property (strong,nonatomic) NSString *password;

- (NSString *)usernameForKeychain;
+ (NSString *)keychainStringWithAccountIdentifier:(int)accountIdentifier;

@end
