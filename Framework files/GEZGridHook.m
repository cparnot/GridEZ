//
//  GEZGridHook.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import "GEZGridHook.h"
#import "GEZServerHook.h"
#import "GEZResourceObserver.h"

NSString *GEZGridHookDidUpdateNotification = @"GEZGridHookDidUpdateNotification";
NSString *GEZGridHookDidLoadNotification = @"GEZGridHookDidLoadNotification";
NSString *GEZGridHookDidChangeNameNotification = @"GEZGridHookDidChangeNameNotification";
NSString *GEZGridHookDidChangeJobsNotification = @"GEZGridHookDidChangeJobsNotification";


//the state changes as the connection progresses from not being connected to having loaded all the attributes of the server
typedef enum {
	GEZGridHookStateUninitialized = 1,
	GEZGridHookStateConnected,
	GEZGridHookStateUpdated,
	GEZGridHookStateLoaded,
	GEZGridHookStateDisconnected,
} GEZGridHookState;


@implementation GEZGridHook


#pragma mark *** Initializations ***

- (id)initWithXgridGrid:(XGGrid *)aGrid serverHook:(GEZServerHook *)aServer
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	if ( self = [super init] ) {
		
		//set up ivars
		gridHookState = GEZGridHookStateUninitialized;
		serverHook = aServer; //no retain to avoid cycles
		[self setXgridGrid:aGrid];
		
		
	}
	return self;
}


- (id)initWithIdentifier:(NSString *)identifier serverHook:(GEZServerHook *)aServer;
{
	
	//get the XGGrid object
	NSEnumerator *e = [[[serverHook xgridController] grids] objectEnumerator];
	XGGrid *aGrid = nil;
	while ( ( aGrid = [e nextObject] ) && ( ! [[aGrid identifier] isEqualToString:identifier] ) ) ;
	if ( aGrid == nil ) {
		[self release];
		self = nil;
		return nil;
	} else
		return [self initWithXgridGrid:aGrid serverHook:aServer];
	
}

+ (GEZGridHook *)gridHookWithXgridGrid:(XGGrid *)aGrid serverHook:(GEZServerHook *)aServer
{
	GEZGridHook *gridHook = [aServer gridHookWithIdentifier:[aGrid identifier]];
	if ( gridHook != nil )
		return gridHook;
	else
		return [[[self alloc] initWithXgridGrid:aGrid serverHook:aServer] autorelease];
}

+ (GEZGridHook *)gridHookWithIdentifier:(NSString *)identifier serverHook:(GEZServerHook *)aServer;
{
	GEZGridHook *gridHook = [aServer gridHookWithIdentifier:identifier];
	if ( gridHook != nil )
		return gridHook;
	else
		return [[[self alloc] initWithIdentifier:identifier serverHook:aServer] autorelease];
}

- (void)dealloc
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	gridHookState = GEZGridHookStateUninitialized;
	serverHook = nil; //no retain/release to avoid cycles
	[self setXgridGrid:nil]; //this takes care of xgridGridObserver as well
	[xgridJobObservers release];
	[super dealloc];
}

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"Grid Connection to '%@-%@' (state %d)", [serverHook address], [xgridGrid name], gridHookState];
}

#pragma mark *** Accessors ***

- (void)setXgridGrid:(XGGrid *)newGrid
{
	if ( newGrid != xgridGrid ) {
		
		//clean the old ivar
		[xgridGridObserver setDelegate:nil];
		[xgridGridObserver release];
		[xgridGrid release];
		
		//setup the new ivar
		xgridGrid = [newGrid retain];
		xgridGridObserver = [[GEZResourceObserver alloc] initWithResource:xgridGrid observedKeys:[NSSet setWithObjects:@"name",@"state",@"jobs",nil]];
		[xgridGridObserver setDelegate:self];
		
		//if ready, notify self to be updated on the next iteration of the run loop
		if ( [xgridGrid isUpdated] == YES ) {
			NSInvocation *updateInvocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(xgridResourceDidUpdate:)]];
			[updateInvocation setSelector:@selector(xgridResourceDidUpdate:)];
			[updateInvocation setTarget:self];
			[updateInvocation setArgument:&xgridGrid atIndex:2];
			[NSTimer scheduledTimerWithTimeInterval:0 invocation:updateInvocation repeats:NO];
		}
	}
}

- (XGGrid *)xgridGrid
{
	return xgridGrid;
}

