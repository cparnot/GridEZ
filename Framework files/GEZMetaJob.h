//
//  GEZMetaJob.h
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */

/**

An GEZMetaJob object encapsulates an array of tasks that need to be completed. The MetaJob object takes care of the scheduling and submission of jobs (GEZJob instances). There can be several jobs for one MetaJob. In fact, this is the whole point of a MetaJob: automatically manage a bunch of jobs to get a list of tasks done. This may involve several submissions of the same task, handling failures,...

A MetaJob works hand-in-hand with its data source, that will provide the description of the tasks, and will take care of validating and saving the results, as they comeback.

A MetaJob can also have a delegate.

If the data source (or the delegate) is a NSManagedObject living in the same context, it will be remembered between restarts (assuming there is also a persistent store saved on disk).

*/



@class GEZJob;
@class GEZGrid;

@interface GEZMetaJob : NSManagedObject
{
	NSMutableIndexSet *availableTasks; //keep track of the indexes of the available commands = not running, not done
	NSTimer *submissionTimer;
}

- (id)dataSource;
- (void)setDataSource:(id)newDataSource;
- (id)delegate;
- (void)setDelegate:(id)newDelegate;
- (NSString *)name;
- (void)setName:(NSString *)name;

- (void)start;
- (BOOL)isRunning;
- (void)suspend; //stop submitting more jobs
- (void)deleteFromStore;

//info about the MetaJob
- (NSNumber *)countTotalTasks;
- (NSNumber *)countDoneTasks;
- (NSNumber *)countPendingTasks;
- (NSNumber *)percentDone;
- (NSNumber *)percentPending;
- (NSNumber *)percentCompleted;
- (NSNumber *)percentDismissed;
- (NSNumber *)percentSubmitted;

//info about the individual tasks
- (int)countFailuresForTaskAtIndex:(int)index;
- (int)countSuccessesForTaskAtIndex:(int)index;
- (int)countSubmissionsForTaskAtIndex:(int)index;
- (NSString *)statusStringForTaskAtIndex:(int)index;

//short description, handy for debugging
- (NSString *)shortDescription;

//MetaJob is a delegate of multiple GEZJob
//these are GEZJob delegate methods
- (void)jobDidNotStart:(GEZJob *)aJob;
- (void)jobDidFinish:(GEZJob *)aJob;
- (void)jobDidFail:(GEZJob *)aJob;
- (void)job:(GEZJob *)aJob didLoadResults:(NSDictionary *)results;

@end


/* the methods declared here provide public typed accessors for CoreData properties of GEZMetaJob */
@interface GEZMetaJob (GEZMetaJobAccessors)
- (int)successCountsThreshold;
- (int)failureCountsThreshold;
- (int)maxSubmissionsPerTask;
- (void)setFailureCountsThreshold:(int)failureCountsThresholdNew;
- (void)setMaxSubmissionsPerTask:(int)maxSubmissionsPerTaskNew;
- (void)setSuccessCountsThreshold:(int)successCountsThresholdNew;

@end


// GEZMetaJob data source methods
@interface NSObject (GEZMetaJobDataSource)

- (BOOL)initializeTasksForMetaJob:(GEZMetaJob *)metaJob;
- (unsigned int)numberOfTasksForMetaJob:(GEZMetaJob *)aJob;
- (id)metaJob:(GEZMetaJob *)metaJob taskAtIndex:(unsigned int)taskIndex;

- (NSString *)metaJob:(GEZMetaJob *)metaJob commandStringForTask:(id)task;
- (NSArray *)metaJob:(GEZMetaJob *)metaJob argumentStringsForTask:(id)task;
- (NSArray *)metaJob:(GEZMetaJob *)metaJob pathsToUploadForTask:(id)task;
- (NSString *)metaJob:(GEZMetaJob *)metaJob stdinPathForTask:(id)task;

- (BOOL)metaJob:(GEZMetaJob *)metaJob validateResultsWithFiles:(NSDictionary *)dictionaryRepresentation standardOutput:(NSData *)stdoutData standardError:(NSData *)stderrData forTask:(id)task;
- (BOOL)metaJob:(GEZMetaJob *)metaJob saveStandardOutput:(NSData *)data forTask:(id)task;
- (BOOL)metaJob:(GEZMetaJob *)metaJob saveStandardError:(NSData *)data forTask:(id)task;
- (BOOL)metaJob:(GEZMetaJob *)metaJob saveOutputFiles:(NSDictionary *)dictionaryRepresentation forTask:(id)task;

//- (BOOL)metaJob:(GEZMetaJob *)metaJob saveResults:(NSDictionary *)results forTask:(id)task;

@end


// GEZMetaJob delegate methods
@interface NSObject(GEZMetaJobDelegate)
- (void)metaJobDidStart:(GEZMetaJob *)metaJob;
- (void)metaJobDidSuspend:(GEZMetaJob *)metaJob;
- (void)metaJob:(GEZMetaJob *)metaJob didSubmitTaskAtIndex:(int)index;
- (void)metaJob:(GEZMetaJob *)metaJob didProcessTaskAtIndex:(int)index;
@end
	
/*
// GEZMetaJob delegate methods
@interface NSObject(GEZMetaJobDelegate)
- (void)didStartMetaJob:(GEZMetaJob *)metaJob;
- (void)didFinishMetaJob:(GEZMetaJob *)metaJob;
- (BOOL)metaJob:(GEZMetaJob *)metaJob shouldSubmitTask:(NSDictionary *)info;
- (void)metaJob:(GEZMetaJob *)metaJob didSubmitTask:(NSDictionary *)info identifier:(NSString *)jobID;
- (void)metaJob:(GEZMetaJob *)metaJob didCancelTask:(NSDictionary *)info identifier:(NSString *)jobID;
- (void)metaJob:(GEZMetaJob *)metaJob didFailTask:(NSDictionary *)info identifier:(NSString *)jobID;
- (void)metaJob:(GEZMetaJob *)metaJob didReceiveEmptyResultsForTask:(NSDictionary *)info identifier:(NSString *)jobID;
- (void)metaJob:(GEZMetaJob *)metaJob didFinishTask:(NSDictionary *)info identifier:(NSString *)jobID;
- (void)metaJob:(GEZMetaJob *)metaJob didProcessTask:(NSDictionary *)info success:(BOOL)flag identifier:(NSString *)jobID;
- (void)metaJob:(GEZMetaJob *)metaJob latestSTDOUT:(NSString *)aString forTask:(NSDictionary *)info identifier:(NSString *)jobID;
- (void)metaJob:(GEZMetaJob *)metaJob latestSTDERR:(NSString *)aString forTask:(NSDictionary *)info identifier:(NSString *)jobID;
*/

