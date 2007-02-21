//
//  GEZResults.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import "GEZResults.h"


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
	
	//prepare the downloads mutable set that will hold the pending XGFileDownload
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
	
	//prepare the downloads mutable set that will hold the pending XGFileDownload
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


//private method used to handle outcome of streamsMonitor and filesMonitor
//results = dictionary of dictionaries, one dictionary per taskIdentifier
- (void)downloadFiles:(NSArray *)files
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	DLog(NSStringFromClass([self class]),10,@"\nFiles:\n%@", [files description]);
	
	XGFile *aFile;
	NSEnumerator *e = [files objectEnumerator];
	while ( aFile = [e nextObject] ) {
		
		//the taskIdentifier is the key to a resultDictionary
		NSString *taskIdentifier = [aFile taskIdentifier];
		
		//retrieve the resultDictionary from the results dictionary, creating it if necessary
		NSMutableDictionary *resultDictionary = [results objectForKey:taskIdentifier];
		if ( resultDictionary == nil ) {
			resultDictionary = [[NSMutableDictionary alloc] init];
			[results setObject:resultDictionary forKey:taskIdentifier];
		}
		
		//create the data object that will hold the data
		NSMutableData *fileData = [NSMutableData data];
		[resultDictionary setObject:fileData forKey:[aFile path]];
		
		//start the download
		XGFileDownload *aFileDownload = [[XGFileDownload alloc] initWithFile:aFile delegate:self];
		[downloads addObject:aFileDownload];
		[aFileDownload release];
		
	}
}




#pragma mark *** Handling XGFileDownload delegate methods ***

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

/*
 - (void)fileDownloadDidBegin:(XGFileDownload *)fileDownload
 {
	 
 }
 */

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

@end


