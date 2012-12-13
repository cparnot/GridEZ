//
//  GEZServer.h
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
 The GEZServer instances are managed objects that expose a simple interface for Xgrid Controllers. Behind the scenes, this class uses a number of other private classes for the server connections, the creation of an application-wide shared managed object context and browsing the local network for servers advertising their services.
 
 To make sure everything works as expected, instances of GEZServer should only be created/retrieved using the public methods listed here. There are three ways to create/retrieve GEZServer instances:
 - using the class method '+allServers'. The returned array contain servers already connected, but also servers that were connected to in previous sessions (saved in a persistent store) and "available" servers found on the local network (when browsing was started using the 'startBrowsing', found servers are automatically added).
 - using the class method '+serverWithAddress:', which may create a new instance or retrieve an existing record from the shared managed object context created by the framework
 - using the class method '+serverWithAddress:managedObjectContext:', which you can use to create and retrieve server objects in a custom managed object context; to "copy" an existing GEZServer into a different managed object context, you can use '-serverInManagedObjectContext:'
 
 These methods ensure that only one instance of GEZServer exists per server address and per managed object context. Once retrieved, the returned instance can be retained as long as needed, and will remain valid and in sync until released. However, it is possible that several instances with the same server address may exist in different managed object contexts. This is fine: connection and network traffic will not be duplicated. The connection process itself is shared by all GEZServer instances with the same address, and these instances are guaranteed to be kept in sync all the time.
 
 To start the connection, call one of the -connect... method.
 Then use a delegate or notifications to keep track of the connection status asynchronously.
 
 IMPORTANT: in the current implementation, the password will NOT be saved to disk.
 
 */


//Constants to use to subscribe to notifications received in response to the connect call
//no delegate as there is only one instance of server per address; thus, several client objects trying to be delegate could overwrite each other in unpredictable ways
APPKIT_EXTERN NSString *GEZServerWillAttemptConnectionNotification;
APPKIT_EXTERN NSString *GEZServerDidConnectNotification;
APPKIT_EXTERN NSString *GEZServerDidNotConnectNotification;
APPKIT_EXTERN NSString *GEZServerDidDisconnectNotification;

//after connection, it might take a while before the object loads all the information from the server: how many grids,...
APPKIT_EXTERN NSString *GEZServerDidLoadNotification;

//server type is determined automatically at the first connection
typedef enum {
	GEZServerTypeUndefined = 0,
	GEZServerTypeRemote = 1,
	GEZServerTypeLocal = 2
} GEZServerType;


@class GEZServerHook;
@class GEZGrid;
@class GEZJob;

@interface GEZServer : NSManagedObject
{
	GEZServerHook *serverHook;

}

//IMPORTANT:
/*
You should only retrieve GEZServer instances using one of these methods (**NEVER** use CoreData creation methods directly):
	+ (NSArray *)allServers;
	+ (GEZServer *)serverWithAddress:(NSString *)address;
	+ (GEZServer *)connectedServer;
	+ (GEZServer *)serverWithAddress:(NSString *)address inManagedObjectContext:(NSManagedObjectContext *)context;
*/

//Creating server instances
//Server instances are added to the default persistent store (see GEZManager), that can be used with bindings to display an automatically updated list of all the servers in the GUI
+ (void)startBrowsing;
+ (void)stopBrowsing;
+ (BOOL)isBrowsing;
+ (NSArray *)allServers;
+ (GEZServer *)serverWithAddress:(NSString *)address;

//returns a connected GEZServer if there is one, otherwise return nil
+ (GEZServer *)connectedServer;

//New instances are always added to the default persistent store (see GEZManager), but using one of these methods, a server can in addition be attached to a custom context (e.g. for document-based app)
//Instances are guaranteed to be unique for a given address and a given managed object context, but you will get two different instances for servers with the same addresses on 2 separate contexts 
+ (GEZServer *)serverWithAddress:(NSString *)address inManagedObjectContext:(NSManagedObjectContext *)context;
- (GEZServer *)serverInManagedObjectContext:(NSManagedObjectContext *)context;

//will remove only offline servers - deleting servers manually from the managed object skip the verification
- (void)deleteFromStore;

//Connecting (either automatically or using a specific protocol)
- (void)connect;
- (void)disconnect;
- (void)connectWithoutAuthentication;
- (void)connectWithSingleSignOnCredentials;
- (void)connectWithPassword:(NSString *)password;
- (void)connectWithKeychainPassword;

//Submitting jobs using the default grid (notifications received by the GEZJob object, see header for that class)
//The GEZJob is added to the same managed object context as the server
//To submit jobs to different grids, use GEZGrid class instead
- (GEZJob *)submitJobWithSpecifications:(NSDictionary *)specs;


//KVO/KVC-compliant accessors
- (NSString *)address;
- (NSSet *)grids; //GEZGrid objects, not XGGrid
- (NSSet *)jobs; //GEZJob objects, not XGJob
- (BOOL)isAvailable;
- (BOOL)isConnecting;
- (BOOL)isConnected;
- (BOOL)isLoaded;
- (NSString *)status;
- (BOOL)shouldStorePasswordInKeychain;
- (void)setShouldStorePasswordInKeychain:(BOOL)flag;
- (GEZServerType)serverType;
- (BOOL)autoconnect;
- (void)setAutoconnect:(BOOL)newValue;


//See GEZGrid for more on that
- (BOOL)isObservingAllJobs; 
- (void)setObservingAllJobs:(BOOL)flag;


//non KVO/KVC-compliant accessors
- (BOOL)hasPasswordInKeychain;
- (GEZGrid *)defaultGrid;
- (GEZGrid *)gridWithIdentifier:(NSString *)identifier;

//low-level accessors
- (XGController *)xgridController;

@end


//methods to call only when running a GUI app
@interface GEZServer (GEZServerUI)

//these calls are exactly equivalent to the GEZManager calls - the latter may become deprecated, so these should be used instead
+ (void)showServerWindow;
+ (void)hideServerWindow;

//direct access to the "Xgrid Controllers" window - in general, you should use 'showServerWindow' and 'hideServerWindow', which will send a 'makeKeyAndOrderFront:'  or 'close:' message respectively (the latter message is only sent if the window already exists)
+ (NSWindow *)serverWindow;

//the Xgrid panel is a somewhat experimental inspector for grids, jobs and results, that should only be displayed to advanced Xgrid users
+ (void)showXgridPanel;
+ (void)hideXgridPanel;

//an interactive connection is one that may involve the user to type a password,...
- (void)connectWithUserInteraction;

@end

