//
//  GEZGrid.h
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */


//a grid is considered synced after all its attributes (name, jobs,...) have been uploaded from the server, but the jobs may not be synced yet
APPKIT_EXTERN NSString *GEZGridDidSyncNotification;

//a grid is considered loaded after all its attributes (name, jobs,...) have been uploaded from the server
APPKIT_EXTERN NSString *GEZGridDidLoadNotification;

@class GEZGridHook;
@class GEZServer;
@class GEZJob;

@interface GEZGrid : NSManagedObject
{
	GEZGridHook *gridHook;
}

//Retrieve grid methods only using the following methods
+ (GEZGrid *)gridWithIdentifier:(NSString *)identifier server:(GEZServer *)server;
//TODO(?)
//- (NSArray *)gridsForServer:(GEZServer *)server;
//- (GEZGrid *)defaultGridForServer:(GEZServer *)server;
//- (GEZGrid *)gridWithName:(NSString *)gridName server:(GEZServer *)server;

//TODO(?)
//returns a connected GEZGrid if there is one, otherwise return nil
//+ (GEZGrid *)connectedGrid;


//The GEZJob is added to the same managed object context as the grid
- (GEZJob *)submitJobWithSpecifications:(NSDictionary *)specs;

//KVO/KVC-compliant accessors
- (GEZServer *)server;
- (NSString *)name;
- (NSString *)identifier;
- (NSSet *)jobs; //GEZJob objects, not XGJob objects

//these are NOT (yet) compliant with KVO/KVC
- (BOOL)isAvailable;
- (BOOL)isConnecting;
- (BOOL)isConnected;
- (BOOL)isSynced;
- (BOOL)isLoaded;
- (NSString *)status;

//low-level accessor
- (XGGrid *)xgridGrid;

@end
