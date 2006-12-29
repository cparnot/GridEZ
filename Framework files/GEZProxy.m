//
//  GEZProxy.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */


#import "GEZProxy.h"
#import "GEZManager.h"
#import "GEZDefines.h"


@implementation GEZProxy

- (void)dealloc
{
	[referencedObject release];
	[super dealloc];
}


//the setter does not care about the "objectURI", as the latter will be set in the "willSave" method when necessary (see below)
- (void)setReferencedObject:(id)anObject
{
	if ( anObject != referencedObject ) {
		[referencedObject release];
		referencedObject = [anObject retain];
	}
}



//on-demand accessor (lazy instantiation)
- (id)referencedObject
{
	if ( referencedObject == nil ) {
		NSManagedObjectContext *context = [self managedObjectContext];
		NSString *uri = [self primitiveValueForKey:@"objectURI"];
		if ( uri != nil ) {
			NSManagedObjectID *objectID = [[context persistentStoreCoordinator] managedObjectIDForURIRepresentation:[NSURL URLWithString:uri]];
			if ( objectID != nil ) {
				[self setReferencedObject:[context objectWithID:objectID]];
			}
			else
				DLog(NSStringFromClass([self class]),10,@"Problem while retrieving referencedObject with ID %@ from GEZProxy %@", objectID, self);
		}
		DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] --> %@",[self class],self,_cmd,referencedObject);
	}
	return referencedObject;
}

//this is when the referenced object is stored as a property, only when needed (delayed-update setter)
//hopefully, the referencedObject is already saved and has a permanent ID (how to enforce that??)
- (void)willSave
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	if ( referencedObject == nil || [referencedObject isKindOfClass:[NSManagedObject class]] == NO )
		[self setPrimitiveValue:nil forKey:@"objectURI"];
	else {
		NSManagedObjectID *objectID = [referencedObject objectID];
		if ( [objectID isTemporaryID] ) {
			//NSLog(@"Object ID '%@' for GEZProxy object is temporary. The following object will not be properly referenced in the saved persistent store:\n%@", [objectID URIRepresentation], referencedObject);
			[self setPrimitiveValue:nil forKey:@"objectURI"];
			//after the context is fully saved, the referenced object should have a final ID; we should then modify that value, otherwise the context will think the GEZProxy object is fine, and will never attempt to save it again because it has not been modified, and the objectID will never stick!
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextDidSave:) name:NSManagedObjectContextDidSaveNotification object:[self managedObjectContext]];
		} else
			[self setPrimitiveValue:[[objectID URIRepresentation] absoluteString] forKey:@"objectURI"];
	}
    [super willSave];
} 

//after the context is fully saved, the referenced object should have a final ID, and we can finally record it; we
- (void)contextDidSave:(NSNotification *)notification
{
	//make sure it actually makes sense to set the objectID of the referencedObject
	if ( [referencedObject isKindOfClass:[NSManagedObject class]] == NO )
		return;
	NSManagedObjectID *objectID = [referencedObject objectID];
	if ( [objectID isTemporaryID] )
		return;
	
	//this is where we finally set the right objectID (calling the non-primitive setter ensures proper notifications that the object needs to be saved the next time the context is saved)
	[self setValue:[[objectID URIRepresentation] absoluteString] forKey:@"objectURI"];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:[self managedObjectContext]];
	//NSLog(@"Object ID '%@' for GEZProxy object is now final. The following object should be properly referenced in the saved persistent store:\n%@", [objectID URIRepresentation], referencedObject);
}


+ (GEZProxy *)proxyWithReferencedObject:(id)anObject
{
	GEZProxy *returnedProxy;
	NSManagedObjectContext *context;
	
	//decide on the context in which the proxy will be stored
	if ( [anObject isKindOfClass:[NSManagedObject class]] )
		context = [anObject managedObjectContext];
	else
		context = [GEZManager managedObjectContext];
	
	//set up the proxy object
	returnedProxy = [NSEntityDescription insertNewObjectForEntityForName:GEZProxyEntityName inManagedObjectContext:context];
	[returnedProxy setReferencedObject:anObject];	
	return returnedProxy;
}

@end
