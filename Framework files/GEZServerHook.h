//
//  GEZServerHook.h
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



/*
 The GEZServerHook class is a private class and this header is not intended for the users of the framework.
 
 The GEZServerHook class is a wrapper around the XGController and XGConnection class provided by the Xgrid APIs. The implementation ensures that there is only one instance of GEZServerHook for each different address, which ensures that network traffic, notifications,... are not duplicated when communicating with the same server. The XGSServer class use the GEZServerHook class for its network operations. There might thus be several XGSServer objects (living in different managed contexts, see the header) that all use the same GEZServerHook. The XGSServeConnection sends notifications to keep the XGSServer objects in sync.

So the two classes, GEZServerHook & XGSServer, are somewhat coupled, though the implementation tries to keep them encapsulated.
*/

@class GEZGridHook;

//Constants to use to subscribe to notifications
APPKIT_EXTERN NSString *GEZServerHookDidConnectNotification;
APPKIT_EXTERN NSString *GEZServerHookDidNotConnectNotification;
APPKIT_EXTERN NSString *GEZServerHookDidDisconnectNotification;
APPKIT_EXTERN NSString *GEZServerHookDidSyncNotification;
APPKIT_EXTERN NSString *GEZServerHookDidLoadNotification;

//server type is determined at connection
typedef enum {
	GEZServerHookTypeUndefined = 0,
	GEZServerHookTypeRemote = 1,
	GEZServerHookTypeLocal = 2
} GEZServerHookType;

@interface GEZServerHook : NSObject
{
	XGConnection *xgridConnection;
	XGController *xgridController;
	NSString *serverName;
	NSString *serverPassword;
	int serverHookState; //private enum
	GEZServerHookType serverType;
	
	NSArray *grids; //array of GEZGridHook
	
	//keeping track of connection attempts
	NSArray *connectionSelectors;
	NSEnumerator *selectorEnumerator;
}

//creating instances of GEZGridHook objects
+ (GEZServerHook *)serverHookWithAddress:(NSString *)address;
+ (GEZServerHook *)serverHookWithAddress:(NSString *)address password:(NSString *)password;
- (id)initWithAddress:(NSString *)address password:(NSString *)password;
- (id)initWithAddress:(NSString *)address;

//accessing grids (GEZGridHook objects)
- (GEZGridHook *)gridHookWithXgridGrid:(XGGrid *)aGrid;
- (GEZGridHook *)gridHookWithIdentifier:(NSString *)identifier;
- (NSArray *)grids;

//accessors
- (NSString *)address;
- (XGConnection *)xgridConnection;
- (XGController *)xgridController;
- (void)setPassword:(NSString *)newPassword;
- (BOOL)isConnecting;
- (BOOL)isConnected;
- (BOOL)isSynced;
- (BOOL)isLoaded;

//set the server type to favor connection protocol to one type of server (remote or local)
//default is 'undefined' and will make an educated guess based on the address format
- (GEZServerHookType)serverType;
- (void)setServerType:(GEZServerHookType)newType;

//connection
- (void)connect;
- (void)disconnect;
- (void)connectWithoutAuthentication;
- (void)connectWithPassword;
- (void)connectWithSingleSignOnCredentials;


@end
