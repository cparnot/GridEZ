//
//  GEZJob.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



/*
 
 The implementation for GEZJob is particularly complex. Unlike GEZGrid and GEZServer, it handles both the Core Data aspect and the XGJob wrapping. It might seem that the implementation strategies are inconsistent, but I think it makes sense: grid and servers are potentially used by a lot of other objects; one job is likely to be used only by one object. This has consequences on the implementation, but also on the interface, in particular the use of notifications vs. delegate. Here is a detailed description of the different parts of the implementation:
 
 * Unlike GEZGrid and GEZServer, there could be different instances of GEZJob for the same id and same context, but that's ok as it is less likely to happen; this allows to have a delegate
 * Unlike GEZGrid and GEZServer, GEZJob uses a delegate (***TODO*** and not notifications at all?); (***TODO*** not sure yet: delegate may be a core data property, which will make it easier to implement metaJob objects in GridStuffer and link the data models with each other; or have similar structures in other programs)
 * The GEZJob goes through a series of states, from Uninitialized to Finished or Failed or Deleted; unlike GEZGrid and GEZServer, but more like GEZServerHook and GEZGridHook
 
 * What should be done when a GEZJob is fetched (when 'awakeFromFetch' is called):
	* if the state is Uninitialized or Submitting, mark the GEZJob as 'Invalid'
	* if the job does not point to a valid GEZGrid or does not have an identifier, mark the GEZJob as 'Invalid'
	* in all other cases, 'hook' the job

 * What should be done to hook a GEZjob (when 'hook' is called):
	* if the grid is not connected yet, wait for the connection and then come back
	* if there is no XGJob with the correct identifier, mark the GEZJob as 'Invalid'
	* if XGJob is loaded already, call 'xgridJobDidLoad'
	* else, get the XGJob and observe it until it is loaded --> observe state
 
 * What should be done when the GEZJob is finally loaded (when 'xgridJobDidLoad' is called):
	* if the job is marked for deletion (state "Deleting"), start the deletion process
	* if the job is finished, and 'shouldRetrieveResultsAutomatically == YES', start the job retrieval process
	* update the state
 
 * What should be done if a job is marked as Invalid (when 'markAsInvalid' is called):
	* if 'shouldDeleteAutomatically == YES', delete from store
  
 * when a new job is created:
	* it is not submitted immediately
	* the grid to be used for submission can still be changed while Uninitialized or Submitting
	* when 'Submitted', to an actual XGGrid, the grid cannnot be changed anymore
	* when the submission is successfull and the XGJob has an id, the job is 'Running'
	* if the submission fails, the GEZJob becomes 'Invalid' and nothing else can be done
 
 * Retrieving results is complicated by the fact that all the different pieces are downloaded independently, all through its own XGFileDownload; but the whole thing is quite easy to do in fact and is fairly independent of the rest of the code; the GEZJob has a property 'shouldRetrieveResultsWhenFinished' set to YES to directly start the downloading when the job is finished
 
 * Deletion requires first deletion from the grid and then deletion from the store; an ActionMonitor needs to be observed for the deletion from the grid; the deletion from the grid does not need to happen if there is no job with the right identifier in the grid and the grid is connected: the job is already gone
 
 * GEZJob needs to observe its XGJob: state, ...?... ***TODO***: this needs to be better defined when the implementation is finished

 */

#define MAX_COUNT_DELETION_ATTEMPTS 3

#import "GEZJob.h"
#import "GEZGrid.h"
#import "GEZServer.h"
#import "GEZServerHook.h"
#import "GEZTask.h"
#import "GEZResults.h"
#import "GEZDefines.h"
#import "GEZManager.h"

//internal state
typedef enum {
	GEZJobStateUninitialized = 1,
	GEZJobStateSubmitting, //submitted to GEZJob, not to XGGrid yet
	GEZJobStateSubmitted, //submitted to XGGrid, the grid is now set and can't be changed anymore
	GEZJobStateInvalid,
	GEZJobStatePending,
	GEZJobStateRunning,
	GEZJobStateSuspended,
	GEZJobStateFailed,
	GEZJobStateFinished,
	GEZJobStateRetrieving,
	GEZJobStateRetrieved,
	GEZJobStateDeleting,
	GEZJobStateDeleted,
} GEZJobState;


//private
//use to convert GEZJobState enum into NSStrings - see +(void)initialize
static NSString *StatusStrings[20];


//public global
//keys used in the results dictionary = same as the 'symbolic file path' used by XGFile
NSString *GEZJobResultsStandardOutputKey;
NSString *GEZJobResultsStandardErrorKey;

