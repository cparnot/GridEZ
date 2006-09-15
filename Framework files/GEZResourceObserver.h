//
//  GEZResourceObserver.h
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */



@interface GEZResourceObserver : NSObject
{
	XGResource *xgridResource;
	id delegate;
	NSSet *observedKeys;
}

- (id)initWithResource:(XGResource *)resource;
- (id)initWithResource:(XGResource *)resource observedKeys:(NSSet *)keys;

- (id)delegate;
- (void)setDelegate:(id)anObject;
- (void)setObservedKeys:(NSSet *)keys;

@end


@interface NSObject (GEZResourceObserverDelegate)
- (void)xgridResourceDidUpdate:(XGResource *)resource;
	//the GEZResourceObserver will dynamically generate a call to the appropriate method, where _KEY_ is the key path corresponding to the changed ivar
- (void)xgridResource_KEY_DidChange:(XGResource *)resource;
@end