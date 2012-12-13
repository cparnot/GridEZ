//
//  GEZMetaJob.h
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

/**

An GEZMetaJob object encapsulates an array of tasks that need to be completed. The MetaJob object takes care of the scheduling and submission of jobs (GEZJob instances). There can be several jobs for one MetaJob. In fact, this is the whole point of a MetaJob: automatically manage a bunch of jobs to get a list of tasks done. This may involve several submissions of the same task, handling failures,...

A MetaJob works hand-in-hand with its data source, that will provide the description of the tasks, and will take care of validating and saving the results, as they comeback.

A MetaJob can also have a delegate.

If the data source (or the delegate) is a NSManagedObject living in the same context, it will be remembered between restarts (assuming there is also a persistent store saved on disk).

*/



@class GEZJob;
@class GEZGrid;
@class GEZServer;

//these keys can be used to submit tasks to a meta job, via its data source
//see data source method
extern NSString *GEZTaskSubmissionCommandKey;
extern NSString *GEZTaskSubmissionArgumentsKey;
extern NSString *GEZTaskSubmissionStandardInputKey;
extern NSString *GEZTaskSubmissionUploadedPathsKey;

@interface GEZMetaJob : NSManagedObject
{
	NSMutableIndexSet *availableTasks; //keep track of the indexes of the available commands = not running, not done
	NSTimer *submissionTimer;
}

//this is the recommanded way to create a metaJob, no -init, no -insertNewObjectForEntityForName...
+ (GEZMetaJob *)metaJobWithName:(NSString *)name;
+ (GEZMetaJob *)metaJobWithManagedObjectContext:(NSManagedObjectContext *)context;

//controlling GEZMetaJob
- (void)start;
- (BOOL)isRunning;
- (void)suspend; //stop submitting more jobs
- (void)deleteFromStore;

//GEZMetaJob general settings
- (NSString *)name;
- (void)setName:(NSString *)name;
- (id)dataSource;
- (void)setDataSource:(id)newDataSource;
- (id)delegate;
- (void)setDelegate:(id)newDelegate;

//GEZMetaJob can be set to submit to several grids, trying to be smart about which one to use; the NSSet 'grids' contains only GEZGrid or GEZServer objects
/* TODO: document the smartness */
- (NSSet *)grids;
- (NSSet *)servers;
- (void)setGrids:(NSSet *)grids;
- (void)setServers:(NSSet *)servers;
- (void)addGridsObject:(GEZGrid *)value;
- (void)removeGridsObject:(GEZGrid *)value;
- (void)addServersObject:(GEZServer *)value;
- (void)removeServersObject:(GEZServer *)value;


//GEZMetaJob submission settings
- (int)minSuccessesPerTask;
- (int)maxFailuresPerTask;
- (int)maxSubmissionsPerTask;
- (int)tasksPerJob;
- (long)maxBytesPerJob;
- (int)maxSubmittedTasks;
- (void)setMinSuccessesPerTask:(int)newMinSuccessesPerTask;
- (void)setMaxFailuresPerTask:(int)newMaxFailuresPerTask;
- (void)setMaxSubmissionsPerTask:(int)newMaxSubmissionsPerTask;
//this is a suggested number which cannot and will not always be achieved; if set to 0, the metajob will try to be smart and guess the best number to use (there might be a learning phase before a supposedly optimal number is reached)
- (void)setTasksPerJob:(int)newTasksPerJob;
- (void)setMaxBytesPerJob:(long)aValue;
- (void)setMaxSubmittedTasks:(int)newMaxSubmittedTasks;
- (BOOL)shouldDeleteJobsAutomatically;
- (void)setShouldDeleteJobsAutomatically:(BOOL)aValue;

//info about the individual tasks
- (int)countFailuresForTaskAtIndex:(int)index;
- (int)countSuccessesForTaskAtIndex:(int)index;
- (int)countSubmissionsForTaskAtIndex:(int)index;
- (NSString *)statusStringForTaskAtIndex:(int)index;


//info about the MetaJob, useful for GUI bindings too
- (NSString *)status;
- (NSNumber *)countTotalTasks;
- (NSNumber *)countDoneTasks; //Completed+Dismissed
- (NSNumber *)countPendingTasks;//not done
- (NSNumber *)percentDone;
- (NSNumber *)percentPending;
- (NSNumber *)percentCompleted; //successfully completed at least minSuccessesPerTask times
- (NSNumber *)percentDismissed; //failed at least maxFailuresPerTask times
- (NSNumber *)percentSubmitted;

@end



// GEZMetaJob data source methods
@interface NSObject (GEZMetaJobDataSource)

//TO REMOVE??
//- (BOOL)initializeTasksForMetaJob:(GEZMetaJob *)metaJob;


/**
the data source should return the number of tasks it wants to run; this number can change but you might have to call 'start' on the meta job to make sure the change is taken into account */
- (unsigned int)numberOfTasksForMetaJob:(GEZMetaJob *)aJob;

