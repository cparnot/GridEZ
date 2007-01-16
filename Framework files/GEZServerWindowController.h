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
	//main window with the list of controllers/grids
	IBOutlet NSOutlineView *gridsOutlineView;
	IBOutlet NSTreeController *gridsController;

	//sheet used to add a server
	IBOutlet NSTextField *addServerAddressField;
	IBOutlet NSWindow *addServerSheet;
	
}

//these are the only methods that needs to be called from another class
+ (void)showServerWindow;
+ (void)hideServerWindow;

//used by the nib to get the managed object context
- (NSManagedObjectContext *)managedObjectContext;

//Actions in the main window and contextual menu
- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)addItem:(id)sender;
- (IBAction)removeItem:(id)sender;

//Actions in the "Add Server" sheet
- (IBAction)addAndConnectServer:(id)sender;
- (IBAction)addServer:(id)sender;
- (IBAction)cancelServerAddition:(id)sender;

@end
