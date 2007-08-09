//
//  GRIDEZ_DEBUG_NSManagedObject.h
//  GridEZ
//
//  Created by Charles Parnot on 8/8/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

/* When using the "Debug" build configuration, NSManagedObject is replaced with GRIDEZ_DEBUG_NSManagedObject by the precompiler  using the following build setting:
	
	GCC_PREPROCESSOR_DEFINITIONS:  DEBUG NSManagedObject=GRIDEZ_DEBUG_NSManagedObject

This will cause GRIDEZ_DEBUG_NSManagedObject to be used instead of NSManagedObject for all the project classes that are subclasses of NSManagedObject
*/
	
#ifdef DEBUG
#undef NSManagedObject

@interface GRIDEZ_DEBUG_NSManagedObject : NSManagedObject {

}
@end

#define NSManagedObject GRIDEZ_DEBUG_NSManagedObject
#endif