/**
 The data source should describe the task at the given index in the returned object. The object returned by the dataSource can be of any class, but should respond in a sensible way to the following KVC calls (i n other words, the GEZMetaJob instance will call 'valueForKey:' on the following keys). It can return nil for some of the keys (a dummy task will be created if the returned values do not make sense), so it does not have to implement a formal protocol. It does not even have to implement an informal protocol (like a delegate), as it only needs to respond to 'valueForKey:'. In most cases, you would return an NSDictionary, but the returned object could be more complex if needed.
 
 - @"command" key (GEZTaskSubmissionCommandKey) : a string with a path to an executable.
    This should be almost always be an absolute path for the following reasons. If this path is in the list of "uploaded paths" (see below), it will be uploaded to the agents and will become a relative path in the working directory (hence GEZMetaJob needs to know the absolute path).  If this path is not in the list of uploaded paths, the command string will be used as is on the agent and will assume that the executable is already on the agent at this exact path. For instance, the command string could be "/bin/ls", which does not need to be uploaded on the agent, and which should work as is on any Mac OS X machine (thus on any Mac OS X agent).
 
 - @"arguments" key (GEZTaskSubmissionArgumentsKey) : an array of strings, that may include paths.
	The same rule as the one for the command applies for arguments that are identical to one of the "uploaded paths". If such a path is recognized in the list, the argument string will be modified so that it will work on the agent as a relative path.

 - @"standardInput" key (GEZTaskSubmissionStandardInputKey) : NSString or NSData for the standard input.
	The string or the data is used as the standard input for the taks, with one exception: if it is a string and the string is an absolute path to an existing file, the meta job will use instead the contents of that file. Be careful to use only immutable objects. Do not use NSMutableString or NSMutableData.

 - @"uploadedPaths" key (GEZTaskSubmissionUploadedPathsKey) : list of paths to files that should be uploaded  on the agents
	The listed paths should be absolute paths. If the path points to a folder, a corresponding folder will be created on the agent, but the contents of that folder won't be uploaded. You have to list all the paths to all the files you really want on the agent. These absolute paths will become relative paths on the agent, in the working directory usually located in /var/xgrid/agent/. Usually, the uploaded files will be uploaded directly at the root of the working directory, and none of the parent folder will be created. You can force deeper folder hierachies to be created on the agent by including paths to parent folders in the list of "uploaded paths". This might be necessary if you want to use hard-coded indirect paths such as '../foo' or '../../bar' in the script you want to run (assuming you run a script on the agent) or in your arguments. In other words, the GEZMetaJob will take the list of absolute paths and make it as flat as it can in the agent working directory. Here is an example:
 
			 Uploaded paths                             Files on the agent
			 -------------------                        ------------------
			 /Users/username/Documents/dir1             dir1
			 /Users/username/Documents/dir1/file1       dir1/file1
			 /Users/username/Documents/dir1/file2       dir1/file2
			 /etc/myfiles/param1                        param1
			 /etc/mydir                                 mydir
			 /etc/mydir/settings1.txt                   mydir/settings1.txt
			 /etc/mydir/settings2.txt                   mydir/settings2.txt
 

*/

- (id)metaJob:(GEZMetaJob *)metaJob taskAtIndex:(unsigned int)taskIndex;

/**
This method is called when the results of a task run come back. The implementation of this method is optional, and the metajob will assume the results are valid if the XGJob finished with no failure. Note that the same task index could be run several times (several "runs"), depending on the metajob settings (for instance, the same task could be submitted several times if all the other tasks are done and there are several agents available, that might as well be all used). If the method is implemented, the data source has the opportunity to do 2 things here:
 
 - Process the results in whichever way is needed. The result dictionary contains a list of "files". The key for each entry is the path of a file in the working directory on the agent (note that only new and modified files are returned). There are 2 special keys used for the standard error and the standart ouput streams, which are defined in GEZJob header: GEZJobResultsStandardOutputKey and GEZJobResultsStandardErrorKey. The values associated with these keys are NSData instances containing the file bytes.
 
 - Validate the results. You might decide to always return YES, or implement more filtering to automatically rerun task that have for example failed to create some of the files you expected. If the method returns NO, this run will be considered failed. If you set 'maxFailuresPerTask', the task will not be submitted anymore when that threshold is reached and will be considered "Dismissed". If the method returns YES, this run will be considered successful. If you set 'minSuccessesPerTask' (default is 1), the task will have to run successfully several times until it reaches that threshold, at which point it will be considered "Completed" (this is a way to "double-check" the results).

 */

- (BOOL)metaJob:(GEZMetaJob *)metaJob validateTaskAtIndex:(int)taskIndex results:(NSDictionary *)results;

/*
- (NSString *)metaJob:(GEZMetaJob *)metaJob commandStringForTask:(id)task;
- (NSArray *)metaJob:(GEZMetaJob *)metaJob argumentStringsForTask:(id)task;
- (NSArray *)metaJob:(GEZMetaJob *)metaJob pathsToUploadForTask:(id)task;
- (NSString *)metaJob:(GEZMetaJob *)metaJob stdinPathForTask:(id)task;

- (BOOL)metaJob:(GEZMetaJob *)metaJob validateResultsWithFiles:(NSDictionary *)dictionaryRepresentation standardOutput:(NSData *)stdoutData standardError:(NSData *)stderrData forTask:(id)task;
- (BOOL)metaJob:(GEZMetaJob *)metaJob saveStandardOutput:(NSData *)data forTask:(id)task;
- (BOOL)metaJob:(GEZMetaJob *)metaJob saveStandardError:(NSData *)data forTask:(id)task;
- (BOOL)metaJob:(GEZMetaJob *)metaJob saveOutputFiles:(NSDictionary *)dictionaryRepresentation forTask:(id)task;

//- (BOOL)metaJob:(GEZMetaJob *)metaJob saveResults:(NSDictionary *)results forTask:(id)task;
*/

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

