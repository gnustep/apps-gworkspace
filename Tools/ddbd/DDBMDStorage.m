/* DDBMDStorage.m
 *  
 * Copyright (C) 2005-2012 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2005
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

#include "DDBMDStorage.h"
#include "ddbd.h"

@implementation	DDBMDStorage

- (void)dealloc
{
  RELEASE (basePath);

  RELEASE (countpath);
  NSZoneFree ([self zone], pnum);
  RELEASE (formstr);
  
  RELEASE (freepath);
  RELEASE (freeEntries);
    
  [super dealloc];
}

- (id)initWithPath:(NSString *)apath
        levelCount:(unsigned)lcount
         dirsDepth:(unsigned)ddepth

{
  self = [super init];
  
  if (self) {
    NSString *str;
    BOOL exists, isdir;  
    unsigned i;
    
    ASSIGN (basePath, apath);
    levcount = lcount;
    depth = ddepth;

    ASSIGN (countpath, [basePath stringByAppendingPathComponent: @"count"]);

    pnum = NSZoneMalloc([self zone], sizeof(int) * depth);

    str = [[NSNumber numberWithUnsignedInt: (levcount - 1)] stringValue];
    ASSIGN (formstr, ([NSString stringWithFormat: @"%%0%lui", (unsigned long)[str length]]));

    ASSIGN (freepath, [basePath stringByAppendingPathComponent: @"free"]);

    fm = [NSFileManager defaultManager];
  
    exists = [fm fileExistsAtPath: basePath isDirectory: &isdir];
    
    if (exists == NO)
      {
	if ([fm createDirectoryAtPath: basePath attributes: nil] == NO)
	  {
	    [NSException raise: NSInvalidArgumentException
			format: @"cannot create directory at: %@", basePath];
	    DESTROY (self);
	    return nil;
	  }    
    
	isdir = YES;
      }
  
    if (isdir == NO)
      {      
	[NSException raise: NSInvalidArgumentException
		    format: @"%@ is not a directory!", basePath];
	DESTROY (self);
	return nil;
      } 
    
    if ([fm fileExistsAtPath: freepath]) {
      freeEntries = [NSMutableArray arrayWithContentsOfFile: freepath];
      RETAIN (freeEntries);
    } else {
      freeEntries = [NSMutableArray new];
      [freeEntries writeToFile: freepath atomically: YES];
    }
  
    if ([fm fileExistsAtPath: countpath]) {
      NSString *countStr = [NSString stringWithContentsOfFile: countpath];
      NSScanner *scanner = [NSScanner scannerWithString: countStr];
      int j = 0;
      
      while ([scanner isAtEnd] == NO) {
        [scanner scanInt: &pnum[j]];
        j++;
      }
        
    } else {
      NSMutableString *countStr = [NSMutableString string];
      
      for (i = 0; i < (depth - 1); i++) {
        pnum[i] = 0;
        [countStr appendFormat: @"%i ", pnum[i]];
      }
      
      pnum[depth - 1] = -1;
      [countStr appendFormat: @"%i ", pnum[depth - 1]];

      [countStr writeToFile: countpath atomically: YES];
    }
  }
  
  return self;
}

- (NSString *)nextEntry
{
  CREATE_AUTORELEASE_POOL (arp);
  NSString *fullpath = [NSString stringWithString: basePath];
  NSString *entry = [NSString string];
  int count = [freeEntries count];
  int i;
  
  if (count > 0) {
    NSArray *components = [freeEntries objectAtIndex: (count - 1)];
    
    for (i = 0; i < depth; i++) {
      entry = [entry stringByAppendingPathComponent: [components objectAtIndex: i]];
    
      if (i < (depth - 1)) {
        fullpath = [fullpath stringByAppendingPathComponent: [components objectAtIndex: i]];

        if ([fm fileExistsAtPath: fullpath] == NO) {
          if ([fm createDirectoryAtPath: fullpath attributes: nil] == NO) {
            [NSException raise: NSInternalInconsistencyException
		                    format: @"cannot create %@", entry]; 
          }
        }
      }
    }

    [freeEntries removeObjectAtIndex: (count - 1)];
    [freeEntries writeToFile: freepath atomically: YES];

  } else {
    BOOL full = YES;

    for (i = 0; i < depth; i++) {
      if (pnum[i] < (levcount - 1)) {
        full = NO;
        break;
      }
    }

    if (full == NO) {
      NSMutableString *countStr = [NSMutableString string];
      int pos = depth - 1;

      while (pos >= 0) {
        pnum[pos]++;

        if (pnum[pos] == levcount) {
          if (pos == 0) {
            pnum[pos]--;
            [NSException raise: NSInternalInconsistencyException
		                    format: @"the directory is full!"]; 
            RELEASE (arp);    
            return nil;
          } else {
            pnum[pos] = 0;  
            pos--;
          }
        } else {
          break;
        }
      }

      for (i = 0; i < depth; i++) {
        NSString *str = [NSString stringWithFormat: formstr, pnum[i]];

        fullpath = [fullpath stringByAppendingPathComponent: str];
        entry = [entry stringByAppendingPathComponent: str];
        [countStr appendFormat: @"%i ", pnum[i]];
        
        if (i < (depth - 1)) {
          if ([fm fileExistsAtPath: fullpath] == NO) {
            if ([fm createDirectoryAtPath: fullpath attributes: nil] == NO) {
              [NSException raise: NSInternalInconsistencyException
		                      format: @"cannot create %@", entry]; 
            }
          }
        }
      }

      [countStr writeToFile: countpath atomically: YES];

    } else {
      [NSException raise: NSInternalInconsistencyException
  		            format: @"the directory is full!"];     
    }
  }

  RETAIN (entry);
  RELEASE (arp); 
          
  return [entry autorelease];
}

- (void)removeEntry:(NSString *)entry
{
  CREATE_AUTORELEASE_POOL (arp);
  NSArray *components = [entry pathComponents];
  int count = [components count];
  int i;
  
  if (count == depth) {
    NSString *lastdir = [NSString stringWithString: basePath];
    NSString *prefix = [components objectAtIndex: (depth - 1)];
    NSArray *contents;
    
    for (i = 0; i < (depth -1); i++) {
      lastdir = [lastdir stringByAppendingPathComponent: [components objectAtIndex: i]];
    }
    
    contents = [fm directoryContentsAtPath: lastdir];

    for (i = 0; i < [contents count]; i++) {
      NSString *fname = [contents objectAtIndex: i];
    
      if ([fname hasPrefix: prefix]) {
        NSString *rmpath = [lastdir stringByAppendingPathComponent: fname];
             
        if ([fm removeFileAtPath: rmpath handler: nil] == NO) {
          [NSException raise: NSInternalInconsistencyException
		                  format: @"cannot remove %@", rmpath];           
        }        
      }
    }
    
    [freeEntries addObject: components];
    [freeEntries writeToFile: freepath atomically: YES];    
    
  } else {
    [NSException raise: NSInvalidArgumentException
		            format: @"cannot remove %@", entry];           
  }
  
  RELEASE (arp);
}

- (void)removePath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL (arp);
  NSString *fullpath = [basePath stringByAppendingPathComponent: path];
  BOOL exists, isdir;

  exists = [fm fileExistsAtPath: fullpath isDirectory: &isdir];

  if ((exists && (isdir == NO)) && subpath(basePath, fullpath)) {
    [fm removeFileAtPath: fullpath handler: nil];
  } else {
    [NSException raise: NSInvalidArgumentException
		            format: @"cannot remove %@", path];           
  }
  
  RELEASE (arp);
}

- (NSString *)basePath
{
  return basePath;
}

@end










