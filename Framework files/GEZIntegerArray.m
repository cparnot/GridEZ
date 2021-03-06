//
//  GEZIntegerArray.m
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


#import "GEZIntegerArray.h"

#define SIZE_INCREMENT 100

@implementation GEZIntegerArray

#pragma mark *** Initializations ***

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"<%@:%p> (size: %d)",[self class],self,(long)([integerArrayMutableData length]/sizeof(int))];
}

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	[self setValue:[NSData data] forKey:@"data"];
	integerArrayMutableData = [[NSMutableData alloc] initWithLength:SIZE_INCREMENT*sizeof(int)];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	//NSLog (@"IntegerArray:\n%@",[self stringRepresentation]);
}


- (void)willSave
{
	if (integerArrayMutableData != nil)
		[self setPrimitiveValue:[NSData dataWithData:integerArrayMutableData] forKey:@"data"];
	//NSLog (@"IntegerArray:\n%@",[self stringRepresentation]);
    [super willSave];
} 

- (void)dealloc
{
//	if (integerArrayMutableData != nil)
//		[self setPrimitiveValue:[NSData dataWithData:integerArrayMutableData] forKey:@"data"];
	[integerArrayMutableData release];
	[super dealloc];
}

#pragma mark *** integer array manipulations ***

- (NSMutableData *)integerArrayMutableData
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	if ( integerArrayMutableData == nil ) {
		NSData *data = [self valueForKey:@"data"];
		if ( [data length] != 0)
			integerArrayMutableData = [[NSMutableData alloc] initWithData:data];
		else
			integerArrayMutableData = [[NSMutableData alloc] initWithLength:SIZE_INCREMENT*sizeof(int)];
	}
	return integerArrayMutableData;
}

- (unsigned int)size
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return ( [[self integerArrayMutableData] length] / sizeof(int) );
}

- (void)setSize:(unsigned int)newSize
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	unsigned int oldSize,count;
	
	oldSize=[self size];
	if ( newSize > oldSize ) {
		count= (newSize-oldSize) * sizeof(int) + SIZE_INCREMENT;
		[[self integerArrayMutableData] increaseLengthBy:count];
	}
}

- (int *)arrayOfInt
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	return (int *)[[self integerArrayMutableData] mutableBytes];
}

- (int)intValueAtIndex:(unsigned int)index
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	if ( index >= [self size] )
		return 0;
	else
		return [self arrayOfInt][index];
}

- (void)setIntValue:(int)newInt AtIndex:(unsigned int)index
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	[self willChangeValueForKey:@"data"];
	[self setSize:index+1];
	[self arrayOfInt][index]=newInt;
	[self didChangeValueForKey:@"data"];
}

- (int)incrementIntValueAtIndex:(unsigned int)index
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	int *intArray;
	[self willChangeValueForKey:@"data"];
	[self setSize:index+1];
	intArray=[self arrayOfInt];
	intArray[index]++;
	[self didChangeValueForKey:@"data"];
	return intArray[index];
}

- (int)decrementIntValueAtIndex:(unsigned int)index
{
	DLog(NSStringFromClass([self class]),15,@"[%@:%p %s] - %@",[self class],self,_cmd,[self shortDescription]);
	int *intArray;
	[self willChangeValueForKey:@"data"];
	[self setSize:index+1];
	intArray=[self arrayOfInt];
	intArray[index]--;
	[self didChangeValueForKey:@"data"];
	return intArray[index];
}

- (NSString *)stringRepresentation
{
	int i,n;
	NSMutableString *result;
	int *intArray;

	n=[self size];
	intArray=[self arrayOfInt];
	result=[NSMutableString stringWithCapacity:n*10];
	for (i=0;i<n-1;i++)
		[result appendFormat:@"%d\t",intArray[i]];
	[result appendFormat:@"%d",intArray[n-1]];
	
	return result;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@:@p> (size:%d)",[self class],self,[self size]];
}


@end
