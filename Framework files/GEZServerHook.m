//
//  GEZServerHook.m
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import "GEZServerHook.h"
#import "GEZGridHook.h"
#import "GEZResourceObserver.h"

//needed for Keychain stuff
#include <Security/Security.h>
//#include <CoreFoundation/CoreFoundation.h>
//#include <CoreServices/CoreServices.h>


/*

From birth to death, an GEZServerHook object goes through a series of states.
 
1. Uninitialized. This is the state when the object is first created using 'initWithAddress:password:'. However, if there was already an instance with the same address, the object returned is the intance already existing
 
2. Connecting. This is the state after calling 'connect' or one of the similar public methods. Behind the scenes, the object actually makes several connection attempts before giving up, starting with the most likely to succed protocol until the least likely. These different connection attempts are the methods 'connect_B1', 'connect_B2',... that try connections via Bonjour or internet, and authentications with/without password or Kerberos single sign-on. So, depending on the value of the address and the password, the object will decide on a series of methods to try in a certain order (stored in connectionSelectors). For each of these attempts, the object will go through these calls:
	- 'startNextConnectionAttempt'
	- if there is no connection attempt left, switch to a 'Failed' state and send notification 
	- if there is one connection attempt left
		- call the corresponding method 'connect_XX', which will create a new XGConnection object each time
		- wait for callback (asynchronouly)
		- if callback is 'connectionDidOpen', switch to a 'Connected' state and send notification
		- if callback is 'connectionDidNotOpen' of 'connectionDidClose', start next connection attempt

3. Connected. The server is now connected, but it only means that the object 'XGConnection' is ready. We now have to wait for the object XGController to be ready. This will happen when its state is set to 'available' and the list of its XGGrid objects is loaded from the server. To keep track of that, we can use KVO on the XGController state. When the state changes, it means the XgridFoundation framework has received the information and is changing all the values of the different instance variables of the XGController object. Then, we know the object will be 'ready', or 'loaded', on the next iteration of the run loop. So, here is the process:
	- set self as observer of the XGController:
		[xgridController addObserver:self forKeyPath:@"state" options:0 context:NULL];
	- wait for the callback
	- when the state changes, call a timer with an interval of 0:
		 [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(controllerDidLoadInstanceVariables:) userInfo:nil repeats:NO];
	- on the next iteration of the run loop, change state to 'Loaded' and send notification
 
4. Loaded. The list of grids and the state of the XGController objects are set. We will now keep an eye on the list of grids to modify the various objects dependent on the grids as needed. ##NOT IMPLEMENTED YET##

*/


//the state changes as the connection progresses from not being connected to having loaded all the attributes of the server
typedef enum {
	GEZServerHookStateUninitialized = 1,
	GEZServerHookStateConnecting,
	GEZServerHookStateConnected,
	GEZServerHookStateUpdated,
	GEZServerHookStateLoaded,
	GEZServerHookStateDisconnected,
	GEZServerHookStateFailed
} GEZServerHookState;

//global constants used for notifications
NSString *GEZServerHookDidConnectNotification = @"GEZServerHookDidConnectNotification";
NSString *GEZServerHookDidLoadNotification = @"GEZServerHookDidLoadNotification";
NSString *GEZServerHookDidUpdateNotification = @"GEZServerHookDidUpdateNotification";
NSString *GEZServerHookDidNotConnectNotification = @"GEZServerHookDidNotConnectNotification";
NSString *GEZServerHookDidDisconnectNotification = @"GEZServerHookDidDisconnectNotification";

//intervals to be used for autoconnect feature
#define AUTOCONNECT_INTERVAL_UNDEFINED 0
#define AUTOCONNECT_INTERVAL_MINIMUM 10
#define AUTOCONNECT_INTERVAL_STEP 2
#define AUTOCONNECT_INTERVAL_MAXIMUM 600


@interface GEZServerHook (GEZServerHookPrivate)
- (void)xgridResourceDidUpdate:(XGResource *)resource;
- (void)connectionProblem:(XGConnection *)connection withError:(NSError *)error;
@end


@implementation GEZServerHook


#pragma mark *** Class Methods ***

