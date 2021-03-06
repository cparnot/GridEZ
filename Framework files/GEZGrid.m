//
//  GEZGrid.m
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
* The names of its contributors may not be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//these are the XGJob
	NSArray *xgridJobs = [[self xgridGrid] jobs];
	if ( [xgridJobs count] < 1 )
		return [NSArray array];
	
	//if some jobs are "submitting", they may not have an identifier yet set on an existing GEZJob, while an XGJob was already created; this GEZJob and the XGJob are not "hooked"; if we let GEZGrid go its way below, a GEZJob may be created in duplicate, so we exit here (GEZJob will call again 'loadAllJobs' when a submission is finally finished, see GEZJob)
	NSSet *currentJobStates = [self valueForKeyPath:@"jobs.isSubmitting"];
	if ( [currentJobStates member:[NSNumber numberWithInt:1]] )
		return [NSArray array];
	
	//jobs already loaded will be ignored based on the XGJob identifier
	NSSet *currentJobIdentifiers = [self valueForKeyPath:@"jobs.identifier"];
	
	//loop through the XGJob and add GEZJob if not existing
	NSMutableArray *addedJobs = [NSMutableArray arrayWithCapacity:[currentJobIdentifiers count]];
	NSEnumerator *e = [xgridJobs objectEnumerator];
	XGJob *oneJob;
	while ( oneJob = [e nextObject] ) {
		if ( [currentJobIdentifiers member:[oneJob identifier]] == nil )
			[addedJobs addObject:[GEZJob jobWithGrid:self identifier:[oneJob identifier]]];
	}
	
	return [NSArray arrayWithArray:addedJobs];
}

/*
- (void)loadAllJobsSoon
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[self callSelectorSoon:@selector(loadAllJobs)];
}
*/


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


- (BOOL)isObservingAllJobs;
{
    [self willAccessValueForKey:@"observingAllJobs"];
    BOOL flag = [[self primitiveValueForKey:@"observingAllJobs"] boolValue];
    [self didAccessValueForKey:@"observingAllJobs"];
    return flag;
}

- (void)setObservingAllJobs:(BOOL)new
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	BOOL old = [[self primitiveValueForKey:@"observingAllJobs"] boolValue];
	if ( new != old ) {
		[self willChangeValueForKey:@"observingAllJobs"];
		[self setPrimitiveValue:[NSNumber numberWithBool:new] forKey:@"observingAllJobs"];
		[self didChangeValueForKey:@"observingAllJobs"];
		if ( new == YES ) {
			DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s - NOW OBSERVING ALL JOBS",[self class],self,_cmd);
			[self loadAllJobs];
		}
		else {
			DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s - NOT OBSERVING ALL JOBS ANYMORE",[self class],self,_cmd);
			[[self server] setObservingAllJobs:NO];
		}
	}
}

- (int)availableAgentsGuess
{
	[self willAccessValueForKey:@"availableAgentsGuess"];
	int availableAgentsGuess = [[self primitiveValueForKey:@"availableAgentsGuess"] intValue];
	[self didAccessValueForKey:@"availableAgentsGuess"];
	return availableAgentsGuess;	
}



//these are NOT complicant with KVO/KVC

- (BOOL)autoconnect
{
	return [[self server] autoconnect];
}

- (void)setAutoconnect:(BOOL)newautoconnect
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self willChangeValueForKey:@"autoconnect"];
	[[self server] setAutoconnect:newautoconnect];
	[self didChangeValueForKey:@"autoconnect"];
}


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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridHookDidChangeJobs:) name:GEZGridHookDidChangeJobsNotification object:gridHook];
	if ( [gridHook isUpdated] && [self isObservingAllJobs] )
		[self loadAllJobs];
}

- (void)gridHookDidUpdate:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[self setValue:[[gridHook xgridGrid] name] forKey:@"name"];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZGridDidUpdateNotification object:self];
	if ( [self isObservingAllJobs] )
		[self loadAllJobs];	
}

- (void)gridHookDidLoad:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[self setValue:[[gridHook xgridGrid] name] forKey:@"name"];
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZGridDidLoadNotification object:self];
	if ( [self isObservingAllJobs] )
		[self loadAllJobs];	
}

- (void)gridHookDidChangeName:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	[self setValue:[[gridHook xgridGrid] name] forKey:@"name"];
}

- (void)gridHookDidChangeJobs:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s = %d jobs",[self class],self,_cmd,[[[self xgridGrid] jobs] count]);
	
	//create GEZJobs if necessary
	if ( [gridHook isUpdated] && [self isObservingAllJobs] )
		[self loadAllJobs];
	
	//maybe we can update the value for availableAgentsGuess
	if ( [gridHook isLoaded] ) {
		NSEnumerator *e = [[[self xgridGrid] jobs] objectEnumerator];
		XGJob *aJob;
		int countPending = 0;
		int countRunning = 0;
		while ( aJob = [e nextObject] ) {
			if ( [aJob state] == XGResourceStatePending )
				countPending ++;
			else if ( [aJob state] == XGResourceStateRunning )
				countRunning += [aJob taskCount] - [aJob completedTaskCount];
		}
		if ( countPending != 0 )
			[self setValue:[NSNumber numberWithInt:countRunning] forKey:@"availableAgentsGuess"];
	}
}

@end

