//
//  GRIDEZ_DEBUG_NSManagedObject.m
//  GridEZ
//
//  Created by Charles Parnot on 8/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//


#ifdef DEBUG

#import "GRIDEZ_DEBUG_NSManagedObject.h"

#define LOG_METHOD_CALL printf("%s", [[NSString stringWithFormat:@"[%@ %s] (target: %p)\n---\n",[self class],_cmd,self] UTF8String]);

@implementation GRIDEZ_DEBUG_NSManagedObject

- (void)awakeFromInsert
{
	LOG_METHOD_CALL;
	[super awakeFromInsert];
}

- (void)awakeFromFetch
{
	LOG_METHOD_CALL;
	[super awakeFromFetch];
}

- (BOOL)validateForDelete:(NSError **)error
{
	LOG_METHOD_CALL;
	[super validateForDelete:error];
}

- (void)dealloc
{
	LOG_METHOD_CALL;
	[super dealloc];
}

@end

#endif
