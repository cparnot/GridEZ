//
//  GEZFileDownloadManager.m
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
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

