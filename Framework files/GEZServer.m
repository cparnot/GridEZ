//
//  GEZServer.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



/*
 Notes on implementation:
 
 GEZServer instances are objects managed by the Core Data framework. Their functionality is built on top of GEZServerHook. When first created and when fetched from store, a GEZServer instance needs to be 'hooked' to a GEZServerHook. When is a good time to set the hook? GEZServer is a subclass of NSManagedObject, and has thus no init methods. The initialization methods for managed objects are normally 'awakeFromInsert' and 'awakeFromFetch'. However, the implementation is such that instances have to be created via a factory method declared in the public interface. When a new object is added to the context, first 'awakeFromInsert' and 'awakeFromFetch' get called, and only then the factory method sets the properties of the GEZServer object, like the address of the server for instance. Thus, it is too early in 'awakeFromInsert' to hook the GEZServer to its GEZServerHook. The question is thus still: when is a good time to set the hook? The answer is actually quite easy. The GEZServerHook is only needed when a connection is tried. So this is the only place where the 'hook' method is called.
  
 */

#import "GEZServer.h"
#import "GEZServerHook.h"
#import "GEZGrid.h"
#import "GEZJob.h"
#import "GEZServerBrowser.h"
#import "GEZManager.h"
#import "GEZDefines.h"

//global constants used for notifications
NSString *GEZServerDidConnectNotification = @"GEZServerDidConnectNotification";
NSString *GEZServerDidNotConnectNotification = @"GEZServerDidNotConnectNotification";
NSString *GEZServerDidDisconnectNotification = @"GEZServerDidDisconnectNotification";
NSString *GEZServerDidLoadNotification = @"GEZServerDidLoadNotification";


@interface GEZServer (GEZServerPrivate)
//- (GEZGrid *)gridWithID:(NSString *)identifier;
//- (void)setServerHook:(GEZServerHook *)newServerHook;
- (void)updateStatus;
- (void)hook;
@end

@implementation GEZServer

+ (void)initialize
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	NSArray *keys;
	if ( self == [GEZServer class] ) {
		//TODO
		keys=[NSArray arrayWithObjects:@"available", @"connecting", @"connected", @"loaded", @"wasAvailableInCurrentSession", @"wasAvailableInPreviousSession", @"wasConnectedInCurrentSession", @"wasConnectedInPreviousSession", nil];
		[self setKeys:keys triggerChangeNotificationsForDependentKey:@"status"];
		[self setKeys:[NSArray arrayWithObject:@"name"] triggerChangeNotificationsForDependentKey:@"address"];
	}
}

#pragma mark *** Class methods for browsing Bonjour network ***

+ (void)startBrowsing
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[[GEZServerBrowser sharedServerBrowser] startBrowsing];
}

+ (void)stopBrowsing
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[[GEZServerBrowser sharedServerBrowser] stopBrowsing];
}

+ (BOOL)isBrowsing
{
	return [[GEZServerBrowser sharedServerBrowser] isBrowsing];
}


#pragma mark *** Create/Retrieve servers ***

+ (NSArray *)allServers
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//to retrieve ALL records for a given entity, one can use a fetch request with no predicate
	NSManagedObjectContext *context = [GEZManager managedObjectContext];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:GEZServerEntityName inManagedObjectContext:context]];
	//[request setPredicate:[NSPredicate predicateWithFormat:@"(name != "")"]];
	NSError *error;
	return [context executeFetchRequest:request error:&error];
}

+ (GEZServer *)serverWithAddress:(NSString *)address
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	return [GEZServer serverWithAddress:address inManagedObjectContext:[GEZManager managedObjectContext]];
}

//this factory method ensures that only one server is created per address and per context
+ (GEZServer *)serverWithAddress:(NSString *)address inManagedObjectContext:(NSManagedObjectContext *)context
{
	
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//fetch request to see if there is already a server by that name in the context
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:GEZServerEntityName inManagedObjectContext:context]];
	[request setPredicate:[NSPredicate predicateWithFormat:@"(name == %@)",address]];
	NSError *error;
	NSArray *results=[context executeFetchRequest:request error:&error];
	
	//if already there, use the record in store
	//if not, create a new server object
	GEZServer *returnedServer;
	if ( [results count] > 0 )
		returnedServer = [results objectAtIndex:0];
	else {
		returnedServer = [NSEntityDescription insertNewObjectForEntityForName:GEZServerEntityName inManagedObjectContext:context];
		[returnedServer setValue:address forKey:@"name"];
		//Make sure the insertion is registered by observers
		[context processPendingChanges];
	}
	
	//create a copy of that server instance in the default managed object context returned by [GEZManager managedObjectContext]
	//this way, that server is registered with the application and available to all managed object contexts
	if ( context != [GEZManager managedObjectContext] ) {
		/*GEZServer *newServer =*/ [self serverWithAddress:address];
	}
	
	return returnedServer;
}


