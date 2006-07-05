//
//  GEZServerBrowser.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
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
	[aServer setValue:[NSNumber numberWithBool:YES] forKey:@"isAvailable"];
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
	[aServer setValue:[NSNumber numberWithBool:NO] forKey:@"isAvailable"];

	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s (server = <%@:%p> = %@",[self class],self,_cmd,[aServer class],aServer,[aServer valueForKey:@"name"]);
}

@end
