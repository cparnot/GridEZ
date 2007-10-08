//
//  GRIDEZ_DEBUG_NSManagedObject.h
//  GridEZ
//
//  Created by Charles Parnot on 8/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

/* The subclass GRIDEZ_DEBUG_NSManagedObject is only defined when using the "Debug", using the following build setting:
	
	GCC_PREPROCESSOR_DEFINITIONS:  DEBUG

This will cause some of NSManagedObject to be swizzled with GRIDEZ_DEBUG_NSManagedObject methods, allowing logging of NSManagedObject internals and debugging
*/

#ifdef DEBUG

@interface NSManagedObject (GRIDEZ_DEBUG_NSManagedObject)
@end

#endif


