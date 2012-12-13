//
//  GEZManager.h
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
 The GEZManager class is used to retrieve and set framework-wide or application-wide settings and objects.
 See individual methods for details.
 */

@class GEZGrid;

@interface GEZManager : NSObject
{
	NSManagedObjectModel *managedObjectModel;
	NSManagedObjectContext *managedObjectContext;
	NSMutableArray *registeredContexts;
}

//the managed object context is used to store objects at the application level; this context is unique for the whole application. In particular, it is used to store GEZServer objects. A persistent store is automatically created too, in the 'Application Support' folder. This path is specific for the running application and will not be the same when the framework is used in two different applications.
+ (NSManagedObjectContext *)managedObjectContext;


//when using additional managed object contexts to create and manage GridEZ objects, you should register them so the GEZServer objects are added to the main managedObjectContext
+ (void)registerManagedObjectContext:(NSManagedObjectContext *)context;


+ (void)setMaxFileDownloads:(int)max;

//these calls are exactly equivalent to the GEZServer calls - these methods will probably be deprecated, so use the GEZServer methods instead
//brings the generic server window to the front and make it key; this window can be used by any application just like the Font panel or one of these application-level panels and windows; it is automatically connected to the managed object context that keeps track of Servers and Grids; the user can connect to different Xgrid Servers, aka Controllers, and can control everything from there
+ (void)showServerWindow;
+ (void)hideServerWindow;
+ (void)showXgridPanel;
+ (void)hideXgridPanel;

@end
