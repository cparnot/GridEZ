//
//  XgridControllersAppDelegate.m
//
//  Xgrid Controllers App
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_XGRIDCONTROLLERSAPP__
This file is part of "Xgrid Controllers App". "Xgrid Controllers App" is free software; you can redistribute it and/or modify it under the terms of the Berkeley Software Distribution (BSD) Modified License, a copy of is provided along with "Xgrid Controllers App".
__END_LICENSE__ */



#import "XgridControllersAppDelegate.h"


@implementation XgridControllersAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[GEZManager showServerWindow];
	//[GEZManager showXgridPanel];
}

- (NSManagedObjectContext *)managedObjectContext
{
	return [GEZManager managedObjectContext];
}

@end
