/* GWFunctions.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GWFunctions.h"
#include <math.h>
#include <limits.h>

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

static NSString *dots = @"...";
static float dtslenght = 0.0;  
static NSFont *lablfont = nil;
static NSDictionary *fontAttr = nil;

@protocol IconsProtocol

- (NSString *)myName;

@end 

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

static inline int compare_Paths(id *p1, id *p2, void *context)
{
  int stype;
  int i1, i2;      
  NSDictionary *attributes; 
  NSDate *d1, *d2;
  unsigned long long fs1, fs2;
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

/*
NSString *cutFileLabelText(NSString *filename, id label, int lenght)
{
	if (lenght > 0) {
		return cut_Text(filename, label, lenght);
	}
  
	return filename;
}
*/

NSString *cutFileLabelText(NSString *filename, id label, int lenght)
{
	if (lenght > 0) {
	  NSFont *font = [label font];
  
    if ((lablfont == nil) || ([lablfont isEqual: font] == NO)) {
      ASSIGN (lablfont, font);
      ASSIGN (fontAttr, [NSDictionary dictionaryWithObject: lablfont 
                                                    forKey: NSFontAttributeName]);
      dtslenght = [dots sizeWithAttributes: fontAttr].width;     
    }

    if ([filename sizeWithAttributes: fontAttr].width > lenght) {
      int tl = [filename length];

      if (tl <= 5) {
        return dots;
      } else {
        int fpto = (tl / 2) - 2;
        int spfr = fpto + 3;
        NSString *fp = [filename substringToIndex: fpto];
        NSString *sp = [filename substringFromIndex: spfr];
        NSString *dotted = [NSString stringWithFormat: @"%@%@%@", fp, dots, sp];
        int dl = [dotted length];
        float dotl = [dotted sizeWithAttributes: fontAttr].width;
        int p = 0;

        while (dotl > lenght) {
          if (dl <= 5) {
            return dots;
          }        

          if (p) {
            fpto--;
          } else {
            spfr++;
          }
          p = !p;

          fp = [filename substringToIndex: fpto];
          sp = [filename substringFromIndex: spfr];
          dotted = [NSString stringWithFormat: @"%@%@%@", fp, dots, sp];
          dotl = [dotted sizeWithAttributes: fontAttr].width;
          dl = [dotted length];
        }      

        return dotted;
      }
    }

    return filename;
	}
  
	return filename;
}

NSString *subtractPathComponentToPath(NSString *apath, NSString *firstpart)
{
	NSString *secondpart;
	int pos;
		
	if ([apath isEqual: firstpart]) {
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

  if ((l1 > l2) || ([p1 isEqual: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqual: p1]) {
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
  if ([path isEqual: fixPath(@"/", 0)]) {
    return 0;
  }
  return [[path pathComponents] count] - 1;
}

NSString *pathRemovingPrefix(NSString *path, NSString *prefix)
{
  if ([path hasPrefix: prefix]) {
	  return [path substringFromIndex: [path rangeOfString: prefix].length + 1];
  }

  return path;  	
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

int compareCellsRemote(id *c1, id *c2, void *context)
{
  return compare_Cells_Remote(c1, c2, context);
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

NSRect rectForWindow(NSArray *otherwins, NSRect proposedRect, BOOL checkKey)
{
  NSRect scr = [[NSScreen mainScreen] visibleFrame];
  NSRect wr = proposedRect;
  int margin = 50;
  int shift = 100;
  NSPoint p = wr.origin;
  int i;  

	for (i = [otherwins count] - 1; i >= 0; i--) {
    NSWindow *window = [otherwins objectAtIndex: i];

    if ([window isKeyWindow] || (checkKey == NO)) {
      p = [window frame].origin;
      p.x += shift;
      p.y -= shift;
      p.y = (p.y < margin) ? margin : p.y;
      if ((p.x + proposedRect.size.width) > (scr.size.width - margin)) {
        p.x -= (shift * 2);
      }
      wr.origin = p;
    }
  }

	for (i = 0; i < [otherwins count]; i++) {
    NSRect r = [[otherwins objectAtIndex: i] frame];

    if (NSEqualRects(wr, r)) {
      p.x += shift;
      p.y -= shift;
      p.y = (p.y < margin) ? margin : p.y;
      if ((p.x + proposedRect.size.width) > (scr.size.width - margin)) {
        p.x -= (shift * 2);
      }
      wr.origin = p;
    }
  }
  
  if (NSEqualRects(wr, proposedRect)) {
    wr.origin.x = scr.origin.x + shift;
    wr.origin.y = scr.size.height - wr.size.height - shift;
  }  
  
  return NSIntegralRect(wr);
}

NSMenuItem *addItemToMenu(NSMenu *menu, NSString *str, 
																NSString *comm, NSString *sel, NSString *key)
{
	NSMenuItem *item = [menu addItemWithTitle: NSLocalizedString(str, comm)
												action: NSSelectorFromString(sel) keyEquivalent: key]; 
	return item;
}