@interface GEZJob (GEZJobPrivate)

//private accessors
- (GEZJobState)state;
- (void)setState:(GEZJobState)newState;
- (BOOL)shouldDelete;
- (NSString *)identifier;
- (void)setJobID:(NSString *)identifierNew;
- (BOOL)shouldDelete;
- (BOOL)shouldRetrieveResultsAutomatically;
- (void)setXgridJob:(XGJob *)newJob;
- (void)setSubmissionAction:(XGActionMonitor *)newAction;
- (void)setDeletionAction:(XGActionMonitor *)newAction;

//hooking the GEZJob to a XGJob
- (void)hookSoon;
- (void)xgridJobDidLoad:(NSTimer *)timer;
- (void)stateDidChange;
- (void)taskCountDidChange;
- (void)completedTaskCountDidChange;

//submission
- (void)submitSoon;

//deletion
- (void)deleteSoon;
- (void)deleteFromStoreSoon;

//result retrieval
- (void)didFinish;
- (void)didFail;
- (void)retrieveResultsSoon;

@end

@implementation GEZJob

+ (void)initialize
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//POTENTIAL PROBLEM
	//not guaranteed to be set before use, but they are only use for result retrieval, so unlikely to be a problem
	//using the same as the 'symbolic file path' used by XGFile
	GEZJobResultsStandardOutputKey = XGFileStandardOutputPath;
	GEZJobResultsStandardErrorKey = XGFileStandardErrorPath;
	
	//'statusString' is a a key for a "virtual" value; its value is calculated on request, and notifications of its change are dependent on the changes in the "real" value for the key 'state'
	[self setKeys:[NSArray arrayWithObject:@"state"] triggerChangeNotificationsForDependentKey:@"status"];

	//'server' is also a key for a virtual value; changing the grid may result in changing the server
	[self setKeys:[NSArray arrayWithObject:@"grid"] triggerChangeNotificationsForDependentKey:@"server"];

	//initialization of the private array of NSString used to convert from GEZJobState enum
	StatusStrings[GEZJobStateUninitialized] = @"Uninitialized";
	StatusStrings[GEZJobStateSubmitting] = @"Submitting";
	StatusStrings[GEZJobStateSubmitted] = @"Submitted";
	StatusStrings[GEZJobStateInvalid] = @"Invalid";
	StatusStrings[GEZJobStatePending] = @"Pending";
	StatusStrings[GEZJobStateRunning] = @"Running";
	StatusStrings[GEZJobStateSuspended] = @"Suspended";
	StatusStrings[GEZJobStateFailed] = @"Failed";
	StatusStrings[GEZJobStateFinished] = @"Finished";
	StatusStrings[GEZJobStateRetrieving] = @"Retrieving";
	StatusStrings[GEZJobStateRetrieved] = @"Retrieved";
	StatusStrings[GEZJobStateDeleting] = @"Deleting";
	StatusStrings[GEZJobStateDeleted] = @"Deleted";
}

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"Job %@ = '%@'", [self primitiveValueForKey:@"identifier"], [self primitiveValueForKey:@"name"]];
}

- (void)dealloc
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self setXgridJob:nil];
	[self setSubmissionAction:nil];
	[self setDeletionAction:nil];

	[jobSpecification release];
	[results release];
	[jobInfo release];
	
	jobSpecification = nil;
	results = nil;
	jobInfo = nil;
	delegate = nil;

	[super dealloc];
}

#pragma mark *** Creating new jobs ***

+ (GEZJob *)jobWithManagedObjectContext:(NSManagedObjectContext *)context
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	GEZJob *newJob = [NSEntityDescription insertNewObjectForEntityForName:GEZJobEntityName inManagedObjectContext:context];
	[newJob setValue:[NSNumber numberWithInt:GEZJobStateUninitialized] forKey:@"state"];
	return newJob;
}


+ (GEZJob *)job
{
	return [self jobWithManagedObjectContext:[GEZManager managedObjectContext]];
}

+ (GEZJob *)jobWithGrid:(GEZGrid *)grid
{
	GEZJob *newJob = [self jobWithManagedObjectContext:[grid managedObjectContext]];
	//note that setGrid: also sets the server so no need to do it too
	[newJob setGrid:grid];
	return newJob;
}

+ (GEZJob *)jobWithServer:(GEZServer *)server
{
	return [self jobWithGrid:[server defaultGrid]];
}

