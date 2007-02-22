//
//  GEZTask.m
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import "GEZTask.h"
#import "GEZDefines.h"

@implementation GEZTask

+ (void)initialize
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	
	//'files' is a a key for a "virtual" value; its value is calculated on request, and notifications of its change are dependent on the changes in the "real" value for the key 'allFiles'
	[self setKeys:[NSArray arrayWithObject:@"allFiles"] triggerChangeNotificationsForDependentKey:@"files"];
	
}

- (NSString *)name
{
	[self willAccessValueForKey:@"name"];
	NSString *name = [self primitiveValueForKey:@"name"];
	[self didAccessValueForKey:@"name"];
	return name;
}

- (NSSet *)filePaths
{
	return [self valueForKey:@"files.path"];
}

- (NSData *)fileContentsForPath:(NSString *)filePath
{
	/*TODO*/
	return [NSData data];
}


//only returns file entities at the root of the file hierarchy by looking for files with no parent
//private methods used only for bindings
- (NSSet *)files
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);

	NSEnumerator *e = [[self valueForKey:@"allFiles"] objectEnumerator];
	NSManagedObject *oneFile;
	NSMutableSet *files = [NSMutableSet set];
	while ( oneFile = [e nextObject] ) {
		if ( [oneFile valueForKey:@"parent"] == nil )
			[files addObject:oneFile];
	}
	return files;
}


@end
