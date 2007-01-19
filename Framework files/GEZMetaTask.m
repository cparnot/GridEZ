//
//  GEZMetaTask.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
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
