//
//  GEZServerWindowController.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



/*
 Singleton class. This makes sense, because there is only one Server Window needed.
 
 The singleton is a window controller for the "ServerWindow" nib file. it responds to all the buttons on the Window, and is connected to the managed object context created by the GridEZ framework to manage Server and Grids at the application level.
 
 */

#import "GEZServerWindowController.h"
#import "GEZServer.h"
#import "GEZManager.h"

//see implementation for details
@interface GEZServerWindowController (GEZServerWindowControllerPrivate)
- (void)startConnectionWithoutAuthentication;
- (void)startConnectionWithAuthentication;
- (void)stopConnection;
- (void)serverDidConnectNotification:(NSNotification *)aNotification;
- (void)serverDidNotConnectNotification:(NSNotification *)aNotification;
- (void)endConnectionProcess;
- (GEZServer *)selectedServerInTheTableView;
- (GEZServer *)selectedServer;
- (void)controlTextDidBeginEditing:(NSNotification *)aNotification;
@end

@implementation GEZServerWindowController

#pragma mark *** Singleton initialization ***

static GEZServerWindowController *sharedServerWindowController = nil;

//lazy instantiation of the singleton instance
+ (GEZServerWindowController *)sharedServerWindowController
{
	if ( sharedServerWindowController == nil )
		sharedServerWindowController = [[GEZServerWindowController alloc] init];
	return sharedServerWindowController;
}

- (id)init
{
	self = [super initWithWindowNibName:@"ServerWindow"];
	if ( self != nil ) {
		[self setWindowFrameAutosaveName:@"GEZServerWindow"];
	}
	return self;
}

#pragma mark *** Public class methods ***

+ (void)showServerWindow
{
	[[self sharedServerWindowController] showWindow:self];
	[GEZServer startBrowsing];
}

+ (void)hideServerWindow
{
	[GEZServer stopBrowsing];
	[[self sharedServerWindowController] close];
}

#pragma mark *** Bindings ***

- (NSManagedObjectContext *)managedObjectContext
{
	return [GEZManager managedObjectContext];
}

#pragma mark *** Actions ***

//see GEZServerWindowControllerPrivate category below for a complete description of the connection process

- (IBAction)connect:(id)sender
{	
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[self startConnectionWithoutAuthentication];
}

- (IBAction)connectWithAuthentication:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	[self startConnectionWithAuthentication];
}

- (IBAction)cancelConnect:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[self stopConnection];
}

@end



@implementation GEZServerWindowController (GEZServerWindowControllerPrivate)

/*
 The connection process is complicated by the fact that a password may be needed, but we are not going to ask for it unless it is needed.
 
 So, here is the process:
 * the user clicks 'Connect' in the main window
 * the action 'connect:' gets called
 * the method 'startConnectionWithoutAuthentication'is called:
	* change the UI to correspond to a state 'isConnecting'
	* setup self to receive notifications of connections
	* start connection w/o password
 * if 'serverDidConnectNotification' is called, connection worked, we are done  and can call 'endConnectionProcess'
 * if 'serverDidNotConnectNotification' is called, connection did not work, so we need to:
	* set up a modal sheet for authentication
	* start the modal sheet
	* wait for user to press 'Connect' in the modal sheet
	* 'startConnectionWithAuthentication is called', which triggers a new connection attempt
	 * if 'serverDidConnectNotification' is called, connection worked, we are done  and can call 'endConnectionProcess'
	 * if 'serverDidNotConnectNotification' is called, connection did not work, we change the GUI to inform the user and wait for the user to Cancel or try another password
 * At any time, the user can click 'Cancel' to cancel the current connection
 * the method 'endConnectionProcess' does the following:
	* clean up intermediary ivars
	* restore the GUI to its initial state
	* close the sheet if open

 */

//first step: connection attempt from the main window, with no password from the user
- (void)startConnectionWithoutAuthentication
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//do we need to even connect?
	currentServer = [[self selectedServer] retain];
	if ([currentServer isConnected]) {
		[self endConnectionProcess];
		return;	
	}
	
	//change the UI of the main window to the state 'isConnecting'
	[connectButton1 setKeyEquivalent:@"\e"];
	[connectButton1 setTitle:@"Cancel"];
	[connectButton1 setAction:@selector(cancelConnect:)];
	[progressIndicator1 startAnimation:self];
	
	//start the connection
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverDidConnectNotification:) name:GEZServerDidConnectNotification object:currentServer];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverDidNotConnectNotification:) name:GEZServerDidNotConnectNotification object:currentServer];
	[currentServer connectWithoutAuthentication];
}

