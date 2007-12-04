//
//  GEZServerBrowser.h
//
//  GridEZ
//
//  Copyright 2006, 2007 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
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
