//
//  GEZXgridPanelController.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import "GEZXgridPanelController.h"
#import "GEZServer.h"
#import "GEZJob.h"
#import "GEZManager.h"
#import "GEZConnectionPanelController.h"

@implementation GEZXgridPanelController

#pragma mark *** Singleton initialization ***

static GEZXgridPanelController *sharedXgridPanelController = nil;

//lazy instantiation of the singleton instance
+ (GEZXgridPanelController *)sharedXgridPanelController
{
	if ( sharedXgridPanelController == nil )
		sharedXgridPanelController = [[GEZXgridPanelController alloc] init];
	return sharedXgridPanelController;
}

+ (void)initialize
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	
	[self setKeys:[NSArray arrayWithObject:@"focusedTableView"] triggerChangeNotificationsForDependentKey:@"gridFocus"];
	[self setKeys:[NSArray arrayWithObject:@"focusedTableView"] triggerChangeNotificationsForDependentKey:@"jobFocus"];
	[self setKeys:[NSArray arrayWithObject:@"focusedTableView"] triggerChangeNotificationsForDependentKey:@"taskFocus"];
	[self setKeys:[NSArray arrayWithObject:@"focusedTableView"] triggerChangeNotificationsForDependentKey:@"fileFocus"];

	//these keys are only used for bindings, so we only activate them here; the getter for these keys are defined in GEZBindingCategories
	[GEZServer setKeys:[NSArray arrayWithObjects:@"isAvailable", @"isConnecting", @"isConnected", @"isLoaded", @"wasAvailableInCurrentSession", @"wasAvailableInPreviousSession", @"wasConnectedInCurrentSession", @"wasConnectedInPreviousSession", nil] triggerChangeNotificationsForDependentKey:@"serverStatus"];
	[GEZServer setKeys:[NSArray arrayWithObjects:@"isConnecting", @"isConnected", @"isLoaded", nil] triggerChangeNotificationsForDependentKey:@"isBusy"];
}

- (id)init
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	self = [super initWithWindowNibName:@"XgridPanel"];
	if ( self != nil ) {
		[self setWindowFrameAutosaveName:@"GEZXgridPanel"];
		fileFont = [[NSFont fontWithName:@"Monaco" size:9.0] retain];
		focusedTableView = 0;
	}
	return self;
}
- (void)awakeFromNib
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	//double-click in the servers/grids is equivalent to connect: action
	[gridsView setDoubleAction:@selector(connect:)];
	
	//this is used together with focusedTableView to keep track of the table view that has the focus
	tableViews[0] = gridsView;
	tableViews[1] = jobsView;
	tableViews[2] = tasksView;
	tableViews[3] = filesView;
	
	//remove Focus Ring to make it look like a panel (cf font or color panels)
	[gridsView setFocusRingType:NSFocusRingTypeNone];
	[jobsView setFocusRingType:NSFocusRingTypeNone];
	[tasksView setFocusRingType:NSFocusRingTypeNone];
	[filesView setFocusRingType:NSFocusRingTypeNone];
	
	//the offset is too large for small text
	[gridsView setIndentationPerLevel:10.0];
	[filesView setIndentationPerLevel:10.0];
	
	//keep the jobs sorted by submission order
	NSSortDescriptor *identifierSorter = [[[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:YES selector:@selector(compareNumerically:)] autorelease];
	NSArray *sortDescriptors = [NSArray arrayWithObject:identifierSorter];
	[jobsController setSortDescriptors:sortDescriptors];
	
	//keep the tasks sorted by index
	NSSortDescriptor *nameSorter = [[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(compareNumerically:)] autorelease];
	sortDescriptors = [NSArray arrayWithObject:nameSorter];
	[tasksController setSortDescriptors:sortDescriptors];

	//keep the files sorted by name
	[filesController setSortDescriptors:sortDescriptors];

	//keep the servers sorted by name
	[gridsController setSortDescriptors:sortDescriptors];
}

- (void)dealloc
{
	[fileFont release];
	[super dealloc];
}

#pragma mark *** Public class methods ***

+ (void)showXgridPanel
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	[[self sharedXgridPanelController] showWindow:self];
	[GEZServer startBrowsing];
}

+ (void)hideXgridPanel
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	//[GEZServer stopBrowsing];
	[[self sharedXgridPanelController] close];
}



#pragma mark *** Switching focus on the table views ***

//values of focusedTableView corresponding to the different table views having the key focus; this is used for tags of UI elements and for focusedTableView assignement
#define GRID_FOCUS 0
#define JOB_FOCUS 1
#define TASK_FOCUS 2
#define FILE_FOCUS 3

#define MIN_FOCUS 0
#define MAX_FOCUS 3

