//
//  GEZServerBrowser.m
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
 Implementation is very simple
 
 * lazy instantiation of the singleton instance
 * lazy instantiation of the unique ivar for this class = netServiceBrowser, when starting the browser
 * a few callbacks = delegate methods for the NSNetServiceBrowser
 * calling the GEZServer initialization methods to create GEZServer methods as they appear in the local network
 * it also knows a little bit about the internals of GEZerver to set up the flags accordingly for 'isAvailable', 'wasAvailable...'

 
*/

#import "GEZServerBrowser.h"
#import "GEZServer.h"

static NSString *XgridServiceType = @"_xgrid._tcp.";
static NSString *XgridServiceDomain = @"local.";

@implementation GEZServerBrowser


#pragma mark *** creating and retrieving the singleton instance ***

GEZServerBrowser *sharedServerBrowser = nil;

+ (GEZServerBrowser *)sharedServerBrowser
{
	if ( sharedServerBrowser == nil ) {
		sharedServerBrowser = [[GEZServerBrowser alloc] init];
	}
	return sharedServerBrowser;
}


#pragma mark *** browsing services ***

- (NSNetServiceBrowser *)netServiceBrowser
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	if (netServiceBrowser==nil) {
		netServiceBrowser = [[NSNetServiceBrowser alloc] init];
		[netServiceBrowser setDelegate:self];
	}
	return netServiceBrowser;
}

- (void)dealloc;
{
	[netServiceBrowser setDelegate:nil];
    [netServiceBrowser release];
    [super dealloc];
}

- (void)startBrowsing
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	//use the accessor for lazy instantiation of the netServiceBrowser
	if ( isBrowsing == YES )
		return;
	[[self netServiceBrowser] searchForServicesOfType:XgridServiceType inDomain:XgridServiceDomain];
	if ( netServiceBrowser != nil )
		isBrowsing = YES;
}

- (void)stopBrowsing
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	//do not use the accessor for the netServiceBrowser; we want to stop it, so we don't want to create one if not existing yet
	[netServiceBrowser stop];
	isBrowsing = NO;
}

- (BOOL)isBrowsing
{
	//here, I do not use the accessor for the netServiceBrowser; if nil, this will return NO, which is the right answer, and we don't want to create one if not existing yet
	return isBrowsing;
}
#pragma mark *** NSNetServiceBrowser delegate methods ***


- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
             didNotSearch:(NSDictionary *)errorDict;
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreComing;
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	GEZServer *aServer;	
    aServer = [GEZServer serverWithAddress:[netService name]];
	[aServer setValue:[NSNumber numberWithInt:GEZServerTypeLocal] forKey:@"serverType"];
	[aServer setValue:[NSNumber numberWithBool:YES] forKey:@"available"];
	[aServer setValue:[NSNumber numberWithBool:YES] forKey:@"wasAvailableInCurrentSession"];
	[aServer setValue:[NSNumber numberWithBool:YES] forKey:@"wasAvailableInPreviousSession"];

	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s (server = <%@:%p> = %@",[self class],self,_cmd,[aServer class],aServer,[aServer valueForKey:@"name"]);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
         didRemoveService:(NSNetService *)netService
               moreComing:(BOOL)moreComing;
{
	GEZServer *aServer;
    
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

    aServer = [GEZServer serverWithAddress:[netService name]];
	[aServer setValue:[NSNumber numberWithBool:NO] forKey:@"available"];

	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s (server = <%@:%p> = %@",[self class],self,_cmd,[aServer class],aServer,[aServer valueForKey:@"name"]);
}

@end