+ (GEZJob *)jobWithGrid:(GEZGrid *)grid identifier:(NSString *)identifier;
{
	GEZJob *newJob = [self jobWithManagedObjectContext:[grid managedObjectContext]];
	[newJob setGrid:grid];
	[newJob setValue:identifier forKey:@"identifier"];
	[newJob hookSoon];
	return newJob;
}


#pragma mark *** Public accessors ***

- (GEZGrid *)grid
{
	GEZGrid *grid;
	[self willAccessValueForKey:@"grid"];
	grid = [self primitiveValueForKey:@"grid"];
	[self didAccessValueForKey:@"grid"];
	return grid;
}

- (GEZServer *)server
{
	return [[self grid] server];
}

- (void)setGrid:(GEZGrid *)newGrid
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//do not change the grid if already submitted
	GEZJobState state = [self state];
	if ( state != GEZJobStateUninitialized && state != GEZJobStateSubmitting )
		return;

	//make sure the newGrid is in the right managedObjectContext
	if ( [self managedObjectContext] != [newGrid managedObjectContext] )
		newGrid = [GEZGrid gridWithIdentifier:[newGrid identifier] server:[[newGrid server] serverInManagedObjectContext:[self managedObjectContext]]];
	
	GEZGrid *oldGrid = [self primitiveValueForKey:@"grid"];
	if ( newGrid == oldGrid )
		return;
	
	//set up the new grid
	if ( oldGrid != nil )
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:oldGrid];
	[self willChangeValueForKey:@"grid"];
	[self setPrimitiveValue:newGrid forKey:@"grid"];
	[self didChangeValueForKey:@"grid"];
	if ( newGrid != nil )
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridDidSync:) name:GEZGridDidSyncNotification object:newGrid];

	//the server should be changed too
	[self willChangeValueForKey:@"server"];
	[self setPrimitiveValue:[newGrid server] forKey:@"server"];
	[self didChangeValueForKey:@"server"];
	

}

- (void)setServer:(GEZServer *)newServer
{
	[self setGrid:[newServer defaultGrid]];
}


//jobInfo is a transient ivar, saved as jobInfoData in the Core Data layer
- (id)jobInfo
{
	NSData *jobInfoData;
	NSValueTransformer *transformer;
	[self willAccessValueForKey:@"jobInfo"];
	if ( jobInfo == nil) {
		jobInfoData = [self valueForKey:@"jobInfoData"];
		transformer = [NSValueTransformer valueTransformerForName:NSUnarchiveFromDataTransformerName];
		jobInfo = [transformer transformedValue:jobInfoData];
		if ( jobInfo == nil )
			jobInfo = [NSData data];
	}
	[self didAccessValueForKey:@"jobInfo"];
	return jobInfo;
}

//jobInfo is a transient ivar, saved as jobInfoData in the Core Data layer
- (void)setJobInfo:(id)newJobInfo
{
	NSData *jobInfoData;
	NSValueTransformer *transformer;
	
	//change the ivar jobInfo
	if ( jobInfo == newJobInfo )
		return;
	[self willChangeValueForKey:@"jobInfo"];
	[newJobInfo retain];
	[jobInfo release];
	jobInfo = newJobInfo;
	[self didChangeValueForKey:@"jobInfo"];
	
	//update the value of jobInfoData
	transformer = [NSValueTransformer valueTransformerForName:NSUnarchiveFromDataTransformerName];
	jobInfoData = [transformer reverseTransformedValue:jobInfo];
	[self setValue:jobInfoData forKey:@"jobInfoData"];
}

- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)newDelegate
{
	delegate = newDelegate;
}

- (BOOL)shouldRetrieveResultsAutomatically
{
	BOOL result;
	[self willAccessValueForKey:@"shouldRetrieveResultsAutomatically"];
	result = [[self primitiveValueForKey:@"shouldRetrieveResultsAutomatically"] boolValue];
	[self didAccessValueForKey:@"shouldRetrieveResultsAutomatically"];
	return result;
}

- (void)setShouldRetrieveResultsAutomatically:(BOOL)flag
{
	[self willChangeValueForKey:@"shouldRetrieveResultsAutomatically"];
	[self setPrimitiveValue:[NSNumber numberWithBool:flag] forKey:@"shouldRetrieveResultsAutomatically"];
	[self didChangeValueForKey:@"shouldRetrieveResultsAutomatically"];
}


- (NSString *)name
{
	NSString *name;
	[self willAccessValueForKey:@"name"];
	name = [self primitiveValueForKey:@"name"];
	[self didAccessValueForKey:@"name"];
	return name;
}

