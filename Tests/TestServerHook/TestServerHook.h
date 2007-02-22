//
//  TestServerHook.h
//
//  TestServerHook
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_TESTSERVERHOOK__
This file is part of "TestServerHook". "TestServerHook" is free software; you can redistribute it and/or modify it under the terms of the Berkeley Software Distribution (BSD) Modified License, a copy of is provided along with "TestServerHook".
__END_LICENSE__ */



@class GEZServerHook;

@interface TestServerHook : NSObject
{
	GEZServerHook *serverHook;
}

- (void)connect;

@end
