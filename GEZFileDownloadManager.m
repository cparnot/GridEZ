//
//  GEZFileDownloadManager.m
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



#import "GEZFileDownloadManager.h"

#define GRIDEZ_DEFAULT_MAX_FILE_DOWNLOADS 4


static NSString *XgridFileKey = @"XgridFileKey";
static NSString *DelegateKey = @"DelegateKey";
static NSString *XgridFileDownloadKey = @"XgridFileDownloadKey";
static NSString *FileDataKey = @"FileDataKey";

@interface GEZFileDownloadManager (GEZFileDownloadManagerPrivate)
- (void)startDownloads;
@end

@implementation GEZFileDownloadManager

#pragma mark *** Initializations ***

static id _sharedFileDownloadManager = nil;
+ (id)sharedFileDownloadManager
{
	if ( _sharedFileDownloadManager == nil )
		_sharedFileDownloadManager = [[self alloc] init];
	return _sharedFileDownloadManager;
}

- (id)init
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);

	self = [super init];
	if ( self != nil ) {
		fileQueue = nil; //lazy instantiation
		maxFileDownloads = GRIDEZ_DEFAULT_MAX_FILE_DOWNLOADS;
	}
	return self;
}

- (void)dealloc
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);
	[fileQueue release];
	[super dealloc];
}


#pragma mark *** Accessors ***

//lazy instantiation - dealloced when not in use anymore (just a gut feeling this might be better than having the same NSMutableArray used all the time during the whole lifetime of the app)
- (NSMutableArray *)fileQueue
{
	if ( fileQueue == nil )
		fileQueue = [[NSMutableArray alloc] init];
	return fileQueue;
}

- (void)setMaxFileDownloads:(int)value
{
	maxFileDownloads = value;
}

- (int)maxFileDownloads
{
	return maxFileDownloads;
}

- (void)addFile:(XGFile *)xgridFile delegate:(id)delegate
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);

	//printf("%d files in the queue (+1)\n", [fileQueue count]);
	[[self fileQueue] addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		xgridFile, XgridFileKey,
		delegate, DelegateKey,
		nil]];
	[self startDownloads];
}


@end

@implementation GEZFileDownloadManager (GEZFileDownloadManagerPrivate)

#pragma mark *** Running the queue ***

- (void)startDownloads
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);

	NSEnumerator *e = [fileQueue objectEnumerator];
	NSMutableDictionary *fileDictionary;
	int i;
	for ( i = 0 ; ( i < maxFileDownloads ) && ( fileDictionary = [e nextObject] ) ; i++ ) {
		if ( [fileDictionary objectForKey:XgridFileDownloadKey] == nil ) {
			
			//create the XGFileDownload which will also trigger the download
			XGFileDownload *aFileDownload = [[XGFileDownload alloc] initWithFile:[fileDictionary objectForKey:XgridFileKey] delegate:self];
			[fileDictionary setObject:aFileDownload forKey:XgridFileDownloadKey];
			[aFileDownload release];
			//printf("%d files in the queue [+1 download])\n", [fileQueue count]);
			
			//create the mutable data object that will hold the data
			NSMutableData *fileData = [NSMutableData data];
			[fileDictionary setObject:fileData forKey:FileDataKey];
		}
	}
	[e allObjects];
}

- (void)removeFileDictionary:(NSMutableDictionary *)fileDictionary
{
	//printf("%d files in the queue (-1))\n", [fileQueue count]);
	[[fileDictionary retain] autorelease];
	[fileQueue removeObjectIdenticalTo:fileDictionary];
	if ( [fileQueue count] < 1 ) {
		//NSLog(@"file queue is empty");
		[fileQueue autorelease];
		fileQueue = nil;
	} else
		[self startDownloads];
}

#pragma mark *** Handling XGFileDownload delegate methods ***


//find the corresponding entry in the fileQueue
- (NSMutableDictionary *)fileDictionaryForFileDownload:(XGFileDownload *)fileDownload
{
	NSEnumerator *e = [fileQueue objectEnumerator];
	NSMutableDictionary *fileDictionary = nil;
	int i;
	for ( i = 0 ; i < maxFileDownloads ; i++ ) {
		fileDictionary = [e nextObject];
		if ( [fileDictionary objectForKey:XgridFileDownloadKey] == fileDownload )
			i = maxFileDownloads;
	}

	//should never be nil, but just in case
	if ( fileDictionary == nil )
		NSLog(@"Unexpected call to delegate method on GEZFileDownloadManager, for XGFileDownload %@, corresponding to file %@ for job %@ '%@' at path %@", fileDownload, [fileDownload file], [[fileDownload file] job], [[[fileDownload file] job] name], [[fileDownload file] path]);

	return fileDictionary;
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
	NSMutableData *fileData = [[self fileDictionaryForFileDownload:fileDownload] objectForKey:FileDataKey];
	[fileData appendData:data];
}

//This method is called when the download has failed
- (void)fileDownload:(XGFileDownload *)fileDownload didFailWithError:(NSError *)error
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);

	//printf("%d files in the queue [FAILURE]\n", [fileQueue count]);

	//notify delegate
	NSMutableDictionary *fileDictionary = [self fileDictionaryForFileDownload:fileDownload];
	id delegate = [fileDictionary objectForKey:DelegateKey];
	if ( [delegate respondsToSelector:@selector(fileDownloadManager:didFailToRetrieveFile:error:)] )
		[delegate fileDownloadManager:self didFailToRetrieveFile:[fileDictionary objectForKey:XgridFileKey] error:error];
	
	//remove file from queue
	[self removeFileDictionary:fileDictionary];
}

//This method is called when the download has finished downloading
- (void)fileDownloadDidFinish:(XGFileDownload *)fileDownload
{
	DLog(NSStringFromClass([self class]),12,@"[%@:%p %s]",[self class],self,_cmd);

	//notify delegate
	NSMutableDictionary *fileDictionary = [self fileDictionaryForFileDownload:fileDownload];
	id delegate = [fileDictionary objectForKey:DelegateKey];
	if ( [delegate respondsToSelector:@selector(fileDownloadManager:didRetrieveFile:data:)] )
		[delegate fileDownloadManager:self didRetrieveFile:[fileDictionary objectForKey:XgridFileKey] data:[fileDictionary objectForKey:FileDataKey]];
	
	//remove file from queue
	[self removeFileDictionary:fileDictionary];
}

@end

