/* FSNFunctions.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "FSNFunctions.h"
#include "FSNodeRep.h"
#include "GNUstep.h"

static NSString *fixpath(NSString *s, const char *c)
{
  static NSFileManager *mgr = nil;
  const char *ptr = c;
  unsigned len;

  if (mgr == nil) {
    mgr = [NSFileManager defaultManager];
    RETAIN (mgr);
  }
  
  if (ptr == 0) {
    if (s == nil) {
	    return nil;
	  }
    ptr = [s cString];
  }
  
  len = strlen(ptr);

  return [mgr stringWithFileSystemRepresentation: ptr length: len]; 
}

static NSString *path_sep(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    separator = fixpath(@"/", 0);
    RETAIN (separator);
  }

  return separator;
}

NSString *path_separator(void)
{
  return path_sep();
}

/*
 * p1 is parent of p2
 */
BOOL isSubpathOfPath(NSString *p1, NSString *p2)
{
  int l1 = [p1 length];
  int l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqualToString: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqualToString: p1]) {
    if ([[p2 pathComponents] containsObject: [p1 lastPathComponent]]) {
      return YES;
    }
  }

  return NO;
}

NSString *subtractFirstPartFromPath(NSString *path, NSString *firstpart)
{
	if ([path isEqual: firstpart] == NO) {
    return [path substringFromIndex: [path rangeOfString: firstpart].length +1];
  }
	return path_separator();
}

int compareWithExtType(id *r1, id *r2, void *context)
{
  FSNInfoType t1 = [(id <FSNodeRep>)r1 nodeInfoShowType];
  FSNInfoType t2 = [(id <FSNodeRep>)r2 nodeInfoShowType];

  if (t1 == FSNInfoExtendedType) {
    if (t2 != FSNInfoExtendedType) {
      return NSOrderedDescending;
    }
  } else {
    if (t2 == FSNInfoExtendedType) {
      return NSOrderedAscending;
    }
  }

  return NSOrderedSame;
}

#define ONE_KB 1024
#define ONE_MB (ONE_KB * ONE_KB)
#define ONE_GB (ONE_KB * ONE_MB)

NSString *sizeDescription(unsigned long long size)
{
	NSString *sizeStr;
	char *sign = "";
    
	if(size == 1) {
		sizeStr = @"1 byte";
	} else if(size < 0) {
		sign = "-";
		size = -size;
	}
	if(size == 0) {
		sizeStr = @"0 bytes";
	} else if(size < (10 * ONE_KB)) {
		sizeStr = [NSString stringWithFormat:@"%s %d bytes", sign, size];
	} else if(size < (100 * ONE_KB)) {
 		sizeStr = [NSString stringWithFormat:@"%s %3.2fKB", sign,
                          					((double)size / (double)(ONE_KB))];
	} else if(size < (100 * ONE_MB)) {
		sizeStr = [NSString stringWithFormat:@"%s %3.2fMB", sign,
                          					((double)size / (double)(ONE_MB))];
	} else {
 		sizeStr = [NSString stringWithFormat:@"%s %3.2fGB", sign,
                          					((double)size / (double)(ONE_GB))];
	}

	return sizeStr;
}

NSArray *makePathsSelection(NSArray *selnodes)
{
  NSMutableArray *selpaths = [NSMutableArray array]; 
  int i;

  for (i = 0; i < [selnodes count]; i++) {
    [selpaths addObject: [[selnodes objectAtIndex: i] path]];
  }
  
  return selpaths;
}

double myrintf(double a)
{
	return (floor(a + 0.5));         
}