//this dictionary keeps track of the instances already created, so that there is only one instance of GEZServerHook per address
NSMutableDictionary *serverHookInstances=nil;

//the serverHookInstances dictionary is created early on when the class is initialized
//I chose not to do lazy instanciation as there is only one dictionary created and the memory footprint is really small
//it is just simpler this way and probably less prone to future problems (e.g. multithreading?)
+ (void)initialize
{
	if ( serverHookInstances == nil )
		serverHookInstances = [[NSMutableDictionary alloc] init];
}

+ (GEZServerHook *)serverHookWithAddress:(NSString *)address password:(NSString *)password
{
	return [[[self alloc] initWithAddress:address password:password] autorelease];
}

+ (GEZServerHook *)serverHookWithAddress:(NSString *)address
{
	return [self serverHookWithAddress:address password:@""];
}



#pragma mark *** Initializations ***

//this method should never be called, as the only allowed initializer takes an address as parameter
//calling 'init' raises an expection
- (id)init
{
	if ( [self class] == [GEZServerHook class] )
		[NSException raise:@"GEZServerHookError" format:@"The 'init' method cannot be called on instances of the GEZServerHook class"];
	return [super init];
}

//designated initializer
//may return an instance already existing
- (id)initWithAddress:(NSString *)address password:(NSString *)password
{
	//do not create a new instance if the address is registered in the serverHookInstances dictionary
	//there is a memory management gotcha, as the instance get retained when added to the global dictionary 'serverHookInstances', so we have to be careful to release self after adding it to the dictionary, or retaining the instance if already in the dictionary, and then to retain the instance before removing it from the dictionary in the dealloc method
	id uniqueInstance;
	if ( uniqueInstance = [serverHookInstances objectForKey:address] ) {
		[self release];
		self = [uniqueInstance retain];
	} else {
		self = [super init];
		if ( self !=  nil ) {
			serverName = [address copy];
			serverPassword = [password copy];
			xgridController = nil;
			xgridConnection = nil;
			autoconnect = NO;
			autoconnectInterval = AUTOCONNECT_INTERVAL_UNDEFINED;
			serverHookState = GEZServerHookStateUninitialized;
			connectionSelectors = nil;
			selectorEnumerator = nil;
		}
		[serverHookInstances setObject:self forKey:address];
	}
	return self;
}

- (id)initWithAddress:(NSString *)address
{
	return [self initWithAddress:address password:@""];
}

- (void)dealloc
{
	[xgridConnection setDelegate:nil];
	[xgridConnection release];
	[xgridController release];
	[serverName release];
	[serverPassword release];
	[grids release];
	[xgridControllerObserver release];
	[connectionSelectors release];
	[selectorEnumerator allObjects];
	[super dealloc];
}

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"Server Connection to '%@' (state %d)", serverName, serverHookState];
}

#pragma mark *** Accessors ***

//public
- (NSString *)address
{
	return serverName;
}

//public
//do not return xgridCConnection object that are transient and may be dumped later
- (XGConnection *)xgridConnection
{
	if ( serverHookState == GEZServerHookStateConnecting )
		return nil;
	else
		return xgridConnection;
}

//public
- (XGController *)xgridController;
{
	return xgridController;
}


//public
- (void)setPassword:(NSString *)newPassword
{
	[newPassword retain];
	[serverPassword release];
	serverPassword = newPassword;
}


- (BOOL)isConnecting
{
	return ( serverHookState == GEZServerHookStateConnecting );
}

- (BOOL)isConnected
{
	return ( serverHookState == GEZServerHookStateConnected || serverHookState == GEZServerHookStateUpdated || serverHookState == GEZServerHookStateLoaded );
}

- (BOOL)isUpdated
{
	return serverHookState == GEZServerHookStateUpdated || serverHookState == GEZServerHookStateLoaded;
}

- (BOOL)isLoaded
{
	return serverHookState == GEZServerHookStateLoaded;
}

//set the server type to favor connection protocol to one type of server (remote or local)
//default is 'undefined' and will make an educated guess based on the address format
- (GEZServerHookType)serverType
{
	return serverType;
}

- (void)setServerType:(GEZServerHookType)newType
{
	serverType = newType;
}


