//
//  main-test-server-connection.m
//
//  TestServerHook
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_TESTSERVERHOOK__
This file is part of "TestServerHook". "TestServerHook" is free software; you can redistribute it and/or modify it under the terms of the Berkeley Software Distribution (BSD) Modified License, a copy of is provided along with "TestServerHook".
__END_LICENSE__ */



#import "TestServerHook.h"

int main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
    TestServerHook *test = [[TestServerHook alloc] init];

	[test connect];
	[[NSRunLoop currentRunLoop] run];

	[pool release];
	
	return 0;
}
