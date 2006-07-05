//
//  GEZTaskNode.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



/* NOT USED ANYMORE FOR NOW */


#import "GEZTaskNode.h"
#import "GEZJob.h"

@implementation GEZTaskNode

- (id)initWithJob:(GEZJob *)aJob name:(NSString *)aString
{
	self = [super init];
	if ( self != nil ) {
		job = [aJob retain];
		name = [aString retain];
	}
	return self;
}

+ (GEZTaskNode *)taskWithJob:(GEZJob *)aJob name:(NSString *)aString
{
	return [[[self alloc] initWithJob:aJob name:aString] autorelease];
}

- (void)dealloc
{
	[job release];
	[name release];
	[super dealloc];
}

- (NSArray *)children
{
	NSDictionary *taskDictionary = [[job allFiles] objectForKey:name];
	//not a task, but a file
	if ( taskDictionary == nil )
		return [NSArray array];
	//otherwise, get a list of the files and make them GEZTaskNode object too
	NSArray *files = [[taskDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator *e = [files objectEnumerator];
	NSMutableArray *children = [NSMutableArray arrayWithCapacity:[files count]];
	NSString *aName;
	while ( aName = [e nextObject] )
		[children addObject:[GEZTaskNode taskWithJob:job name:aName]];
	return children;
}

- (id)copyWithZone:(NSZone *)zone
{
	return [self retain];
}

- (NSString *)name
{
	return name;
}

- (GEZJob *)job
{
	return job;
}


@end
