//
//  GEZUtilites.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import "GEZManager.h"
#import "GEZServer.h"
#import "GEZGrid.h"
#import "GEZTransformers.h"
#import "GEZServerWindowController.h"
#import "GEZXgridPanelController.h"
#import "GEZDefines.h"

@implementation GEZManager

#pragma mark *** initialization for the framework ***

+ (void)initialize
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//register the string to image transformer
	GEZStringToImageTransformer *transformer1 = [[[GEZStringToImageTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer1 forName:@"GEZStringToImageTransformer"];
	
	//register the data to string transformer
	GEZDataToStringTransformer *transformer2 = [[[GEZDataToStringTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer2 forName:@"GEZDataToStringTransformer"];
}

#pragma mark *** creating and retrieving the singleton instance ***

GEZManager *sharedManager = nil;

+ (GEZManager *)sharedManager
{
	if ( sharedManager == nil )
		sharedManager = [[GEZManager alloc] init];
	return sharedManager;
}

#pragma mark *** Deallocation ***
//will probably never happen
- (void)dealloc
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[managedObjectContext release];
	[managedObjectModel release];
	[registeredContexts release];
	[super dealloc];
}

#pragma mark *** Main Managed Object Context ***

- (NSBundle *)gridezFramework
{
	return [NSBundle bundleForClass:[GEZManager class]];
}

- (NSManagedObjectModel *)managedObjectModel
{
	//lazy instantiation
	if ( managedObjectModel != nil )
		return managedObjectModel;
	
	NSMutableSet *allBundles = [NSMutableSet set];
	[allBundles addObject: [NSBundle mainBundle]];
	[allBundles addObjectsFromArray: [NSBundle allFrameworks]];
	managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles: [allBundles allObjects]] retain];

	//DLog(NSStringFromClass([self class]),5,@"<%@:%p> %s - Model =\n%@",[self class],self,_cmd,[managedObjectModel entitiesByName]);

    return managedObjectModel;
}

//convenience function to create a directory
//returns NO upon error or if a file is at that path and not a directory
BOOL CreateFolder (NSString *path)
{
	BOOL isDir;
	NSFileManager *manager = [NSFileManager defaultManager];
	if ( [manager fileExistsAtPath:path isDirectory:&isDir] )
		return isDir;
	else
		return [manager createDirectoryAtPath:path attributes:nil];
}

- (NSString *)validApplicationSupportFolder
{
	//create an application support folder in the user directory
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES);
	if ( [paths count] < 1 )
		return nil;
	NSString *resultPath = [paths objectAtIndex:0];
	if ( CreateFolder(resultPath) == NO )
		return nil;
	
	//...then create a folder with the name of the running application
	NSString *applicationName = [[[[NSBundle mainBundle] bundlePath] lastPathComponent] stringByDeletingPathExtension];
	resultPath = [resultPath stringByAppendingPathComponent:applicationName];
	if ( CreateFolder(resultPath) == NO )
		return nil;
	
	//...then create a GridEZ folder inside
	resultPath = [resultPath stringByAppendingPathComponent:@"GridEZ"];
	if ( CreateFolder(resultPath) == NO )
		return nil;

	//...now a subfolder with the version number
	//major version are compatible with each other (e.g. 1.1 and 1.5 are compatible)
	//except before 1.0 where minor versions are not compatible (0.3.0 and 0.3.1 are compatible, but not 0.3 and 0.4)
	NSString *bundleVersion = [[self gridezFramework] objectForInfoDictionaryKey:@"CFBundleVersion"];
	NSString *version = @"0";
	if ( [bundleVersion length] > 0 ) {
		version = [bundleVersion substringToIndex:1];
			if ( [version isEqualToString:@"0"] && [bundleVersion length] > 2 )
				version = [bundleVersion substringToIndex:3];
	}
	version = [@"Version " stringByAppendingString:version];
	//use a different name in debug mode, I found this was useful, can't remember why
#ifdef DEBUG
	version = [version stringByAppendingString:@"_DEBUG"];
#endif
	resultPath = [resultPath stringByAppendingPathComponent:version];
	if ( CreateFolder(resultPath) == NO )
		return nil;
	
    return resultPath;
}

