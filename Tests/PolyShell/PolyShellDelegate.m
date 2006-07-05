//
//  PolyShellDelegate.m
//
//  PolyShell
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_POLYSHELL__
This file is part of "PolyShell". "PolyShell" is free software; you can redistribute it and/or modify it under the terms of the Berkeley Software Distribution (BSD) Modified License, a copy of is provided along with "TestServerHook".
__END_LICENSE__ */



#import "PolyShellDelegate.h"

//private method used to generate the job specification in Xgrid format
@interface PolyShellDelegate (PolyShellDelegatePrivate)
- (NSDictionary *)jobSpecificationWithCommands:(NSArray *)commands name:(NSString *)jobName;
@end

@implementation PolyShellDelegate

- (NSManagedObjectContext *)managedObjectContext
{
	return [GEZManager managedObjectContext];
}

- (IBAction)save:(id)sender
{
	NSError *error;
	if ( [[self managedObjectContext] save:&error] == NO )
		NSLog(@"Error while saving: %@", error);
}

- (IBAction)submit:(id)sender
{
	//get the selected grid from the UI
	NSArray *selectedGrids = [gridsController selectedObjects];
	if ( [selectedGrids count] < 1 )
		return;
	GEZGrid *selectedGrid = [selectedGrids objectAtIndex:0];

	//create the job specification by splitting the commands in the text view so that each line corresponds to one command
	NSArray *commands = [[commandView string] componentsSeparatedByString:@"\n"];
	if ( [commands count] < 1 )
		return;
	NSDictionary *jobSpecification = [self jobSpecificationWithCommands:commands name:[commands objectAtIndex:0]];
	
	//submit the job to the selected grid
	GEZJob *newJob = [GEZJob jobWithGrid:selectedGrid];
	[newJob setDelegate:self];
	[newJob submitWithJobSpecification:jobSpecification];
	
	NSLog(@"Commands submitted to grid '%@'", [selectedGrid name]);
	NSLog(@"The job specification is:\n%@", [jobSpecification description]);

}

//delegate method for GEZJob
- (void)jobDidRetrieveResults:(GEZJob *)aJob
{
	NSLog(@"Results retrieved for job '%@'",[aJob name]);
}


//delegate methods for NSApp, called at application launching and termination (duh!)

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[GEZManager showXgridPanel];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[self save:self];
}


@end


@implementation PolyShellDelegate (PolyShellDelegatePrivate)

//tasks specification for one command
//simply use the commandString _as is_ and make that the argument to the /bin/sh executable
- (NSDictionary *)taskSpecificationWithCommand:(NSString *)commandString
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		@"/bin/sh", XGJobSpecificationCommandKey,
		[NSArray arrayWithObjects:@"-c", commandString, nil], XGJobSpecificationArgumentsKey,
		nil];
}

//build the final job specification in Xgrid format
- (NSDictionary *)jobSpecificationWithCommands:(NSArray *)commands name:(NSString *)jobName;
{
	// create array of task specifications
	int i;
	int n = [commands count];
	NSMutableDictionary *tasks = [NSMutableDictionary dictionaryWithCapacity:n];
	for ( i=0; i<n; i++ )
		[tasks setObject:[self taskSpecificationWithCommand:[commands objectAtIndex:i]] forKey:[NSString stringWithFormat:@"%d",i]];
	
	// final job specification
	return [NSDictionary dictionaryWithObjectsAndKeys:
		XGJobSpecificationTypeTaskListValue, XGJobSpecificationTypeKey,
		jobName, XGJobSpecificationNameKey,
		@"Polyshell",XGJobSpecificationSubmissionIdentifierKey,
		tasks, XGJobSpecificationTaskSpecificationsKey,
		nil];
}

@end