+ (GEZServer *)connectedServer
{
	NSEnumerator *e = [[self allServers] objectEnumerator];
	GEZServer *aServer;
	while ( aServer = [e nextObject] ) {
		if ( [aServer isConnected] )
			return aServer;
	}
	return nil;
}

- (GEZServer *)serverInManagedObjectContext:(NSManagedObjectContext *)context
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	NSString *address = [self valueForKey:@"name"];
	return [[self class] serverWithAddress:address inManagedObjectContext:context];
}

- (void)awakeFromFetch
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	[super awakeFromFetch];
	//autoconnect if appropriate (see setAvailable for the case GEZServerTypeLocal)
	if ( [self autoconnect] == YES && [[self valueForKey:@"wasConnectedInPreviousSession"] boolValue] == YES && [self serverType] == GEZServerTypeRemote )
		[self connect];
}


- (void)deleteFromStore
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//do not delete if the server is online
	if ( [self isAvailable] || [self isLoaded] || [self isConnected] || [self isConnecting] )
		return;

	//the method 'validateForDelete:' will take care of the clean-up
	[[self managedObjectContext] deleteObject:self];
}

- (BOOL)validateForDelete:(NSError **)error
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	if ( [super validateForDelete:error] == NO )
		return NO;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[serverHook release];
	serverHook = nil;
	return YES;
}


- (void)dealloc
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[serverHook release];
	[super dealloc];
}


#pragma mark *** Public accessors ***

- (NSString *)address
{
	NSString *address;
	[self willAccessValueForKey:@"name"];
	address = [self primitiveValueForKey:@"name"];
	[self didAccessValueForKey:@"name"];
	return address;
}

//this is an 'abstract' ivar, which is made KVO compliant by triggering it after any change in the state properties (see the +initialize method)
- (NSString *)status
{
	NSString *result;
    [self willAccessValueForKey:@"status"];
	if ([self isLoaded])
		result = @"Connected";
	else if ([self isConnected])
		result = @"Loading";
	else if ([self isConnecting])
		result = @"Connecting";
	else if ([self isAvailable])
		result = @"Available";
	else if ([[self valueForKey:@"wasConnectedInCurrentSession"] boolValue])
		result = @"Disconnected";
	else 
		result = @"Offline";
	[self didAccessValueForKey:@"status"];
	return result;
}

- (BOOL)isAvailable
{
    [self willAccessValueForKey:@"available"];
    BOOL flag = [[self primitiveValueForKey:@"available"] boolValue];
    [self didAccessValueForKey:@"available"];
    return flag;
}
- (BOOL)isConnected
{
    [self willAccessValueForKey:@"connected"];
    BOOL flag = [[self primitiveValueForKey:@"connected"] boolValue];
    [self didAccessValueForKey:@"connected"];
    return flag;
}

- (BOOL)isConnecting
{
    [self willAccessValueForKey:@"connecting"];
    BOOL flag = [[self primitiveValueForKey:@"connecting"] boolValue];
    [self didAccessValueForKey:@"connecting"];
    return flag;
}

- (BOOL)isLoaded
{
    [self willAccessValueForKey:@"loaded"];
    BOOL flag = [[self primitiveValueForKey:@"loaded"] boolValue];
    [self didAccessValueForKey:@"loaded"];
    return flag;
}

- (BOOL)shouldStorePasswordInKeychain;
{
    [self willAccessValueForKey:@"shouldStorePasswordInKeychain"];
    BOOL flag = [[self primitiveValueForKey:@"shouldStorePasswordInKeychain"] boolValue];
    [self didAccessValueForKey:@"shouldStorePasswordInKeychain"];
    return flag;
}

- (void)setShouldStorePasswordInKeychain:(BOOL)flag
{
	[self willChangeValueForKey:@"shouldStorePasswordInKeychain"];
	[self setPrimitiveValue:[NSNumber numberWithBool:flag] forKey:@"shouldStorePasswordInKeychain"];
	[self didChangeValueForKey:@"shouldStorePasswordInKeychain"];
}

