//
//  PolyShellDelegate.h
//
//  PolyShell
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_POLYSHELL__
This file is part of "PolyShell". "PolyShell" is free software; you can redistribute it and/or modify it under the terms of the Berkeley Software Distribution (BSD) Modified License, a copy of is provided along with "TestServerHook".
__END_LICENSE__ */



#import <Cocoa/Cocoa.h>


@interface PolyShellDelegate : NSObject
{
	IBOutlet NSArrayController *gridsController;
	IBOutlet NSTextView *commandView;
}

- (IBAction)save:(id)sender;
- (IBAction)submit:(id)sender;

@end
