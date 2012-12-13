//
//  GEZResourceObserver.m
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


#import "GEZResourceObserver.h"


@implementation GEZResourceObserver


- (id)initWithResource:(XGResource *)resource observedKeys:(NSSet *)keys
{
	self = [super init];
	if ( self != nil ) {
		xgridResource = [resource retain];
		delegate = nil;
		if ( [keys member:@"updated"] == NO )
			[xgridResource addObserver:self forKeyPath:@"updated" options:0 context:nil];
		[self setObservedKeys:keys];
	}
	return self;
}

- (id)initWithResource:(XGResource *)resource
{
	return [self initWithResource:resource observedKeys:[NSSet set]];
}

- (void)dealloc
{
	delegate = nil;
	[self setObservedKeys:nil];
	[xgridResource removeObserver:self forKeyPath:@"updated"];
	[xgridResource release];
	[super dealloc];
}

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"Resource observer for %@", xgridResource];
}


- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)anObject
{
	//by convention, no retain for delegates
	delegate = anObject;
}

- (void)setObservedKeys:(NSSet *)keys
{
	if ( keys == observedKeys )
		return;
	
	//clean-up old keys
	NSEnumerator *e = [observedKeys objectEnumerator];
	NSString *aKey;
	while ( aKey = [e nextObject] )
		[xgridResource removeObserver:self forKeyPath:aKey];
	[observedKeys release];
	
	//observe new keys
	observedKeys = [keys copy];
	e = [observedKeys objectEnumerator];
	while ( aKey = [e nextObject] )
		[xgridResource addObserver:self forKeyPath:aKey options:0 context:nil];
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - %@\nObject = <%@:%p>\nKey Path = %@\nChange = %@",[self class],self,_cmd, [self shortDescription], [object class], object, keyPath, [change description]);
	
	//if a change occurs when the resource is not updated yet, we ignore it; this is not a real change
	if ( [xgridResource isUpdated] == NO )
		return;
	
	//otherwise, we need to notify the delegate of the change in the next iteration of the run loop, using the appropriate selector:
	// - @selector(xgridResourceDidUpdate:) if the changed key is "updated"
	// - @selector(xgridResource_KEY_DidChange:) if the changed key is "_KEY_"
	SEL delegateSelector;
	
	//if the key is "updated", we need to notify the delegate using the method defined in the delegate informal protocol
	if ( [keyPath isEqualToString:@"updated"] )
		delegateSelector = @selector(xgridResourceDidUpdate:);
	else {
		NSString *capitalizedKey = [NSString stringWithFormat:@"%@%@",[[keyPath substringToIndex:1] uppercaseString], [keyPath substringFromIndex:1]];
		delegateSelector = NSSelectorFromString([NSString stringWithFormat:@"xgridResource%@DidChange:",capitalizedKey]);
	}
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s] - Sending message %s to %@",[self class],self,_cmd, delegateSelector, delegate);
	
	//builds an invocation if the delegate responds to the selector
	if ( delegate == nil || [delegate respondsToSelector:delegateSelector] == NO )
		return;
	NSMethodSignature *delegateSelectorSignature = [delegate methodSignatureForSelector:delegateSelector];
	if ( delegateSelectorSignature == nil )
		return;
	if ( [delegateSelectorSignature numberOfArguments] != 3 )
		return;
	NSInvocation *delegateInvocation = [NSInvocation invocationWithMethodSignature:delegateSelectorSignature];
	[delegateInvocation setSelector:delegateSelector];
	[delegateInvocation setTarget:delegate];
	[delegateInvocation setArgument:&xgridResource atIndex:2];
	
	//fire a timer that will call the delegate on the next iteration of the run loop
	[NSTimer scheduledTimerWithTimeInterval:0 invocation:delegateInvocation repeats:NO];
}


@end