- (NSManagedObjectContext *)managedObjectContext
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

    //lazy instantiation means potential early exit...
    if ( managedObjectContext )
        return managedObjectContext;

	//create a folder in the application support folder, typically '~/Library/Application Support/Killer App/GridEZ/Version 1/'
    NSString *applicationSupportFolder = [self validApplicationSupportFolder];
	if ( applicationSupportFolder == nil ) {
		NSLog (@"Could not create application support folder at path %@",applicationSupportFolder);
		return nil;
	}

	//by default, the default managed object context created by the framework will create a store of type SQLLite; this setting can be changed by the developer by using the Info.plist of the application (see user docs)
	NSString *storeType = [[[NSBundle mainBundle] infoDictionary] objectForKey:GEZStoreType];
	NSString *storeExtension;
	DLog(NSStringFromClass([self class]),10,@"Store type from info.plist with key %@ is %@", GEZStoreType, storeType);
	if ( [storeType isEqualToString:@"XML"] ) {
		storeType = NSXMLStoreType;
		storeExtension = @"xml";
	}
	else if ( [storeType isEqualToString:@"Binary"] ) {
		storeType = NSBinaryStoreType;
		storeExtension = @"bin";
	}
	else if ( [storeType isEqualToString:@"InMemory"] ) {
		storeType = NSInMemoryStoreType;
		storeExtension = @"nonapplicable";
	}
	else {
		storeType = NSSQLiteStoreType;
		storeExtension = @"db";
	}
	
	//create the stack for the managed object context
    NSURL *url = [NSURL fileURLWithPath: [[applicationSupportFolder stringByAppendingPathComponent: @"GridStuffer"] stringByAppendingPathExtension:storeExtension]];
	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    NSError *error;
	
	
    if ([coordinator addPersistentStoreWithType:storeType configuration:nil URL:url options:nil error:&error]){
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    } else {
		NSLog(@"Error while creating the managed object context for GridEZ:\n%@",error);
        [NSApp presentError:error];
    }    
    [coordinator release];
	
	//in general, it is better not to have any NSUndoManager
	//however, this option can be overriden in the application bundle options (Info.plist) to keep an active NSUndoManager (see user docs)
	if ( [[[[NSBundle mainBundle] infoDictionary] objectForKey:GEZShouldUseUndoManager] boolValue] == NO ) {
		DLog(NSStringFromClass([self class]),10,@"Removing NSUndoManager");
		[managedObjectContext setUndoManager:nil];
	}
    
    return managedObjectContext;
}


#pragma mark *** Other managed object contexts ***

//when using additional managed object contexts to create and manage GridEZ objects, we should register them so the GEZServer objects are added to the main managedObjectContext
//NOTE:it is not clear at this point that we really need to keep all of these registered contexts in an NSSet
- (void)registerManagedObjectContext:(NSManagedObjectContext *)context
{
	if ( registeredContexts == nil )
		registeredContexts = [[NSMutableArray alloc] initWithCapacity:1];
	
	//we could have used a NSMutableSet, but anyway we might as well verify that the context is not already in the list to avoid loading the list of servers again
	if ( [registeredContexts indexOfObjectIdenticalTo:context] == NSNotFound ) {
		[registeredContexts addObject:context];
		//retrieve all GEZServer from the context to register
		NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
		[request setEntity:[NSEntityDescription entityForName:GEZServerEntityName inManagedObjectContext:context]];
		NSError *error;
		NSEnumerator *e = [[context executeFetchRequest:request error:&error] objectEnumerator];
		//add these to the main context
		GEZServer *newServer;
		while ( newServer = [e nextObject] )
			newServer = [newServer serverInManagedObjectContext:[self managedObjectContext]];
	}
	
}

#pragma mark *** Public class methods ***

+ (NSManagedObjectContext *)managedObjectContext
{
	return [[self sharedManager] managedObjectContext];
}


//when using additional managed object contexts to create and manage GridEZ objects, we should register them so the GEZServer objects are added to the main managedObjectContext
+ (void)registerManagedObjectContext:(NSManagedObjectContext *)context
{
	return [[self sharedManager] registerManagedObjectContext:context];
}

//brings the generic server window to the front and make it key; this window can be used by any application just like the Font panel or one of these application-level panels and windows; it is automatically connected to the managed object context that keeps track of Servers and Grids; the user can connect to different Xgrid Servers, aka Controllers, and can control everything from there
+ (void)showServerWindow
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[GEZServerWindowController showServerWindow];
}

//does exactly what it says
+ (void)hideServerWindow
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[GEZServerWindowController hideServerWindow];
}


+ (void)showXgridPanel
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[GEZXgridPanelController showXgridPanel];
}

+ (void)hideXgridPanel
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[GEZXgridPanelController hideXgridPanel];
}


@end
