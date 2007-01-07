//
//  GEZMetaJob.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */

#import "GEZMetaJob.h"
#import "GEZGrid.h"
#import "GEZServer.h"
#import "GEZJob.h"
#import "GEZIntegerArray.h";
#import "GEZProxy.h";
#import "GEZDefines.h"
#import "GEZManager.h"

//default values based on personal experience of what the optimal values could be in many situations (see submitNextJob)
#define DEFAULT_TASKS_PER_JOB_VALUE 10
#define DEFAULT_JOBS_PER_GRID_VALUE 10

@class GEZTaskSource;
@class GEZOutputInterface;

NSString *GEZTaskSubmissionCommandKey = @"GEZTaskSubmissionCommandKey";
NSString *GEZTaskSubmissionArgumentsKey = @"GEZTaskSubmissionArgumentsKey";
NSString *GEZTaskSubmissionStandardInputKey = @"GEZTaskSubmissionStandardInputKey";
NSString *GEZTaskSubmissionUploadedPathsKey = @"GEZTaskSubmissionUploadedPathsKey";


@interface GEZMetaJob (GEZMetaJobPrivate)
- (void)resetAvailableTasks;
- (void)removeJob:(GEZJob *)aJob;
- (BOOL)submitNextJob;
- (void)submitNextJobSoon;
- (void)submitNextJobSoonIfRunning;
- (GEZIntegerArray *)failureCounts;
- (GEZIntegerArray *)submissionCounts;
- (GEZIntegerArray *)successCounts;
- (void)setFailureCounts:(GEZIntegerArray *)failureCountsNew;
- (void)setSubmissionCounts:(GEZIntegerArray *)submissionCountsNew;
- (void)setSuccessCounts:(GEZIntegerArray *)successCountsNew;
- (NSString *)shortDescription;
@end



@implementation GEZMetaJob

#pragma mark *** Initializations ***

+ (void)initialize
{
	NSArray *keys;
	if ( self == [GEZMetaJob class] ) {
		keys=[NSArray arrayWithObjects:@"countCompletedTasks",@"countDismissedTasks",nil];
		[self setKeys:keys triggerChangeNotificationsForDependentKey:@"countDone"];
		[self setKeys:keys triggerChangeNotificationsForDependentKey:@"percentDone"];
		[self setKeys:keys triggerChangeNotificationsForDependentKey:@"countPendingTasks"];
		[self setKeys:keys triggerChangeNotificationsForDependentKey:@"percentPending"];
		keys=[NSArray arrayWithObjects:@"countDismissedTasks",nil];
		[self setKeys:keys triggerChangeNotificationsForDependentKey:@"percentDismissed"];
		keys=[NSArray arrayWithObjects:@"countCompletedTasks",nil];
		[self setKeys:keys triggerChangeNotificationsForDependentKey:@"percentCompleted"];
		keys=[NSArray arrayWithObjects:@"countSubmittedTasks",nil];
		[self setKeys:keys triggerChangeNotificationsForDependentKey:@"percentSubmitted"];
	}
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	availableTasks = [[NSMutableIndexSet alloc] init];
	if ( [self isRunning] ) {
		[self suspend];
		[self start];
	}
	//[self resetavailableTasks];
}

- (void)dealloc
{
	[submissionTimer invalidate];
	submissionTimer = nil;
	[availableTasks release];
	[super dealloc];
}

+ (GEZMetaJob *)metaJobWithName:(NSString *)name
{
	GEZMetaJob *newMetaJob = [self metaJobWithManagedObjectContext:[GEZManager managedObjectContext]];
	[newMetaJob setName:name];
	return newMetaJob;
}

+ (GEZMetaJob *)metaJobWithManagedObjectContext:(NSManagedObjectContext *)context
{
	//the integer arrays are used to count submissions, successes and failures of all the individual tasks
	GEZIntegerArray *submissions = [NSEntityDescription insertNewObjectForEntityForName:@"GEZIntegerArray" inManagedObjectContext:context];
	GEZIntegerArray *successes = [NSEntityDescription insertNewObjectForEntityForName:@"GEZIntegerArray" inManagedObjectContext:context];
	GEZIntegerArray *failures = [NSEntityDescription insertNewObjectForEntityForName:@"GEZIntegerArray" inManagedObjectContext:context];

	//create and setup the metaJob
	GEZMetaJob *newMetaJob = [NSEntityDescription insertNewObjectForEntityForName:GEZMetaJobEntityName inManagedObjectContext:context];	
	[newMetaJob setValue:submissions forKey:@"submissionCounts"];
	[newMetaJob setValue:successes forKey:@"successCounts"];
	[newMetaJob setValue:failures forKey:@"failureCounts"];
	
	return newMetaJob;
}

#ifdef DEBUG
- (void)willSave
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
}
#endif

#pragma mark *** accessors for grids/servers ***

- (NSSet *)grids
{
	[self willAccessValueForKey:@"grids"];
	NSSet *value = [self primitiveValueForKey:@"grids"];
	[self didAccessValueForKey:@"grids"];
	return value;
}

- (void)setGrids:(NSSet *)aValue
{
	[self willChangeValueForKey:@"grids"];
	[self setPrimitiveValue:aValue forKey:@"grids"];
	[self didChangeValueForKey:@"grids"];
	[self submitNextJobSoonIfRunning];
}

- (NSSet *)servers
{
	[self willAccessValueForKey:@"servers"];
	NSSet *value = [self primitiveValueForKey:@"servers"];
	[self didAccessValueForKey:@"servers"];
	return value;
}

- (void)setServers:(NSSet *)aValue
{
	[self willChangeValueForKey:@"servers"];
	[self setPrimitiveValue:aValue forKey:@"servers"];
	[self didChangeValueForKey:@"servers"];
	[self submitNextJobSoonIfRunning];
}


- (void)addGridsObject:(GEZGrid *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"grids" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"grids"] addObject: value];
    
    [self didChangeValueForKey:@"grids" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];

	[self submitNextJobSoonIfRunning];
}

- (void)removeGridsObject:(GEZGrid *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"grids" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"grids"] removeObject: value];
    
    [self didChangeValueForKey:@"grids" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}


- (void)addServersObject:(GEZServer *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"servers" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"servers"] addObject: value];
    
    [self didChangeValueForKey:@"servers" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];

	[self submitNextJobSoonIfRunning];
}

