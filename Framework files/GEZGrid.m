//
//  GEZGrid.m
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
 
 GEZGrid instances are objects managed by the Core Data framework. Their functionality is built on top of GEZServerHook and GEZGridHook. When first created and when fetched from store, a GEZGrid instance needs to be 'hooked' to a GEZGridHook. When is a good time to set the hook? GEZGrid is a subclass of NSManagedObject, and has thus no init methods. The initialization methods for managed objects are normally 'awakeFromInsert' and 'awakeFromFetch'. However, the implementation is such that instances have to be created via a factory method declared in the public interface. When a new object is added to the context, first 'awakeFromInsert' and 'awakeFromFetch' get called, and only then the factory method sets the properties of the GEZGrid object, like the identifier and the GEZServer. Thus, it is too early in 'awakeFromInsert' to hook the GEZGrid to its GEZGridHook.
 
 The question is thus still: when is a good time to set the hook? It only needs to be done if the GEZServer is itself connected, and there is some real network stuff going on. Thus, in 'AwakeFromFetch', the instance is immediately hooked if the server is updated (XGGrid objects are created), or registers for GEZServerHookDidUpdate notification. In general, it seems to also be a better idea to let the run loop finish before actually doing anything. So the hook is actually called with a timer set to 0.
 
 */


#import "GEZGrid.h"
#import "GEZServer.h"
#import "GEZGridHook.h"
#import "GEZServerHook.h"
#import "GEZJob.h"
#import "GEZDefines.h"

NSString *GEZGridDidUpdateNotification = @"GEZGridDidUpdateNotification";
NSString *GEZGridDidLoadNotification = @"GEZGridDidLoadNotification";

@interface GEZGrid (GEZGridPrivate)
- (void)hookWhenNecessary;
- (void)hook;
@end


@implementation GEZGrid


#pragma mark *** Initializations ***

- (void)awakeFromFetch
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[super awakeFromFetch];
	[self hookWhenNecessary];
}

+ (GEZGrid *)gridWithIdentifier:(NSString *)identifier server:(GEZServer *)server
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//query the GEZServer to know if the grid already exists
	GEZGrid *resultGrid = [server gridWithIdentifier:identifier];
	if ( resultGrid != nil )
		return resultGrid;
	
	//if not existing, create it
	resultGrid = [NSEntityDescription insertNewObjectForEntityForName:GEZGridEntityName inManagedObjectContext:[server managedObjectContext]];
	[resultGrid setValue:server forKey:@"server"];
	[resultGrid setValue:identifier forKey:@"identifier"];
	
	//prepare it for hooking
	[resultGrid hookWhenNecessary];
	
	//Make sure the insertion is registered by observers
	[[server managedObjectContext] processPendingChanges];
	
	return resultGrid;
}

+ (GEZGrid *)connectedGrid
{
	/*TODO*/
	[NSException raise:@"GridEZNotImplementedRuntimeError" format:@"The method %s in class %@ has not been implemented yet",_cmd,[self class]];
	return nil;
}


- (void)dealloc
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[gridHook release];
	gridHook = nil;
	[super dealloc];
}


- (NSArray *)loadAllJobs
{
	//these are the XGJob
	NSArray *xgridJobs = [[self xgridGrid] jobs];
	if ( [xgridJobs count] < 1 )
		return [NSArray array];
	
	//jobs already loaded will be ignored
	NSSet *currentJobIdentifiers = [self valueForKeyPath:@"jobs.identifier"];
	
	//loop through the XGJob and add GEZJob if not existing
	NSMutableArray *addedJobs = [NSMutableArray arrayWithCapacity:[currentJobIdentifiers count]];
	NSEnumerator *e = [xgridJobs objectEnumerator];
	XGJob *oneJob;
	while ( oneJob = [e nextObject] ) {
		NSString *identifier = [oneJob identifier];
		if ( [currentJobIdentifiers member:identifier] == nil )
			[addedJobs addObject:[GEZJob jobWithGrid:self identifier:identifier]];
	}
	
	return [NSArray arrayWithArray:addedJobs];
}


#pragma mark *** Job submissions ***

//The GEZJob is added to the same managed object context as the grid
- (GEZJob *)submitJobWithSpecifications:(NSDictionary *)specs
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	GEZJob *newJob = [GEZJob jobWithGrid:self];
	[newJob submitWithJobSpecification:specs];
	return newJob;
}


#pragma mark *** Accessors ***

//KVO/KVC-compliant accessors
- (NSString *)name
{
	[self willAccessValueForKey:@"name"];
	NSString *name = [self primitiveValueForKey:@"name"];
	[self didAccessValueForKey:@"name"];
	return name;
}

//GEZJob objects, not XGJob
- (NSSet *)jobs
{
	[self willAccessValueForKey:@"jobs"];
	NSSet *jobs = [self primitiveValueForKey:@"jobs"];
	[self didAccessValueForKey:@"jobs"];
	return jobs;
}

- (GEZServer *)server
{
	[self willAccessValueForKey:@"server"];
	GEZServer *server = [self primitiveValueForKey:@"server"];
	[self didAccessValueForKey:@"server"];
	return server;
}

