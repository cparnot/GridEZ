//
//  TestServerHook.m
//
//  TestServerHook
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_TESTSERVERHOOK__
This file is part of "TestServerHook". "TestServerHook" is free software; you can redistribute it and/or modify it under the terms of the Berkeley Software Distribution (BSD) Modified License, a copy of is provided along with "TestServerHook".
__END_LICENSE__ */



#import "TestServerHook.h"

//import private classes from GridEZ
#import "GEZServerHook.h"

@implementation TestServerHook

- (id)init
{
	if ( [super init] != nil ) {
		
		//HERE CHANGE THE STRINGS FOR THE SERVER AND PASSWORD TO TEST DIFFERENT CONFIGS
		serverHook = [[GEZServerHook alloc] initWithAddress:@"localhost" password:@""];
		
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(changeNotification:) name:GEZServerHookDidConnectNotification object:serverHook];
		[nc addObserver:self selector:@selector(changeNotification:) name:GEZServerHookDidDisconnectNotification object:serverHook];
		[nc addObserver:self selector:@selector(changeNotification:) name:GEZServerHookDidNotConnectNotification object:serverHook];
		[nc addObserver:self selector:@selector(changeNotification:) name:GEZServerHookDidUpdateNotification object:serverHook];
		[nc addObserver:self selector:@selector(changeNotification:) name:GEZServerHookDidLoadNotification object:serverHook];
	}
	return self;
}

- (void)report
{
	//report status
	NSLog(@"Connecting: %@",[serverHook isConnecting]?@"YES":@"NO");
	NSLog(@"Connected : %@", [serverHook isConnected]?@"YES":@"NO");
	NSLog(@"Updated    : %@",    [serverHook isUpdated]?@"YES":@"NO");
	NSLog(@"Loaded    : %@",    [serverHook isLoaded]?@"YES":@"NO");
	
	//report grids
	NSLog(@"Grids:");
	NSEnumerator *e = [[[serverHook xgridController] grids] objectEnumerator];
	id aGrid;
	while ( aGrid = [e nextObject] )
		NSLog(@"\t%@",[aGrid name]);
}

- (void)connect
{
	NSLog(@"Starting...");
	[self report];
	[serverHook connectWithSingleSignOnCredentials];
}

- (void)changeNotification:(NSNotification *)aNotification
{
	NSLog(@"Notification %@",[aNotification name]);
	[self report];
}

@end
