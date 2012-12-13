//
//  GEZMetaTask.m
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

#import "GEZMetaTask.h"


@implementation GEZMetaTask

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	[self setValue:[NSData data] forKey:@"specifications"];
	specifications = [[NSDictionary alloc] init];
}

- (void)dealloc
{
	[specifications release];
	[super dealloc];
}

- (void)willSave
{
	NSString *error;
	NSData *specificationData = [NSPropertyListSerialization dataFromPropertyList:specifications format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];
	if ( error != nil ) {
		specificationData = nil;
		[error autorelease];
	}
	if (specificationData != nil)
		[self setPrimitiveValue:specificationData forKey:@"specifications"];
    [super willSave];
} 

- (NSDictionary *)specifications
{
	if ( specifications == nil ) {
		NSData *specificationData = [self valueForKey:@"specifications"];
		if ( [specificationData length] != 0) {
			NSString *error;
			specifications = [[NSPropertyListSerialization propertyListFromData:specificationData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&error] retain];
			if ( error != nil ) {
				[error autorelease];
				[specifications autorelease];
				specifications = [[NSDictionary alloc] init];
			}
		}
		else
			specifications = [[NSDictionary alloc] init];
	}
	return specifications;
}

- (void)setSpecifications:(NSDictionary *)newSpecifications
{
	if ( newSpecifications != specifications ) {
		[self willChangeValueForKey:@"specifications"];
		[specifications release];
		specifications = [newSpecifications retain];
		[self didChangeValueForKey:@"specifications"];
	}
}
@end
