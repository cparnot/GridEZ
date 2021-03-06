//
//  GEZServerWindowController.m
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
 Singleton class. This makes sense, because there is only one Server Window needed.
 
 The singleton is a window controller for the "ServerWindow" nib file. it responds to all the buttons on the Window, and is connected to the managed object context created by the GridEZ framework to manage Server and Grids at the application level
 
 */

#import "GEZServerWindowController.h"
#import "GEZServer.h"
#import "GEZBindingsCategories.h"
#import "GEZManager.h"
#import "GEZConnectionPanelController.h"


@implementation GEZServerWindowController

+ (void)initialize
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	//set up toolbar images
	NSBundle *gridezBundle = [NSBundle bundleForClass:[GEZServerWindowController class]];
	NSArray *files = [NSArray arrayWithObjects:@"ConnectServerToolbarIcon", @"DisconnectServerToolbarIcon", @"AddServerToolbarIcon", @"RemoveServerToolbarIcon", nil];
	NSEnumerator *e = [files objectEnumerator];
	NSString *filename;
	while ( filename = [e nextObject] ) {
		NSImage *toolbarIcon =  [[NSImage alloc] initWithContentsOfFile:[gridezBundle pathForResource:filename ofType:@"png"]];
		[toolbarIcon setName:filename];
	}

	//these keys are only used for bindings, so we only activate them here, not in GEZServer; the getters for these keys are defined in GEZBindingCategories
	//serverStatus is used as a replacement for "status", and is designed to onlyh return a value for GEZServer, not GEZGrid, so that only GEZServer objects have a status image in the Outline view
	[GEZServer setKeys:[NSArray arrayWithObjects:@"available", @"connecting", @"connected", @"loaded", @"wasAvailableInCurrentSession", @"wasAvailableInPreviousSession", @"wasConnectedInCurrentSession", @"wasConnectedInPreviousSession", nil] triggerChangeNotificationsForDependentKey:@"serverStatus"];
	//this key is used to enable/disable the different icons in the toolbar
	[GEZServer setKeys:[NSArray arrayWithObjects:@"connecting", @"connected", @"loaded", nil] triggerChangeNotificationsForDependentKey:@"busy"];
}


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
	//double-click in the servers/grids outline view is equivalent to connect: action
	[gridsOutlineView setDoubleAction:@selector(connect:)];

	//keep the servers sorted by name
	[gridsController setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(compareNumerically:)] autorelease]]];
	
	//adding the toolbar and setting the defaults
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"ServerWindowToolbar"] autorelease];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setSizeMode:NSToolbarSizeModeSmall];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [toolbar setAutosavesConfiguration:YES];
	[[self window] setToolbar:toolbar];
	[toolbar setVisible:YES];
	[[self window] setShowsToolbarButton:NO];
	
}

//validation of the actions triggered by the toolbar items and the hidden 'delete' and 'connect' buttons
- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	BOOL validate = NO;
	
	SEL action = [anItem action];
	//NSLog(@"Validate action: %s", action);
	if ( action == @selector(addItem:) )
		validate = YES;
	else {
		//validation depends on how many items are already connected, disconnected, or available
		NSArray *selection = [gridsController valueForKeyPath:@"selectedObjects.server"];
		int countTotal = [selection count];
		if ( countTotal < 1 )
			validate = NO;
		else if ( action == @selector(autoconnect:) )
			validate = YES;
		else {
			int countBusy = 0;
			int countAvailable = 0;
			NSEnumerator *e = [selection objectEnumerator];
			GEZServer *aServer;
			while ( aServer = [e nextObject] ) {
				if ( [aServer isBusy] )
					countBusy++;
				if ( [aServer isAvailable] )
					countAvailable++;
			}
			if ( ( countAvailable != countTotal ) && ( action == @selector(removeItem:) ) )
				validate = YES;
			if ( ( countBusy > 0 ) && ( action == @selector(disconnect:) ) )
				validate = YES;
			if ( ( countBusy != countTotal ) && ( action == @selector(connect:) ) )
				validate = YES;
		}
	}
	
	return validate;
}


#pragma mark *** Public class methods ***

+ (void)showServerWindow
{
	[[[self sharedServerWindowController] window] makeKeyAndOrderFront:self];
	[GEZServer startBrowsing];
}

