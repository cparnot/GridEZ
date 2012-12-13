//
//  GEZXgridPanelController.h
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
