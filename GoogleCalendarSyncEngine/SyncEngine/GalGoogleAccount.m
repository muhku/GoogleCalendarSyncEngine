/*
 * This file is part of the GoogleCalendarSyncEngine project,
 * (C)Copyright 2010-2014 Matias Muhonen <mmu@iki.fi>
 * See the file ''LICENSE'' for using the code.
 *
 * https://github.com/muhku/GoogleCalendarSyncEngine
 */

#import "GalGoogleAccount.h"

@implementation GalGoogleAccount

- (id)init
{
    if (self = [super init]) {
		_identifier = 0;
		_username = @"";
		_password = @"";
    }
    return self;
}

- (NSString *)usernameForKeychain
{
	return [GalGoogleAccount keychainStringWithAccountIdentifier:_identifier];
}

+ (NSString *)keychainStringWithAccountIdentifier:(int)accountIdentifier
{
	return [NSString stringWithFormat:@"ga%i", accountIdentifier];
}

@end
