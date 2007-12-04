//
//  GRIDEZ_DEBUG_NSManagedObject.m
//  GridEZ
//
//  Created by Charles Parnot on 8/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//


#ifdef DEBUG

#import "GRIDEZ_DEBUG_NSManagedObject.h"
#import "MethodSwizzle.h"

#define LOG_METHOD_CALL printf("%s", [[NSString stringWithFormat:@"[%@ %s] (target: %@-%p)\n---\n",[self class], _cmd, [[self entity] name], self] UTF8String]);

@implementation NSManagedObject (GRIDEZ_DEBUG_NSManagedObject)

NSMutableDictionary *entityCounts = nil;
- (id)GRIDEZ_DEBUG_initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context
{
	if ( entityCounts == nil )
		entityCounts = [[NSMutableDictionary alloc] init];
	NSString *name = [entity name];
	NSNumber *count = [entityCounts objectForKey:name];
	int i;
	if ( count == nil )
		i = 0;
	else
		i = [count intValue];
	[entityCounts setObject:[NSNumber numberWithInt:i+1] forKey:name];
	printf("%s : %d\n", [name UTF8String], i);
	
	return [self GRIDEZ_DEBUG_initWithEntity:entity insertIntoManagedObjectContext:context];
}

- (void)GRIDEZ_DEBUG_dealloc
{
	//LOG_METHOD_CALL;
	
	if ( entityCounts == nil )
		entityCounts = [[NSMutableDictionary alloc] init];
	NSEntityDescription *entity = [self entity];
	NSString *name = [entity name];
	NSNumber *count = [entityCounts objectForKey:name];
	int i;
	if ( count == nil )
		i = 0;
	else
		i = [count intValue];
	[entityCounts setObject:[NSNumber numberWithInt:i-1] forKey:name];
	printf("%s : %d\n", [name UTF8String], i);
	
	//calling the original implementation
	[self GRIDEZ_DEBUG_dealloc];
}


- (void)GRIDEZ_DEBUG_awakeFromInsert
{
	LOG_METHOD_CALL;
	//calling the original implementation
	[self GRIDEZ_DEBUG_awakeFromInsert];
}

- (void)GRIDEZ_DEBUG_awakeFromFetch
{
	//LOG_METHOD_CALL;
	//calling the original implementation
	[self GRIDEZ_DEBUG_awakeFromFetch];
}

- (BOOL)GRIDEZ_DEBUG_validateForDelete:(NSError **)error
{
	//LOG_METHOD_CALL;
	//calling the original implementation
	BOOL valid = [self GRIDEZ_DEBUG_validateForDelete:error];
	if ( !valid ) {
		NSArray *detailedErrors = [[*error userInfo] objectForKey:NSDetailedErrorsKey];
		unsigned numErrors = [detailedErrors count];
		NSMutableString *errorString = [NSMutableString stringWithFormat:@"%u validation errors have occurred:\n", numErrors];
		unsigned i;
		for (i = 0; i < numErrors; i++) {
			[errorString appendFormat:@"%@\n",
			 [[detailedErrors objectAtIndex:i] localizedDescription]];
		}
		NSLog(@"error in [%@:%p %s] : %@\nNSManagedObject description:%@", [self class], self, _cmd, *error, [self description]);
		NSLog(@"%@", errorString);
	}
	return valid;
}

- (BOOL)GRIDEZ_DEBUG_validateValue:(id *)value forKey:(NSString *)key error:(NSError **)error
{
	//LOG_METHOD_CALL;
	//calling the original implementation
	BOOL valid = [self GRIDEZ_DEBUG_validateValue:value forKey:key error:error];
	if ( !valid )
		NSLog(@"error in [%@:%p %s] : %@", [self class], self, _cmd, *error);
	return valid;
}



@end

#endif
