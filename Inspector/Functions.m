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

NSString *fixPath(NSString *s, const char *c)
{
  return fix_path(s, c);
}

NSString *cutFileLabelText(NSString *filename, id label, int lenght)
{
	if (lenght > 0) {
		return cut_Text(filename, label, lenght);
	}
  
	return filename;
}

NSString *subtractPathComponentToPath(NSString *apath, NSString *firstpart)
{
	NSString *secondpart;
	int pos;
		
	if([apath isEqualToString: firstpart] == YES) {
		return fixPath(@"/", 0);
  }
	pos = [apath rangeOfString: firstpart].length +1;
	secondpart = [apath substringFromIndex: pos];

	return secondpart;
}

BOOL subPathOfPath(NSString *p1, NSString *p2)
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

NSString *pathFittingInContainer(id container, NSString *fullPath, int margins)
{
	NSArray *pathcomps;
	float cntwidth;
	NSFont *font;	
	NSString *path;
  NSString *relpath = nil;		
	int i;
						
	cntwidth = [container frame].size.width - margins;
	font = [container font];

	if([font widthOfString: fullPath] < cntwidth) {
		return fullPath;
	}
  
	cntwidth = cntwidth - [font widthOfString: fixPath(@"../", 0)];
		
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
		path = [NSString stringWithFormat: @"%@%@%@", [pathcomps objectAtIndex: i], fixPath(@"/", 0), path];
	}
	
	relpath = [NSString stringWithFormat: @"%@%@", fixPath(@"../", 0), relpath];
	
	return relpath;
}

NSString *relativePathFittingInContainer(id container, NSString *fullPath)
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
  	
	cntwidth = cntwidth - [font widthOfString: fixPath(@"../", 0)];
		
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
		path = [NSString stringWithFormat: @"%@%@%@", [pathcomps objectAtIndex: i], fixPath(@"/", 0), path];
	}
	
	relpath = [NSString stringWithFormat: @"%@%@", fixPath(@"../", 0), relpath];
	
	return relpath;
}

int pathComponentsToPath(NSString *path)
{
  if ([path isEqualToString: fixPath(@"/", 0)]) {
    return 0;
  }
  return [[path pathComponents] count] - 1;
}

NSString *commonPrefixInArray(NSArray *a)
{
  NSString *s = @"";
  unsigned minlngt = INT_MAX;
  int index = 0;
  BOOL done = NO;
  int i, j;
  
  if ([a count] == 0) {
    return nil;
  }
  if ([a count] == 1) {
    return [a objectAtIndex: 0];
  }
  
  for (i = 0; i < [a count]; i++) {
    unsigned l = [[a objectAtIndex: i] length];
    if (l < minlngt) {
      minlngt = l;
    }
  }
  
  while (index < minlngt) {
    NSString *s1, *s2;
    unichar c1, c2;
    
    for (i = 0; i < [a count]; i++) {
      s1 = [a objectAtIndex: i];
      c1 = [s1 characterAtIndex: index];

      for (j = 0; j < [a count]; j++) {
        s2 = [a objectAtIndex: j];
        c2 = [s2 characterAtIndex: index];

        if (i != j) {
          if (c1 != c2) {
            done = YES;
            break;
          }
        }
      }
    
      if (done) {
        break;
      }
    } 

    if (done) {
      break;
    }
    
    s = [s1 substringWithRange: NSMakeRange(0, index + 1)];
       
    index++;
  } 
  
  return ([s length] ? s : nil);
}

NSString *fileSizeDescription(unsigned long long size)
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

NSMenuItem *addItemToMenu(NSMenu *menu, NSString *str, 
																NSString *comm, NSString *sel, NSString *key)
{
	NSMenuItem *item = [menu addItemWithTitle: NSLocalizedString(str, comm)
												action: NSSelectorFromString(sel) keyEquivalent: key]; 
	return item;
}
