//
//  GEZResults.m
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



#import "GEZResults.h"
#import "GEZFileDownloadManager.h"

@interface GEZResults (GEZResultsPrivate)
- (void)checkDidLoadResults;
@end

@implementation GEZResults

#pragma mark *** Public methods ***

- (id)initWithXgridJob:(XGJob *)job
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	self = [super init];
	if ( self !=nil ) {
		xgridJob = [job retain];
		isRetrieving = NO;
	}
	return self;
}

- (void)dealloc
{
	[streamsMonitor removeObserver:self forKeyPath:@"outcome"];
	[filesMonitor removeObserver:self forKeyPath:@"outcome"];
	
	[streamsMonitor release];
	[filesMonitor release];
	[downloads release];
	[results release];
	[xgridJob release];
	
	delegate = nil;
	
	[super dealloc];
}

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"%@",self];
}

#pragma mark *** Public methods ***

- (void)retrieve
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	
	if ( isRetrieving || xgridJob == nil )
		return;
	isRetrieving == YES;
	
	//prepare the result dictionary that will hold the results
	[results release];
	results = [[NSMutableDictionary alloc] initWithCapacity:[xgridJob taskCount]];
	
	//prepare the downloads mutable set that will hold the pending XGFile
	[downloads release];
	downloads = [[NSMutableSet alloc] init];
	
	//start the result retrieval process
	[streamsMonitor release];
	[filesMonitor release];
	streamsMonitor = [[xgridJob performGetOutputStreamsAction] retain];
	filesMonitor   = [[xgridJob performGetOutputFilesAction]   retain];
	[streamsMonitor addObserver:self forKeyPath:@"outcome" options:0 context:NULL];
	[filesMonitor   addObserver:self forKeyPath:@"outcome" options:0 context:NULL];
	
}

//temporary version to retrieve only streams
- (void)retrieveStreams
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	
	if ( isRetrieving || xgridJob == nil )
		return;
	isRetrieving == YES;
	
	//prepare the result dictionary that will hold the results
	[results release];
	results = [[NSMutableDictionary alloc] initWithCapacity:[xgridJob taskCount]];
	
	//prepare the downloads mutable set that will hold the pending XGFile
	[downloads release];
	downloads = [[NSMutableSet alloc] init];
	
	//start the result retrieval process
	[streamsMonitor release];
	[filesMonitor release];
	streamsMonitor = [[xgridJob performGetOutputStreamsAction] retain];
	filesMonitor   = nil;
	[streamsMonitor addObserver:self forKeyPath:@"outcome" options:0 context:NULL];
	
}


- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)newDelegate
{
	//weak linking
	delegate = newDelegate;
}

- (BOOL)isDone
{
	return NO;
}

//GEZResults is in fact non-mutable, and the results will not change once done
- (NSDictionary *)allFiles
{
	if ( isRetrieving )
		return [NSDictionary dictionary];
	else
		return [[results retain] autorelease];
}


/*
- (void)cancelLoadResults
{
	NSEnumerator *e;
	XGFileDownload *aFileDownload;
	
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	
	//stop the action monitors
	[streamsMonitor removeObserver:self forKeyPath:@"outcome"];
	[streamsMonitor release];
	streamsMonitor = nil;
	[filesMonitor removeObserver:self forKeyPath:@"outcome"];
	[filesMonitor release];
	filesMonitor = nil;	
	
	//stop the file downloads
	e = [downloads objectEnumerator];
	while ( aFileDownload = [e nextObject] )
		[aFileDownload cancel];
	[downloads release];
	downloads = nil;
	
	//empty the results
	[results release];
	results = nil;
}
*/

@end

@implementation GEZResults (GEZResultsPrivate)

#pragma mark *** Getting the list of files ***

//private method used to handle outcome of streamsMonitor and filesMonitor
- (void)downloadFiles:(NSArray *)files
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	DLog(NSStringFromClass([self class]),10,@"\nFiles:\n%@", [files description]);

	//add the files to the download queue of GEZFileDownloadManager
	XGFile *aFile;
	NSEnumerator *e = [files objectEnumerator];
	while ( aFile = [e nextObject] )
		[[GEZFileDownloadManager sharedFileDownloadManager] addFile:aFile delegate:self];

	//the downloads ivar is used to keep track of which XGFile are still pending
	[downloads addObjectsFromArray:files];

}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@\nObject = <%@:%p>\nKey Path = %@\nChange = %@",[self class],self,_cmd, [self shortDescription], [object class], object, keyPath, [change description]);
	
	if ( object==streamsMonitor && [keyPath isEqualToString:@"outcome"]==YES ) {
		DLog(NSStringFromClass([self class]),10,@"Object = Streams Monitor");
		[self downloadFiles:[[streamsMonitor results] objectForKey:XGActionMonitorResultsOutputStreamsKey]];
		[streamsMonitor removeObserver:self forKeyPath:@"outcome"];
		[streamsMonitor release];
		streamsMonitor = nil;
		[self checkDidLoadResults];
	}
	
	else if ( object==filesMonitor && [keyPath isEqualToString:@"outcome"]==YES ) {
		DLog(NSStringFromClass([self class]),10,@"Object = Files Monitor");
		[self downloadFiles:[[filesMonitor results] objectForKey:XGActionMonitorResultsOutputFilesKey]];
		[filesMonitor removeObserver:self forKeyPath:@"outcome"];
		[filesMonitor release];
		filesMonitor = nil;
		[self checkDidLoadResults];
	}
	
}