//public
- (void)storePasswordInKeychain:(NSString *)newPassword
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//the service is shared with all applications using the GridEZ framework
	const char *serviceName = "GridEZ";
	UInt32 serviceLength = 6;

	//the account name is the address of the Xgrid server
	const char *accountName = [[self address] UTF8String];
	UInt32 accountLength = [[self address] length];

	//the password needs to be a C string
	const void *passwordData = [newPassword UTF8String];
	UInt32 passwordLength = [newPassword length];
	
	//determine wether a password is already stored and get the itemRef if it exists
	SecKeychainItemRef itemRef = NULL;
	OSStatus status = SecKeychainFindGenericPassword ( NULL, serviceLength, serviceName, accountLength, accountName, NULL, NULL, &itemRef);

	
	//if not existing, we need to create a keychain item
	if ( status == errSecItemNotFound ) {
		DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s --> add the keychain password for %@",[self class],self,_cmd,[self address]);
		status = SecKeychainAddGenericPassword ( NULL, serviceLength, serviceName, accountLength, accountName, passwordLength, passwordData, NULL );
	}
	
	//if the password is already stored, we need to update the keychain instead
	else  {
		DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s --> change the keychain password for %@",[self class],self,_cmd,[self address]);
		// Set up attribute vector (each attribute consists of {tag, length, pointer}):
		SecKeychainAttribute attrs[] = {
        { kSecAccountItemAttr, strlen(accountName), (char *)accountName },
        { kSecServiceItemAttr, strlen(serviceName), (char *)serviceName }
		};
		const SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]), attrs };
		status = SecKeychainItemModifyAttributesAndData ( itemRef, &attributes, passwordLength, passwordData );
	}

	//an error may have occur on the first or the second attempt, a little logging won't hurt
	if ( status != noErr )
		NSLog(@"Error occured when attempting to store the password in the user keychain: error %d",status);

	//we are in charge of releasing the item reference (see Apple docs)
	if (itemRef)
		CFRelease(itemRef);
}

- (BOOL)hasPasswordInKeychain
{
	
	//the service is shared with all applications using the GridEZ framework
	const char *serviceName = "GridEZ";
	UInt32 serviceLength = 6;
	
	//the account name is the address of the Xgrid server
	const char *accountName = [[self address] UTF8String];
	UInt32 accountLength = [[self address] length];
	
	//do a request without providing a pointer for the password
	OSStatus status = SecKeychainFindGenericPassword ( NULL, serviceLength, serviceName, accountLength, accountName, NULL, NULL, NULL);

	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s --> %@",[self class],self,_cmd,( status == noErr )?@"YES":@"NO");

	return ( status == noErr );
}

//private
- (NSString *)passwordFromKeychain
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	if ( [self hasPasswordInKeychain] == NO )
		return nil;
	
	//the service is shared with all applications using the GridEZ framework
	const char *serviceName = "GridEZ";
	UInt32 serviceLength = 6;
	
	//the account name is the address of the Xgrid server
	const char *accountName = [[self address] UTF8String];
	UInt32 accountLength = [[self address] length];
	
	//will be allocated and filled in by SecKeychainFindGenericPassword
	void *passwordData = nil;
	UInt32 passwordLength = nil;
	
	OSStatus status = SecKeychainFindGenericPassword ( NULL, serviceLength, serviceName, accountLength, accountName, &passwordLength, &passwordData, NULL);
	
	//an error may have occured, in which case we just return nil
	if ( status != noErr ) {
		NSLog(@"Error occured when attempting to retrieve the password in the user keychain: error %d",status);
		return nil;
	}

	//generate a NSString from the buffer returned
	NSString *passwordFromKeychain = nil;
	if ( passwordData != nil ) {
		passwordFromKeychain = [[[NSString alloc] initWithBytes:passwordData length:passwordLength encoding:NSUTF8StringEncoding] autorelease];
		status = SecKeychainItemFreeContent ( NULL, passwordData );
	}
	return passwordFromKeychain;
}




//PRIVATE
//when the xgridConnection is set, always use self as its delegate
- (void)setXgridConnection:(XGConnection *)newXgridConnection
{
	if ( newXgridConnection != xgridConnection ) {
		[xgridConnection setDelegate:nil];
		[xgridConnection release];
		[newXgridConnection retain];
		[newXgridConnection setDelegate:self];
		xgridConnection = newXgridConnection;
	}
}


