//
//  GEZMetaTask.h
//
//  GridEZ
//
//  Copyright 2006 Charles Parnot. All rights reserved.
//

/* __BEGIN_LICENSE_GRIDEZ__
This file is part of "GridEZ.framework". "GridEZ.framework" is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. "GridEZ.framework" is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details. You should have received a copy of the GNU Lesser General Public License along with GridEZ.framework; if not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
__END_LICENSE__ */

/*
 GEZMetaTask is a private class used to keep information about "metatasks", which are the tasks that form a metajob. A metatask is not the same as an xgrid task, because it can be submitted to several xgrid jobs. A metatask keeps track of the number of submissions, the number of failures and the number of successes. The GEZMetaTask instances are only manipulated by GEZMetaJob objects.
 */

@interface GEZMetaTask : NSManagedObject
{
	//ivar used to mirror the attribute "specifications" stored by CoreData as binary data
	NSDictionary *specifications;
}

- (NSDictionary *)specifications;
- (void)setSpecifications:(NSDictionary *)newSpecifications;

@end
