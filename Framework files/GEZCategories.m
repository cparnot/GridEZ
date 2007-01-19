//
//  GEZCategories.m
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



#import "GEZCategories.h"

/*
@implementation NSObject (NSObjectGridEZTimers)

- (void)callSelectorSoon:(SEL)aSelector
{
	NSMethodSignature *signature = [self methodSignatureForSelector:aSelector];
	NSAssert( [signature numberOfArguments] == 2, @"callSelectorSoon can only be used on methods without arguments" );
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setTarget:self];
	[invocation setSelector:aSelector];
	[NSTimer scheduledTimerWithTimeInterval:0 invocation:invocation repeats:NO];
}

@end
*/

//to sort using sortWithSelector
@implementation NSString (NSStringGridEZCompareString)
- (NSComparisonResult)compareNumerically:(NSString *)aString
{
	return [self compare:aString options:NSNumericSearch];
}
@end




//for debugging messages
#ifdef DEBUG

@implementation XGJob (XGJobGridEZDebug)
- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@:%p> { id: %@, name: %@, state: %d, submitted: %@ }", [self class], self, [self identifier], [self name], [self state], [self dateSubmitted]]; 
}
@end


#endif