//PRIVATE
- (void)setXgridController:(XGController *)newXgridController
{
	if ( newXgridController != xgridController ) {
		[xgridController release];
		[newXgridController retain];
		xgridController = newXgridController;
	}
}


//PRIVATE
//when the connectionSelectors is set, also reset the selectorEnumerator
- (void)setConnectionSelectors:(NSArray *)anArray
{
	//set the connectionSelectors array
	[anArray retain];
	[connectionSelectors release];
	connectionSelectors = [anArray retain];
	
	//reset the selectorEnumerator
	[selectorEnumerator allObjects];
	[selectorEnumerator release];
	if ( anArray == nil )
		selectorEnumerator = nil;
	else
		selectorEnumerator = [[connectionSelectors objectEnumerator] retain];
}

- (BOOL)autoconnect
{
	return autoconnect;
}

- (void)setAutoconnect:(BOOL)newautoconnect
{
	autoconnect = newautoconnect;
}


#pragma mark *** Accessing Grids ***

- (GEZGridHook *)gridHookWithXgridGrid:(XGGrid *)aGrid
{
	NSEnumerator *e = [grids objectEnumerator];
	GEZGridHook *aGridHook;
	while ( aGridHook = [e nextObject] ) {
		if ( [aGridHook xgridGrid] == aGrid )
			return aGridHook;
	}
	return nil;
}

- (GEZGridHook *)gridHookWithIdentifier:(NSString *)identifier
{
	//already a GEZGridHook with the right identifier?
	NSEnumerator *e = [grids objectEnumerator];
	GEZGridHook *aGrid;
	while ( aGrid = [e nextObject] ) {
		if ( [[[aGrid xgridGrid] identifier] isEqualToString:identifier] )
			return aGrid;
	}
	return nil;
}

- (NSArray *)grids
{
	return grids;
}


#pragma mark *** Private connection methods ***

//trying to use a Bonjour connection without password
- (void)connect_B1
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create a new XGConnection with a NSNetService
	NSNetService *netService = [[NSNetService alloc] initWithDomain:@"local."
															   type:@"_xgrid._tcp."
															   name:serverName];
	XGConnection *newConnection = [[XGConnection alloc] initWithNetService:netService];
	[netService release];
	
	//set the authenticator
	[newConnection setAuthenticator:nil];
	
	//... and go!!
	[self setXgridConnection:newConnection];
	[newConnection open];
	[newConnection release];
}

//trying to use a Bonjour connection with a password
- (void)connect_B2
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create a new XGConnection with a NSNetService
	NSNetService *netService = [[NSNetService alloc] initWithDomain:@"local."
															   type:@"_xgrid._tcp."
															   name:serverName];
	XGConnection *newConnection = [[XGConnection alloc] initWithNetService:netService];
	[netService release];
	
	//set the authenticator
	XGTwoWayRandomAuthenticator *authenticator = [[XGTwoWayRandomAuthenticator alloc] init];
	[authenticator setUsername:@"one-xgrid-client"];
	[authenticator setPassword:serverPassword];
	[newConnection setAuthenticator:authenticator];
	[authenticator release];
	
	//... and go!!
	[self setXgridConnection:newConnection];
	[newConnection open];
	[newConnection release];
}

//trying to use a Bonjour connection with Kerberos
- (void)connect_B3
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create a new XGConnection with a NSNetService
	NSNetService *netService = [[NSNetService alloc] initWithDomain:@"local."
															   type:@"_xgrid._tcp."
															   name:serverName];
	XGConnection *newConnection = [[XGConnection alloc] initWithNetService:netService];
	[netService release];
	
	//set the authenticator
	XGGSSAuthenticator *authenticator = [[XGGSSAuthenticator alloc] init];
	NSString *servicePrincipal = [newConnection servicePrincipal];
	if (servicePrincipal == nil)
		servicePrincipal=[NSString stringWithFormat:@"xgrid/%@", [newConnection name]];		
	[authenticator setServicePrincipal:servicePrincipal];
	[newConnection setAuthenticator:authenticator];
	[authenticator release];
	
	//... and go!!
	[self setXgridConnection:newConnection];
	[newConnection open];
	[newConnection release];
}


