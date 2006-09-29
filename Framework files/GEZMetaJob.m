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
#import "GEZServer.h"
#import "GEZJob.h"
#import "GEZIntegerArray.h";
#import "GEZProxy.h";

@class GEZTaskSource;
@class GEZOutputInterface;


@interface GEZMetaJob (GEZMetaJobPrivateAccessors)
- (GEZIntegerArray *)failureCounts;
- (GEZIntegerArray *)submissionCounts;
- (GEZIntegerArray *)successCounts;
- (void)setFailureCounts:(GEZIntegerArray *)failureCountsNew;
- (void)setSubmissionCounts:(GEZIntegerArray *)submissionCountsNew;
- (void)setSuccessCounts:(GEZIntegerArray *)successCountsNew;

@end



@implementation GEZMetaJob

#pragma mark *** Initializations ***

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"MetaJob '%@'",[self primitiveValueForKey:@"name"]];
	//return [NSString stringWithFormat:@"MetaJob '%@' (%d MetaTasks)",[self name],[self countTotalTasks]];
}

//we need to register to keep track of percentDone etc... in jobs
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


#pragma mark *** accessors ***

- (id)dataSource
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
    [self willAccessValueForKey:@"dataSource"];
    id dataSource = [[self primitiveValueForKey:@"dataSource"] referencedObject];
    [self didAccessValueForKey:@"dataSource"];
    return dataSource;
}

- (void)setDataSource:(id)newDataSource
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
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
	[self setPrimitiveValue:[GEZProxy proxyWithReferencedObject:newDataSource] forKey:@"dataSource"];
	[self didChangeValueForKey:@"dataSource"];
	
	//the value of countTotalTasks is potentially changed too
	unsigned int n=[newDataSource numberOfTasksForMetaJob:self];
	[self setValue:[NSNumber numberWithInt:n] forKey:@"countTotalTasks"];
}

- (id)delegate
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
    [self willAccessValueForKey:@"delegate"];
    id delegate = [[self primitiveValueForKey:@"delegate"] referencedObject];
    [self didAccessValueForKey:@"delegate"];
    return delegate;
}

//do not retain to avoid retain cycles
- (void)setDelegate:(id)newDelegate
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	[self willChangeValueForKey:@"delegate"];
	[self setPrimitiveValue:[GEZProxy proxyWithReferencedObject:newDelegate] forKey:@"delegate"];
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

//when reset, the available commands contains indexes that follow these rules
//	* index < [dataSource numberOfTasks]
//	* number of successes < successCountsThreshold
//	* number of failures < failureCountsThreshold (if failureCountsThreshold>0)
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
	//	* number of successes < successCountsThreshold
	//	* number of failures < failureCountsThreshold (if failureCountsThreshold>0)
	//	* number of submissions < maxSubmissionsPerTask
	//At the same time, count completed tasks and dismissed tasks
	countCompletedTasks = 0;
	countDismissedTasks = 0;
	int threshold1, threshold2;
	if ( availableTasks == nil )
		availableTasks = [[NSMutableIndexSet alloc] init];
	[availableTasks removeAllIndexes];
	threshold1 = [self successCountsThreshold];
	threshold2 = [self failureCountsThreshold];
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
	/*
	threshold = [self failureCountsThreshold];
	if ( threshold > 0 ) {
		for (i=0;i<n;i++) {
			if ( [fai intValueAtIndex:i] >= threshold ) {
				[availableTasks removeIndex:i];
				countDismissedTasks++:
			}
		}
	}
	 */
	int threshold = [self maxSubmissionsPerTask];
	for (i=0;i<n;i++) {
		if ( [sub intValueAtIndex:i] >= threshold )
			[availableTasks removeIndex:i];
	}
	
	//now we can update the value for countCompletedTasks and countDismissedTasks in the store
	[self setValue:[NSNumber numberWithInt:countCompletedTasks] forKey:@"countCompletedTasks"];
	[self setValue:[NSNumber numberWithInt:countDismissedTasks] forKey:@"countDismissedTasks"];
	
	//get the first index
	i=[availableTasks firstIndex];
	if (i==NSNotFound)
		return;
	
	//get the max of number of successes + number of submissions
	//note that i = first available command
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
	if (allTheSame)
		return;
	
	//now remove availableTasks for which totalSub>=max
	for (i=0;i<n;i++) {
		totalSub = [suc intValueAtIndex:i] + [sub intValueAtIndex:i];
		if (totalSub>=max)
			[availableTasks removeIndex:i];
	}
}

