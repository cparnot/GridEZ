//
//  GEZOutlineView.m
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
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