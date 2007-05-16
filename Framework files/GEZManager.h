//
//  GEZManager.h
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
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
