//
//  GEZServerWindowController.h
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
+ (GEZServerWindowController *)sharedServerWindowController;

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