/*
//calculate the total number of tasks submitted so far for this metaJob
//by looking at the tasks of running and pending jobs
- (unsigned int)countSubmittedTasks
{
	NSSet *jobs;
	int total;
	GEZJob *aJob;
	XGJob *xgridJob;
	NSEnumerator *e;
	XGResourceState state;
	
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);

	total = 0;
	jobs = [self valueForKey:@"jobs"];
	e = [jobs objectEnumerator];
	while ( aJob = [e nextObject] ) {
		xgridJob = [aJob xgridJob];
		state = [xgridJob state];
		if ( state == XGResourceStateRunning || state == XGResourceStatePending )
			total += [xgridJob taskCount];
	}
	return total;
}
*/

//convenience method called by several other methods to decrement the submission counts for the tasks of a finished job
- (void)removeJob:(GEZJob *)aJob
{
	NSDictionary *taskMap;
	NSEnumerator *e;
	NSNumber *metaTaskIndex;

	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);

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
}

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
	if ( [self countSuccessesForTaskAtIndex:index] >= [self successCountsThreshold] )
		return @"Completed";
	if ( [self countSubmissionsForTaskAtIndex:index] > 0 )
		return @"Submitted";
	
	int threshold = [self failureCountsThreshold];
	if ( threshold > 0 &&  [self countFailuresForTaskAtIndex:index] >= threshold)
		return @"Dismissed";
	
	return @"Pending";
}

#pragma mark *** task specifications ***

// All these methods may later be updated to check that the data source implements the different selectors


- (NSString *)commandStringForTask:(id)taskItem
{
	id dataSource = [self dataSource];
	if ( [dataSource respondsToSelector:@selector(metaJob:commandStringForTask:)] )
		return [dataSource metaJob:self commandStringForTask:taskItem];
	else
		return nil;
}

- (NSArray *)argumentStringsForTask:(id)taskItem
{
	id dataSource = [self dataSource];
	if ( [dataSource respondsToSelector:@selector(metaJob:argumentStringsForTask:)] )
		return [dataSource metaJob:self argumentStringsForTask:taskItem];
	else
		return nil;
}

- (NSString *)stdinPathForTask:(id)taskItem
{
	id dataSource = [self dataSource];
	if ( [dataSource respondsToSelector:@selector(metaJob:stdinPathForTask:)] )
		return [dataSource metaJob:self stdinPathForTask:taskItem];
	else
		return nil;
}

- (NSArray *)pathsToUploadForTask:(id)taskItem
{
	NSMutableArray *pathsToUpload = [NSMutableArray array];
	
	NSString *stdinPath = [self stdinPathForTask:taskItem];
	if ( stdinPath != nil )
		[pathsToUpload addObject:stdinPath];		

	id dataSource = [self dataSource];
	if ( [dataSource respondsToSelector:@selector(metaJob:pathsToUploadForTask:)] )
		[pathsToUpload addObjectsFromArray:[dataSource metaJob:self pathsToUploadForTask:taskItem]];
	return pathsToUpload;
}


#pragma mark *** submitting jobs ***


/* TODO */

//this method is called by submitNextJobs (see below)
/*
taskList dictionary:
		key   = global task index
		value = taskItem (as returned by dataSource)
pathsToUpload have been already defined in the method 'submitNextJobs' :
	- they are all the same for the tasks (or some tasks may have no paths to upload)
	- they are alphabetically ordered
NOTE: I cannot have different sets of paths for different tasks, because the key XGJobSpecificationInputFileMapKey does not behave as expected; using this key in the task specifications cancel all uploads otherwise defined by the XGJobSpecificationInputFilesKey; this could be a bug in Xgrid or me not understanding the syntax ('man xgrid' for an example of batch format job submission, which apparently follows the same syntax as the dictionary used by the Cocoa APIs)
 */
