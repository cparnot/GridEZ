//
//  GEZOutlineView.m
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



#import "GEZOutlineView.h"

/*
 This subclass of NSOutlineView is used to catch moveLeft: and moveRight: events. We need to catch these to navigate between the various NSTableView and NSOutlineView in the XGrid panel. NSTableView don't catch key events, but NSOutlineView catches arrow keys to allow expanding parent items. We will let NSOutlineView do what is normally does except when what it normally does is actually nothing:
	* when the current item is not expandable (a leaf) or is already "unexpanded" and the left arrow is clicked, the subclass notifies the delegate of leftArrow:
	* when the current item is not expandable (a leaf) or is already expanded and the right arrow is clicked, the subclass notifies the delegate of rightArrow:
 */


@implementation GEZOutlineView

//to catch moveLeft and moveRight, it seems we have to override keyDown, as moveLeft: and moveRight: don't get called and are bypassed
- (void)keyDown:(NSEvent *)theEvent
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	//we will be looking for left and right arrows
	NSString *chars = [theEvent characters];
	NSCharacterSet *leftArrowSet = [NSCharacterSet characterSetWithRange:NSMakeRange((unsigned int)NSLeftArrowFunctionKey,1)];
	NSCharacterSet *rightArrowSet = [NSCharacterSet characterSetWithRange:NSMakeRange((unsigned int)NSRightArrowFunctionKey,1)];
	NSRange rangeLeft = [chars rangeOfCharacterFromSet:leftArrowSet options:NSBackwardsSearch];
	NSRange rangeRight = [chars rangeOfCharacterFromSet:rightArrowSet options:NSBackwardsSearch];

	//we may have to handle one of the arrows pressed
	if ( ( rangeLeft.location != NSNotFound ) || (rangeRight.location != NSNotFound ) ) {
		
		id theDelegate = [self delegate];
		id item = [self itemAtRow:[self selectedRow]];
		BOOL isLeaf = ( [self isExpandable:item] == NO );
		
		//left and right are both given a chance
		BOOL couldCatchLeftArrow = NO;
		if ( ( rangeLeft.location != NSNotFound ) && ( isLeaf || ( [self isItemExpanded:item] == NO ) ) && [theDelegate respondsToSelector:@selector(moveLeft:)] )
			couldCatchLeftArrow = YES;
		BOOL couldCatchRightArrow = NO;
		if ( ( rangeRight.location != NSNotFound ) && ( isLeaf || ( [self isItemExpanded:item] == YES ) ) && [theDelegate respondsToSelector:@selector(moveRight:)] )
			couldCatchRightArrow = YES;
		
		//now, who wins?
		if ( couldCatchLeftArrow && ( ( rangeRight.location == NSNotFound ) || ( rangeLeft.location > rangeRight.location ) ) )
			[theDelegate moveLeft:self];
		else if ( couldCatchRightArrow )
			[theDelegate moveRight:self];
			
	}
	
	//in any case, the superclass should handle the event too (we know that we have only handled characters that the superclass is not going to do anything with anyway)
	[super keyDown:theEvent];
}

/*
- (void)moveLeft:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[super moveLeft:sender];
	[[self delegate] moveLeft:sender];
}

- (void)moveRight:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[super moveRight:sender];
	[[self delegate] moveRight:sender];
}
*/

@end

/*
@implementation NSOutlineView (GEZOutlineView)

- (void)moveLeft:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[super moveLeft:sender];
	[[self delegate] moveLeft:sender];
}

- (void)moveRight:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[super moveRight:sender];
	[[self delegate] moveRight:sender];
}

@end
*/