//
//  GEZTransformers.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */




#import "GEZTransformers.h"


@implementation GEZStringToImageTransformer

+ (Class)transformedValueClass;
{
    return [NSImage class];
}

+ (BOOL)allowsReverseTransformation;
{
    return NO;   
}

- (id)transformedValue:(id)value;
{
	NSBundle *myBundle;
	NSImage *result;
	NSString *path;
	if ( [value isKindOfClass:[NSString class]] && [value isEqualToString:@""] )
		return nil;
	result = [NSImage imageNamed:value];
	if (result == nil) {
		myBundle = [NSBundle bundleForClass:[GEZStringToImageTransformer class]];
		path = [myBundle pathForImageResource:value];
		result = [[NSImage alloc] initWithContentsOfFile:path];
		[result setName:value];
	}
	return result;
}

@end


@implementation GEZDataToStringTransformer

+ (Class)transformedValueClass;
{
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation;
{
    return NO;   
}

- (id)transformedValue:(id)value;
{
	if ( value == nil )
		return nil;
	return [[[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding] autorelease];
}

@end