//"status" is an 'abstract' ivar, which is made KVO compliant by triggering it after any change in the state properties (see the +initialize method)
- (NSString *)status
{
	return StatusStrings[[self state]];
}

- (unsigned int)taskCount
{
	[self willAccessValueForKey:@"taskCount"];
	int taskCount = [[self primitiveValueForKey:@"taskCount"] intValue];
	[self didAccessValueForKey:@"taskCount"];
	return taskCount;
}

- (unsigned int)completedTaskCount
{
	[self willAccessValueForKey:@"completedTaskCount"];
	int taskCount = [[self primitiveValueForKey:@"completedTaskCount"] intValue];
	[self didAccessValueForKey:@"completedTaskCount"];
	return taskCount;
}

- (NSDictionary *)allFiles
{
	[self willAccessValueForKey:@"allFiles"];
	NSDictionary *allFilesLocal = [self primitiveValueForKey:@"allFiles"];
	[self didAccessValueForKey:@"allFiles"];
	allFilesLocal = nil;
	return [results allFiles];
}



//checking the state of a job
//note that you can also check directly the status of the underlying XGJob and get a XGResourceState value
//none of these methods are KVO compliant (for now)
- (XGResourceState)xgridJobState
{
	return [xgridJob state];
}

- (BOOL)isSubmitting
{
	return [self state] == GEZJobStateSubmitting;
}

- (BOOL)isSubmitted
{
	GEZJobState state = [self state];
	return ( state != GEZJobStateUninitialized ) && ( state != GEZJobStateSubmitting ) && ( state != GEZJobStateInvalid ) && ( state != GEZJobStateDeleted );
}

- (BOOL)isRetrievingResults
{
	return [self state] == GEZJobStateRetrieving;
}

- (BOOL)isRetrieved
{
	return [self state] == GEZJobStateRetrieved;
}

- (BOOL)isDeleting
{
	return [self state] == GEZJobStateDeleting;
}

- (BOOL)isDeleted
{
	return [self state] == GEZJobStateDeleted;
}


#pragma mark *** Public actions ***

- (void)submitWithJobSpecification:(NSDictionary *)spec
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//update state
	if ( [self state] != GEZJobStateUninitialized )
		return;
	[self setState:GEZJobStateSubmitting];
	jobSpecification = [spec retain];

	//get the name of the job from the specification
	NSString *name = [jobSpecification objectForKey:XGJobSpecificationNameKey];
	if ( name == nil )
		name = @"Unnamed Job";
	[self setValue:name forKey:@"name"];
	
	//now, start the submission process
	[self submitSoon];
	
}

- (void)delete
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	if ( deletionAction != nil )
		return;
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"shouldDelete"];
	
	//not ready for deletion?
	GEZJobState state = [self state];
	if ( state == GEZJobStateSubmitted )
		return;
	
	//no need to delete from the grid?
	if ( state == GEZJobStateUninitialized || state == GEZJobStateSubmitting || state == GEZJobStateInvalid || [self grid] == nil || [[self identifier] intValue] < 1 ) {
		[self deleteFromStoreSoon];
		return;
	}

	//we can only delete stuff on a grid that is loaded, about which we have all the information
	if ( [[self grid] isLoaded] == NO )
		return;	

	//is the XGJob even defined or existing on the grid?
	if ( xgridJob == nil )
		return;
	if ( [[[self grid] xgridGrid] jobForIdentifier:[self identifier]] == nil ) {
		[self deleteFromStoreSoon];
		return;
	}
	
	//if we get here, it means the xgrid job exists on the grid and is ready to be deleted by sending a delete action, that we should then observe to know when it is done
	[self setDeletionAction:[xgridJob performDeleteAction]];
}

- (void)deleteFromStore
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//clean state
	[self setState:GEZJobStateDeleted];
	[xgridJob release];
	xgridJob = nil;
	[self setGrid:nil];
	[self setValue:@"-1" forKey:@"identifier"];
	
	[[self managedObjectContext] deleteObject:self];
}

- (void)retrieveResults
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	if ( results != nil || xgridJob == nil )
		return;
	
	[self setState:GEZJobStateRetrieving];
	results = [[GEZResults alloc] initWithXgridJob:xgridJob];
	[results setDelegate:self];
	[results retrieve];
}

@end


@implementation GEZJob (GEZJobPrivate)

#pragma mark *** Hooking ***

