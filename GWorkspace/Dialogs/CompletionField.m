/* CompletionField.m
 *  
 * Copyright (C) 2003-2010 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "GWFunctions.h"
#import "FSNFunctions.h"
#import "CompletionField.h"

@implementation CompletionField

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithCoder: (NSCoder *) coder
{
  self = [super initWithCoder: coder];  
  if (self)
  {
    [self setRichText: NO];
    [self setImportsGraphics: NO];
    [self setUsesFontPanel: NO];
    [self setUsesRuler: NO];
    [self setEditable: YES];
    fm = [NSFileManager defaultManager];
  }
  
  return self;  
}


- (void)setFrame:(NSRect)frameRect
{
  NSSize size;

  [super setFrame: frameRect];
  size = NSMakeSize(1e7, [self bounds].size.height);
  [[self textContainer] setContainerSize: size];
  [[self textContainer] setWidthTracksTextView: YES];
}

- (void)keyDown:(NSEvent *)theEvent
{
  NSString *eventstr = [theEvent characters];
  NSString *str = [self string];

#define CHECK_SEPARATOR \
if ([path hasSuffix: pathSeparator] == NO) \
[path appendString: pathSeparator]
 
  if (([eventstr isEqual: @"\r"] == NO)
                              && ([eventstr isEqual: @"\t"] == NO)) { 
                               
    [super keyDown: theEvent];
  }
  
  if ([eventstr isEqual: @"\t"] && [str length]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSString *pathSeparator = path_separator();
    NSArray *components = [str componentsSeparatedByString: pathSeparator];
    NSMutableString *path = [NSMutableString string];
    int i, j, m, n;
    
    if ([[components objectAtIndex: 0] isEqual: str]) {
      RELEASE (arp);
      return;
    }
        
    [path appendString: pathSeparator];
    
    for (i = 0; i < [components count]; i++) {
      NSString *component = [components objectAtIndex: i];
      NSString *teststr = [path stringByAppendingString: component];
      BOOL isDir;
      
      if (([fm fileExistsAtPath: teststr isDirectory: &isDir] && isDir)
                                          && ([path isEqual: teststr] == NO)) {
        NSArray *contents = [fm directoryContentsAtPath: teststr];
        
        if (contents && ([str hasSuffix: pathSeparator] == NO)) {
          BOOL found = NO;
        
          for (j = 0; j < [contents count]; j++) {
            NSString *fname = [contents objectAtIndex: j];
            
            if ([fname hasPrefix: component] && (![fname isEqual: component])) {
              found = YES; 
            }
          }
        
          if (found) {
            CHECK_SEPARATOR;
            [path appendString: component];
            NSBeep();
          } else {
            CHECK_SEPARATOR;
            [path appendString: component];
            if (isDir) {
              [path appendString: pathSeparator];
            }
          }
          
        } else {
          CHECK_SEPARATOR;
          [path appendString: component];
          if (isDir) {
            [path appendString: pathSeparator];
          }
        }
        
      } else {
        NSArray *contents = [fm directoryContentsAtPath: path];

        if (contents) {
          NSMutableArray *common = [NSMutableArray array];
          unsigned *lengths = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unsigned) * [contents count]);
          unsigned prefLength = 0;
          int index = 0;;

          for (j = 0; j < [contents count]; j++) {
            lengths[j] = 0;
          }

          for (j = 0; j < [contents count]; j++) {
            NSString *fname = [contents objectAtIndex: j];

            if ([fname hasPrefix: component]) {
              NSRange range = [fname rangeOfString: component];

              if (range.length >= prefLength) {
                prefLength = range.length;
                lengths[j] = range.length;
                index = j;
              }

              [common addObject: fname];
            }
          }

          if (prefLength != 0) {
            BOOL found = NO;

            for (m = 0; m < [contents count]; m++) {
              unsigned l1 = lengths[m];

              for (n = 0; n < [contents count]; n++) {
                unsigned l2 = lengths[n];

                if ((m != n) && ((l1 != 0) && (l2 != 0))) {
                  if ((l1 == l2) && (l1 == prefLength)) {
                    found = YES;
                    break;
                  }
                }
              }

              if (found) {
                break;
              }
            }

            if (found == NO) {
              NSString *cprefix = commonPrefixInArray(common);
              
              if (cprefix) {
                CHECK_SEPARATOR;
                [path appendString: cprefix];

                if ([fm fileExistsAtPath: path isDirectory: &isDir]) {
                  if (isDir) {
                    [path appendString: pathSeparator];
                  }
                } else {
                  NSBeep();
                }
              } else {
                CHECK_SEPARATOR;
                [path appendString: [contents objectAtIndex: index]];
                [path appendString: pathSeparator];
              }
            } else {
              NSString *cprefix = commonPrefixInArray(common);

              if (cprefix) {
                CHECK_SEPARATOR;
                [path appendString: cprefix];
              } else {
                NSString *s = [[contents objectAtIndex: index] substringToIndex: prefLength];
                [path appendString: s];
              }

              NSZoneFree (NSDefaultMallocZone(), lengths);
              NSBeep();
              break;
            }
          }

          NSZoneFree (NSDefaultMallocZone(), lengths);
        }
      }
    }
  
    [self setString: path];
    RELEASE (arp);
  
  } else if ([eventstr isEqual: @"\r"] && [str length]) {
    [controller completionFieldDidEndLine: self];
  }
}

@end