- (void)removeServersObject:(GEZServer *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"servers" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [[self primitiveValueForKey: @"servers"] removeObject: value];
    
    [self didChangeValueForKey:@"servers" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

//convenience private (make it public?) method to retrieve all grids from grids and servers lists
- (NSSet *)allGrids
{
	NSMutableSet *allGrids = [NSMutableSet setWithSet:[self grids]];
	[allGrids unionSet:[self valueForKeyPath:@"servers.grids"]];
	return [NSSet setWithSet:allGrids];
}


#pragma mark *** accessors ***

//Note on dataSource and delegate: I have to use a different name for the accessor and the relationship key in the core data model. The object in the core data model is a GEZProxy, and the object returned by the accessor is of a different class. If I use 'dataSource' as the name in the data model, when saving, Core Data does some validation and checks that the object returned by dataSource is of the right type, and for this it used the accessor method, and thus the validation fails. Same thing for delegate. Things are even worse when the object is not even an NSManagedObject. Instead of overriding validation method, I decided to use a different name 'dataSourceProxy' in the model. Less code, probably cleaner, and somewhat more logical.

- (id)dataSource
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
    [self willAccessValueForKey:@"dataSource"];
    id dataSource = [[self primitiveValueForKey:@"dataSourceProxy"] referencedObject];
    [self didAccessValueForKey:@"dataSource"];
    return dataSource;
}

- (void)setDataSource:(id)newDataSource
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	
	/* TODO */

	/*
	//is the data source even responding to the appropriate messages?
	if ( newDataSource!=nil ) {
		if ( ![newDataSource respondsToSelector:@selector(numberOfTasksForMetaJob:)] )
			[NSException raise:@"GEZMetaJobError" format:@"Data Source of GEZMetaJob must responds to selector numberOfTasksForMetaJob:"];
		if ( ![newDataSource respondsToSelector:@selector(metaJob:taskAtIndex:)] )
			[NSException raise:@"GEZMetaJobError" format:@"Data Source of GEZMetaJob must responds to selector metaJob:taskAtIndex:"];
	}
	 */
	
	//OK, we can use that object
	[self willChangeValueForKey:@"dataSource"];
	[self setPrimitiveValue:[GEZProxy proxyWithReferencedObject:newDataSource] forKey:@"dataSourceProxy"];
	[self didChangeValueForKey:@"dataSource"];
	
	//the value of countTotalTasks is potentially changed too
	unsigned int n=[newDataSource numberOfTasksForMetaJob:self];
	[self setValue:[NSNumber numberWithInt:n] forKey:@"countTotalTasks"];
}

- (id)delegate
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
    [self willAccessValueForKey:@"delegate"];
    id delegate = [[self primitiveValueForKey:@"delegateProxy"] referencedObject];
    [self didAccessValueForKey:@"delegate"];
    return delegate;
}

//do not retain to avoid retain cycles
- (void)setDelegate:(id)newDelegate
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	[self willChangeValueForKey:@"delegate"];
	[self setPrimitiveValue:[GEZProxy proxyWithReferencedObject:newDelegate] forKey:@"delegateProxy"];
	[self didChangeValueForKey:@"delegate"];
}

- (NSString *)name
{
	NSString *nameLocal;
	[self willAccessValueForKey:@"name"];
	nameLocal = [self primitiveValueForKey:@"name"];
	[self didAccessValueForKey:@"name"];
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return nameLocal;
}

- (void)setName:(NSString *)nameNew
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	[self willChangeValueForKey:@"name"];
	[self setPrimitiveValue:nameNew forKey:@"name"];
	[self didChangeValueForKey:@"name"];
}

- (NSString *)status
{
	[self willAccessValueForKey:@"status"];
	NSString * value = [self primitiveValueForKey:@"status"];
	[self didAccessValueForKey:@"status"];
	return value;
}

- (void)setStatus:(NSString *)aValue
{
	[self willChangeValueForKey:@"status"];
	[self setPrimitiveValue:aValue forKey:@"status"];
	[self didChangeValueForKey:@"status"];
}

- (int)minSuccessesPerTask
{
	[self willAccessValueForKey:@"minSuccessesPerTask"];
	int value = [[self primitiveValueForKey:@"minSuccessesPerTask"] intValue];
	[self didAccessValueForKey:@"minSuccessesPerTask"];
	return value;
}

- (void)setMinSuccessesPerTask:(int)aValue
{
	[self willChangeValueForKey:@"minSuccessesPerTask"];
	[self setPrimitiveValue:[NSNumber numberWithInt:aValue] forKey:@"minSuccessesPerTask"];
	[self didChangeValueForKey:@"minSuccessesPerTask"];
	
	//this change may mean that tasks considered completed or dismissed may change status and may now need more work
	[self resetAvailableTasks];
	[self submitNextJobSoonIfRunning];
}

- (int)maxFailuresPerTask
{
	[self willAccessValueForKey:@"maxFailuresPerTask"];
	int value = [[self primitiveValueForKey:@"maxFailuresPerTask"] intValue];
	[self didAccessValueForKey:@"maxFailuresPerTask"];
	return value;
}

- (void)setMaxFailuresPerTask:(int)aValue
{
	[self willChangeValueForKey:@"maxFailuresPerTask"];
	[self setPrimitiveValue:[NSNumber numberWithInt:aValue] forKey:@"maxFailuresPerTask"];
	[self didChangeValueForKey:@"maxFailuresPerTask"];

	//this change may mean that tasks considered completed or dismissed may change status and may now need more work
	[self resetAvailableTasks];
	[self submitNextJobSoonIfRunning];
}

- (int)maxSubmissionsPerTask
{
	[self willAccessValueForKey:@"maxSubmissionsPerTask"];
	int value = [[self primitiveValueForKey:@"maxSubmissionsPerTask"] intValue];
	[self didAccessValueForKey:@"maxSubmissionsPerTask"];
	return value;
}

- (void)setMaxSubmissionsPerTask:(int)aValue
{
	[self willChangeValueForKey:@"maxSubmissionsPerTask"];
	[self setPrimitiveValue:[NSNumber numberWithInt:aValue] forKey:@"maxSubmissionsPerTask"];
	[self didChangeValueForKey:@"maxSubmissionsPerTask"];
	[self submitNextJobSoonIfRunning];
}

- (int)tasksPerJob
{
	[self willAccessValueForKey:@"tasksPerJob"];
	int value = [[self primitiveValueForKey:@"tasksPerJob"] intValue];
	[self didAccessValueForKey:@"tasksPerJob"];
	return value;
}

- (void)setTasksPerJob:(int)aValue
{
	[self willChangeValueForKey:@"tasksPerJob"];
	[self setPrimitiveValue:[NSNumber numberWithInt:aValue] forKey:@"tasksPerJob"];
	[self didChangeValueForKey:@"tasksPerJob"];
	[self submitNextJobSoonIfRunning];
}

- (long)maxBytesPerJob
{
	[self willAccessValueForKey:@"maxBytesPerJob"];
	int value = [[self primitiveValueForKey:@"maxBytesPerJob"] longValue];
	[self didAccessValueForKey:@"maxBytesPerJob"];
	return value;
}

- (void)setMaxBytesPerJob:(long)aValue
{
	[self willChangeValueForKey:@"maxBytesPerJob"];
	[self setPrimitiveValue:[NSNumber numberWithLong:aValue] forKey:@"maxBytesPerJob"];
	[self didChangeValueForKey:@"maxBytesPerJob"];
}

- (int)maxSubmittedTasks
{
	[self willAccessValueForKey:@"maxSubmittedTasks"];
	int value = [[self primitiveValueForKey:@"maxSubmittedTasks"] intValue];
	[self didAccessValueForKey:@"maxSubmittedTasks"];
	return value;
}

- (void)setMaxSubmittedTasks:(int)aValue
{
	[self willChangeValueForKey:@"maxSubmittedTasks"];
	[self setPrimitiveValue:[NSNumber numberWithInt:aValue] forKey:@"maxSubmittedTasks"];
	[self didChangeValueForKey:@"maxSubmittedTasks"];
	[self submitNextJobSoonIfRunning];
}