- (void)awakeFromFetch
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[super awakeFromFetch];
	
	// Get invalid jobs out of the way
	GEZJobState state = [self state];
	if ( /* state == GEZJobStateUninitialized || */ state == GEZJobStateSubmitting || state == GEZJobStateSubmitted || state == GEZJobStateInvalid || [[self identifier] intValue] < 1 || [self grid] == nil ) {
		[self setState:GEZJobStateInvalid];
		[self deleteFromStoreSoon];
		return;
	}

	// Initializations only for valid jobs
	countDeletionAttempts = 0;
	[self hookSoon];
}

- (void)hook:(NSTimer *)aTimer
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	// Only hook a job if it makes sense
	GEZJobState state = [self state];
	GEZGrid *grid = [self grid];
	NSString *identifier = [self identifier];
	if ( /*state == GEZJobStateUninitialized || */ state == GEZJobStateSubmitting || state == GEZJobStateSubmitted || state == GEZJobStateInvalid || [identifier intValue] < 0 || grid == nil ) {
		//[self setState:GEZJobStateInvalid];
		//[self deleteFromStoreSoon];
		return;
	}
	
	// Maybe we have to wait for the grid to be synced, so that the array of XGJob is loaded
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridDidSync:) name:GEZGridDidSyncNotification object:grid];
	if ( [grid isSynced] == NO )
		return;

	// Hook GEZJob to its XGJob
	// When the XGGrid is "synced", it has all the jobs in an array, but only their identifier is set, which means -jobWithIdentifier will work if the identifier is valid, but will return a job that is not yet "loaded" from the grid, with all other ivars set to 0 or nil (except the state = 4 = Available ?!?)
	// See GEZGridHook implementation of 'xgridGridDidSyncIvars" for the log that showed me that this is true
	[self setXgridJob:[[grid xgridGrid] jobForIdentifier:identifier]];
	if ( xgridJob == nil ) {
		//no job with the identifier
		[self deleteFromStoreSoon];
		return;
	}
	
	//maybe the XGJob is already loaded, which would be true if its name is not nil
	//then we have to do whatever is needed once loaded (but it is best to wait for the next iteration of the run loop)
	if ( [xgridJob name] != nil ) {
		[self setValue:[xgridJob name] forKey:@"name"];
		[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(xgridJobDidLoad:) userInfo:nil repeats:NO];
	}
}

- (void)hookSoon
{
	[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(hook:) userInfo:nil repeats:NO];
}


- (void)xgridJobDidLoad:(NSTimer *)timer
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//get notification of state and completedTaskCount changes to keep things in sync
	[self stateDidChange];
	[self completedTaskCountDidChange];
	[self taskCountDidChange];

	//now is time to delete if marked for deletion
	if ( [self shouldDelete] ) {
		[self deleteSoon];
		return;
	}
	
}

- (void)gridDidSync:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self hookSoon];
}

//update the state of GEZJob to be in sync with XGJob as much as possible
- (void)stateDidChange
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//maybe time to delete
	if ( [self shouldDelete] ) {
		[self deleteSoon];
		return;
	}
	
	//update state
	if ( xgridJob == nil )
		return;
	XGResourceState currentXgridState = [xgridJob state];
	if ( currentXgridState == XGResourceStatePending )
		[self setState:GEZJobStatePending];
	else if ( currentXgridState == XGResourceStateRunning ) {
		GEZJobState previousState = [self state];
		if ( previousState != GEZJobStateRunning ) {
			[self setState:GEZJobStateRunning];
			if ( [delegate respondsToSelector:@selector(jobDidStart:)] )
				[delegate jobDidStart:self];
		} 
	}
	else if ( currentXgridState == XGResourceStateSuspended )
		[self setState:GEZJobStateSuspended];
	else if ( currentXgridState == XGResourceStateFinished )
		[self didFinish];
	else if ( currentXgridState == XGResourceStateFailed )
		[self didFail];
	
}

// keep completedTaskCount in sync
- (void)completedTaskCountDidChange
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	if ( xgridJob != nil ) {
		int newCount = [xgridJob completedTaskCount];
		[self setValue:[NSNumber numberWithInt:newCount] forKey:@"completedTaskCount"];
		if ( [delegate respondsToSelector:@selector(jobDidProgress:completedTaskCount:)] )
			[delegate jobDidProgress:self completedTaskCount:newCount];
	}
}

