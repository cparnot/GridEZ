//
//  GEZServerBrowser.h
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



/**

The GEZServerBrowser is a private class. To use it, one should first retrieve the singleton instance using the class method 'sharedServerBrowser'. The singleton instance can them be used to browse for Xgrid controllers that advertise their services using the Bonjour technology in the local network. Servers found by the browser will then be added to the list of servers by calling the appropriate GEZServer methods. See the GEZServer class for more details: the server instances are saved in the default managed object context as defined by GEZManager.
*/

@class GEZServer;

@interface GEZServerBrowser : NSObject
{
    NSNetServiceBrowser *netServiceBrowser;
	BOOL isBrowsing;
}

//it is best to only use the singleton instance
+ (GEZServerBrowser *)sharedServerBrowser;

//methods used to start and stop browsing for Xgrid servers avertising on Bonjour
//the servers found get automatically added to the application-level persistent store
- (void)startBrowsing;
- (void)stopBrowsing;
- (BOOL)isBrowsing;

@end