NSNumber *IntNumberWithAdditionOfIntNumbers(NSNumber *number1,NSNumber *number2)
{
	int a1=[number1 intValue];
	int a2=[number2 intValue];
	return [NSNumber numberWithInt:a1+a2];
}

NSNumber *IntNumberWithSubstractionOfIntNumbers(NSNumber *number1,NSNumber *number2)
{
	int a1=[number1 intValue];
	int a2=[number2 intValue];
	return [NSNumber numberWithInt:a1-a2];
}

NSNumber *FloatNumberWithPercentRatioOfNumbers(NSNumber *number1,NSNumber *number2)
{
	float a1=[number1 floatValue];
	float a2=[number2 floatValue];
	return [NSNumber numberWithFloat:100.0*a1/a2];
}

- (NSNumber *)countTotalTasks
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s]",[self class],self,_cmd);
	NSNumber *countTotalTasksLocal;
	[self willAccessValueForKey:@"countTotalTasks"];
	countTotalTasksLocal = [self primitiveValueForKey:@"countTotalTasks"];
	[self didAccessValueForKey:@"countTotalTasks"];
	return countTotalTasksLocal;
}

- (NSNumber *)countDoneTasks
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return IntNumberWithAdditionOfIntNumbers([self valueForKey:@"countCompletedTasks"],
											 [self valueForKey:@"countDismissedTasks"]);
}

- (NSNumber *)countPendingTasks
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return IntNumberWithSubstractionOfIntNumbers([self countTotalTasks],
												 [self countDoneTasks]);
}

- (NSNumber *)percentDone
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return FloatNumberWithPercentRatioOfNumbers([self countDoneTasks],
												[self countTotalTasks]);
}

- (NSNumber *)percentPending
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return FloatNumberWithPercentRatioOfNumbers([self countPendingTasks],
												[self countTotalTasks]);
}

- (NSNumber *)percentCompleted
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return FloatNumberWithPercentRatioOfNumbers([self valueForKey:@"countCompletedTasks"],
												[self countTotalTasks]);
}

- (NSNumber *)percentDismissed
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return FloatNumberWithPercentRatioOfNumbers([self valueForKey:@"countDismissedTasks"],
												[self countTotalTasks]);
}

- (NSNumber *)percentSubmitted
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return FloatNumberWithPercentRatioOfNumbers([self valueForKey:@"countSubmittedTasks"],
												[self countTotalTasks]);
}

#pragma mark *** tracking tasks ***


- (void)incrementCountDismissedTasks
{
	int old = [[self valueForKey:@"countDismissedTasks"] intValue];
	[self setValue:[NSNumber numberWithInt:old+1] forKey:@"countDismissedTasks"];
}

- (void)decrementCountDismissedTasks
{
	int old = [[self valueForKey:@"countDismissedTasks"] intValue];
	[self setValue:[NSNumber numberWithInt:old-1] forKey:@"countDismissedTasks"];
}

- (void)incrementCountCompletedTasks
{
	int old = [[self valueForKey:@"countCompletedTasks"] intValue];
	[self setValue:[NSNumber numberWithInt:old+1] forKey:@"countCompletedTasks"];
}

- (void)decrementCountCompletedTasks
{
	int old = [[self valueForKey:@"countCompletedTasks"] intValue];
	[self setValue:[NSNumber numberWithInt:old-1] forKey:@"countCompletedTasks"];
}

- (int)countFailuresForTaskAtIndex:(int)index
{
	return [[self failureCounts] intValueAtIndex:index];
}

- (int)countSuccessesForTaskAtIndex:(int)index
{
	return [[self successCounts] intValueAtIndex:index];
}

- (int)countSubmissionsForTaskAtIndex:(int)index
{
	return [[self submissionCounts] intValueAtIndex:index];
}

- (NSString *)statusStringForTaskAtIndex:(int)index
{
	if ( [self countSuccessesForTaskAtIndex:index] >= [self minSuccessesPerTask] )
		return @"Completed";
	if ( [self countSubmissionsForTaskAtIndex:index] > 0 )
		return @"Submitted";
	
	int threshold = [self maxFailuresPerTask];
	if ( threshold > 0 &&  [self countFailuresForTaskAtIndex:index] >= threshold)
		return @"Dismissed";
	
	return @"Pending";
}


#pragma mark ***public methods for starting/stopping a metajob ***

- (void)start
{
	NSMutableSet *currentJobs;
	NSEnumerator *e;
	GEZJob *oneJob;
	
	DLog(NSStringFromClass([self class]),5,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	//if already running, we will still restart the metajob, which can be useful at least for debugging purpose, and which won't hurt in any case
	if ( [self isRunning] ) {
		if ( [availableTasks count] < 1 )
			[self resetAvailableTasks];
		[self submitNextJobSoon];
		return;
	}

	//update state
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"isRunning"];
	[self setStatus:@"Running"];
	if ([[self delegate] respondsToSelector:@selector(metaJobDidStart:)])
		[[self delegate] metaJobDidStart:self];

	//clean-up and reset current pending jobs
	currentJobs = [self mutableSetValueForKey:@"jobs"];
	e = [currentJobs objectEnumerator];
	while ( oneJob = [e nextObject] ) {
		[oneJob setDelegate:self];
		[oneJob setShouldRetrieveResultsAutomatically:YES];
	}
	
	//prepare for task submissions
	[self resetAvailableTasks];
	
	//start the "run loop"
	[self submitNextJobSoon];
}

- (void)suspend
{
	DLog(NSStringFromClass([self class]),5,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);

	[self setValue:[NSNumber numberWithBool:NO] forKey:@"isRunning"];
	[self setStatus:@"Suspended"];
	[submissionTimer invalidate];
	submissionTimer = nil;
	if ([[self delegate] respondsToSelector:@selector(metaJobDidSuspend:)])
		[[self delegate] metaJobDidSuspend:self];
}

- (BOOL)isRunning
{
	BOOL flag;
	
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	[self willAccessValueForKey:@"isRunning"];
	flag = [[self primitiveValueForKey:@"isRunning"] boolValue];
	[self didAccessValueForKey:@"isRunning"];
	return flag;
}


- (void)deleteFromStore
{
	NSEnumerator *e;
	NSArray *jobs;
	GEZJob *aJob;

	DLog(NSStringFromClass([self class]),5,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);

	//no more notifications
	[self setDelegate:nil];
	if ( [self isRunning] )
		[self suspend];
	
	//delete all the jobs
	jobs = [self valueForKey:@"jobs"];
	e = [jobs objectEnumerator];
	while ( aJob = [e nextObject] ) {
		[aJob setDelegate:nil];
		[aJob delete];
	}
	
	//now remove from the managed context
	[[self managedObjectContext] deleteObject:self];
	[[self managedObjectContext] processPendingChanges];
}


#pragma mark *** GEZJob delegate methods ***

//MetaJob is a delegate of multiple GEZJob
//these are the GEZJob delegate methods

