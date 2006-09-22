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
 
 The GEZServerHook class is a wrapper around the XGController and XGConnection class provided by the Xgrid APIs. The implementation ensures that there is only one instance of GEZServerHook for each different address, which ensures that network traffic, notifications,... are not duplicated when communicating with the same server. The GEZServer class use the GEZServerHook class for its network operations. There might thus be several GEZServer objects (living in different managed contexts, see the header) that all use the same GEZServerHook. The GEZServerHook sends notifications to keep the GEZServer objects in sync.

So the two classes, GEZServerHook & GEZServer, are somewhat coupled, though the implementation tries to keep them encapsulated.
*/

@class GEZGridHook;
@class GEZResourceObserver;

//Constants to use to subscribe to notifications
APPKIT_EXTERN NSString *GEZServerHookDidConnectNotification;
APPKIT_EXTERN NSString *GEZServerHookDidNotConnectNotification;
APPKIT_EXTERN NSString *GEZServerHookDidDisconnectNotification;
APPKIT_EXTERN NSString *GEZServerHookDidUpdateNotification;
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
	
	GEZResourceObserver *xgridControllerObserver;
	
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
- (BOOL)isConnecting;
- (BOOL)isConnected;
- (BOOL)isUpdated;
- (BOOL)isLoaded;

//the password will only be stored until the connection is successfull or failed
- (void)setPassword:(NSString *)newPassword;

//once a password is stored in the keychain, it will be automatically be used in future sessions again
//the password is only stored for the duration of the function (note: still stored in the heap)
- (void)storePasswordInKeychain:(NSString *)newPassword;
- (BOOL)hasPasswordInKeychain;


//set the server type to favor connection protocol to one type of server (remote or local)
//default is 'undefined' and will make an educated guess based on the address format
- (GEZServerHookType)serverType;
- (void)setServerType:(GEZServerHookType)newType;

//connection
//in general, these methods try to connect in different ways, starting with the most likely possibility, based on the server name (is it local or remote server?) and the availability of a password (either set in clear or in the keychain)

- (void)connectWithoutAuthentication;
- (void)connectWithSingleSignOnCredentials;

//if a password is stored in the keychain, it will be tried first, then the password set by 'setPassword:' if any
//these alternatives also applies to the method '-connect'
- (void)connectWithPassword;

//the method 'connect' will try the different authentication methods in the order that seems to make the most sense, based on the server name/address and the password settings
- (void)connect;
- (void)disconnect;


@end
