//
//  DebugLog.m
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



#import "DebugLog.h"

#ifdef DEBUG

static NSArray *identifierArray = nil;

NSArray *identifiers ()
{
	if ( identifierArray == nil )
		identifierArray = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DebugIdentifiers"] retain];
	return identifierArray;
}

//valid identifiers and verbose level may be set using the user defaults
//if the value for one of the user defaults is nil, just ignore that setting
void DLog(NSString *identifier, int level, NSString *fmt,...)
{
	//check the verbose level
	id currentVerboseLevel = [[NSUserDefaults standardUserDefaults] valueForKey:@"DebugLogVerboseLevel"];
	if ( ( currentVerboseLevel != nil ) && ( level > [currentVerboseLevel intValue] ) )
		return;
	// printf("current verbose level = %s = %d < %d = %s\n", [[currentVerboseLevel description] UTF8String], [currentVerboseLevel intValue], level, ( level > [currentVerboseLevel intValue] )?"yes":"no");
	
	//check the identifer
	NSArray *ids = identifiers();
	if ( (identifier !=nil) && ( ids!=nil ) && ([ids indexOfObject:identifier] == NSNotFound) )
		return;
	
	//now, we can log!
    va_list ap;
    va_start(ap,fmt);
    NSLogv(fmt,ap);
}

#else

//inline void DLog(NSString *identifier, int level, NSString *fmt,...) {}

#endif
