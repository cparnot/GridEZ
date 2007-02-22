//
//  GEZXgridPanelController.h
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import <Cocoa/Cocoa.h>


@interface GEZXgridPanelController : NSWindowController
{
	IBOutlet NSOutlineView *gridsView;
	IBOutlet NSTableView *jobsView;
	IBOutlet NSTableView *tasksView;
	IBOutlet NSOutlineView *filesView;
	id tableViews[4];
	
	//add controller sheet
	IBOutlet NSTextField *addControllerAddressField;
	IBOutlet NSWindow *addControllerSheet;

	//keys used for bindings
	int focusedTableView;
	NSFont *fileFont;
	
	IBOutlet NSTreeController *gridsController;
	IBOutlet NSArrayController *jobsController;
	IBOutlet NSArrayController *tasksController;
	IBOutlet NSTreeController *filesController;
}

//brings the job panel to the front and make it key
+ (void)showXgridPanel;

//does what it says
+ (void)hideXgridPanel;

//used by the nib to get the managed object context
- (NSManagedObjectContext *)managedObjectContext;

//used with Bindings to switch the contents of the bottom "inspector" panel
- (IBAction)changeInspectorType:(id)sender;

//actions for servers and grids
- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)loadAllJobs:(id)sender;

//actions for servers, grids and jobs
- (IBAction)addItem:(id)sender;
- (IBAction)removeItem:(id)sender;
- (IBAction)addAndConnectController:(id)sender;
- (IBAction)addController:(id)sender;
- (IBAction)cancelControllerAddition:(id)sender;

//actions for jobs
//actions for servers, grids and jobs
- (IBAction)retrieveJobResults:(id)sender;
- (IBAction)retrieveJobStreams:(id)sender;
- (IBAction)resetResults:(id)sender;

@end
