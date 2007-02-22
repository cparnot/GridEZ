//
//  GEZProxy.h
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */

/*
 
 Managed class to provide "weak" links between objects from different CoreData models. In particular, this is used to allow delegate and data source of GEZMetaJob instances to be other managed object contexts and be stored in the same context. The way Core Data is built, it seems you can't have relationships between objects unless you know the entity when creating the context.
 
 */

#import <Cocoa/Cocoa.h>

@interface GEZProxy : NSManagedObject
{
	id referencedObject;
}

+ (GEZProxy *)proxyWithReferencedObject:(id)anObject;
- (id)referencedObject;

@end
