/* Functions.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "Functions.h"
#include "GNUstep.h"

#define ONE_KB 1024
#define ONE_MB (ONE_KB * ONE_KB)
#define ONE_GB (ONE_KB * ONE_MB)

#define ATTRIBUTES_AT_PATH(a, p, l) \
a = [[NSFileManager defaultManager] fileAttributesAtPath: (NSString *)p traverseLink: l]

#define SORT_INDEX(i, p) { \
BOOL isdir; \
[[NSFileManager defaultManager] fileExistsAtPath: (NSString *)p isDirectory: &isdir]; \
if (isdir) { \
i = 2; \
} else { \
if ([[NSFileManager defaultManager] isExecutableFileAtPath: (NSString *)p] == YES) { \
i = 1; \
} else { \
i = 0; \
} \
} }

#define byname 0
#define bykind 1
#define bydate 2
#define bysize 3
#define byowner 4

@protocol IconsProtocol

- (NSString *)myName;

@end 

static inline NSString *cut_Text(NSString *filename, id label, int lenght)
{
	NSString *cutname = nil;
  NSString *reststr = nil;
	NSFont *labfont;
	float w, cw, dotslenght;
	int i;

	cw = 0;
	labfont = [label font];
	dotslenght = [labfont widthOfString: @"..."];
	w = [labfont widthOfString: filename];
	if (w > lenght) {
		i = 0;
		while (cw <= lenght - dotslenght) {
			if (i == [filename length]) {
				break;
      }
			cutname = [filename substringToIndex: i];
			reststr = [filename substringFromIndex: i];
			cw = [labfont widthOfString: cutname];
			i++;
		}	
		if ([cutname isEqual: filename] == NO) {      // QUA !!!!!!!!!!!!!
			if ([reststr length] <= 3) { 
				return filename;
			} else {
				cutname = [cutname stringByAppendingString:@"..."];
      }
		} else {
			return filename;
		}	
	} else {
		return filename;
	}
	return cutname;
}

static inline int compare_Paths(id *p1, id *p2, void *context)
{
  int stype;
  int i1, i2;      
  NSDictionary *attributes; 
  NSDate *d1, *d2;
  float fs1, fs2;
  NSString *own1, *own2;
     
  stype = (int)context;

  switch(stype) {
    case byname:
			{
				NSString *n1 = [(NSString *)p1 lastPathComponent];
				NSString *n2 = [(NSString *)p2 lastPathComponent];

      	if ([n2 hasPrefix: @"."] || [n1 hasPrefix: @"."]) {
        	if ([n2 hasPrefix: @"."] && [n1 hasPrefix: @"."]) {
          	return [n1 caseInsensitiveCompare: n2];
        	} else {
          	return [n2 caseInsensitiveCompare: n1];
        	}
      	}
      	return [n1 caseInsensitiveCompare: n2];
      	break;
  		}
			
    case bykind:      
 			SORT_INDEX (i1, p1);
			SORT_INDEX (i2, p2);
			    
      if (i1 == i2) {			
        return [(NSString *)p1 compare: (NSString *)p2]; 
      }   
			   
      return (i1 < i2 ? 1 : -1);
      break;
  
    case bydate:
			ATTRIBUTES_AT_PATH(attributes, p1, NO);
      d1 = [attributes fileModificationDate];
			ATTRIBUTES_AT_PATH(attributes, p2, NO);
      d2 = [attributes fileModificationDate];
    
      return [d1 compare: d2]; 
      break;

    case bysize:
			ATTRIBUTES_AT_PATH(attributes, p1, NO);
      fs1 = [attributes fileSize];
			ATTRIBUTES_AT_PATH(attributes, p2, NO);
      fs2 = [attributes fileSize];
    
      return (fs1 < fs2 ? 1 : -1);    
      break;

    case byowner:
			ATTRIBUTES_AT_PATH(attributes, p1, NO);
      own1 = [attributes fileOwnerAccountName];
			ATTRIBUTES_AT_PATH(attributes, p2, NO);
      own2 = [attributes fileOwnerAccountName];
    
      return [own1 compare: own2];     
      break;
 
    default:
      break;
  }

  return 1;
}

static inline int compare_Cells(id *c1, id *c2, void *context)
{
  NSDictionary *dict = (NSDictionary *)context;
  NSString *basepath = fixPath([dict objectForKey: @"path"], 0);
  NSString *s1 = [basepath stringByAppendingPathComponent: [(NSCell *)c1 stringValue]];
  NSString *s2 = [basepath stringByAppendingPathComponent: [(NSCell *)c2 stringValue]];
  int stype = [[dict objectForKey: @"type"] intValue]; 
  
	return comparePaths((id *)s1, (id *)s2, (void *)stype);
}

static inline int comp_Icons(id *c1, id *c2, void *context)
{
	NSDictionary *sdict = (NSDictionary *)context;
	NSString *basepath = fixPath([sdict objectForKey: @"path"], 0);
	int stype = [[sdict objectForKey: @"type"] intValue];

  NSString *s1 = [basepath stringByAppendingPathComponent: [(id<IconsProtocol>)c1 myName]];
  NSString *s2 = [basepath stringByAppendingPathComponent: [(id<IconsProtocol>)c2 myName]];
  
  return comparePaths((id *)s1, (id *)s2, (void *)stype);
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

int comparePaths(id *p1, id *p2, void *context)
{
	NSString *s1 = fixPath((NSString *)p1, 0);
	NSString *s2 = fixPath((NSString *)p2, 0);	
  return compare_Paths((id *)s1, (id *)s2, context);
}

int compareCells(id *c1, id *c2, void *context)
{
  return compare_Cells(c1, c2, context);
}

int compareDimmedCells(id *c1, id *c2, void *context)
{
  NSString *s1 = [(NSCell *)c1 stringValue];
  NSString *s2 = [(NSCell *)c2 stringValue];
  return [s1 compare: s2]; 
}

int compIcons(id *c1, id *c2, void *context)
{
  return comp_Icons(c1, c2, context);
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
