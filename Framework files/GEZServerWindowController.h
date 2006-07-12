//
//  GEZServerWindowController.h
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



/*
 Private class in charge of the Server Window (aka Controller Window) that displays Xgrid Servers available in the local network, as well as previously connected servers, and allows the user to connect/disconnect to them
 */

@class GEZServer;

@interface GEZServerWindowController : NSWindowController
{
	GEZServer *currentServer;

	//for the main window
	IBOutlet NSTableView *serverListTableView;
	IBOutlet NSArrayController *serverArrayController;
	IBOutlet NSTextField *serverAddressTextField;
	IBOutlet NSButton *connectButton1;
	IBOutlet NSProgressIndicator *progressIndicator1;
	
	//for the connection sheet
	IBOutlet NSWindow *connectSheet;
	IBOutlet NSMatrix *authenticationTypeMatrix;
	IBOutlet NSTextField *serverNameField;
	IBOutlet NSSecureTextField *passwordField;
	IBOutlet NSTextField *authenticationFailedTextField;
	IBOutlet NSButton *connectButton2;
	IBOutlet NSProgressIndicator *progressIndicator2;

}

//brings the server window to the front and make it key
+ (void)showServerWindow;

//does what it says
+ (void)hideServerWindow;

//used by the nib to get the managed object context
- (NSManagedObjectContext *)managedObjectContext;

//Actions used for connections
- (IBAction)connect:(id)sender;
- (IBAction)connectWithAuthentication:(id)sender;
- (IBAction)cancelConnect:(id)sender;

@end