/*
 - (void)jobDidSubmit:(GEZJob *)aJob;
 - (void)jobDidNotSubmit:(GEZJob *)aJob;
 - (void)jobDidStart:(GEZJob *)aJob;
 - (void)jobDidFinish:(GEZJob *)aJob;
 - (void)jobDidFail:(GEZJob *)aJob;
 - (void)jobWasDeleted:(GEZJob *)aJob fromGrid:(GEZGrid *)aGrid;
 - (void)jobWasNotDeleted:(GEZJob *)aJob;
 - (void)jobDidProgress:(GEZJob *)aJob completedTaskCount:(unsigned int)count;
 - (void)jobDidRetrieveResults:(GEZJob *)aJob;
 */ 

//it might be possible to submit more jobs as less "submitted" jobs will be present
- (void)jobDidSubmit:(GEZJob *)aJob
{
	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);

	//the delegate might want to know the tasks were submitted
	if ( [[self delegate] respondsToSelector:@selector(metaJob:didSubmitTaskAtIndex:)] ) {
		NSEnumerator *e = [[[aJob jobInfo] objectForKey:@"TaskMap"] objectEnumerator];
		NSString *metaTaskIndex;
		while ( metaTaskIndex = [e nextObject] )
			[[self delegate] metaJob:self didSubmitTaskAtIndex:[metaTaskIndex intValue]];
	}
	
	//ready to submit more	
	[self submitNextJobSoon];
}

/*
- (void)jobDidStart:(GEZJob *)aJob
{
	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);
}
*/

- (void)jobDidNotStart:(GEZJob *)aJob
{
	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);
	[self removeJob:aJob];
}

- (void)jobDidFail:(GEZJob *)aJob
{
	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);

	//the taskMap allows to convert taskID into metaTaskIndex
	NSDictionary *taskMap = [[aJob jobInfo] objectForKey:@"TaskMap"];
	if ( taskMap == nil )
		[NSException raise:@"GEZMetaJobError" format:@"No task map stored in the job"];
		
	//loop over the dictionary values to get all the metaTask indices
	NSEnumerator *e = [taskMap objectEnumerator];
	NSString *metaTaskIndex;
	while ( metaTaskIndex = [e nextObject] ) {
		
		//update the count of failures for the metaTask
		int index = [metaTaskIndex intValue];
		int numberOfFailures = [[self failureCounts] incrementIntValueAtIndex:index];
		
		//do we need to update the count of dismissed metaTasks?
		int maxFailuresPerTask = [self maxFailuresPerTask];
		if ( maxFailuresPerTask > 0 && numberOfFailures == maxFailuresPerTask ) {
			int numberOfSuccesses = [[self successCounts] intValueAtIndex:index];
			int minSuccessesPerTask = [self minSuccessesPerTask];
			if ( numberOfSuccesses < minSuccessesPerTask ) {
				[self incrementCountDismissedTasks];
			}
		}
	}		
	
	//we can now dump the job and might be ready for more!
	[self removeJob:aJob];
	[self submitNextJobSoon];
}

- (void)jobDidFinish:(GEZJob *)aJob
{
	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);
}

- (void)jobDidRetrieveResults:(GEZJob *)aJob;
{	
	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);
	DLog(NSStringFromClass([self class]),10,@"\nResults:\n%@",[[aJob allFiles] description]);

	//the taskMap allows to convert taskID in metaTaskIndex
	NSDictionary *taskMap = [[aJob jobInfo] objectForKey:@"TaskMap"];
	if ( taskMap == nil )
		[NSException raise:@"GEZMetaJobError" format:@"No task map stored in job %@", [aJob name]];

	//loop over the dictionary keys to return individual task results
	NSDictionary *results = [aJob allFiles];
	id dataSource = [self dataSource];
	NSEnumerator *e = [results keyEnumerator];
	NSString *taskIdentifier;
	while ( taskIdentifier = [e nextObject] ) {
		
		//based on the validation result, the task was either a success or a failure; then, depending on how many successes and failures, the metatask could be considered completed or be dismissed
		unsigned int metaTaskIndex = [[taskMap objectForKey:taskIdentifier] intValue];
		int minSuccessesPerTask = [self minSuccessesPerTask];
		int maxFailuresPerTask = [self maxFailuresPerTask];
		if ( [dataSource metaJob:self validateTaskAtIndex:metaTaskIndex results:[results objectForKey:taskIdentifier]] ) {
			int numberOfSuccesses = [[self successCounts] incrementIntValueAtIndex:metaTaskIndex];
			int numberOfFailures = [[self failureCounts] intValueAtIndex:metaTaskIndex];
			if ( numberOfSuccesses == minSuccessesPerTask ) {
				[self incrementCountCompletedTasks];
				if ( maxFailuresPerTask > 0 && numberOfFailures >= maxFailuresPerTask )
					[self decrementCountDismissedTasks];
			}
		} else {
			int numberOfSuccesses = [[self successCounts] intValueAtIndex:metaTaskIndex];
			int numberOfFailures = [[self failureCounts] incrementIntValueAtIndex:metaTaskIndex];
			if ( ( maxFailuresPerTask > 0 ) && ( numberOfFailures == maxFailuresPerTask ) && ( numberOfSuccesses < minSuccessesPerTask ) )
				[self incrementCountDismissedTasks];
		}
	}
	
	//we are done with the job - delete it...
	[self removeJob:aJob];
}

//if job was deleted by somebody outside of GEZMetaJob, we need to clean up
- (void)jobWasDeleted:(GEZJob *)aJob fromGrid:(GEZGrid *)aGrid
{
	if ( [[self valueForKey:@"jobs"] member:aJob] )
		[self removeJob:aJob];
}


@end


@implementation GEZMetaJob (GEZMetaJobPrivate)

#pragma mark *** utilities for submitting jobs ***


//convenience functions used to decide on the bestGridForSubmission (see below)
//pending jobs mean they are acknoledged by the Xgrid controller, but are in the pipeline, waiting for an agent to run them
int pendingJobCountForGrid(GEZGrid *aGrid)
{
	//we loop on the XGGrid, not the GEZGrid, as the GEZGrid does not necessarily keep track of all the jobs
	NSEnumerator *e = [[[aGrid xgridGrid] jobs] objectEnumerator];
	XGJob *aJob;
	int jobCount = 0;
	while ( aJob = [e nextObject] ) {
		if ( [aJob state] == XGResourceStatePending )
			jobCount ++;
	}

	DLog(NSStringFromClass([GEZMetaJob class]),12,@"Pending jobs for Grid %@ = %d",[aGrid name], jobCount);

	return jobCount;
}
//submitting jobs were submitted by the program, but are not yet acknowledged by the Xgrid controller (and we have no identifier yet); if too many accumulate, it is probably because the controller is unresponsive and we should stop harassing it until it is OK
int submittingJobCountForGrid(GEZGrid *aGrid)
{
	NSEnumerator *e = [[aGrid jobs] objectEnumerator];
	GEZJob *aJob;
	int jobCount = 0;
	while ( aJob = [e nextObject] ) {
		if ( [aJob isSubmitting] )
			jobCount ++;
	}

	DLog(NSStringFromClass([GEZMetaJob class]),12,@"Submitting jobs for Grid %@ = %d",[aGrid name], jobCount);

	return jobCount;	
}