- (void)submitJobWithTaskList:(NSDictionary *)taskList paths:(NSArray *)pathsToUpload
{
	NSEnumerator *e;
	NSNumber *metaTaskIndex;
	id taskItem;
	NSArray *paths;
	NSDictionary *fileDictionary,*jobSpecification;
	NSMutableDictionary *taskSpecifications, *oneTaskDictionary, *inputFiles, *fileMap;
	NSString *currentPath,*currentDir, *subPath, *commandString, *temp1, *temp2, *stdinPath;
	NSMutableString *jobName;
	NSArray *argumentStrings;
	NSMutableArray *args;
	NSFileManager *fileManager;
	BOOL exists,isDir,isSubPath;
	NSRange pathRange;
	GEZJob *newJob;
	int taskID;
	NSMutableDictionary *taskMap;
	
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	DLog(NSStringFromClass([self class]),12,@"\ntaskList:\n%@\npathsToUpload:\n%@",[taskList description],[pathsToUpload description]);

	//create the GEZJob object used to wrap the XGJob
	newJob = [NSEntityDescription insertNewObjectForEntityForName:@"Job" inManagedObjectContext:[self managedObjectContext]];
	[[self mutableSetValueForKey:@"jobs"] addObject:newJob];
	[newJob setDelegate:self];
	
	//create the taskMap = simple correspondance between taskID (index in the Job) and metaTaskIndex (index in the MetaJob) --> used in the jobInfo entry of the GEZJob
	taskMap = [NSMutableDictionary dictionaryWithCapacity:[taskList count]];
	taskID = 0;
	e = [taskList keyEnumerator];
	while ( metaTaskIndex = [e nextObject] ) {
		[taskMap setObject:metaTaskIndex forKey:[NSString stringWithFormat:@"%d",taskID]];
		taskID++;
	}
	[newJob setJobInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		[[self objectID] URIRepresentation], @"MetaJobID",
		taskMap, @"TaskMap",
		nil] ];
	
	//fileMap dictionary will keep track of the correspondance between paths on the client and paths on the agent
	//	key   = path on the client (a full path)
	//	value = path on the agent  (a relative path in the working directory)
	fileMap = [NSMutableDictionary dictionaryWithCapacity:[pathsToUpload count]];
	
	/* definition of the inputFiles */
	/*	- a dir on the client ==> any subpath is also a subpath on the agent
		- a group of subpaths of a dir on the client ==> all uploaded inside one directory in the working directory of the agent
	As a result, the file tree is more 'flat' on the agent; for instance:
		Paths on the client							Files on the agent
		-------------------							------------------
		/Users/username/Documents/dir1				dir1
		/Users/username/Documents/dir1/file1		dir1/file1
		/Users/username/Documents/dir1/file2		dir1/file2
		/etc/myfiles/param1							param1
		/etc/mydir									mydir
		/etc/mydir/settings1.txt					mydir/settings1.txt
		/etc/mydir/settings2.txt					mydir/settings2.txt
	*/
	inputFiles = [NSMutableDictionary dictionaryWithCapacity:[pathsToUpload count]];
	fileManager = [NSFileManager defaultManager];
	currentDir = @"."; //that can't be the first character in a path!
	e = [pathsToUpload objectEnumerator];
	while ( currentPath = [e nextObject] ) {
		exists = [fileManager fileExistsAtPath:currentPath isDirectory:&isDir];
		if ( exists ) {
			
			//is the currentPath a subpath of the currentDir?
			if ( [currentDir length] > [currentPath length]-1 )
				isSubPath = NO;
			else {
				pathRange = NSMakeRange(0,[currentDir length]);
				subPath = [currentPath substringWithRange:pathRange];
				isSubPath = [subPath isEqualToString:currentDir];
			}

			//the subPath string is the relative path on the agent
			if ( isSubPath )
				subPath = [[currentDir lastPathComponent] stringByAppendingPathComponent:[currentPath substringFromIndex:[currentDir length]+1]];
			else
				subPath = [currentPath lastPathComponent];
			[fileMap setObject:subPath forKey:currentPath];
			
			//if it is a dir, we may need to redefine the currentDir
			//and we need to create a dummy file to make sure the dir is created
			if ( isDir ) {
				if ( isSubPath ==NO )
					currentDir = currentPath;
				subPath = [subPath stringByAppendingPathComponent:@".GridStuffer_dummy_file_to_force_dir_creation"];
				fileDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSData dataWithBytes:"hi" length:2], XGJobSpecificationFileDataKey,
					@"NO", XGJobSpecificationIsExecutableKey,
					nil];
			}
				
			//if it is a file, we add it to the inputFile, and we may need to reset the currentDir
			else {
				if ( isSubPath==NO )
					currentDir = @"//";
				fileDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSData dataWithContentsOfFile:currentPath], XGJobSpecificationFileDataKey,
					[fileManager isExecutableFileAtPath:currentPath]?@"YES":@"NO", XGJobSpecificationIsExecutableKey,
					nil];
			}
			
			//now add the file to the input files
			[inputFiles setObject:fileDictionary forKey:subPath];
		}
	}

	
	//define the task specifications by calling the appropriate methods on the dataSource
	taskID = 0;
	taskSpecifications = [NSMutableDictionary dictionaryWithCapacity:[taskList count]];
	e = [taskList keyEnumerator];
	while ( metaTaskIndex = [e nextObject] ) {
		
		//this is the task item, as it was returned by the datasource
		taskItem = [taskList objectForKey:metaTaskIndex];
		commandString = [self commandStringForTask:taskItem];
		argumentStrings = [self argumentStringsForTask:taskItem];
		stdinPath = [self stdinPathForTask:taskItem];

		//the dictionary for one task has at most 4 entries
		oneTaskDictionary = [NSMutableDictionary dictionaryWithCapacity:4];
		
		
		//if the task has no paths, we need to add an inputFileMap to prevent inputFiles addition to that task
		paths = [self pathsToUploadForTask:taskItem];
		if ( [paths count] == 0 )
			[oneTaskDictionary setObject:[NSDictionary dictionary] forKey:XGJobSpecificationInputFileMapKey];
		
		//otherwise the stdin, the command and argument strings might need to be changed if corresponding to one of the uploaded paths
		else if ( [inputFiles count]>0 ) {

			//the standard-in value should be the path on the agent, and has to be one of the file in the fileMap
			if ( ( stdinPath != nil ) && ( temp1 = [fileMap objectForKey:stdinPath] ) )
				stdinPath = temp1;
			else
				stdinPath = nil;
			
			//the command string might need to be changed
			//use the 'working' directory instead of the 'executable' directory because the executable might not be in 'executable'
			//it seems to be a bug of xgrid: a path with several components will not be properly uploaded to the 'executable', only the 'working' directory
			if ( (commandString!=nil) && (temp1=[fileMap objectForKey:commandString]) )
				commandString = [@"../working" stringByAppendingPathComponent:temp1];
			
			//the argument sstrings may need to be changed
			args = [NSMutableArray arrayWithCapacity:[argumentStrings count]];
			NSEnumerator *e2 = [argumentStrings objectEnumerator];
			while ( temp2 = [e2 nextObject] ){
				temp1 = [fileMap objectForKey:temp2];
				[args addObject:temp1?temp1:temp2];
			}
			argumentStrings = [NSArray arrayWithArray:args];
		}
		
		//add final dictionary to tasksSpecification dictionary
		if ( stdinPath != nil )
			[oneTaskDictionary setObject:stdinPath forKey:XGJobSpecificationInputStreamKey];
		if ( commandString!=nil)
			[oneTaskDictionary setObject:commandString forKey:XGJobSpecificationCommandKey];
		if ( [argumentStrings count]>0 )
			[oneTaskDictionary setObject:argumentStrings forKey:XGJobSpecificationArgumentsKey];
		[taskSpecifications setObject:[NSDictionary dictionaryWithDictionary:oneTaskDictionary] forKey:[NSString stringWithFormat:@"%d",taskID]];
		taskID++;
	}

	//create a name for the job
	NSArray *indexes = [[taskList allKeys] sortedArrayUsingSelector:@selector(compare:)];
	jobName = [NSMutableString stringWithFormat:@"%@ [", [self valueForKey:@"name"]];
	int i,ii,j,n;
	if ( [indexes count]>0 ) {
		j = 0; //number of ranges already added
		e = [indexes objectEnumerator];
		i = [[e nextObject] intValue]; //current index
		n = i; //current start of range
		[jobName appendFormat:@" %d",n];
		while ( metaTaskIndex = [e nextObject] ) {
			ii = [metaTaskIndex intValue];
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
	jobSpecification = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithString:jobName], XGJobSpecificationNameKey,
		@"gridstuffer", XGJobSpecificationApplicationIdentifierKey,
		inputFiles, XGJobSpecificationInputFilesKey,
		taskSpecifications, XGJobSpecificationTaskSpecificationsKey,
		nil];
	
	//submit!!
	DLog(NSStringFromClass([self class]),12,@"\njobSpecification:\n%@",[jobSpecification description]);
	[newJob submitWithJobSpecification:jobSpecification];
	[newJob setShouldRetrieveResultsAutomatically:YES];
}

