//
//  GEZGridHook.h
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



/*
 The GEZGridHook class is a private class.
 It is only used by GEZServerHook to monitor XGGrid objects owned by an XGController. The GEZServerHook simply implements the GEZGridHookServerProtocol to receive callbacks when the grid is updated, loaded, deleted,...
 The code for this class is designed to work with GEZServerHook and is not very portable
 */


APPKIT_EXTERN NSString *GEZGridHookDidUpdateNotification;
APPKIT_EXTERN NSString *GEZGridHookDidLoadNotification;
APPKIT_EXTERN NSString *GEZGridHookDidChangeNameNotification;
APPKIT_EXTERN NSString *GEZGridHookDidChangeJobsNotification;


@class GEZServerHook;
@class GEZResourceObserver;

@interface GEZGridHook : NSObject
{
	XGGrid *xgridGrid;
	GEZServerHook *serverHook;
	int gridHookState; //private enum
	NSSet *xgridJobObservers;
	GEZResourceObserver *xgridGridObserver;
}

+ (GEZGridHook *)gridHookWithXgridGrid:(XGGrid *)aGrid serverHook:(GEZServerHook *)aServer;
+ (GEZGridHook *)gridHookWithIdentifier:(NSString *)identifier serverHook:(GEZServerHook *)aServer;

//accessors
- (void)setXgridGrid:(XGGrid *)newGrid;
- (XGGrid *)xgridGrid;
- (BOOL)isUpdated;
- (BOOL)isLoaded;
- (GEZServerHook *)serverHook;

@end

