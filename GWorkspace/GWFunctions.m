/* GWFunctions.m
 *  
 * Copyright (C) 2003-2013 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <math.h>
#include <limits.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "GWFunctions.h"


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

NSString *systemRoot()
{
  static NSString *root = nil;

  if (root == nil) {
    #if defined(__MINGW32__)
    /* FIXME !!!!!! */
      root = @"\\";	
    #else
      root = @"/";	
    #endif

    RETAIN (root);
  }

  return root;
}

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

    s1 = s2 = nil;
    
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
  
  if ([s length]) {
    return s;
  }
  
  return nil;
}

NSString *fileSizeDescription(unsigned long long size)
{
  NSString *sizeStr;
  char *sign = "";
    
  if(size == 1)
    sizeStr = @"1 byte";
  else if(size == 0)
    sizeStr = @"0 bytes";
  else if(size < (10 * ONE_KB))
    sizeStr = [NSString stringWithFormat:@"%s %ld bytes", sign, (long)size];
  else if(size < (100 * ONE_KB))
    sizeStr = [NSString stringWithFormat:@"%s %3.2fKB", sign,
			((double)size / (double)(ONE_KB))];
  else if(size < (100 * ONE_MB))
    sizeStr = [NSString stringWithFormat:@"%s %3.2fMB", sign,
			((double)size / (double)(ONE_MB))];
  else
    sizeStr = [NSString stringWithFormat:@"%s %3.2fGB", sign,
			((double)size / (double)(ONE_GB))];

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