//this method decides how many tasks and jobs to create based on the MetaJob settings
//it create TaskLists to send to the above method 'submitJobWithTaskList:paths:'
- (void)submitNextJobs
{
	int a,b,minTasks,maxTasks,maxBytes;
	int byteCount,taskCount;
	int taskIndex;
	id taskItem;
	NSMutableDictionary *taskList;
	NSArray *paths,*newPaths;
	
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);

	//have we already reached the maxSubmittedTasks?
	if ( [[self valueForKey:@"countSubmittedTasks"] intValue] >= [[self valueForKey:@"maxSubmittedTasks"] intValue] )
		return;
	
	//initializations
	byteCount = taskCount = 0;
	a        = [[self valueForKey:@"availableAgentsMultiplication"] intValue];
	b        = [[self valueForKey:@"availableAgentsAddition"] intValue];
	minTasks = [[self valueForKey:@"minTasksPerSubmission"] intValue];
	maxTasks = [[self valueForKey:@"maxTasksPerSubmission"] intValue];
	maxBytes = [[self valueForKey:@"maxBytesPerSubmission"] intValue];
	taskList  = [NSMutableDictionary dictionaryWithCapacity:maxTasks];
	paths = [NSArray array];
	
	//the real value of maxTasks = the number we really want to submit 
	/* TO DO : count available agents + etc... */
	if ( b < maxTasks )
		maxTasks = b;
	if ( maxTasks < minTasks )
		maxTasks = minTasks;
	
	
	//retrieve tasks items from the data source until:
	//		- countTasks = maxTasks
	//  OR	- countBytes = maxBytes
	/*** TO DO : add code to REALLY take into account maxBytes !!! ***/
	while ( taskCount < maxTasks && byteCount < maxBytes ) {
		
		//get the next taskItem from the data source, if any
		taskIndex = [availableTasks firstIndex];
		if ( taskIndex == NSNotFound )
			break;
		taskItem = [[self dataSource] metaJob:self taskAtIndex:taskIndex];
		if ( taskItem == nil )
			break;
		
		//keep track of submissions
		[availableTasks removeIndex:taskIndex];
		int newSubmissionCounts = [[self submissionCounts] incrementIntValueAtIndex:taskIndex];
		if ( newSubmissionCounts == 1 ) {
			int old = [[self valueForKey:@"countSubmittedTasks"] intValue];
			[self setValue:[NSNumber numberWithInt:old+1] forKey:@"countSubmittedTasks"];
		}
		if ( [[self delegate] respondsToSelector:@selector(metaJob:didSubmitTaskAtIndex:)] )
			[[self delegate] metaJob:self didSubmitTaskAtIndex:taskIndex];
		taskCount ++;
		
		//to be in the same jobs, tasks need to have the same uploaded paths
		//so I use that criteria to group tasks in jobs (sorting paths allows to direwctly compare arrays and is needed in the next steps anyway)
		/* TO DO : have a 'NSArray *StandardizedPaths (NSArray *paths)' function to make sure we get standardized paths */
		newPaths = [self pathsToUploadForTask:taskItem];
		newPaths = [newPaths sortedArrayUsingSelector:@selector(compare:)];
		if (	[paths count]    == 0				//paths not yet defined
			 || [newPaths count] == 0				//no paths on this task
			 || [newPaths isEqualToArray:paths]	)	//paths are exactly the same as previous tasks
		{
			//then we can simply add that task to the current job and maybe define paths
			[taskList setObject:taskItem forKey:[NSNumber numberWithInt:taskIndex]];
			if ( [paths count]==0 )
				paths = newPaths;
		} else {
			//otherwise, we are done with the current job and we can start a new taskList
			[self submitJobWithTaskList:taskList paths:paths];
			[taskList removeAllObjects];
			[taskList setObject:taskItem forKey:[NSNumber numberWithInt:taskIndex]];
			paths = newPaths;
		}
	}
	
	//now start the last taskList if not empty
	if ( [taskList count]>0 )
		[self submitJobWithTaskList:taskList paths:paths];
	
}

