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
 
 The singleton is a window controller for the "ServerWindow" nib file. it responds to all the buttons on the Window, and is connected to the managed object context created by the GridEZ framework to manage Server and Grids at the application level
 
 */

#import "GEZServerWindowController.h"
#import "GEZServer.h"
#import "GEZManager.h"
#import "GEZConnectionPanelController.h"

@interface GEZServerWindowController (GEZServerWindowControllerPrivate)
- (GEZServer *)selectedServerInTheTableView;
- (GEZServer *)selectedServer;
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

- (void)awakeFromNib
{
	//double-click in the table view is equivalent to clicking the connect button
	[serverListTableView setDoubleAction:@selector(connect:)];
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


#pragma mark *** Actions ***

//see GEZServerWindowControllerPrivate category below for a complete description of the connection process

- (IBAction)connect:(id)sender
{	
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	[GEZConnectionPanelController runConnectionPanelWithServer:[self selectedServer]];
	return;
}

@end

