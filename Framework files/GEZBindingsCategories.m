//
//  GEZBindingsCategories.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import "GEZBindingsCategories.h"


@implementation GEZServer (GEZServerBindings)

//this key is only meaniningful for GEZServer, and not GEZGrid, so it can be used in an outline view to only show the status of the server (parent) and not of the grids (children)
- (NSString *)serverStatus
{
	return [self status];
}

//this is useful to be able to use the 'server' key on both GEZGrid and GEZServer
- (GEZServer *)server
{
	return self;
}

//this is useful to be able to use the 'identifier' key on both GEZGrid and GEZServer
- (NSString *)identifier
{
	return @"---";
}

//bindings used to enable/disable the connect and disconnect buttons
- (BOOL)isBusy
{
	return ( [self isLoaded] || [self isConnected] || [self isConnecting] );
}

@end



@implementation GEZGrid (GEZGridBindings)

//this will allow GEZGrid entities to be used in an Outline view where GEZServer entities are at the root
- (NSArray *)grids
{
	return [NSArray array];
}

//this key is only meaniningful for GEZServer, and not GEZGrid, so it can be used in an outline view to only show the status of the server (parent) and not of the grids (children)
- (NSString *)serverStatus
{
	return @"";
}

@end



@implementation GEZJob (GEZJobBindings)

/*
- (NSArray *)tasks
{
	int n = [self taskCount];
	if ( n == 0 )
		return [NSArray array];
	int i;
	NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:n];
	for ( i = 0; i < n; i++ )
		[tasks addObject:[NSString stringWithFormat:@"%d",i]];
	return tasks;
	
	//old version using a specialized class GEZTaskNode - Maybe I should do something similar, actually, using an entity
	NSDictionary *allFiles = [self allFiles];
	if ( [allFiles count] == 0 )
		return [NSArray array];
	NSEnumerator *e = [[[allFiles allKeys] sortedArrayUsingSelector:@selector(compareNumerically:)] objectEnumerator];
	NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:[allFiles count]];
	NSString *aName;
	while ( aName = [e nextObject] )
		[tasks addObject:[GEZTaskNode taskWithJob:self name:aName]];
	return tasks;
}
*/

@end