//called every 'submissionInterval' seconds to submit more jobs
- (void)submitNextJobsWithTimer:(NSTimer *)timer
{
	NSTimeInterval interval;
	
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	//check consistency
	if (submissionTimer!=timer)
		[NSException raise:@"GEZMetaJobInconsistency"
					format:@"The ivar submissionTimer should be equal to the timer passed as argument to 'submitNextJobsWithTimer:'"];
	submissionTimer=nil;
	
	//Only submit more jobs if isRunning
	if ( [self isRunning]==NO )
		return;
	[self submitNextJobs];
	if ( [availableTasks count] < 1 )
		[self resetAvailableTasks];
	
	//fire a new timer
	interval = [[self valueForKey:@"submissionInterval"] intValue];
	submissionTimer=[NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(submitNextJobsWithTimer:) userInfo:nil repeats:NO];
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

- (void)start
{
	NSMutableSet *currentJobs;
	NSEnumerator *e;
	GEZJob *oneJob;
	
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	//update state
	if ( [self isRunning] )
		return;
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"isRunning"];
	[self setValue:@"Running" forKey:@"statusString"];
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
	[self submitNextJobsWithTimer:nil];
}

- (void)suspend
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);

	[self setValue:[NSNumber numberWithBool:NO] forKey:@"isRunning"];
	[self setValue:@"Suspended" forKey:@"statusString"];
	[submissionTimer invalidate];
	submissionTimer = nil;
	if ([[self delegate] respondsToSelector:@selector(metaJobDidSuspend:)])
		[[self delegate] metaJobDidSuspend:self];
}

