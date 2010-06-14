/* Functions.m
 *  
 * Copyright (C) 2004-2010 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep GWorkspace application
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <limits.h>

#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>
#import "Functions.h"



static NSString *fix_path(NSString *s, const char *c)
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

BOOL isSubpath(NSString *p1, NSString *p2)
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

NSString *relativePathFittingInField(id field, NSString *fullPath)
{
	NSArray *pathcomps;
	float cntwidth;
	NSFont *font;	
	NSString *path;
  NSString *relpath = nil;		
	int i;
						
	cntwidth = [field bounds].size.width;
	font = [field font];

	if ([font widthOfString: fullPath] < cntwidth) {
		return fullPath;
	}
  	
	cntwidth = cntwidth - [font widthOfString: fix_path(@"../", 0)];
		
	pathcomps = [fullPath pathComponents];
	i = [pathcomps count] - 1;
	path = [NSString stringWithString: [pathcomps objectAtIndex: i]];
	
	while (i > 0) {
		i--;		
		if ([font widthOfString: path] < cntwidth) {
			relpath = [NSString stringWithString: path];
		} else {
			break;
    }						
		path = [NSString stringWithFormat: @"%@%@%@", [pathcomps objectAtIndex: i], fix_path(@"/", 0), path];
	}
	
	relpath = [NSString stringWithFormat: @"%@%@", fix_path(@"../", 0), relpath];
	
	return relpath;
}

