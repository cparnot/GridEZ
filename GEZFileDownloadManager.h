//
//  GEZFileDownloadManager.h
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
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