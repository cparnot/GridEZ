//
//  GEZCategories.m
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

