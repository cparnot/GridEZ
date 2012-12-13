//
//  GEZProxy.m
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

	if ( referencedObject == nil || [referencedObject isKindOfClass:[NSManagedObject class]] == NO || [referencedObject managedObjectContext] != [self managedObjectContext] )
		[self setPrimitiveValue:nil forKey:@"objectURI"];
	else {
		NSManagedObjectID *objectID = [referencedObject objectID];
		if ( [objectID isTemporaryID] ) {
			DLog(NSStringFromClass([self class]),10,@"Object ID '%@' for GEZProxy object is temporary. The following object will not be properly referenced in the saved persistent store: <%@:%p>", [objectID URIRepresentation], [referencedObject class], referencedObject);
			[self setPrimitiveValue:nil forKey:@"objectURI"];
			//after the context is fully saved, the referenced object should have a final ID; we should then modify that value, otherwise the context will think the GEZProxy object is fine, and will never attempt to save it again because it has not been modified, and the objectID will never stick!
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextDidSave:) name:NSManagedObjectContextDidSaveNotification object:[self managedObjectContext]];
		} else {
			DLog(NSStringFromClass([self class]),10,@"Object ID '%@' for GEZProxy object is not temporary. The following object will be properly referenced in the saved persistent store: <%@:%p>", [objectID URIRepresentation], [referencedObject class], referencedObject);
			[self setPrimitiveValue:[[objectID URIRepresentation] absoluteString] forKey:@"objectURI"];
		}
	}
    [super willSave];
} 

//after the context is fully saved, the referenced object should have a final ID, and we can finally record it; we
- (void)contextDidSave:(NSNotification *)notification
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	//make sure it actually makes sense to set the objectID of the referencedObject
	if ( [referencedObject isKindOfClass:[NSManagedObject class]] == NO )
		return;
	NSManagedObjectID *objectID = [referencedObject objectID];
	if ( [objectID isTemporaryID] )
		return;
	
	//this is where we finally set the right objectID (calling the non-primitive setter ensures proper notifications that the object needs to be saved the next time the context is saved)
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] --> setting the referencedObject ID",[self class],self,_cmd);
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