//trying to use a Bonjour connection with password from the keychain
- (void)connect_B4
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create a new XGConnection with a NSNetService
	NSNetService *netService = [[NSNetService alloc] initWithDomain:@"local."
															   type:@"_xgrid._tcp."
															   name:serverName];
	XGConnection *newConnection = [[XGConnection alloc] initWithNetService:netService];
	[netService release];
	
	//set the authenticator
	XGTwoWayRandomAuthenticator *authenticator = [[XGTwoWayRandomAuthenticator alloc] init];
	[authenticator setUsername:@"one-xgrid-client"];
	[authenticator setPassword:[self passwordFromKeychain]];
	[newConnection setAuthenticator:authenticator];
	[authenticator release];
	
	//... and go!!
	[self setXgridConnection:newConnection];
	[newConnection open];
	[newConnection release];
}


//trying to use a remote connection without a password
- (void)connect_H1
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create a new XGConnection
	XGConnection *newConnection = [[XGConnection alloc] initWithHostname:serverName portnumber:0];
	
	//set the authenticator
	[newConnection setAuthenticator:nil];
	
	//... and go!!
	[self setXgridConnection:newConnection];
	[newConnection open];
	[newConnection release];
}

//trying to use a remote connection with a password
- (void)connect_H2
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create a new XGConnection
	XGConnection *newConnection = [[XGConnection alloc] initWithHostname:serverName portnumber:0];
	
	//set the authenticator
	XGTwoWayRandomAuthenticator *authenticator = [[XGTwoWayRandomAuthenticator alloc] init];
	[authenticator setUsername:@"one-xgrid-client"];
	[authenticator setPassword:serverPassword];
	[newConnection setAuthenticator:authenticator];
	[authenticator release];
	
	//... and go!!
	[self setXgridConnection:newConnection];
	[newConnection open];
	[newConnection release];
}

//trying to use a remote connection with Kerberos
- (void)connect_H3
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create a new XGConnection
	XGConnection *newConnection = [[XGConnection alloc] initWithHostname:serverName portnumber:0];
	
	//set the authenticator
	XGGSSAuthenticator *authenticator = [[XGGSSAuthenticator alloc] init];
	NSString *servicePrincipal = [newConnection servicePrincipal];
	if (servicePrincipal == nil)
		servicePrincipal=[NSString stringWithFormat:@"xgrid/%@", [newConnection name]];		
	[authenticator setServicePrincipal:servicePrincipal];
	[newConnection setAuthenticator:authenticator];
	[authenticator release];
	
	//... and go!!
	[self setXgridConnection:newConnection];
	[newConnection open];
	[newConnection release];
}

//trying to use a remote connection with password from the keychain
- (void)connect_H4
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create a new XGConnection
	XGConnection *newConnection = [[XGConnection alloc] initWithHostname:serverName portnumber:0];
	
	//set the authenticator
	XGTwoWayRandomAuthenticator *authenticator = [[XGTwoWayRandomAuthenticator alloc] init];
	[authenticator setUsername:@"one-xgrid-client"];
	[authenticator setPassword:[self passwordFromKeychain]];
	[newConnection setAuthenticator:authenticator];
	[authenticator release];
	
	//... and go!!
	[self setXgridConnection:newConnection];
	[newConnection open];
	[newConnection release];
}


- (void)startNextConnectionAttempt
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);

	//depending on the hostname and password values, we have decided on a series of connection type to make,
	//as defined by the array connectionSelectors, enumerated by selectorEnumerator
	NSString *selectorString = [selectorEnumerator nextObject];
	
	//if there is still one selector to try, go ahead
	if ( selectorString != nil ) {
		selectorString = [@"connect_" stringByAppendingString:selectorString];
		SEL selector = NSSelectorFromString (selectorString);
		[self performSelector:selector];
	}
	
	//otherwise, the connection failed
	else {
		serverHookState = GEZServerHookStateFailed;
		[self connectionProblem:nil withError:nil];
		serverHookState = GEZServerHookStateFailed;
		[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerHookDidNotConnectNotification object:self];
	}
}

