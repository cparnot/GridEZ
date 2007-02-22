//
//  GEZConnectionPanelController.h
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
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