//decides on the optimal grid to use given the settings of the meta job, returning nil if no grid fits the requirements
//this decision depends on the number of "Pending" jobs (the presence of pending jobs means the grid is full) and of "Submitting" jobs (jobs in the pipeline not yet acknowledged by XgridFoundation, we have to wait for these to be acknowledged)
- (GEZGrid *)bestGridForSubmission
{
	GEZGrid *bestGrid = nil;
	int bestPendingJobCount = -1;
	int bestAvailableAgentCount = -1;
	
	//if no prefered grids, just use the best one available
	NSSet *allGrids = [self allGrids];
	if ( [allGrids count] == 0 ) {
		NSEnumerator *allServers = [[GEZServer allServers] objectEnumerator];
		NSMutableSet *gridSet = [NSMutableSet set];
		GEZServer *aServer;
		while ( aServer = [allServers nextObject] )
			[gridSet unionSet:[aServer grids]];
		allGrids = [NSSet setWithSet:gridSet];
	}
	
	//looping through all the grids to find the best one = connected, less pending jobs, more available agents
	NSEnumerator *e = [allGrids objectEnumerator];
	GEZGrid *aGrid;
	while ( aGrid = [e nextObject] ) {
		int pendingJobCount = pendingJobCountForGrid(aGrid);
		int availableAgentsGuess = [aGrid availableAgentsGuess];
		if ( [aGrid isConnected] && ( bestPendingJobCount == -1 || pendingJobCount < bestPendingJobCount ) &&  availableAgentsGuess > bestAvailableAgentCount ) {
			bestGrid = aGrid;
			bestPendingJobCount = pendingJobCount;
			bestAvailableAgentCount = availableAgentsGuess;
		}
	}
	if ( bestGrid == nil )
		return nil;
	
	//maxPendingJobs = jobs already in the queue in the grid = when all the agents are busy working and jobs pile up
	//maxSubmittingJobs = job still not acknoledged by Xgrid as being submitted = no identifer yet, ActionMonitor still pending (see GEZJob too)
	if ( ( bestPendingJobCount >= [[self valueForKey:@"maxPendingJobs"] intValue] ) || ( submittingJobCountForGrid(bestGrid) >= [[self valueForKey:@"maxSubmittingJobs"] intValue] ) )
		return nil;
	
	return  bestGrid;	
}

//when sent to the agents, the full paths on the client filesystem will become relative paths, relative to the working directory on the agent; in the process, the file tree will be made as flat as possible to avoid sending too much information to the agent; this function takes care of "flattening" (symplifying) the file tree, for instance:
//
//		Paths on the client							Files on the agent
//	    -------------------							------------------
//		/Users/username/Documents/dir1				dir1
//		/Users/username/Documents/dir1/file1		dir1/file1
//		/Users/username/Documents/dir1/file2		dir1/file2
//		/etc/myfiles/param1							param1
//		/etc/mydir									mydir
//		/etc/mydir/settings1.txt					mydir/settings1.txt
//		/etc/mydir/settings2.txt					mydir/settings2.txt

NSDictionary *relativePaths(NSArray *fullPaths)
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSEnumerator *fullPathsEnumerator = [fullPaths objectEnumerator];
	NSString *currentPath;
	NSString *currentDir = nil;
	NSMutableDictionary *relativePaths = [NSMutableDictionary dictionaryWithCapacity:[fullPaths count]];
	while ( currentPath = [fullPathsEnumerator nextObject] ) {
		BOOL isDir,isSubPath;
		if ( [fileManager fileExistsAtPath:currentPath isDirectory:&isDir] ) {
			
			//isSubPath = is the currentPath a subpath of the currentDir?
			if ( [currentDir length] > [currentPath length]-1 )
				isSubPath = NO;
			else
				isSubPath = [currentDir isEqualToString:[currentPath substringWithRange:NSMakeRange(0,[currentDir length])]];
			
			//the subPath string is the relative path on the agent
			NSString *subPath;
			if ( isSubPath )
				subPath = [[currentDir lastPathComponent] stringByAppendingPathComponent:[currentPath substringFromIndex:[currentDir length]+1]];
			else {
				subPath = [currentPath lastPathComponent];
				//if it is not a subpath of the currentDir, we need to redefine the currentDir
				currentDir = (isDir?currentPath:@"");
			}
			
			//OK, we have more more entry!
			[relativePaths setObject:subPath forKey:currentPath];
		}
	}
	
	//for optimization, I won't make a non-mutable copy, hoping the rest of my code will only use this object once and will not do silly things
	return relativePaths;
}

//when reset, the available commands contains indexes that follow these rules
//	* index < [dataSource numberOfTasks]
//	* number of successes < minSuccessesPerTask
//	* number of failures < maxFailuresPerTask (if maxFailuresPerTask>0)
//	* number of submissions < maxSubmissionsPerTask
//Then, we get the following values for each of the commands left:
//	* number of successes
//	* number of submissions
//	* --> sum of the two = countTotalSubmissions
//... and then the max of that number for all these commands = N
//if all the commands have the same value N, keep them all in availableTasks
//Otherwise, this last condition ensures that all commands are at the same level:
//	* keep only commands for which successes + submissions < N
//Each time availableTasks is reset, it may thus include commands that are already submitted and pending,
//even though the results may not be needed. But this way, the last commands still pending may be
//done faster by being submitted to several agents in parallel
- (void)resetAvailableTasks
{
	unsigned int i,n;
	int totalSub, max, countCompletedTasks, countDismissedTasks;
	GEZIntegerArray *suc,*fai,*sub;
	BOOL allTheSame;
	
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	//max index to use
	n=[[self dataSource] numberOfTasksForMetaJob:self];
	if ( n != [[self countTotalTasks] intValue] )
		[self setValue:[NSNumber numberWithInt:n] forKey:@"countTotalTasks"];
	
	//get pointers to the array for success, failures and submissions count
	suc=[self successCounts];
	fai=[self failureCounts];
	sub=[self submissionCounts];
	DLog(NSStringFromClass([self class]),10,@"successes: %@\nfailures: %@\nsubmissions: %@\n",[suc stringRepresentation],[fai stringRepresentation], [sub stringRepresentation]);
	
	//set up a first version of availableTasks
	//	* number of successes < minSuccessesPerTask
	//	* number of failures < maxFailuresPerTask (if maxFailuresPerTask>0)
	//	* number of submissions < maxSubmissionsPerTask
	//At the same time, count completed tasks and dismissed tasks
	countCompletedTasks = 0;
	countDismissedTasks = 0;
	int threshold1, threshold2;
	if ( availableTasks == nil )
		availableTasks = [[NSMutableIndexSet alloc] init];
	[availableTasks removeAllIndexes];
	threshold1 = [self minSuccessesPerTask];
	threshold2 = [self maxFailuresPerTask];
	for (i=0;i<n;i++) {
		if ( [suc intValueAtIndex:i] < threshold1 ) {
			if ( ( threshold2 > 0 ) && ( [fai intValueAtIndex:i] >= threshold2 ) )
				countDismissedTasks++;
			else
				[availableTasks addIndex:i];
		}
		else
			countCompletedTasks++;
	}
	
	//adjust this by also taking into account maxSubmissionsPerTask
	int threshold = [self maxSubmissionsPerTask];
	for (i=0;i<n;i++) {
		if ( [sub intValueAtIndex:i] >= threshold )
			[availableTasks removeIndex:i];
	}
	
	//now we can update the value for countCompletedTasks and countDismissedTasks in the store
	[self setValue:[NSNumber numberWithInt:countCompletedTasks] forKey:@"countCompletedTasks"];
	[self setValue:[NSNumber numberWithInt:countDismissedTasks] forKey:@"countDismissedTasks"];
	
	//get the first index, and if no task left, this is it
	i=[availableTasks firstIndex];
	if (i==NSNotFound)
		return;
	
	//get the max of ( number of successes + number of submissions ) values
	max = [suc intValueAtIndex:i] + [sub intValueAtIndex:i];
	allTheSame=YES;
	for (i++;i<n;i++) {
		if ([availableTasks containsIndex:i]) {
			totalSub = [suc intValueAtIndex:i] + [sub intValueAtIndex:i];
			if ( totalSub > max ) {
				max=totalSub;
				allTheSame=NO;
			}
		}
	}
	
	//this is the special case where all the values are the same, and we don't want to remove them all in the next step!
	if (allTheSame)
		return;
	
	//now remove availableTasks for which totalSub=max
	for (i=0;i<n;i++) {
		totalSub = [suc intValueAtIndex:i] + [sub intValueAtIndex:i];
		if (totalSub>=max) //using '>=' instead of '==' does not hurt
			[availableTasks removeIndex:i];
	}
	
}


