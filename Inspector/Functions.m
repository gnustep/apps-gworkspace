/* Functions.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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
#include "Functions.h"
#include <limits.h>

#define ONE_KB 1024
#define ONE_MB (ONE_KB * ONE_KB)
#define ONE_GB (ONE_KB * ONE_MB)

static inline NSString *cut_Text(NSString *filename, id label, int lenght)
{
	NSString *cutname = nil;
  NSString *reststr = nil;
  NSString *dots;
	NSFont *labfont;
  NSDictionary *attr;
	float w, cw, dotslenght;
	int i;

	cw = 0;
	labfont = [label font];
  
  attr = [NSDictionary dictionaryWithObjectsAndKeys: 
			                        labfont, NSFontAttributeName, nil];  
  
  dots = @"...";  
	dotslenght = [dots sizeWithAttributes: attr].width;  
  w = [filename sizeWithAttributes: attr].width;
  
	if (w > lenght) {
		i = 0;
		while (cw <= (lenght - dotslenght)) {
			if (i == [filename length]) {
				break;
      }
			cutname = [filename substringToIndex: i];
			reststr = [filename substringFromIndex: i];
      cw = [cutname sizeWithAttributes: attr].width;
			i++;
		}	
		if ([cutname isEqual: filename] == NO) {      
			if ([reststr length] <= 3) { 
				return filename;
			} else {
				cutname = [cutname stringByAppendingString: dots];
      }
		} else {
			return filename;
		}	
	} else {
		return filename;
	}
  
	return cutname;
}

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

NSString *fixpath(NSString *s, const char *c)
{
  return fix_path(s, c);
}

NSString *relativePathFit(id container, NSString *fullPath)
{
	NSArray *pathcomps;
	float cntwidth;
	NSFont *font;	
	NSString *path;
  NSString *relpath = nil;		
	int i;
						
	cntwidth = [container frame].size.width;
	font = [container font];

	if([font widthOfString: fullPath] < cntwidth) {
		return fullPath;
	}
  	
	cntwidth = cntwidth - [font widthOfString: fixpath(@"../", 0)];
		
	pathcomps = [fullPath pathComponents];
	i = [pathcomps count] - 1;
	path = [NSString stringWithString: [pathcomps objectAtIndex: i]];
	
	while(i > 0) {
		i--;		
		if([font widthOfString: path] < cntwidth) {
			relpath = [NSString stringWithString: path];
		} else {
			break;
    }						
		path = [NSString stringWithFormat: @"%@%@%@", [pathcomps objectAtIndex: i], fixpath(@"/", 0), path];
	}
	
	relpath = [NSString stringWithFormat: @"%@%@", fixpath(@"../", 0), relpath];
	
	return relpath;
}

NSString *fsDescription(unsigned long long size)
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