//the tags in the UI are actually offset by this value, otherwise we have to use 0 for one of the tag value, and this is the default value of all elements, which makes it difficult to retrieve a table/outline view using its tag number
#define TAG_OFFSET 1000

- (void)setFocusedTableView:(int)newFocus
{
	if ( ( newFocus != focusedTableView ) && ( newFocus >= MIN_FOCUS ) && ( newFocus <= MAX_FOCUS ) ) {
		if ( [[self window] makeFirstResponder:tableViews[newFocus]] )
			focusedTableView = newFocus;
	}
}

- (NSManagedObjectContext *)managedObjectContext
{
	return [GEZManager managedObjectContext];
}

//the key "focusedTableView" is used to bind the tabless NSTabView used to display the different inspectors depending on the selection
- (IBAction)changeInspectorType:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	
	//the action may come from one of the NSTableView/NSOutlineView, which tells the controller it has just been selected
	int focus = GRID_FOCUS;
	if ( sender != nil )
		focus = [sender tag];
	
	//if the action is not a result of a NSTableView/NSOutlineView selection, and comes from somewhere else in the code, e.g. when window becomes main/key, we need to determine which of them is the first responder and has the focus
	else {
		id focusedView = [[self window] firstResponder];
		if ( [focusedView isKindOfClass:[NSTableView class]] )
			focus = [focusedView tag];
	}

	[self setFocusedTableView:focus-TAG_OFFSET];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[self changeInspectorType:nil];
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[self changeInspectorType:nil];
}


- (BOOL)gridFocus
{
	return focusedTableView == GRID_FOCUS;
}

- (BOOL)jobFocus
{
	return focusedTableView == JOB_FOCUS;
}
- (BOOL)taskFocus
{
	return focusedTableView == TASK_FOCUS;
}
- (BOOL)fileFocus
{
	return focusedTableView == FILE_FOCUS;
}

//change the table view that has the focus and select an item if none is
- (void)moveFocus:(int)newFocus
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	int old = focusedTableView;
	[self setFocusedTableView:newFocus];
	int new = focusedTableView;
	if ( new != old ) {
		NSTableView *table = tableViews[focusedTableView];
		if ( [table selectedRow] == -1 )
			[table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	}
}

- (void)moveLeft:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[self moveFocus:focusedTableView-1];
}

- (void)moveRight:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	if ( ( focusedTableView < MAX_FOCUS ) && ( [tableViews[focusedTableView+1] numberOfRows] > 0 ) )
		[self moveFocus:focusedTableView+1];
}

#pragma mark *** Actions ***

- (IBAction)connect:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	NSArray *selection = [gridsController valueForKeyPath:@"selectedObjects.server"];
	GEZServer *selectedServer;
	NSEnumerator *e = [selection objectEnumerator];
	while ( selectedServer = [e nextObject] )
		[GEZConnectionPanelController runConnectionPanelWithServer:[selection objectAtIndex:0]];
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
	[NSApp beginSheet:addControllerSheet modalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)removeItem:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	if ( focusedTableView == GRID_FOCUS ) {
		
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

		/*
		//[gridsController remove:self];
		//return;
		//remove selected servers if offline
		NSArray *selection = [gridsController valueForKeyPath:@"selectedObjects.server"];
		GEZServer *selectedServer;
		NSEnumerator *e = [selection objectEnumerator];
		while ( selectedServer = [e nextObject] ) {
			if ( ![selectedServer isAvailable] ) {
				//[selectedServer performSelector:@selector(deleteFromStore) withObject:nil afterDelay:0];
				[selectedServer deleteFromStore];
				[gridsController fetch:self];
				[gridsController rearrangeObjects];
			}
		*/
		
	} else if ( focusedTableView == JOB_FOCUS ) {
		//remove selected jobs from grid
		NSArray *selection = [jobsController valueForKeyPath:@"selectedObjects"];
		GEZJob *selectedJob;
		NSEnumerator *e = [selection objectEnumerator];
		while ( selectedJob = [e nextObject] )
			[selectedJob delete];
	}
}

- (IBAction)cancelControllerAddition:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	//close the sheet
	[NSApp endSheet:addControllerSheet];
	[addControllerSheet orderOut:self];
}

- (IBAction)addController:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	//add the server
	[GEZServer serverWithAddress:[addControllerAddressField stringValue]];
	
	//close the sheet
	[NSApp endSheet:addControllerSheet];
	[addControllerSheet orderOut:self];
}

- (IBAction)addAndConnectController:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	
	//add the server and start connection
	GEZServer *newServer = [GEZServer serverWithAddress:[addControllerAddressField stringValue]];
	[GEZConnectionPanelController runConnectionPanelWithServer:newServer];
	
	//close the sheet
	[NSApp endSheet:addControllerSheet];
	[addControllerSheet orderOut:self];
}

@end