//convenience method called by several other methods to decrement the submission counts for the tasks of a finished job
- (void)removeJob:(GEZJob *)aJob
{
	NSDictionary *taskMap;
	NSEnumerator *e;
	NSNumber *metaTaskIndex;
	
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	taskMap = [[aJob jobInfo] objectForKey:@"TaskMap"];
	e = [taskMap objectEnumerator];
	while ( metaTaskIndex = [e nextObject] ) {
		int newSubmissionCounts = [[self submissionCounts] decrementIntValueAtIndex:[metaTaskIndex intValue]];
		if ( newSubmissionCounts == 0 ) {
			int old = [[self valueForKey:@"countSubmittedTasks"] intValue];
			[self setValue:[NSNumber numberWithInt:old-1] forKey:@"countSubmittedTasks"];
		}
		//the delegate might want to know the task was processed
		if ( [[self delegate] respondsToSelector:@selector(metaJob:didProcessTaskAtIndex:)] )
			[[self delegate] metaJob:self didProcessTaskAtIndex:[metaTaskIndex intValue]];
		
	}
	[aJob setDelegate:nil];
	[[self mutableSetValueForKey:@"jobs"] removeObject:aJob];
	[aJob delete];
	
	[self submitNextJobSoonIfRunning];
}

#pragma mark *** submitting jobs ***