- (BOOL)hasPasswordInKeychain
{
	[self hook];
	return [serverHook hasPasswordInKeychain];
}


- (BOOL)isObservingAllJobs;
{
    [self willAccessValueForKey:@"observingAllJobs"];
    BOOL flag = [[self primitiveValueForKey:@"observingAllJobs"] boolValue];
    [self didAccessValueForKey:@"observingAllJobs"];
    return flag;
}

- (void)setObservingAllJobs:(BOOL)new
{
	BOOL old = [[self primitiveValueForKey:@"observingAllJobs"] boolValue];
	if ( new != old ) {
		[self willChangeValueForKey:@"observingAllJobs"];
		[self setPrimitiveValue:[NSNumber numberWithBool:new] forKey:@"observingAllJobs"];
		[self didChangeValueForKey:@"observingAllJobs"];
		NSEnumerator *e = [[self grids] objectEnumerator];
		GEZGrid *oneGrid;
		while ( oneGrid = [e nextObject] )
			[oneGrid setObservingAllJobs:new];
	}
	/*TODO: ideally, this setting should also apply to future grids potentially added*/
}

/*
- (void)setPassword:(NSString *)aString
{
	[self willChangeValueForKey:@"password"];
	[self setPrimitiveValue:aString forKey:@"password"];
	[self didChangeValueForKey:@"password"];
}
*/

- (NSSet *)grids
{
    [self willAccessValueForKey:@"grids"];
    NSSet *grids = [self primitiveValueForKey:@"grids"];
    [self didAccessValueForKey:@"grids"];
    return grids;
}

- (NSSet *)jobs
{
	[self willAccessValueForKey:@"jobs"];
	NSSet *jobs = [self primitiveValueForKey:@"jobs"];
	[self didAccessValueForKey:@"jobs"];
	return jobs;
}

- (XGController *)xgridController
{
	return [serverHook xgridController];
}

//get the corresponding GEZGrid, returning nil if not existing
- (GEZGrid *)gridWithIdentifier:(NSString *)identifier
{
	GEZGrid *aGrid;
	NSSet *currentGrids = [self valueForKey:@"grids"];
	NSEnumerator *e = [currentGrids objectEnumerator];
	while ( (aGrid = [e nextObject]) && ( [[aGrid valueForKey:@"identifier"] isEqualToString:identifier]==NO ) )
		;
	[e allObjects];
	return aGrid;
}

- (GEZGrid *)defaultGrid
{	
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//get the default grid from the controller, if connected
	XGGrid *grid = [[self xgridController] defaultGrid];
	if ( grid == nil )
		return nil;
	
	return [self gridWithIdentifier:[grid identifier]];
}

- (GEZServerType)serverType
{
    [self willAccessValueForKey:@"serverType"];
    GEZServerType serverType = [[self primitiveValueForKey:@"serverType"] intValue];
    [self didAccessValueForKey:@"serverType"];
    return serverType;
}

//auto-reconnect when connection is lost, or as soon as available if wasConnectedInPreviousSession == YES, or immediately if remote connection and wasConnectedInPreviousSession == YES; in the latter 2 cases, also set the serverHook to autoconnect
- (BOOL)autoconnect
{
	[self willAccessValueForKey:@"autoconnect"];
	BOOL autoconnectBool = [[self primitiveValueForKey:@"autoconnect"] boolValue];
	[self didAccessValueForKey:@"autoconnect"];
	return autoconnectBool;
}

- (void)setAutoconnect:(BOOL)newautoconnect
{
	[self willChangeValueForKey:@"autoconnect"];
	[self setPrimitiveValue:[NSNumber numberWithBool:newautoconnect] forKey:@"autoconnect"];
	[self didChangeValueForKey:@"autoconnect"];
}



#pragma mark *** Connection public methods ***

- (void)connectWithoutAuthentication
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self hook];
	[serverHook connectWithoutAuthentication];
}

- (void)connectWithKeychainPassword
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self hook];
	[serverHook setPassword:nil];
	[serverHook connectWithPassword];
}

- (void)connectWithPassword:(NSString *)password
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self hook];
	if ( [self shouldStorePasswordInKeychain] )
		[serverHook storePasswordInKeychain:password];
	[serverHook setPassword:password];
	[serverHook connectWithPassword];
}

