//
//  GEZConnectionPanelController.h
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

/*
 This class takes care of displaying a "connection panel" for a particular server, in a way that mimicks what "Connect to Server..." does in the Finder. You only need to call "runConnectionPanelWithServer:" to get it started and have the connection process started. This class takes care of interacting with the user to ask for authentication as needed.
*/

#import <Cocoa/Cocoa.h>

@class GEZServer;

@interface GEZConnectionPanelController : NSWindowController
{
	IBOutlet NSTextField *statusField;
	IBOutlet NSProgressIndicator *connectionProgress;
	IBOutlet NSMatrix *authenticationTypeMatrix;
	IBOutlet NSSecureTextField *passwordField;
	GEZServer *server;
	BOOL connecting;
}

//this is the only public method to start a session with a GEZConnectionPanelController
//it is not necessarily going to result in any panel being displayed (only after 2 seconds or if authentication is needed)
+ (void)runConnectionPanelWithServer:(GEZServer *)aServer;

- (GEZServer *)server;

//actions for the UI
- (IBAction)cancel:(id)sender;
- (IBAction)connect:(id)sender;


@end