//this method decides how many tasks and jobs to create based on the MetaJob settings
//it create TaskLists to send to the above method 'submitJobWithTaskList:paths:'
- (BOOL)submitNextJob
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	//if we have gone through all the currently queued tasks, we need to build a new queue first
	if ( [availableTasks count] < 1 )
		[self resetAvailableTasks];
		
	//decide on the best grid to use for submission
	GEZGrid *bestGrid = [self bestGridForSubmission];
	if ( bestGrid == nil ) {
		DLog(NSStringFromClass([self class]),10,@"No job submission: no suitable grid");
		return NO;
	}
	
	//submit a job only if at least tasksPerJob can be submitted, which is not always possible:
	//	* when there are not enough tasks left (maxAvailableTasks), just submit anyway
	//	* when other constraints are reached (e.g. maxBytesPerJob, see next steps later in the method)
	//	* when tasksPerJob == 0, smart submission (see later too)
	int tasksPerJob = [self tasksPerJob];
	int maxSubmittedTasks = [self maxSubmittedTasks];
	int maxAvailableTasks = [availableTasks count];
	int countSubmittedTasks = [[self valueForKey:@"countSubmittedTasks"] intValue];
	if ( tasksPerJob > 0 && maxAvailableTasks >= tasksPerJob && countSubmittedTasks >= maxSubmittedTasks - tasksPerJob ) {
		DLog(NSStringFromClass([self class]),10,@"No job submission: too many tasks already submitted");
		return NO;
	}
	
	//if tasksPerJob == 0, supersmart calculation on the number of tasks per job, based on the guessed number of agents
	if ( tasksPerJob < 1 ) {
		int availableAgentsGuess = [bestGrid availableAgentsGuess];
		if ( availableAgentsGuess > 0 )
			//wild (supersmart) guess
			tasksPerJob = 1 + availableAgentsGuess / (int)DEFAULT_JOBS_PER_GRID_VALUE;
		else
			//even wilder guess
			tasksPerJob = DEFAULT_TASKS_PER_JOB_VALUE;
	}
	
	//taskMap dictionary will be built as the tasks are added to the list = simple correspondance between taskID (index in the XGJob) and metaTaskIndex (index in the MetaJob) --> used in the jobInfo entry of the GEZJob
	NSMutableDictionary *taskMap = [NSMutableDictionary dictionaryWithCapacity:tasksPerJob];
	
	//the taskSpecifications is part of the final job specification (see man xgrid)
	NSMutableDictionary *taskSpecifications = [NSMutableDictionary dictionaryWithCapacity:tasksPerJob];
	
	//the inputFiles is also part of the final job specification, and will be built in parallel with the task specifications; for this dictionary, I decided to name the keys "filexxx" where x is an int; the values are the NSData object to be uploaded to the agent; the final path on the agent will be decided by the inputFileMap set for each task specification (see xgrid man page and the GridEZ developer docs, and see below how task specification are built)
	NSMutableDictionary *inputFiles = [NSMutableDictionary dictionary];
	int inputFilesCurrentIndex = 0;
	
	//this dictionary will keep track of the paths already listed in 'inputFiles' and the key used to store them, so we can easily retrieve the key of an inputFile entry to be used in the inputFileMap in a task specification; in inputFileFullPaths, the paths are the keys and the inputFile keys are the values; I could have simply used the full path as the keys in the inputFiles dictionary and get away with just one dictionary (inputFiles), but I decided not do because of security concerns: including full paths in the specifications sent to the agents is revealing too much about the client filesystem
	NSMutableDictionary *inputFileFullPaths = [NSMutableDictionary dictionary];
	
	//stdin entries can be paths, but also NSString or NSData, and they thus have to be treated differently in the latter 2 cases to avoid duplicate entries in inputFiles; when stdin is not given as a path, we keep track of the NSString or NSData objects by storing them in the stdinObjects dictionary; the NSString or NSData are the keys (keys are copied but this is OK because NSString and NSData are immutable, so not physically copied), and the inputFile keys are the values
	NSMutableDictionary *stdinObjects = [NSMutableDictionary dictionary];
	
	//loop over tasks to construct the taskSpecifications and the inputFiles entries	
	int taskCount = 0;
	long byteCount = 0;
	long maxBytes = [self maxBytesPerJob];
	unsigned int metaTaskIndex = [availableTasks firstIndex];
	while ( taskCount < tasksPerJob && byteCount < maxBytes && metaTaskIndex != NSNotFound ) {
		
		//get the next taskDescription from the data source
		id taskDescription = [[self dataSource] metaJob:self taskAtIndex:metaTaskIndex];
		if ( taskDescription == nil )
			break;
		
		//standard input ÐÐ> the data will be stored in inputFiles; it might already be there from other tasks, and we need to check that; to keep track of the data already stored, we use the dictionaries stdinObjects (if stdin is provided as NSData or NSString) and inputFileFullPaths (if stdin is provided as a file path; this dictionary is also used for the uploaded paths, see next step)
		NSString *stdinInputFileKey = nil;
		NSData *stdinData = [NSData data];
		id standardInput = [taskDescription valueForKey:GEZTaskSubmissionStandardInputKey];
		if ( [standardInput isKindOfClass:[NSData class]] ) {
			stdinInputFileKey = [stdinObjects objectForKey:standardInput];
			if ( stdinInputFileKey == nil ) {
				stdinData = standardInput;
				stdinInputFileKey = [NSString stringWithFormat:@"file%d-stdin",inputFilesCurrentIndex];
				inputFilesCurrentIndex ++;
				[inputFiles setObject:[NSDictionary dictionaryWithObjectsAndKeys:stdinData, XGJobSpecificationFileDataKey, @"NO", XGJobSpecificationIsExecutableKey, nil] forKey:stdinInputFileKey];
				[stdinObjects setObject:stdinInputFileKey forKey:standardInput];
			}
		}
		else if ( [standardInput isKindOfClass:[NSString class]] ) {
			BOOL isDir;
			if ( [[NSFileManager defaultManager] fileExistsAtPath:standardInput isDirectory:&isDir] && (!isDir) ) {
				stdinInputFileKey = [inputFileFullPaths objectForKey:standardInput];
				if ( stdinInputFileKey == nil ) {
					stdinData = [NSData dataWithContentsOfFile:standardInput];
					stdinInputFileKey = [NSString stringWithFormat:@"file%d-stdin",inputFilesCurrentIndex];
					inputFilesCurrentIndex ++;
					[inputFiles setObject:[NSDictionary dictionaryWithObjectsAndKeys:stdinData, XGJobSpecificationFileDataKey, @"NO", XGJobSpecificationIsExecutableKey, nil] forKey:stdinInputFileKey];
					[inputFileFullPaths setObject:stdinInputFileKey forKey:standardInput];
				}
			}
			else {
				stdinInputFileKey = [stdinObjects objectForKey:standardInput];
				if ( stdinInputFileKey == nil ) {
					stdinData = [standardInput dataUsingEncoding:NSUTF8StringEncoding];
					stdinInputFileKey = [NSString stringWithFormat:@"file%d-stdin",inputFilesCurrentIndex];
					inputFilesCurrentIndex ++;
					[inputFiles setObject:[NSDictionary dictionaryWithObjectsAndKeys:stdinData, XGJobSpecificationFileDataKey, @"NO", XGJobSpecificationIsExecutableKey, nil] forKey:stdinInputFileKey];
					[stdinObjects setObject:stdinInputFileKey forKey:standardInput];
				}
			}
		}
		byteCount += [stdinData length];
		
		//now, we can start building the task specification, starting with the stdin and inputFileMap
		NSMutableDictionary *taskSpecification = [NSMutableDictionary dictionaryWithCapacity:4];
		NSArray *uploadedPaths = [taskDescription valueForKey:GEZTaskSubmissionUploadedPathsKey];
		NSMutableDictionary *inputFileMap = [NSMutableDictionary dictionaryWithCapacity:[uploadedPaths count]+(stdinInputFileKey!=nil)];
		[taskSpecification setObject:inputFileMap forKey:XGJobSpecificationInputFileMapKey];
		if ( stdinInputFileKey != nil ) {
			[inputFileMap setObject:stdinInputFileKey forKey:stdinInputFileKey];
			[taskSpecification setObject:stdinInputFileKey forKey:XGJobSpecificationInputStreamKey];
		}
		
		//adding the uploaded paths to inputFileMap, after changing the file tree; the full paths (client filesystem) will become relative paths, relative to the working directory on the agent; in the process, the file tree will be made as flat as possible (see 'relativePaths' implementation)
		NSDictionary *agentPaths = relativePaths(uploadedPaths);
		NSEnumerator *e = [uploadedPaths objectEnumerator];
		NSString *fullPath;
		while ( fullPath = [e nextObject] ) {
			//maybe the file is already in the inputFiles, which would mean it would also be listed in inputFilesFullPaths
			NSString *inputFileKey = [inputFileFullPaths objectForKey:fullPath];
			BOOL isDir = NO;
			if ( inputFileKey == nil ) {
				if ( [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] ) {
					if ( isDir == NO ) {
						//case where we actually add a file to inputFiles
						NSData *fileData = [NSData dataWithContentsOfFile:fullPath];
						NSString *fileIsExecutable = [[NSFileManager defaultManager] isExecutableFileAtPath:fullPath]?@"YES":@"NO";
						NSDictionary *fileDictionary = [NSDictionary dictionaryWithObjectsAndKeys: fileData, XGJobSpecificationFileDataKey, fileIsExecutable, XGJobSpecificationIsExecutableKey, nil];
						inputFileKey = [NSString stringWithFormat:@"file%d",inputFilesCurrentIndex];
						inputFilesCurrentIndex ++;
						[inputFiles setObject:fileDictionary forKey:inputFileKey];
						[inputFileFullPaths setObject:inputFileKey forKey:fullPath];
						byteCount += [fileData length];
					} else {
						//directories are a special case: we use a dummy file to force the creation of the directory on the agent working dir; only files can be added to inputFiles, not dirs, so we have to use this trick
						inputFileKey = @".GridEZ_dummy_file_to_force_dir_creation";
						if ( [inputFiles objectForKey:inputFileKey] == nil )
							[inputFiles setObject:[NSDictionary dictionaryWithObjectsAndKeys: [NSData data], XGJobSpecificationFileDataKey, @"NO", XGJobSpecificationIsExecutableKey, nil] forKey:inputFileKey];
					}
				}
			}
			//in the inputFileMap, we decide on the final path on the agent, and the data is refered to the inputFiles entry (at the job level); for directories, we need to create a dummy file
			NSString *agentPath = [agentPaths objectForKey:fullPath];
			if ( isDir )
				agentPath = [agentPath stringByAppendingPathComponent:@".GridEZ_dummy_file_to_force_dir_creation"];
			if ( inputFileKey != nil )
				[inputFileMap setObject:inputFileKey forKey:agentPath];
		}
		
		//command string might need to be changed from an absolute path (from the client filesystem) to a relative path (on the working dir on the agent); in addition, we need to use the 'working' directory instead of the 'executable' directory because the executable might not be in 'executable' (it is a "bug" in xgrid: even if files are set to be executable in the inputFiles, only one file will be uploaded and it cannot be inside a directory; but what saves us is that anyway all the files will also be in the 'working' directory)
		NSString *commandString = [taskDescription valueForKey:@"GEZTaskSubmissionCommandKey"];
		NSString *relativePath = nil;
		if ( ( commandString != nil )  && ( relativePath = [agentPaths objectForKey:commandString] ) )
			commandString = [@"../working" stringByAppendingPathComponent:relativePath];
		if ( commandString == nil )
			commandString = @"/bin/echo";
		[taskSpecification setObject:commandString forKey:XGJobSpecificationCommandKey];
		
		//arguments strings may also need to be changed from an absolute path (from the client filesystem) to a relative path (on the working dir on the agent)
		NSArray *argumentStrings = [taskDescription valueForKey:@"GEZTaskSubmissionArgumentsKey"];
		if ( argumentStrings != nil ) {
			NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:[argumentStrings count]];
			e = [argumentStrings objectEnumerator];
			NSString *arg;
			while ( arg = [e nextObject] ){
				relativePath = [agentPaths objectForKey:arg];
				[arguments addObject:(relativePath?relativePath:arg)];
			}
			argumentStrings = [NSArray arrayWithArray:arguments];
			[taskSpecification setObject:argumentStrings forKey:XGJobSpecificationArgumentsKey];
		}
		
		//this task specification is ready to be added  to the task list
		NSString *taskIndexString = [NSString stringWithFormat:@"%d",taskCount];
		NSString *metaTaskIndexString = [NSString stringWithFormat:@"%d",metaTaskIndex];
		[taskSpecifications setObject:taskSpecification forKey:taskIndexString];
		[taskMap setObject:metaTaskIndexString forKey:taskIndexString];
		
		//keep track of submissions
		[availableTasks removeIndex:metaTaskIndex];
		int newSubmissionCounts = [[self submissionCounts] incrementIntValueAtIndex:metaTaskIndex];
		if ( newSubmissionCounts == 1 ) {
			int old = [[self valueForKey:@"countSubmittedTasks"] intValue];
			[self setValue:[NSNumber numberWithInt:old+1] forKey:@"countSubmittedTasks"];
		}
		
		//get ready for the next task
		taskCount ++;
		metaTaskIndex = [availableTasks indexGreaterThanIndex:metaTaskIndex];
	}
	
	//we have note submitted anything??
	if ( taskCount < 1 ) {
		DLog(NSStringFromClass([self class]),10,@"No job submission: no available task to submit");
		return NO;
	}
	
	//create a human-readable name for the job with the metatask indexes
	NSArray *indexes = [[taskMap allValues] sortedArrayUsingSelector:@selector(compare:)];
	NSMutableString *jobName = [NSMutableString stringWithFormat:@"%@ [", [self valueForKey:@"name"]];
	int i,ii,j,n;
	if ( [indexes count]>0 ) {
		j = 0; //number of ranges already added
		NSEnumerator *e = [indexes objectEnumerator];
		NSNumber *metaIndex;
		i = [[e nextObject] intValue]; //current index
		n = i; //current start of range
		[jobName appendFormat:@" %d",n];
		while ( metaIndex = [e nextObject] ) {
			ii = [metaIndex intValue];
			if ( ii==i+1 )
				i = ii;
			else {
				if ( n<i )
					[jobName appendFormat:@"-%d",i];
				n=i=ii;
				j++;
				if ( j>20 ) {
					[jobName appendString:@",...  "];
					[e allObjects];
				} else
					[jobName appendFormat:@", %d",ii];
			}
		}
		if ( n<i && j<21 )
			[jobName appendFormat:@"-%d",i];
	}
	[jobName appendString:@" ]"];	
	
	
	//the final job specifications dictionary, ready to submit
	NSDictionary *jobSpecification = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithString:jobName], XGJobSpecificationNameKey,
		[[NSBundle mainBundle] bundleIdentifier], XGJobSpecificationApplicationIdentifierKey,
		inputFiles, XGJobSpecificationInputFilesKey,
		taskSpecifications, XGJobSpecificationTaskSpecificationsKey,
		nil];
	
	//the taskMap is stored in the jobInfo of the GEZJob object (one entry dictionary, to which we could later add more stuff)
	GEZJob *newJob = [GEZJob jobWithGrid:bestGrid];
	[newJob setJobInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		taskMap, @"TaskMap",
		nil] ];
	
	//submit the job!!
	DLog(NSStringFromClass([self class]),12,@"\njobSpecification:\n%@",[jobSpecification description]);
	[newJob setValue:self forKey:@"metaJob"];
	[newJob setDelegate:self];
	[newJob setShouldRetrieveResultsAutomatically:YES];
	[newJob submitWithJobSpecification:jobSpecification];
	
	return YES;
	
}

