//
//  GEZResults.h
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



#import <Cocoa/Cocoa.h>


@interface GEZResults : NSObject
{
	XGJob *xgridJob;
	XGActionMonitor *streamsMonitor;
	XGActionMonitor *filesMonitor;
	NSMutableSet *downloads;
	NSMutableDictionary *results;
	id delegate;
	BOOL isRetrieving;
}

- (id)initWithXgridJob:(XGJob *)job;
- (void)retrieve;
- (void)retrieveStreams;

- (id)delegate;
- (void)setDelegate:(id)newDelegate;

- (BOOL)isDone;
- (NSDictionary *)allFiles;

@end


//protocol for the delegate
@interface NSObject (GEZResultsDelegate)
- (void)didRetrieveResults:(GEZResults *)results;
@end