- (void)deleteFromStore
{
	NSEnumerator *e;
	NSArray *jobs;
	GEZJob *aJob;

	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);

	//no more notifications
	[self setDelegate:nil];
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
}


#pragma mark *** GEZJob delegate methods ***

//MetaJob is a delegate of multiple GEZJob
//these are the GEZJob delegate methods

/*
 - (void)jobDidStart:(GEZJob *)aJob;
 - (void)jobDidNotStart:(GEZJob *)aJob;
 - (void)jobStatusDidChange:(GEZJob *)aJob;
 - (void)jobDidFinish:(GEZJob *)aJob;
 - (void)jobDidFail:(GEZJob *)aJob;
 - (void)jobWasDeleted:(GEZJob *)aJob fromGrid:(GEZGrid *)aGrid;
 - (void)jobWasNotDeleted:(GEZJob *)aJob;
 - (void)jobDidProgress:(GEZJob *)aJob completedTaskCount:(unsigned int)count;
 - (void)job:(GEZJob *) didReceiveResults:(NSDictionary *)results task:(GEZTask *)task;
*/ 


- (void)jobDidStart:(GEZJob *)aJob
{
	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);
}

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
		int failureCountsThreshold = [self failureCountsThreshold];
		if ( failureCountsThreshold > 0 && numberOfFailures == failureCountsThreshold ) {
			int numberOfSuccesses = [[self successCounts] intValueAtIndex:index];
			int successCountsThreshold = [self successCountsThreshold];
			if ( numberOfSuccesses < successCountsThreshold )
				[self incrementCountDismissedTasks];
		}
	}		
	
	//we can now dump the job
	[self removeJob:aJob];
}

