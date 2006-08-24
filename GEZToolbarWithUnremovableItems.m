//
//  GEZToolbarWithUnremovableItems.m
//  GridEZ
//
//  Created by Charles Parnot on 8/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

/* use to bypass the "Remove item" action in the toolbar contextual menu. I can't remove this menu item like I removed the "customize" menu item, as it only appears when ctrl-click on a toolbar button, but not on the toolbar itself. Thus not sure how to remove it. Thus just bypassing the action */

#import "GEZToolbarWithUnremovableItems.h"


@implementation GEZToolbarWithUnremovableItems

- (void)_userRemoveItemAtIndex:(id)sender
{
	DLog(NSStringFromClass([self class]),12,@"<%@:%p> %s",[self class],self,_cmd);
}

@end
