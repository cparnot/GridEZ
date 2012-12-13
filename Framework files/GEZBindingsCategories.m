//
//  GEZBindingsCategories.m
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
- (NSSet *)grids
{
	return [NSSet set];
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
