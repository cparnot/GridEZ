//
//  GEZFileDownloadManager.h
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


/* Private class used to queue file downloads and limit  the number of concurrent requests */

#import <Cocoa/Cocoa.h>


@interface GEZFileDownloadManager : NSObject
{
	NSMutableArray *fileQueue;
	int maxFileDownloads;
}

+ (id)sharedFileDownloadManager;

- (void)addFile:(XGFile *)xgridFile delegate:(id)delegate;

- (void)setMaxFileDownloads:(int)value;
- (int)maxFileDownloads;


@end


//protocol for the delegates
@interface NSObject (GEZFileDownloadManagerDelegate)
- (void)fileDownloadManager:(GEZFileDownloadManager *)manager didRetrieveFile:(XGFile *)xgridFile data:(NSData *)fileData;
- (void)fileDownloadManager:(GEZFileDownloadManager *)manager didFailToRetrieveFile:(XGFile *)xgridFile error:(NSError *)error;
@end