- (void)autoconnectWithTimer:(NSTimer *)aTimer
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	if ( autoconnectInterval == AUTOCONNECT_INTERVAL_UNDEFINED || autoconnect == NO || [self isConnecting] == YES || [self isConnected] == YES ) {
		autoconnectInterval = AUTOCONNECT_INTERVAL_UNDEFINED;
		return;
	}
	[self connect];
}

#pragma mark *** XGConnection delegate methods, going from "Connecting" to "Connected" ***

- (void)connectionDidOpen:(XGConnection *)connection;
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//create the XGController object
	[xgridController release];
	xgridController = [[XGController alloc] initWithConnection:xgridConnection];
	
	//clean-up
	[self setConnectionSelectors:nil];
	
	//change the current state
	serverHookState= GEZServerHookStateConnected;
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerHookDidConnectNotification object:self];
	autoconnectInterval = AUTOCONNECT_INTERVAL_UNDEFINED;
	
	//next step is to get the controller 'updated' = all instance variables updated
	if ( [xgridController isUpdated] )
		[self xgridResourceDidUpdate:xgridController];
	else {
		[xgridControllerObserver release];
		xgridControllerObserver = [[GEZResourceObserver alloc] initWithResource:xgridController];
		[xgridControllerObserver setDelegate:self];
	}
}

//this method is the code common to both connectionDidNotOpen: and connectionDidClose: XGConnection delegate callbacks
- (void)connectionProblem:(XGConnection *)connection withError:(NSError *)error
{	
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//connection failed?
	if ( serverHookState == GEZServerHookStateConnecting )
		[self startNextConnectionAttempt];

	//connection dropped?
	else {
		serverHookState = GEZServerHookStateDisconnected;
		[self setConnectionSelectors:nil];
		[self setXgridConnection:nil];
		[self setXgridController:nil];
		[grids release];
		grids = nil;
		[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerHookDidDisconnectNotification object:self];
		if ( [self autoconnect] ) {
			if ( autoconnectInterval == AUTOCONNECT_INTERVAL_UNDEFINED )
				autoconnectInterval = AUTOCONNECT_INTERVAL_MINIMUM;
			else {
				autoconnectInterval *= AUTOCONNECT_INTERVAL_STEP;
				if ( autoconnectInterval > AUTOCONNECT_INTERVAL_MAXIMUM )
					autoconnectInterval = AUTOCONNECT_INTERVAL_MAXIMUM;
			}
			[NSTimer scheduledTimerWithTimeInterval:autoconnectInterval target:self selector:@selector(autoconnectWithTimer:) userInfo:nil repeats:NO];
		}
	}
}

- (void)connectionDidNotOpen:(XGConnection *)connection withError:(NSError *)error
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self connectionProblem:connection withError:error];
}

- (void)connectionDidClose:(XGConnection *)connection;
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self connectionProblem:connection withError:nil];
}


#pragma mark *** XGController observing, going from "Connected" to "Updated" ***

//checks wether all grids are "updated"
- (BOOL)allGridsUpdated
{
	BOOL allUpdated = YES;
	NSEnumerator *e = [grids objectEnumerator];
	GEZGridHook *aGrid;
	while ( aGrid = [e nextObject] )
		allUpdated = allUpdated && [aGrid isUpdated];
	return allUpdated;
}

//checks wether all grids are "loaded"
- (BOOL)allGridsLoaded
{
	BOOL allLoaded = YES;
	NSEnumerator *e = [grids objectEnumerator];
	GEZGridHook *aGrid;
	while ( aGrid = [e nextObject] )
		allLoaded = allLoaded && [aGrid isLoaded];
	return allLoaded;
}



