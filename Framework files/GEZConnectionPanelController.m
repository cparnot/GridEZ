//
//  GEZConnectionPanelController.m
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



#import "GEZConnectionPanelController.h"
#import "GEZServer.h"

@interface GEZConnectionPanelController (GEZConnectionPanelControllerResize)
- (void)hideAuthentication;
- (void)showAuthentication;
@end


@implementation GEZConnectionPanelController

- (id)initWithServer:(GEZServer *)aServer
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	
	self = [super initWithWindowNibName:@"ConnectionPanel"];
	if ( self != nil ) {
		//we want to use the server from the main managed object context, as it will always be around
		server = [[GEZServer serverWithAddress:[aServer address]] retain];
		[self setWindowFrameAutosaveName:[NSString stringWithFormat:@"GEZConnectionPanel for %@",[server address]]];
		connecting = NO;
	}
	return self;
}

//this ensures uniqueness of panel controller: one server address per panel
static NSMutableDictionary *connectionPanelControllers;
+ (GEZConnectionPanelController *)connectionPanelControllerWithServer:(GEZServer *)server
{
	if ( connectionPanelControllers == nil )
		connectionPanelControllers = [[NSMutableDictionary alloc] initWithCapacity:1];
	NSString *address = [server address];
	GEZConnectionPanelController *result = [connectionPanelControllers objectForKey:address];
	if ( result == nil ) {
		result = [[self alloc] initWithServer:server];
		[connectionPanelControllers setObject:result forKey:address];
	}
	return result;
}

- (void)dealloc
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[server release];
	[super dealloc];
}

- (void)awakeFromNib
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[self hideAuthentication];
	[[self window] setTitle:[server address]];
	[passwordField setStringValue:@""];
	//[shouldRememberPasswordCheckBox setState:[server shouldStorePasswordInKeychain]];
}

#pragma mark *** start and stop ***

- (void)startConnectionProcess
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	connecting = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverDidConnectNotification:) name:GEZServerDidConnectNotification object:server];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverDidNotConnectNotification:) name:GEZServerDidNotConnectNotification object:server];
	//show the window if connection takes more than 2 seconds
	[NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(showWindow:) userInfo:nil repeats:NO];
	if ( [server hasPasswordInKeychain] ) {
		[statusField setStringValue:@"Connecting using the keychain password..."];
		[server connectWithKeychainPassword];
	}
	else {
		[statusField setStringValue:@"Connecting without authentication..."];
		[server connectWithoutAuthentication];
	}
}


//this is the only public method to start a session with a GEZConnectionPanelController
//it is not necessarily going to result in any panel being displayed (only after 2 seconds or if authentication is needed)
+ (void)runConnectionPanelWithServer:(GEZServer *)aServer
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);

	if ( [aServer isConnected] )
		return;
	[[self connectionPanelControllerWithServer:aServer] startConnectionProcess];
}

//override super's implementation to not show if server is already connected
- (void)showWindow:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	if ( !connecting || [server isConnected] )
		return;
	[super showWindow:sender];
	[connectionProgress startAnimation:nil];
}

//override super's implementation to do some clean up
- (void)close
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	connecting = NO;
	[connectionProgress stopAnimation:nil];
	[self hideAuthentication];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super close];
}

#pragma mark *** GEZServer notifications ***

- (void)serverDidConnectNotification:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[self close];
}

- (void)serverDidNotConnectNotification:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	if ( [[statusField stringValue] isEqualToString:@"Connecting without authentication..."] )
		[statusField setStringValue:@"Authentication needed"];
	else
		[statusField setStringValue:@"Authentication failed"];
	[self showWindow:nil];
	[self showAuthentication];
	[connectionProgress stopAnimation:nil];
}

- (GEZServer *)server
{
	return server;
}

#pragma mark *** Actions ***

- (IBAction)cancel:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	[self close];
}

- (IBAction)connect:(id)sender
{
	DLog(NSStringFromClass([self class]),10,@"[%@:%p %s]",[self class],self,_cmd);
	if ( [[authenticationTypeMatrix selectedCell] tag] == 0 ) {
		[server connectWithSingleSignOnCredentials];
		[statusField setStringValue:@"Authenticating with Single Sign On credentials..."];
	}
	else {
		[server connectWithPassword:[passwordField stringValue]];
		[statusField setStringValue:@"Authenticating with provided password..."];
	}
	[self hideAuthentication];
	[connectionProgress startAnimation:nil];
}

- (IBAction)rememberPassword:(id)sender
{
	if ( [sender state] == NSOnState )
		[server setShouldStorePasswordInKeychain:YES];
	else
		[server setShouldStorePasswordInKeychain:NO];
}

#pragma mark *** NSTextField delegate ***

//self is set to be a delegate of the password text field
//this method is then triggered by the user when typing a password
//the radio button for 'connection with password' is then automatically selected
- (void)controlTextDidBeginEditing:(NSNotification *)aNotification
{
	DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	[[authenticationTypeMatrix cellWithTag:1] performClick:self];
}
/*
 - (void)controlTextDidChange:(NSNotification *)aNotification
 {
	 DLog(NSStringFromClass([self class]),10,@"<%@:%p> %s",[self class],self,_cmd);
	 [[authenticationTypeMatrix cellWithTag:1] performClick:self];
 }
 */

@end


@implementation GEZConnectionPanelController (GEZConnectionPanelControllerResize)


#pragma mark *** Resizing the window to show/hide authentication ***

//these values are the two possible heights for the connection window
#define HEIGHT_WITHOUT_AUTHENTICATION 61
#define HEIGHT_WITH_AUTHENTICATION 176

- (void)resizeWithHeight:(float)target
{
	NSWindow *connectionPanel = [self window];
	NSRect frame1 = [connectionPanel frame];
	NSRect frame2 = [[connectionPanel contentView] frame];
	float delta = frame2.size.height - target;
	NSRect newFrame = NSMakeRect(frame1.origin.x,frame1.origin.y + delta, frame1.size.width, frame1.size.height - delta);
	BOOL isVisible = [connectionPanel isVisible];
	[connectionPanel setFrame:newFrame display:isVisible animate:isVisible];
}

- (void)hideAuthentication
{
	[passwordField setStringValue:@""];
	[self resizeWithHeight:HEIGHT_WITHOUT_AUTHENTICATION];
}

- (void)showAuthentication
{
	[passwordField setStringValue:@""];
	[self resizeWithHeight:HEIGHT_WITH_AUTHENTICATION];
}

- (void)toggle:(NSTimer *)timer
{
	if ( [[[self window] contentView] frame].size.height == HEIGHT_WITH_AUTHENTICATION )
		[self hideAuthentication];
	else
		[self showAuthentication];
}



@end