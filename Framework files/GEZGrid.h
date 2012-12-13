//
//  GEZGrid.h
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


//a grid is considered updated after all its attributes (name, jobs,...) have been uploaded from the server, but the jobs may not be updated yet
APPKIT_EXTERN NSString *GEZGridDidUpdateNotification;

//a grid is considered loaded after all its attributes (name, jobs,...) have been uploaded from the server
APPKIT_EXTERN NSString *GEZGridDidLoadNotification;

@class GEZGridHook;
@class GEZServer;
@class GEZJob;

@interface GEZGrid : NSManagedObject
{
	GEZGridHook *gridHook;
}

//Retrieve grid methods only using the following methods
+ (GEZGrid *)gridWithIdentifier:(NSString *)identifier server:(GEZServer *)server;
//TODO(?)
//- (NSArray *)gridsForServer:(GEZServer *)server;
//- (GEZGrid *)defaultGridForServer:(GEZServer *)server;
//- (GEZGrid *)gridWithName:(NSString *)gridName server:(GEZServer *)server;

//TODO(?)
//returns a connected GEZGrid if there is one, otherwise return nil
//+ (GEZGrid *)connectedGrid;


//The GEZJob is added to the same managed object context as the grid
- (GEZJob *)submitJobWithSpecifications:(NSDictionary *)specs;

//KVO/KVC-compliant accessors
- (GEZServer *)server;
- (NSString *)name;
- (NSString *)identifier;
- (NSSet *)jobs; //GEZJob objects, not XGJob objects

//this is really just a guess based on the number of running and pending jobs observed in the past; the returned value is actually the sum of available and working agents (non-offline non-unavailable); usually, the number guessed will be lower than the actual number of available agents; the returned value will be lower than 0 when no guess could be made
- (int)availableAgentsGuess;

//these are NOT (yet) compliant with KVO/KVC
- (BOOL)isAvailable;
- (BOOL)isConnecting;
- (BOOL)isConnected;
- (BOOL)isUpdated;
- (BOOL)isLoaded;
- (NSString *)status;

//low-level accessor
- (XGGrid *)xgridGrid;

//setup the GEZGrid so that all of the jobs submitted to the grid are available as GEZJob, not just the jobs submitted by the application itself, and the jobs actually added are returned; in general, you don't want to use that feature, as you are probably only interested in jobs submitted by the app itself; the current implementation does not keep track of new jobs added to the grid by other applications; in addition, there is no callback to let you know when all the jobs have indeed be loaded, but you could get notifications from each of them; in some instances, jobs might exist in duplicate
- (BOOL)isObservingAllJobs;
- (void)setObservingAllJobs:(BOOL)flag;
- (NSArray *)loadAllJobs;


@end