//delegate method for GEZResourceObserver, when the xgrid controller is "updated"
- (void)xgridResourceDidUpdate:(XGResource *)resource
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//early exit?
	if ( serverHookState != GEZServerHookStateConnected || [xgridController state] != XGResourceStateAvailable )
		return;
	
	//prepare the 'grids' array
	XGGrid *aGrid;
	NSEnumerator *e = [[xgridController grids] objectEnumerator];
	NSMutableArray *tempGrids = [NSMutableArray arrayWithCapacity:[[xgridController grids] count]];
	while ( aGrid = [e nextObject] ) {
		GEZGridHook *gridHook = [GEZGridHook gridHookWithXgridGrid:aGrid serverHook:self];
		NSAssert(gridHook!=nil,@"[GEZGridHook gridHookWithXgridGrid:aGrid serverHook:self] returning nil");
		[tempGrids addObject:gridHook];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridHookDidUpdate:) name:GEZGridHookDidUpdateNotification object:gridHook];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gridHookDidLoad:) name:GEZGridHookDidLoadNotification object:gridHook];
	}
	[grids release];
	grids = [[NSArray alloc] initWithArray:tempGrids];
	
	//now, the server is updated!
	[xgridControllerObserver setDelegate:nil];
	[xgridControllerObserver release];
	xgridControllerObserver = nil;
	serverHookState = GEZServerHookStateUpdated;
	[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerHookDidUpdateNotification object:self];
	
	//next is to wait for the grids to be loaded... except if they already are
	if ( [self allGridsLoaded] ) {
		serverHookState = GEZServerHookStateLoaded;
		[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerHookDidLoadNotification object:self];		
	}
	
}



#pragma mark *** GEZGridHook callbacks, going from "Updated" to "Loaded" ***

- (void)gridHookDidUpdate:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s %@",[self class],self,_cmd, [[[notification object] xgridGrid] name]);

	/*
	if ( serverHookState != GEZServerHookStateUpdated )
		return;
	
	//is the server now considered "loaded"?
	if ( [self allGridsUpdated] ) {
		serverHookState = GEZServerHookStateLoaded;
		[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerHookDidLoadNotification object:self];
	}
	 */
}

- (void)gridHookDidLoad:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s %@",[self class],self,_cmd, [[[notification object] xgridGrid] name]);
	if ( serverHookState != GEZServerHookStateUpdated )
		return;
	
	//is the server now considered "loaded"?
	if ( [self allGridsLoaded] ) {
		serverHookState = GEZServerHookStateLoaded;
		[[NSNotificationCenter defaultCenter] postNotificationName:GEZServerHookDidLoadNotification object:self];
	}
}


#pragma mark *** Public connection methods ***

//function used to decide is an address string is likely to be that of a remote host or of a local (Bonjour) server
BOOL isRemoteHost (NSString *anAddress)
{
	if ( [anAddress isEqualToString:@"localhost"] )
		return YES;
	else
		return ( [anAddress rangeOfString:@"."].location != NSNotFound );
	
}



- (void)connectWithoutAuthentication
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//exit if already connecting or connected
	if ( serverHookState == GEZServerHookStateConnecting || serverHookState == GEZServerHookStateConnected || serverHookState == GEZServerHookStateLoaded )
		return;
	
	//change the state of the serverHook
	serverHookState = GEZServerHookStateConnecting;
	
	//decide on the successive attempts that will be made to connect
	//the choice depends on the address name (Bonjour or remote?) and on the password
	NSArray *selectors = nil;
	if ( isRemoteHost(serverName) )
		selectors = [NSArray arrayWithObjects:@"H1",@"B1",nil];
	else
		selectors = [NSArray arrayWithObjects:@"B1",@"H1",nil];
	[self setConnectionSelectors:selectors];
	
	//start the connection process
	[self startNextConnectionAttempt];
}

- (void)connectWithSingleSignOnCredentials
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//exit if already connecting or connected
	if ( serverHookState == GEZServerHookStateConnecting || serverHookState == GEZServerHookStateConnected || serverHookState == GEZServerHookStateLoaded )
		return;
	
	//change the state of the serverHook
	serverHookState = GEZServerHookStateConnecting;
	
	//decide on the successive attempts that will be made to connect
	//the choice depends on the address name (Bonjour or remote?) and on the password
	NSArray *selectors = nil;
	if ( isRemoteHost(serverName) )
		selectors = [NSArray arrayWithObjects:@"H3",@"B3",nil];
	else
		selectors = [NSArray arrayWithObjects:@"B3",@"H3",nil];
	[self setConnectionSelectors:selectors];
	
	//start the connection process
	[self startNextConnectionAttempt];
}