- (void)jobDidFinish:(GEZJob *)aJob
{
	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);
}

/* TODO */
- (void)job:(GEZJob *)aJob didLoadResults:(NSDictionary *)results
{
	NSEnumerator *e;
	NSString *taskIdentifier;
	NSNumber *metaTaskIndex;
	NSDictionary *taskMap,*resultDictionary,*taskItem;
	GEZIntegerArray *successCounts, *failureCounts, *submissionCounts;
	int index;
	id dataSource;

	DLog(NSStringFromClass([self class]),10,@"[<%@:%p> %s %@]",[self class],self,_cmd,[aJob name]);
	DLog(NSStringFromClass([self class]),10,@"\nResults:\n%@",[results description]);

	//the taskMap allows to convert taskID in metaTaskIndex
	taskMap = [[aJob jobInfo] objectForKey:@"TaskMap"];
	if ( taskMap == nil )
		[NSException raise:@"GEZMetaJobError" format:@"No task map stored in the job"];

	
	//get the integer arrays used to keep track of submissions and successes
	successCounts = [self successCounts];
	failureCounts = [self failureCounts];
	submissionCounts = [self submissionCounts];
	
	//loop over the dictionary keys to return individual task results
	dataSource = [self dataSource];
	e = [results keyEnumerator];
	while ( taskIdentifier = [e nextObject] ) {
		
		//each task has: an index, a taskItem and a resultDictionary
		metaTaskIndex = [taskMap objectForKey:taskIdentifier];
		index = [metaTaskIndex intValue];
		taskItem = [dataSource metaJob:self taskAtIndex:index];
		resultDictionary = [results objectForKey:taskIdentifier];
		
		//the result dictionary can be divided in 3 pieces: the files, the sdout and the stderr
		NSMutableDictionary *resultFiles;
		resultFiles = [NSMutableDictionary dictionaryWithDictionary:resultDictionary];
		[resultFiles removeObjectForKey:GEZJobResultsStandardOutputKey];
		[resultFiles removeObjectForKey:GEZJobResultsStandardErrorKey];
		NSData *stdoutData, *stderrData;
		stdoutData = [resultDictionary objectForKey:GEZJobResultsStandardOutputKey];
		stderrData = [resultDictionary objectForKey:GEZJobResultsStandardErrorKey];

		//the data source may want to validate the results and decide if they are good or not
		BOOL resultsAreValid;
		if ( [dataSource respondsToSelector:@selector(metaJob:validateResultsWithFiles:standardOutput:standardError:forTask:)] )
			resultsAreValid = [dataSource metaJob:self validateResultsWithFiles:resultFiles standardOutput:stdoutData standardError:stderrData forTask:taskItem];
		else
			resultsAreValid = YES;

		//based on the validation result, the task was either a success or a failure
		//then, depending on how many successes and failures, the task could be considered completed or be dismissed
		int numberOfSuccesses,numberOfFailures;
		int successCountsThreshold = [self successCountsThreshold];
		int failureCountsThreshold = [self failureCountsThreshold];
		if ( resultsAreValid ) {
			numberOfSuccesses = [successCounts incrementIntValueAtIndex:index];
			numberOfFailures = [successCounts intValueAtIndex:index];
			if ( numberOfSuccesses == successCountsThreshold ) {
				[self incrementCountCompletedTasks];
				if ( failureCountsThreshold > 0 && numberOfFailures >= failureCountsThreshold )
					[self decrementCountDismissedTasks];
			}
		} else {
			numberOfSuccesses = [successCounts intValueAtIndex:index];
			numberOfFailures = [failureCounts incrementIntValueAtIndex:index];
			if ( ( failureCountsThreshold > 0 ) && ( numberOfFailures == failureCountsThreshold ) && ( numberOfSuccesses < successCountsThreshold ) )
				[self incrementCountDismissedTasks];
		}
			
		//some of the results may be handled by the data source, and if not they will be handled by the output interface
		BOOL shouldSaveStdout = YES;
		BOOL shouldSaveStderr = YES;
		BOOL shouldSaveFiles  = YES;
		NSMutableDictionary *resultsHandledByOutputInterface;
		resultsHandledByOutputInterface = [NSMutableDictionary dictionary];
		
		//if the results are valid, the data source is given a chance to save the results
		if ( resultsAreValid ) {
			if ( [dataSource respondsToSelector:@selector(metaJob:saveStandardOutput:forTask:)] 
				 && [dataSource metaJob:self saveStandardOutput:stdoutData forTask:taskItem] )
				shouldSaveStdout = NO;
			if ( [dataSource respondsToSelector:@selector(metaJob:saveStandardError:forTask:)]
				 && [dataSource metaJob:self saveStandardError:stderrData forTask:taskItem] )
				shouldSaveStderr = NO;
			if ( [dataSource respondsToSelector:@selector(metaJob:saveOutputFiles:forTask:)] 
				 && [dataSource metaJob:self saveOutputFiles:resultFiles forTask:taskItem] )
				shouldSaveFiles  = NO;
		}
		
		//if the results are not valid, they might still be handled by the output interface
		else if ( [[self valueForKey:@"shouldSaveFailedTasks"] boolValue] == NO ) {
			shouldSaveStdout = NO;
			shouldSaveStderr = NO;
			shouldSaveFiles  = NO;
		}
		
		//whatever is left to be saved will be handled by the output interface
		if ( ( shouldSaveStdout )  && ( stdoutData !=nil ) )
			[resultsHandledByOutputInterface setObject:stdoutData forKey:GEZJobResultsStandardOutputKey];
		if ( ( shouldSaveStderr ) && ( stderrData !=nil ) )
			[resultsHandledByOutputInterface setObject:stderrData forKey:GEZJobResultsStandardErrorKey];
		if ( shouldSaveFiles )
			[resultsHandledByOutputInterface addEntriesFromDictionary:resultFiles];
		
		//the path to use for the output interface is different for valid and invalid results
		//also, results are grouped in subfolders if more than the max allowed
		NSString *resultSubPath;
		if ( resultsAreValid )
			resultSubPath = @"";
		else
			resultSubPath = @"failures";
		int total = [[self countTotalTasks] intValue];
		int max = [[self valueForKey:@"maxTasksPerFolder"] intValue];
		if ( total > max ) {
			int start, end;
			start = index / max;
			start *= max;
			end = start + max - 1;
			NSString *rangeSubPath = [NSString stringWithFormat:@"%d-%d/",start,end];
			resultSubPath = [resultSubPath stringByAppendingPathComponent:rangeSubPath];
		}
		resultSubPath = [resultSubPath stringByAppendingPathComponent:[metaTaskIndex stringValue]];
		
		/*
		//create a folder only if one of the 'shouldSave' flag is YES (this prevents the creation of an empty folder when it does not make sense)
		if ( shouldSaveStdout || shouldSaveStderr || shouldSaveFiles )
			[[self outputInterface] saveFiles:resultsHandledByOutputInterface inFolder:resultSubPath duplicatesInSubfolder:@"results"];
		*/
	}
	
	//we are done with the job - delete it...
	[self removeJob:aJob];
}

@end


@implementation GEZMetaJob (GEZMetaJobPrivateAccessors)

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