// keep taskCount in sync
- (void)taskCountDidChange
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	if ( xgridJob == nil ) 
		return;

	//make sure the number really changed
	int oldCount = [self taskCount];
	int newCount = [xgridJob taskCount];
	if ( oldCount == newCount )
		return;
	[self setValue:[NSNumber numberWithInt:newCount] forKey:@"taskCount"];
	
	//create GEZTask for the job
	int i;
	for ( i = 0 ; i < newCount ; i++ ) {
		GEZTask *newTask = [NSEntityDescription insertNewObjectForEntityForName:GEZTaskEntityName inManagedObjectContext:[self managedObjectContext]];
		[newTask setValue:[NSString stringWithFormat:@"%d",i] forKey:@"name"];
		[newTask setValue:self forKey:@"job"];
	}
}



#pragma mark *** KVO callback ***

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@\nObject = <%@:%p>\nKey Path = %@\nChange = %@",[self class],self,_cmd, [self shortDescription], [object class], object, keyPath, [change description]);
	
	if ( object == xgridJob ) {
		DLog(NSStringFromClass([self class]),10,@"Object = XGJob");
		if ( [keyPath isEqualToString:@"name"] ) {
			//we only observe the name to know when XGJob is loaded
			// at the next iteration of the run loop, all XGJob ivars will be set and XGJob will then be "loaded"
			[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(xgridJobDidLoad:) userInfo:nil repeats:NO];
		}
		else if ( [keyPath isEqualToString:@"state"] )
			[self stateDidChange];
		else if ( [keyPath isEqualToString:@"completedTaskCount"] )
			[self completedTaskCountDidChange];
		else if ( [keyPath isEqualToString:@"taskCount"] )
			[self taskCountDidChange];
	}
	
	else if ( object == submissionAction ) {
		DLog(NSStringFromClass([self class]),10,@"Object = Submission Monitor");
		XGActionMonitorOutcome outcome = [submissionAction outcome];
		if ( outcome == XGActionMonitorOutcomeSuccess) {
			NSString *identifier = [[submissionAction results] objectForKey:@"jobIdentifier"];
			[self setValue:identifier forKey:@"identifier"];
			[self setState:GEZJobStatePending];
			if ( [delegate respondsToSelector:@selector(jobDidSubmit:)] )
				[delegate jobDidSubmit:self];
			[self hookSoon];
		} else {
			if ( [delegate respondsToSelector:@selector(jobDidNotSubmit:)] )
				[delegate jobDidNotSubmit:self];
			[self setState:GEZJobStateInvalid];
		}
		[self setSubmissionAction:nil];
	}	
	else if ( object == deletionAction ) {
		DLog(NSStringFromClass([self class]),10,@"Object = Deletion Monitor");
		XGActionMonitorOutcome outcome = [deletionAction outcome];
		[self setDeletionAction:nil];
		if ( outcome == XGActionMonitorOutcomeSuccess) {
			if ( [delegate respondsToSelector:@selector(jobWasDeleted:fromGrid:)] )
				[delegate jobWasDeleted:self fromGrid:[self grid]];
			[self deleteFromStoreSoon];
		} else {
			countDeletionAttempts ++;
			if ( countDeletionAttempts < MAX_COUNT_DELETION_ATTEMPTS )
				[self deleteSoon];
		}
	}
}


#pragma mark *** Deletion ***

- (void)deleteSoon
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(deleteWithTimer:) userInfo:nil repeats:NO];
}

- (void)deleteWithTimer:(NSTimer *)timer
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self delete];
}

- (void)deleteFromStoreSoon
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(deleteFromStoreWithTimer:) userInfo:nil repeats:NO];
}

- (void)deleteFromStoreWithTimer:(NSTimer *)timer
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self deleteFromStore];
}


#pragma mark *** Submission ***

- (void)submitSoon
{
	[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(submit:) userInfo:nil repeats:NO];
}

- (void)submit:(NSTimer *)aTimer
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//get the grid for submission, either already set by the user or an arbitrary connected grid obtained from the GEZManager
	GEZGrid *grid = [self grid];
	if ( grid == nil ) {
		grid = [[GEZServer connectedServer] defaultGrid];
		 if ( grid != nil )
		   [self setGrid:grid];
		else {
			//any server that connects in the future will do
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidSync:) name:GEZServerHookDidSyncNotification object:nil];
			return;
		}
	}

	//make sure the grid can be accessed: the GEZServerHook has to be "Synced", so the XGGrid object can be obtained
	GEZServerHook *serverHook = [GEZServerHook serverHookWithAddress:[[grid server] address]];
	if ( ![serverHook isSynced] ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidSync:) name:GEZServerHookDidSyncNotification object:serverHook];
		return;
	}
	
	//start submission process, which will be completed when the actionMonitor changes its state
	[submissionAction release];
	GEZServer *server = [grid server];
	[self setSubmissionAction:[[server xgridController] performSubmitJobActionWithJobSpecification:jobSpecification gridIdentifier:[grid identifier]]];
	[jobSpecification autorelease];
	jobSpecification = nil;
	
	//if the server disconnects before the submission process is done, we need to invalidate the job
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverHookDidDisconnect:) name:GEZServerHookDidDisconnectNotification object:serverHook];
}