//make sure only one timer is used
- (void)submitNextJobSoon
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	if ( submissionTimer != nil )
		return;
	submissionTimer = [[NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(submitNextJobWithTimer:) userInfo:nil repeats:NO] retain];
}

- (void)submitNextJobSoonIfRunning
{
	if ( [self isRunning] )
		[self submitNextJobSoon];
}


//only to be called by submitNextJobSoon
- (void)submitNextJobWithTimer:(NSTimer *)timer
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	//check consistency
	if ( submissionTimer != timer )
		[NSException raise:@"GEZMetaJobInconsistency" format:@"The ivar submissionTimer should be equal to the timer passed as argument to 'submitNextJobWithTimer:'"];
	[submissionTimer release];
	submissionTimer = nil;
	
	//Only submit more jobs if isRunning
	if ( [self isRunning]==NO )
		return;
	
	//submit only one job per iteration of the run loop
	if ( [self submitNextJob] )
		[self submitNextJobSoon];
	
}


#pragma mark *** private accessors ***

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"MetaJob '%@'",[self primitiveValueForKey:@"name"]];
	//return [NSString stringWithFormat:@"MetaJob '%@' (%d MetaTasks)",[self name],[self countTotalTasks]];
}


- (GEZIntegerArray *)failureCounts
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	GEZIntegerArray *failureCountsLocal;
	[self willAccessValueForKey:@"failureCounts"];
	failureCountsLocal = [self primitiveValueForKey:@"failureCounts"];
	[self didAccessValueForKey:@"failureCounts"];
	return failureCountsLocal;
}

- (GEZIntegerArray *)submissionCounts
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	GEZIntegerArray *submissionCountsLocal;
	[self willAccessValueForKey:@"submissionCounts"];
	submissionCountsLocal = [self primitiveValueForKey:@"submissionCounts"];
	[self didAccessValueForKey:@"submissionCounts"];
	return submissionCountsLocal;
}

- (GEZIntegerArray *)successCounts
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	GEZIntegerArray *successCountsLocal;
	[self willAccessValueForKey:@"successCounts"];
	successCountsLocal = [self primitiveValueForKey:@"successCounts"];
	[self didAccessValueForKey:@"successCounts"];
	return successCountsLocal;
}

- (void)setFailureCounts:(GEZIntegerArray *)failureCountsNew
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	[self willChangeValueForKey:@"failureCounts"];
	[self setPrimitiveValue:failureCountsNew forKey:@"failureCounts"];
	[self didChangeValueForKey:@"failureCounts"];
}

- (void)setSubmissionCounts:(GEZIntegerArray *)submissionCountsNew
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	[self willChangeValueForKey:@"submissionCounts"];
	[self setPrimitiveValue:submissionCountsNew forKey:@"submissionCounts"];
	[self didChangeValueForKey:@"submissionCounts"];
}

- (void)setSuccessCounts:(GEZIntegerArray *)successCountsNew
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	[self willChangeValueForKey:@"successCounts"];
	[self setPrimitiveValue:successCountsNew forKey:@"successCounts"];
	[self didChangeValueForKey:@"successCounts"];
}


@end
