/* Functions.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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
#include "GNUstep.h"
#include <limits.h>

static NSString *fixp(NSString *s, const char *c)
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
  return fixp(s, c);
}

static inline NSString *cut_label_text(NSString *filename, id label, int lenght)
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
			if (i == [filename cStringLength]) {
				break;
      }
			cutname = [filename substringToIndex: i];
			reststr = [filename substringFromIndex: i];
      cw = [cutname sizeWithAttributes: attr].width;
			i++;
		}	
		if ([cutname isEqual: filename] == NO) {      
			if ([reststr cStringLength] <= 3) { 
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

NSString *cutLabelText(NSString *filename, id label, int lenght)
{
	if (lenght > 0) {
		return cut_label_text(filename, label, lenght);
	}
  
	return filename;
}

static inline int compare_Cells_Remote(id *c1, id *c2, void *context)
{
  NSString *n1 = [(NSCell *)c1 stringValue];
  NSString *n2 = [(NSCell *)c2 stringValue];

  if ([n2 hasPrefix: @"."] || [n1 hasPrefix: @"."]) {
    if ([n2 hasPrefix: @"."] && [n1 hasPrefix: @"."]) {
      return [n1 caseInsensitiveCompare: n2];
    } else {
      return [n2 caseInsensitiveCompare: n1];
    }
  }
  return [n1 caseInsensitiveCompare: n2];
}

int compareCellsRemote(id *c1, id *c2, void *context)
{
  return compare_Cells_Remote(c1, c2, context);
}