- (void)serverHookDidSync:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	if ( [self state] == GEZJobStateSubmitting )
		[self submitSoon];
	else
		[[NSNotificationCenter defaultCenter] removeObserver:self name:GEZServerHookDidSyncNotification object:nil];
}


- (void)serverHookDidDisconnect:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	if ( ( [self state] == GEZJobStateSubmitting || [self state] == GEZJobStateSubmitted ) ) {
		[self setState:GEZJobStateInvalid];
		[jobSpecification release];
		jobSpecification = nil;
	}
	else
		[[NSNotificationCenter defaultCenter] removeObserver:self name:GEZServerHookDidDisconnectNotification object:nil];
}


#pragma mark *** Result retrieval ***

- (void)retrieveResultsSoon
{
	[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(retrieveResultsWithTimer:) userInfo:nil repeats:NO];
}

- (void)retrieveResultsWithTimer:(NSTimer *)aTimer
{
	[self retrieveResults];
}


- (void)didFinish;
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	if ( [delegate respondsToSelector:@selector(jobDidFinish:)] )
		[delegate jobDidFinish:self];
	if ( [self shouldDelete] || ( xgridJob == nil ) )
		return;
	
	//we should only mark the job as finished and retrieve the results if not already retrieved
	//we probably don't have to care too much about jobs being deleted
	if ( [self state] != GEZJobStateRetrieved ) {
		[self setState:GEZJobStateFinished];
		if ( [self shouldRetrieveResultsAutomatically] )
			[self retrieveResultsSoon];
	}
}

- (void)didFail;
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	if ( [delegate respondsToSelector:@selector(jobDidFail:)] )
		[delegate jobDidFail:self];
	if ( [self shouldDelete] || ( xgridJob == nil ) )
		return;
	[self setState:GEZJobStateFailed];
}

//delegate method for GEZResults
- (void)didRetrieveResults:(GEZResults *)theResults
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//this is the result dictionary
	NSDictionary *allFiles = [theResults allFiles];
	
	//it is time to fill the GEZTask with the results
	NSEnumerator *e = [[self valueForKey:@"tasks"] objectEnumerator];
	GEZTask *oneTask;
	while ( oneTask = [e nextObject] ) {
		
		//to keep track of the file hierarchy, we will use a dictionary that will store one file entity per path, where path is used as a key to ensure uniqueness of each created file entity
		NSDictionary *filePaths = [allFiles objectForKey:[oneTask name]];
		NSMutableDictionary *fileEntities = [NSMutableDictionary dictionaryWithCapacity:[filePaths count]];
		
		//create all the file entities, adding parent directories as necessary
		//note that files and dirs use the same entity, but dirs have no contents (==nil)
		NSEnumerator *ee = [filePaths keyEnumerator];
		NSString *path;
		while ( path = [ee nextObject] ) {
			NSManagedObject *newFile = [fileEntities objectForKey:path];
			if ( newFile == nil ) {
				newFile = [NSEntityDescription insertNewObjectForEntityForName:GEZFileEntityName inManagedObjectContext:[self managedObjectContext]];
				[fileEntities setObject:newFile forKey:path];
				[newFile setValue:path forKey:@"path"];
				[newFile setValue:[path lastPathComponent] forKey:@"name"];
				[newFile setValue:[filePaths objectForKey:path] forKey:@"contents"];
				[newFile setValue:oneTask forKey:@"task"];
				[newFile setValue:[NSNumber numberWithBool:NO] forKey:@"isDirectory"];
				NSString *parentPath = [path stringByDeletingLastPathComponent];
				while ( ![parentPath isEqualToString:@""] ) {
					NSManagedObject *parentFile = [fileEntities objectForKey:parentPath];
					if ( parentFile == nil ) {
						parentFile = [NSEntityDescription insertNewObjectForEntityForName:GEZFileEntityName inManagedObjectContext:[self managedObjectContext]];
						[fileEntities setObject:parentFile forKey:parentPath];
						[parentFile setValue:parentPath forKey:@"path"];
						[parentFile setValue:[parentPath lastPathComponent] forKey:@"name"];
						[parentFile setValue:oneTask forKey:@"task"];
						[parentFile setValue:[NSNumber numberWithBool:YES] forKey:@"isDirectory"];
					}
					[newFile setValue:parentFile forKey:@"parent"];
					//go up in the hierarchy and repeat
					parentPath = [parentPath stringByDeletingLastPathComponent];
					newFile = parentFile;
				}
			}
		}
	}

	/*
	//we don't need the GEZResults object anymore
	[results setDelegate:nil];
	[results release];
	results = nil;
	*/
	
	//it is now official: the job has been retrieved
	[self setState:GEZJobStateRetrieved];
	if ( [delegate respondsToSelector:@selector(jobDidRetrieveResults:)] )
		[delegate jobDidRetrieveResults:self];
	
}