#pragma mark *** GEZFileDownloadManager delegate ***

- (BOOL)resultsDidLoad
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);
	if ( results == nil )
		return NO;
	if ( [downloads count]==0 && streamsMonitor==nil && filesMonitor==nil )
		return YES;
	else
		return NO;
}

//this methods checks if the results are all loaded and ready
- (void)checkDidLoadResults
{
	if ( [delegate respondsToSelector:@selector(didRetrieveResults:)] && [self resultsDidLoad] )
		[delegate didRetrieveResults:self];
}


//the file data are stored in the 'results' ivar, which is a dictionary of dictionaries; there is one dictionary per taskIdentifier, and then the subdictionary stores the data in the value, and use the paths for the keys
/*
 Example dictionary

results = {
	0 = {
			'file1.txt' = <dGhpcyBpcyBhIHRlc3Q=...>,
			'dir1/file2.txt' = <abcdefgh1234566789...>
	} ,
	1 = {
		'image.png' = <somedatatattata...>,
		'stdout' = <morebytesbytes...>,
		....
	} ,
	...
}
 */

- (void)fileDownloadManager:(GEZFileDownloadManager *)manager didRetrieveFile:(XGFile *)xgridFile data:(NSData *)fileData
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);
	
	//the taskIdentifier is the key to a dictionary that will contains the files for the task
	NSString *taskIdentifier = [xgridFile taskIdentifier];
	
	//retrieve the resultDictionary from the results dictionary, creating it if necessary
	NSMutableDictionary *resultDictionary = [results objectForKey:taskIdentifier];
	if ( resultDictionary == nil ) {
		resultDictionary = [NSMutableDictionary dictionary];
		[results setObject:resultDictionary forKey:taskIdentifier];
	}
	
	//add the data object using the path as the key
	[resultDictionary setObject:fileData forKey:[xgridFile path]];
	
	//remove the file from the list of downloads
	[[xgridFile retain] autorelease];
	[downloads removeObject:xgridFile];
	[self checkDidLoadResults];
	
}

//in case of error, we simply resubmit to GEZFileDownloadManager, hoping it will work better...
- (void)fileDownloadManager:(GEZFileDownloadManager *)manager didFailToRetrieveFile:(XGFile *)xgridFile error:(NSError *)error
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);
	[[GEZFileDownloadManager sharedFileDownloadManager] addFile:xgridFile delegate:self];
}


/*
 - (void)fileDownloadDidBegin:(XGFileDownload *)fileDownload
 {
	 
 }
 */

/*
 //This method is called when the download has loaded data
 - (void)fileDownload:(XGFileDownload *)fileDownload didReceiveData:(NSData *)data
 {
	 DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);
	 
	 NSString *taskIdentifier = [[fileDownload file] taskIdentifier];
	 NSDictionary *resultDictionary =  [results objectForKey:taskIdentifier];
	 NSMutableData *fileData = [resultDictionary objectForKey:[[fileDownload file] path]];
	 [fileData appendData:data];
	 
	 DLog(NSStringFromClass([self class]),15,@"File contents:\n%@",[NSString stringWithCString:[fileData bytes] length:[fileData length]]);
 }
 
 //This method is called when the download has failed
 - (void)fileDownload:(XGFileDownload *)fileDownload didFailWithError:(NSError *)error
 {
	 DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);
	 
	 NSString *taskIdentifier = [[fileDownload file] taskIdentifier];
	 [[results objectForKey:taskIdentifier] removeObjectForKey:[[fileDownload file] path]];
	 [downloads removeObject:fileDownload];
	 [self checkDidLoadResults];
 }
 
 //This method is called when the download has finished downloading
 - (void)fileDownloadDidFinish:(XGFileDownload *)fileDownload
 {
	 DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);
	 [downloads removeObject:fileDownload];
	 [self checkDidLoadResults];
 }
 */

@end