- (NSString *)identifier
{
	[self willAccessValueForKey:@"identifier"];
	NSString *identifier = [self primitiveValueForKey:@"identifier"];
	[self didAccessValueForKey:@"identifier"];
	return identifier;
}


- (BOOL)shouldObserveAllJobs;
{
    [self willAccessValueForKey:@"shouldObserveAllJobs"];
    BOOL flag = [[self primitiveValueForKey:@"shouldObserveAllJobs"] boolValue];
    [self didAccessValueForKey:@"shouldObserveAllJobs"];
    return flag;
}

- (void)setShouldObserveAllJobs:(BOOL)new
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	BOOL old = [[self primitiveValueForKey:@"shouldObserveAllJobs"] boolValue];
	if ( new != old ) {
		[self willChangeValueForKey:@"shouldObserveAllJobs"];
		[self setPrimitiveValue:[NSNumber numberWithBool:new] forKey:@"shouldObserveAllJobs"];
		[self didChangeValueForKey:@"shouldObserveAllJobs"];
		if ( new == YES ) {
			DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s - NOW OBSERVING ALL JOBS",[self class],self,_cmd);
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridHookDidChangeJobs:) name:GEZGridHookDidChangeJobsNotification object:gridHook];
			[self loadAllJobs];
		}
		else {
			DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s - NOT OBSERVING ALL JOBS ANYMORE",[self class],self,_cmd);
			[[NSNotificationCenter defaultCenter] removeObserver:self name:GEZGridHookDidChangeJobsNotification object:gridHook];
			[[self server] setShouldObserveAllJobs:NO];
		}

	}
}


//these are NOT complicant with KVO/KVC
- (BOOL)isAvailable
{
	return [[self server] isAvailable];
}

- (BOOL)isConnecting;
{
	return [[self server] isConnecting];
}

- (BOOL)isConnected;
{
	return [[self server] isConnected];
}

- (BOOL)isUpdated
{
	return [gridHook isUpdated];
}

- (BOOL)isLoaded;
{
	return [[self server] isLoaded];
}

- (NSString *)status
{
	return [[self server] status];
}


//low-level accessor
- (XGGrid *)xgridGrid
{
	return [gridHook xgridGrid];
}

@end


@implementation GEZGrid (GEZGridPrivate)

//hook is never called directly, instead use hookWhenNecessary that will get it called on the next event loop if necessary, or when the server is ready
- (void)hookWhenNecessary
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//in any case, we need to be always listening to notifications from the ServerHook to know when we can expect the GEZGridHook objects to be ready
	GEZServerHook *serverHook = [GEZServerHook serverHookWithAddress:[[self server] address]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidUpdate:) name:GEZServerHookDidUpdateNotification object:serverHook];
	
	//if server is already updated, the GEZGrid is ready to be hooked to its GEZGridHook, and we can do it at the next iteration of the run loop
	if ( [serverHook isUpdated] )
		[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(hookWithTimer:) userInfo:nil repeats:NO];
}

- (void)serverHookDidUpdate:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self hookWhenNecessary];
}

- (void)hookWithTimer:(NSTimer *)aTimer
{
	[self hook];
}

- (void)hook
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	GEZServerHook *serverHook = [GEZServerHook serverHookWithAddress:[[self server] address]];
	GEZGridHook *newGridHook = [serverHook gridHookWithIdentifier:[self identifier]];

	//no need to hook again if there is no change
	if ( gridHook == newGridHook )
		return;
	
	//release the old instance
	if ( gridHook != nil )
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:gridHook];
	[gridHook release];
	
	//set up the new instance
	gridHook = [newGridHook retain];
	NSString *name = [[gridHook xgridGrid] name];
	if ( name != nil )
		[self setValue:name forKey:@"name"];
	else
		[self setValue:@"undefined" forKey:@"name"];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridHookDidUpdate:) name:GEZGridHookDidUpdateNotification object:gridHook];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridHookDidLoad:) name:GEZGridHookDidLoadNotification object:gridHook];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridHookDidChangeName:) name:GEZGridHookDidChangeNameNotification object:gridHook];
	if ( [gridHook isUpdated] && [self shouldObserveAllJobs] )
		[self loadAllJobs];
}

- (void)gridHookDidUpdate:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[self setValue:[[gridHook xgridGrid] name] forKey:@"name"];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZGridDidUpdateNotification object:self];
	if ( [self shouldObserveAllJobs] )
		[self loadAllJobs];	
}

- (void)gridHookDidLoad:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[self setValue:[[gridHook xgridGrid] name] forKey:@"name"];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZGridDidLoadNotification object:self];
	if ( [self shouldObserveAllJobs] )
		[self loadAllJobs];	
}

- (void)gridHookDidChangeName:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	[self setValue:[[gridHook xgridGrid] name] forKey:@"name"];
}

- (void)gridHookDidChangeJobs:(NSNotification *)notification
{
	[self loadAllJobs];
}

@end