- (void)connectWithSingleSignOnCredentials;
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self hook];
	[serverHook connectWithSingleSignOnCredentials];
}

- (void)disconnect
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[serverHook disconnect];
}

- (void)connect
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self hook];
	[serverHook connect];
}



- (GEZJob *)submitJobWithSpecifications:(NSDictionary *)specs
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	GEZJob *newJob = [GEZJob jobWithServer:self];
	[newJob submitWithJobSpecification:specs];
	return newJob;
}

@end


@implementation GEZServer (GEZServerPrivate)

//- (GEZGrid *)gridWithID:(NSString *)identifier;

//update the status of the server, based on the status of the serverHook
- (void)updateStatus
{
	BOOL l = [serverHook isLoaded];
	BOOL s = [serverHook isUpdated];
	BOOL c = [serverHook isConnected];
	BOOL lsc = l || s || c;
	BOOL n = [serverHook isConnecting];
	if ( lsc ) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"wasConnectedInPreviousSession"];
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"wasAvailableInPreviousSession"];
	}
	[self setValue:[NSNumber numberWithBool:lsc] forKey:@"connected"];
	[self setValue:[NSNumber numberWithBool:lsc] forKey:@"wasConnectedInCurrentSession"];
	[self setValue:[NSNumber numberWithBool:lsc] forKey:@"wasAvailableInCurrentSession"];
	[self setValue:[NSNumber numberWithBool:n]   forKey:@"connecting"];
	[self setValue:[NSNumber numberWithBool:l]   forKey:@"loaded"];

	//if Bonjour, the GEZServer browser should take care of that. For remote server, available should be on/off at the same time as connection
	if ( [self serverType] == GEZServerTypeRemote )
		[self setValue:[NSNumber numberWithBool:lsc] forKey:@"available"];
}

- (BOOL)isAvailable
{
	[self willAccessValueForKey:@"available"];
	BOOL value = [[self primitiveValueForKey:@"available"] boolValue];
	[self didAccessValueForKey:@"available"];
	return value;
}

- (void)setAvailable:(BOOL)aValue
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self willChangeValueForKey:@"available"];
	[self setPrimitiveValue:[NSNumber numberWithBool:aValue] forKey:@"available"];
	[self didChangeValueForKey:@"available"];
	if ( aValue == YES && [self autoconnect] == YES && [[self primitiveValueForKey:@"wasConnectedInPreviousSession"] boolValue] == YES )
		[self connect];
}

//creates the hook with a GEZServerHook that will allow for the real stuff to happen
- (void)hook
{
	if ( serverHook != nil )
		return;

	//change the serverHook ivar to the new value
	serverHook = [[GEZServerHook alloc] initWithAddress:[self valueForKey:@"name"]];
	if ( serverHook == nil )
		return;
	
	//setuup autoconnect
	if ( [self autoconnect] ==YES )
		[serverHook setAutoconnect:YES];
	
	//We need to be notified of all the activity of the GEZServerHook object
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidConnect:) name:GEZServerHookDidConnectNotification object:serverHook];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidLoad:) name:GEZServerHookDidLoadNotification object:serverHook];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidUpdate:) name:GEZServerHookDidUpdateNotification object:serverHook];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidNotConnect:) name:GEZServerHookDidNotConnectNotification object:serverHook];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidDisconnect:) name:GEZServerHookDidDisconnectNotification object:serverHook];
	
	//update the status of the server based on server connection status
	[self updateStatus];
		
}

#pragma mark *** GEZServerHook notifications ***

- (void)serverHookDidConnect:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self updateStatus];
	[self setValue:[NSNumber numberWithInt:[serverHook serverType]] forKey:@"serverType"];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerDidConnectNotification object:self];
}

- (void)serverHookDidNotConnect:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self updateStatus];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerDidNotConnectNotification object:self];
}

- (void)serverHookDidDisconnect:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self updateStatus];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerDidDisconnectNotification object:self];
}

- (void)serverHookDidUpdate:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self updateStatus];
	NSEnumerator *e = [[[serverHook xgridController] grids] objectEnumerator];
	XGGrid *aGrid;
	while ( aGrid = [e nextObject] ) {
		GEZGrid *newGrid = [GEZGrid gridWithIdentifier:[aGrid identifier] server:self];
		[newGrid setObservingAllJobs:[self isObservingAllJobs]];
	}
}

- (void)serverHookDidLoad:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self updateStatus];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerDidLoadNotification object:self];
}


@end

