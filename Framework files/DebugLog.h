//
//  DebugLog.h
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */


/*
	DLog is equivalent to NSLog
	but is only used and compiled #ifdef DEBUG
 */

//the value of DEBUG is set in the build settings using the -D flag for gcc, in 'Preprocessor Macros', add 'DEBUG'
//DEBUG is defined only for the Development Configuration, not Deployment

#ifdef DEBUG
void DLog(NSString *identifier, int level, NSString *fmt,...);


#else

//I struggle a bit to get Dlog to be completely gone when DEBUG is not defined, this is the best I could come up with: any occurence of DLog is replaced by a ';' thanks to the #define 

#define DLog(...) ;

//the following is what I had hoped would work, but it turns out the arguments are still evaluated
//inline void DLog(NSString *identifier, int level, NSString *fmt,...);

#endif
