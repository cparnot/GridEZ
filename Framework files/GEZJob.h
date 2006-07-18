//
//  GEZJob.h
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



@class GEZGrid;
@class GEZServer;
@class GEZResults;

//keys used in the result dictionary of each task for the stdout and sterr data streams
//other keys are the paths (on the agent) of the new or modified files
extern NSString *GEZJobResultsStandardOutputKey;
extern NSString *GEZJobResultsStandardErrorKey;

@interface GEZJob : NSManagedObject
{
	XGJob *xgridJob;
	id delegate;
	XGActionMonitor *submissionAction;
	XGActionMonitor *deletionAction;
	NSDictionary *jobSpecification;
	unsigned int countDeletionAttempts;
	id jobInfo;
	GEZResults *results;
}

//Creating GEZJob objects
//Calling the methods below does not submit a job, it only creates one that can later be submitted using "submitJobWithSpecification:"
//The managed object will be attached to the context of the server (or grid) to which it is submitted, or to a custom context
+ (GEZJob *)job;
+ (GEZJob *)jobWithServer:(GEZServer *)server; //same rules as '-setServer:', see below
+ (GEZJob *)jobWithGrid:(GEZGrid *)grid; //same rules as '-setGrid:', see below
+ (GEZJob *)jobWithManagedObjectContext:(NSManagedObjectContext *)context;

//a job can be affected to a specific server or grid using the factory methods above, but this can still be set or changed using the accessors below
//	- if set before submission, the job will try to use it and will fail to start if the grid is disconnected
//	- if not set, or set to nil, the job will use the first available server connected
//	- after submission and even if the submission fails, the grid cannot be modified
//	- during submission, the grid may change several times, but will be fixed once the submission has successed or failed
//if the server (or grid) and the job objects are in different managed contexts, the equivalent server (and grid) in the correct managed object context will be used instead
- (void)setServer:(GEZServer *)newServer;
- (void)setGrid:(GEZGrid *)newGrid;


//the 'submit' method can only be used once on a given job
//the job specification is only cached during submission, and is discarded if submission succeeds or fails (this is because it can be big)
- (void)submitWithJobSpecification:(NSDictionary *)jobSpecification;


//this method is different from the other factory methods in that it creates a GEZJob object from a job already existing on the corresponding Xgrid server, and thus potentially submitted by another application; the managedObjectContext in which the new GEZJob lives is the same as the GEZGrid object; this factory method may or may not create a new GEZJob object on every call (so please do not assume one or the other); in general, you don't need to use this method as your application will usually only be interested in jobs it submitted itself; note that the job properties other than its identifier may not be available immediately if the corresponding grid is not connected, but everything will be uploaded as soon as connection is established
+ (GEZJob *)jobWithGrid:(GEZGrid *)grid identifier:(NSString *)identifier;

//the job will be stopped and then deleted from the Xgrid server and then from the managed object context. A notification is sent when the deletion is successful or if it failed
- (void)delete;

//the job is immediately deleted from the managed object context, but may remain in the xgrid controller
- (void)deleteFromStore;

//the job can be set to automatically load the results when it is finished (which may be immediately triggered if already finished)
//manual loading of the results with '-retrieveResults' can be called anytime, even before the job finishes for intermediary results, which will also cancel the automatic download (if not already started)
//the delegate will receive the results asynchronouly when all the task results have been loaded
//you need to wait until the results are loaded before calling '-retrieveResults' again (or else cancel the load first)
- (void)retrieveResults;
//- (void)cancelResultRetrieval; /*TODO*/
- (NSDictionary *)allFiles;
- (BOOL)shouldRetrieveResultsAutomatically;
- (void)setShouldRetrieveResultsAutomatically:(BOOL)flag;

//jobInfo can be used to store persistent information about the job (can be retrieved or modified even after submission, as opposed to the job specification)
//for persistent storage, the jobInfo object has to follow the NSCoding protocol
- (void)setJobInfo:(id)newJobInfo;
- (id)jobInfo;

//see below, the informal protocol for the delegate
- (id)delegate;
- (void)setDelegate:(id)newDelegate;

//checking the state of a job
//note that you can also check directly the status of the undelying XGJob and get a XGResourceState value
//none of these methods are KVO compliant (for now)
- (XGResourceState)xgridJobState;
- (BOOL)isSubmitting;
- (BOOL)isSubmitted;
- (BOOL)isRetrievingResults;
- (BOOL)isRetrieved;
- (BOOL)isDeleting;
- (BOOL)isDeleted;

//KVO/KVC-compliant accessors
- (NSString *)name;
- (NSString *)status;
- (unsigned int)taskCount;
- (unsigned int)completedTaskCount;
- (GEZServer *)server;
- (GEZGrid *)grid;

@end


//methods that can be implemented by the GEZJob delegate
@interface NSObject (GEZJobDelegate)
- (void)jobDidSubmit:(GEZJob *)aJob;
- (void)jobDidNotSubmit:(GEZJob *)aJob;
- (void)jobDidStart:(GEZJob *)aJob;
- (void)jobDidFinish:(GEZJob *)aJob;
- (void)jobDidFail:(GEZJob *)aJob;
- (void)jobWasDeleted:(GEZJob *)aJob fromGrid:(GEZGrid *)aGrid;
- (void)jobWasNotDeleted:(GEZJob *)aJob;
- (void)jobDidProgress:(GEZJob *)aJob completedTaskCount:(unsigned int)count;
- (void)jobDidRetrieveResults:(GEZJob *)aJob;
@end