//called if an authentication sheet has been brought, and the user typed a password and is ready to connect
- (void)startConnectionWithAuthentication
{
	//change the UI of the authentication sheet to the state 'isConnecting'
	[connectButton2 setEnabled:NO];
	[authenticationFailedTextField setHidden:YES];
	[progressIndicator2 startAnimation:self];
	
	//start the connection
	if ( [[authenticationTypeMatrix selectedCell] tag] == 0 )
		[currentServer connectWithSingleSignOnCredentials];
	else
		[currentServer connectWithPassword:[passwordField stringValue]];
}


//connection worked, with or w/o password, we don't care --> endConnectionProcess
- (void)serverDidConnectNotification:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self endConnectionProcess];
}


//connection did not work:
//	* if no password yet --> bring the authentication sheet to try with one
//	* if already done with password --> notify the user and let her resolve the issue
- (void)serverDidNotConnectNotification:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	if ( [aNotification object] != currentServer ) {
		[self endConnectionProcess];
		return;
	}
	
	//if no authentication sheet, it means authentication w/o password failed, so we have to now try with authentication
	if ( [[self window] attachedSheet] == nil ) {
		[progressIndicator1 stopAnimation:self];
		[authenticationFailedTextField setHidden:YES];
		[serverNameField setStringValue:[currentServer address]];
		[NSApp beginSheet:connectSheet modalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
	}
	
	//else the authentication sheet is already on, which means the authentication failed
	else {
		//change the UI of the authentication sheet to the state 'isNotConnecting' and 'Failed'
		[connectButton2 setEnabled:YES];
		[progressIndicator2 stopAnimation:self];
		[authenticationFailedTextField setHidden:NO];
	}
	
}

- (void)stopConnection
{
	[currentServer disconnect];

	//if no authentication sheet or no connection connection with authentication, it means canceling the whole connection process
	if ( [[self window] attachedSheet] == nil || [connectButton2 isEnabled] )
		[self endConnectionProcess];

	//otherwise, we only need to cancel the connection w/o authentication and exit
	else {
		//change the UI of the authentication sheet to the state 'isNotConnecting'
		[connectButton2 setEnabled:YES];
		[progressIndicator2 stopAnimation:self];
		[authenticationFailedTextField setHidden:YES];
	}
}


//called in all cases, at the end of the connection process, which could be because it worked, was canceled, or something fishy happened
- (void)endConnectionProcess
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//change the UI of the main window to the state 'isNotConnecting'
	[connectButton1 setKeyEquivalent:@"\r"];
	[connectButton1 setTitle:@"Connect"];
	[connectButton1 setAction:@selector(connect:)];
	[progressIndicator1 stopAnimation:self];
	[serverAddressTextField setStringValue:@""];
	
	//reset the currentServer
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[currentServer release];
	currentServer = nil;
	
	//remove the connect sheet if open
	if ( [[self window] attachedSheet] ) {
		//change the UI of the authentication sheet to the state 'isNotConnecting'
		[connectButton2 setEnabled:YES];
		[authenticationFailedTextField setHidden:YES];
		[progressIndicator2 stopAnimation:self];
		[passwordField setStringValue:@""];
		//close the sheet
		[NSApp endSheet:connectSheet];
		[connectSheet orderOut:self];
	}
}

//returns the GEZServer instance selected in the table view of the main window
- (GEZServer *)selectedServerInTheTableView
{
	NSArray *servers;
	servers = [serverArrayController selectedObjects];
	if ( [servers count] == 1 )
		return [servers objectAtIndex:0];
	else
		return nil;
}

//returns the server with the name typed in the text field or the one selected in the table view
- (GEZServer *)selectedServer
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//if the text view has the focus and is not empty, use that for the server
	if ( [[self window] firstResponder] ) {
		NSString *address =  [serverAddressTextField stringValue];
		if ( [address length] > 0 )
			return [GEZServer serverWithAddress:address];
	}
	
	//otherwise, use the server selected in the table view, if any
	return [self selectedServerInTheTableView];
}

//self is set to be a delegate of the password text field
//this method is then triggered by the user when typing a password in the connect sheet
//the radio button for 'connection with password' is then automatically selected
- (void)controlTextDidBeginEditing:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[[authenticationTypeMatrix cellWithTag:1] performClick:self];
}



@end