#pragma mark *** Private accessors ***

- (void)setXgridJob:(XGJob *)newJob
{
	if ( newJob != xgridJob ) {

		//get rid of the old guy
		[xgridJob removeObserver:self forKeyPath:@"name"];
		[xgridJob removeObserver:self forKeyPath:@"state"];
		[xgridJob removeObserver:self forKeyPath:@"taskCount"];
		[xgridJob removeObserver:self forKeyPath:@"completedTaskCount"];
		[xgridJob release];
		
		//get the new guy ready
		xgridJob = [newJob retain];
		[xgridJob addObserver:self forKeyPath:@"name" options:0 context:NULL];
		[xgridJob addObserver:self forKeyPath:@"state" options:0 context:NULL];
		[xgridJob addObserver:self forKeyPath:@"taskCount" options:0 context:NULL];
		[xgridJob addObserver:self forKeyPath:@"completedTaskCount" options:0 context:NULL];
		
		DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] (job '%@') : created XGJob %@ ",[self class],self,_cmd,[self name],xgridJob);
		
	}
}

- (void)setSubmissionAction:(XGActionMonitor *)newAction
{
	if ( newAction != submissionAction ) {
		[submissionAction removeObserver:self forKeyPath:@"outcome"];
		[submissionAction release];
		submissionAction = [newAction retain];
		[submissionAction addObserver:self forKeyPath:@"outcome" options:0 context:NULL];
	}
}

- (void)setDeletionAction:(XGActionMonitor *)newAction
{
	if ( newAction != deletionAction ) {
		[deletionAction removeObserver:self forKeyPath:@"outcome"];
		[deletionAction release];
		deletionAction = [newAction retain];
		[deletionAction addObserver:self forKeyPath:@"outcome" options:0 context:NULL];
	}
}

- (GEZJobState)state
{
	GEZJobState result;
	[self willAccessValueForKey:@"state"];
	result = [[self primitiveValueForKey:@"state"] intValue];
	[self didAccessValueForKey:@"state"];
	return result;
}

- (void)setState:(GEZJobState)newState
{
	[self willChangeValueForKey:@"state"];
	[self setPrimitiveValue:[NSNumber numberWithInt:newState] forKey:@"state"];
	[self didChangeValueForKey:@"state"];
}

- (NSString *)identifier
{
	NSString *identifierLocal;
	[self willAccessValueForKey:@"identifier"];
	identifierLocal = [self primitiveValueForKey:@"identifier"];
	[self didAccessValueForKey:@"identifier"];
	return identifierLocal;
}

- (void)setJobID:(NSString *)identifierNew
{
	[self willChangeValueForKey:@"identifier"];
	[self setPrimitiveValue:identifierNew forKey:@"identifier"];
	[self didChangeValueForKey:@"identifier"];
}

- (BOOL)shouldDelete
{
	BOOL result;
	[self willAccessValueForKey:@"shouldDelete"];
	result = [[self primitiveValueForKey:@"shouldDelete"] boolValue];
	[self didAccessValueForKey:@"shouldDelete"];
	return result;
}

- (BOOL)shouldRetrieveResultsAutomatically
{
	BOOL result;
	[self willAccessValueForKey:@"shouldRetrieveResultsAutomatically"];
	result = [[self primitiveValueForKey:@"shouldRetrieveResultsAutomatically"] boolValue];
	[self didAccessValueForKey:@"shouldRetrieveResultsAutomatically"];
	return result;
}

- (BOOL)shouldDeleteAutomatically
{
	BOOL result;
	[self willAccessValueForKey:@"shouldDeleteAutomatically"];
	result = [[self primitiveValueForKey:@"shouldDeleteAutomatically"] boolValue];
	[self didAccessValueForKey:@"shouldDeleteAutomatically"];
	return result;
}

@end