+ (void)hideServerWindow
{
	[GEZServer stopBrowsing];
	if ( sharedServerWindowController != nil )
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
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	NSArray *selection = [gridsController valueForKeyPath:@"selectedObjects.server"];
	GEZServer *selectedServer;
	NSEnumerator *e = [selection objectEnumerator];
	while ( selectedServer = [e nextObject] )
		[GEZConnectionPanelController runConnectionPanelWithServer:selectedServer];
}


- (IBAction)disconnect:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	NSArray *selection = [gridsController valueForKeyPath:@"selectedObjects.server"];
	GEZServer *selectedServer;
	NSEnumerator *e = [selection objectEnumerator];
	while ( selectedServer = [e nextObject] )
		[selectedServer disconnect];
}

- (IBAction)addItem:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[NSApp beginSheet:addServerSheet modalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)removeItem:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//if there is more than 1 object deleted, they can not be simply deleted from the managed object context without telling the NSTreeController (bug??), so we have to delete them using the NSTreeController instance 'gridsController'
	NSEnumerator *e1 = [[gridsController selectedObjects] objectEnumerator];
	NSEnumerator *e2 = [[gridsController selectionIndexPaths] objectEnumerator];
	id serverOrGrid;
	NSIndexPath *path;
	NSMutableArray *deletedPaths = [NSMutableArray array];
	while ( ( serverOrGrid = [e1 nextObject] ) && ( path = [e2 nextObject] ) ) {
		if ( [serverOrGrid isKindOfClass:[GEZServer class]] && ( [serverOrGrid isAvailable] == NO ) )
			[deletedPaths addObject:path];
	}
	[gridsController removeObjectsAtArrangedObjectIndexPaths:deletedPaths];
}



- (IBAction)cancelServerAddition:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	//close the sheet
	[NSApp endSheet:addServerSheet];
	[addServerSheet orderOut:self];
}

- (IBAction)addServer:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	NSString *address = [addServerAddressField stringValue];
	if ( [address isEqualToString:@""] )
		return;

	//close the sheet
	[NSApp endSheet:addServerSheet];
	[addServerSheet orderOut:self];

	//add the server
	[GEZServer serverWithAddress:address];
	
}

- (IBAction)addAndConnectServer:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	NSString *address = [addServerAddressField stringValue];
	if ( [address isEqualToString:@""] )
		return;
	
	//close the sheet
	[NSApp endSheet:addServerSheet];
	[addServerSheet orderOut:self];

	//retrieve the server and start connection
	GEZServer *newServer = [GEZServer serverWithAddress:address];
	[GEZConnectionPanelController runConnectionPanelWithServer:newServer];
	
}


#pragma mark *** NSOutlineView delegate ***

/*
//update the state of the menu item "Autoconnect" in the outline view contextual menu
- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	NSArray *selection = [gridsController valueForKeyPath:@"selectedObjects.server"];
	NSCellStateValue menuState = NSMixedState;
	if ( [selection count] == 1 )
		menuState = [[selection objectAtIndex:0] autoconnect];
	[[[[aNotification object] menu] itemWithTitle:@"Autoconnect"] setState:menuState];
}
*/

#pragma mark *** Toolbar setup ***


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    
    if ( [itemIdentifier isEqualToString:@"ConnectServer"] ) {
        [item setLabel:@"Connect"];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"ConnectServerToolbarIcon"]];
        [item setTarget:self];
        [item setAction:@selector(connect:)];
		[item setToolTip:@"Connect to the selected controller(s)"];
    } else if ( [itemIdentifier isEqualToString:@"DisconnectServer"] ) {
        [item setLabel:@"Disconnect"];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"DisconnectServerToolbarIcon"]];
        [item setTarget:self];
        [item setAction:@selector(disconnect:)];
		[item setToolTip:@"Disconnect the selected controller(s)"];
    } else if ( [itemIdentifier isEqualToString:@"AddServer"] ) {
        [item setLabel:@"Add"];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"AddServerToolbarIcon"]];
        [item setTarget:self];
        [item setAction:@selector(addItem:)];
		[item setToolTip:@"Add a controller"];
    } else if ( [itemIdentifier isEqualToString:@"RemoveServer"] ) {
        [item setLabel:@"Remove"];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"RemoveServerToolbarIcon"]];
        [item setTarget:self];
        [item setAction:@selector(removeItem:)];
		[item setToolTip:@"Remove the selected controller(s)"];
    }
    
    return item;
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:@"ConnectServer", @"DisconnectServer", @"AddServer", @"RemoveServer", nil];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    return [NSArray arrayWithObjects:@"ConnectServer", @"DisconnectServer", @"AddServer", @"RemoveServer", nil];
}


@end