- (BOOL)isUpdated
{
	return ( gridHookState == GEZGridHookStateUpdated ) || ( gridHookState == GEZGridHookStateLoaded );
}

- (BOOL)isLoaded
{
	return gridHookState == GEZGridHookStateLoaded;
}

#pragma mark *** job observing ***

- (BOOL)checkAllJobsUpdated
{
	if ( [self isLoaded] == YES )
		return YES;
	
	BOOL allJobsUpdated = YES;
	NSEnumerator *e = [[xgridGrid jobs] objectEnumerator];
	XGJob *oneJob;
	while ( oneJob = [e nextObject] ) {
		if ( [oneJob isUpdated] == NO ) {
			allJobsUpdated = NO;
			[e allObjects];
		}
	}
	if ( allJobsUpdated ) {
		gridHookState = GEZGridHookStateLoaded;
		[[NSNotificationCenter defaultCenter] postNotificationName:GEZGridHookDidLoadNotification object:self];
		[xgridJobObservers release];
		xgridJobObservers = nil;
	}
	
	return [self isLoaded];
}

- (void)startJobObservation
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//maybe jobs are already observed or already updated
	if ( xgridJobObservers != nil )
		return;
	if ( [self checkAllJobsUpdated] )
		return;
	
	//create GEZResourceObserver objects to observe them until they are all updated
	NSArray *xgridJobs = [xgridGrid jobs];
	NSMutableSet *observers = [NSMutableSet setWithCapacity:[xgridJobs count]];
	NSEnumerator *e = [xgridJobs objectEnumerator];
	XGJob *oneJob;
	while ( oneJob = [e nextObject] ) {
		GEZResourceObserver *resourceObserver = [[[GEZResourceObserver alloc] initWithResource:oneJob] autorelease];
		[resourceObserver setDelegate:self];
		[observers addObject:resourceObserver];
		
	}
	xgridJobObservers = [observers copy];
	
}

#pragma mark *** XGGrid observing, going from "Connected" to "Updated" ***

- (void)logStatus
{
	NSLog(@"***********");
	NSLog(@"State: %d",[[self xgridGrid] state]);
	NSLog(@"Jobs: %@",[[self xgridGrid] jobs]);
	NSLog(@"Name: %@",[[self xgridGrid] name]);
	NSLog(@"isUpdating: %@",[[self xgridGrid] isUpdating]?@"YES":@"NO");
	NSLog(@"isUpdated: %@",[[self xgridGrid] isUpdated]?@"YES":@"NO");
}


//delegate  callback from GEZResourceObserver, when the XGGrid object is updated or when one of the XGJob objects is updated
- (void)xgridResourceDidUpdate:(XGResource *)resource
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s : %@",[self class],self,_cmd,resource);	
	//[self logStatus];
	
	//Case 1: the XGGrid is now updated and updated with the values on the remote server		
	if ( resource == xgridGrid ) {
		if ( gridHookState != GEZGridHookStateUninitialized )
			return;
		
		//update gridHookState to be consistent with XGGrid state
		XGResourceState gridState = [xgridGrid state];
		if ( gridState == XGResourceStateAvailable )
			gridHookState = GEZGridHookStateUpdated;
		else if ( gridState == XGResourceStateOffline || gridState == XGResourceStateUnavailable )
			gridHookState = GEZGridHookStateDisconnected;
		
		//this log shows that the XGJob instances are available when calling 'jobs', but only their identifier is properly set, and they are not "updated" yet (no name, status, starting date,...)
		DLog(NSStringFromClass([self class]),12,@"<%@:%p> jobs:\n%@",[self class],self,[[self xgridGrid] jobs]);
		if ( [self checkAllJobsUpdated] == NO )
			[self startJobObservation];
		
		//notify of the change of state
		[[NSNotificationCenter defaultCenter] postNotificationName:GEZGridHookDidUpdateNotification object:self];
	}
	
	//Case 2: one of the XGJob did update
	else
		[self checkAllJobsUpdated];
	
}

//delegate callback from GEZResourceObserver
- (void)xgridResourceNameDidChange:(XGResource *)resource
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);	
	//[self logStatus];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZGridHookDidChangeNameNotification object:self];	
}

//delegate callback from GEZResourceObserver
- (void)xgridResourceJobsDidChange:(XGResource *)resource
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);	
	//[self logStatus];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZGridHookDidChangeJobsNotification object:self];	
}

@end