- (void)connectWithPassword
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//exit if already connecting or connected
	if ( serverHookState == GEZServerHookStateConnecting || serverHookState == GEZServerHookStateConnected || serverHookState == GEZServerHookStateLoaded )
		return;
	
	//change the state of the serverHook
	serverHookState = GEZServerHookStateConnecting;
	
	//decide on the successive attempts that will be made to connect
	//the choice depends on the address name (Bonjour or remote?) and on the password (keychain or not?)
	NSArray *selectors = nil;
	if ( isRemoteHost(serverName) ) {
		if ( [self hasPasswordInKeychain] && ( [serverPassword length] > 0) )
			selectors = [NSArray arrayWithObjects:@"H4",@"H2",@"B4",@"B2",nil];
		else if ( [self hasPasswordInKeychain] && ( [serverPassword length] < 1 ) )
			selectors = [NSArray arrayWithObjects:@"H4",@"B4",nil];
		else
			selectors = [NSArray arrayWithObjects:@"H2",@"B2",nil];
	} else {
		if ( [self hasPasswordInKeychain] && ( [serverPassword length] > 0) )
			selectors = [NSArray arrayWithObjects:@"B4",@"B2",@"H4",@"H2",nil];
		else if ( [self hasPasswordInKeychain] && ( [serverPassword length] < 1 ) )
			selectors = [NSArray arrayWithObjects:@"B4",@"H4",nil];
		else
			selectors = [NSArray arrayWithObjects:@"B2",@"H2",nil];
	}	[self setConnectionSelectors:selectors];
	
	//start the connection process
	[self startNextConnectionAttempt];
}

- (void)connect
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//exit if already connecting or connected
	if ( serverHookState == GEZServerHookStateConnecting || serverHookState == GEZServerHookStateConnected || serverHookState == GEZServerHookStateLoaded )
		return;
	
	//change the state of the serverHook
	serverHookState = GEZServerHookStateConnecting;
	
	//decide on the successive attempts that will be made to connect
	//the choice depends on the address name (Bonjour or remote?) and on the password (ivar set? keychain?)
	//there are 2 x 2 x 2 = 8 possibilities, just dumbly tested using if...else if...else if...
	//the order chosen for the different connections is quite logical, but is partly a matter of taste and is an empirical choice
	NSArray *selectors = nil;
	BOOL remoteHost = isRemoteHost(serverName);
	BOOL usePassword = ( [serverPassword length] > 0 );
	BOOL useKeychain = ( [self passwordFromKeychain] != nil );
	if ( usePassword && remoteHost && useKeychain )
		selectors = [NSArray arrayWithObjects:@"H4",@"H2",@"B4",@"B2",@"H1",@"H3",@"B1",@"B3",nil];
	else if ( usePassword && remoteHost && !useKeychain )
		selectors = [NSArray arrayWithObjects:@"H2",@"B2",@"H1",@"H3",@"B1",@"B3",nil];
	else if ( !usePassword && remoteHost && useKeychain )
		selectors = [NSArray arrayWithObjects:@"H4",@"B4",@"H1",@"H3",@"B1",@"B3",nil];
	else if ( usePassword && !remoteHost && useKeychain )
		selectors = [NSArray arrayWithObjects:@"B4",@"B2",@"H4",@"H2",@"B1",@"B3",@"H1",@"H3",nil];
	else if ( usePassword && !remoteHost && !useKeychain )
		selectors = [NSArray arrayWithObjects:@"B2",@"H2",@"B1",@"B3",@"H1",@"H3",nil];
	else if ( !usePassword && !remoteHost && useKeychain )
		selectors = [NSArray arrayWithObjects:@"B4",@"H4",@"B1",@"B3",@"H1",@"H3",nil];
	else if ( !usePassword && remoteHost && !useKeychain )
		selectors = [NSArray arrayWithObjects:@"H1",@"H3",@"B1",@"B3",nil];
	else if ( !usePassword && !remoteHost && !useKeychain )
		selectors = [NSArray arrayWithObjects:@"B1",@"B3",@"H1",@"H3",nil];
	[self setConnectionSelectors:selectors];
	
	//start the connection process
	[self startNextConnectionAttempt];
}

- (void)disconnect
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[xgridConnection close];
	[self setConnectionSelectors:nil];
}

@end
