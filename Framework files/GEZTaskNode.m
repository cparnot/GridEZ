//
//  GEZTaskNode.m
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
