/* FSNFunctions.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>
#import "FSNFunctions.h"
#import "FSNodeRep.h"

NSString *path_separator(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    #if defined(__MINGW32__)
      separator = @"\\";	
    #else
      separator = @"/";	
    #endif
  }

  return separator;
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

NSComparisonResult compareWithExtType(id r1, id r2, void *context)
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
    
  if (size == 1)
    sizeStr = @"1 byte";
  else if (size == 0)
    sizeStr = @"0 bytes";
  else if (size < (10 * ONE_KB))
    sizeStr = [NSString stringWithFormat:@" %ld bytes", (long)size];
  else if (size < (100 * ONE_KB))
    sizeStr = [NSString stringWithFormat:@" %3.2fKB", ((double)size / (double)(ONE_KB))];
  else if (size < (100 * ONE_MB))
    sizeStr = [NSString stringWithFormat:@" %3.2fMB", ((double)size / (double)(ONE_MB))];
  else
    sizeStr = [NSString stringWithFormat:@" %3.2fGB", ((double)size / (double)(ONE_GB))];

  return sizeStr;
}

NSArray *makePathsSelection(NSArray *selnodes)
{
  NSMutableArray *selpaths = [NSMutableArray array]; 
  NSUInteger i;

  for (i = 0; i < [selnodes count]; i++) {
    [selpaths addObject: [[selnodes objectAtIndex: i] path]];
  }
  
  return selpaths;
}

double myrintf(double a)
{
  return (floor(a + 0.5));
}


/* --- Text Field Editing Error Messages */

void showAlertNoPermission(Class c, NSString *name)
{
  NSRunAlertPanel(
                  NSLocalizedStringFromTableInBundle(@"Error", nil, [NSBundle bundleForClass:c], @""), 
                  [NSString stringWithFormat: @"%@ \"%@\"!\n", 
                            NSLocalizedStringFromTableInBundle(@"You do not have write permission for", nil, [NSBundle bundleForClass:c], @""), 
                            name],
                  NSLocalizedStringFromTableInBundle(@"Continue", nil, [NSBundle bundleForClass:c], @""),
                  nil, nil);   
}

void showAlertInRecycler(Class c)
{
  NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Error", nil, [NSBundle bundleForClass:c], @""),
                  NSLocalizedStringFromTableInBundle(@"You can't rename an object that is in the Recycler", nil, [NSBundle bundleForClass:c], @""),
                  NSLocalizedStringFromTableInBundle(@"Continue", nil, [NSBundle bundleForClass:c], @"")
                  , nil, nil);   
}

void showAlertInvalidName(Class c)
{
  NSLog(@"Class %@ Bundle %@", c, [NSBundle bundleForClass:c]);
  NSRunAlertPanel(NSLocalizedStringFromTableInBundle(@"Error", nil, [NSBundle bundleForClass:c], @""),
                  NSLocalizedStringFromTableInBundle(@"Invalid name", nil, [NSBundle bundleForClass:c], @""),
                  NSLocalizedStringFromTableInBundle(@"Continue", nil, [NSBundle bundleForClass:c], @""),
                  nil, nil);  
}

NSInteger showAlertExtensionChange(Class c, NSString *extension)
{
  NSString *msg;
  NSInteger r;

  msg = NSLocalizedStringFromTableInBundle(@"Are you sure you want to add the extension", nil, [NSBundle bundleForClass:c], @"");

  msg = [msg stringByAppendingFormat: @"\"%@\" ", extension];
  msg = [msg stringByAppendingString: NSLocalizedStringFromTableInBundle(@"to the end of the name?", nil, [NSBundle bundleForClass:c], @"")];
  msg = [msg stringByAppendingString: NSLocalizedStringFromTableInBundle(@"\nif you make this change, your folder may appear as a single file.", nil, [NSBundle bundleForClass:c], @"")];

  r = NSRunAlertPanel(@"", msg, 
                      NSLocalizedStringFromTableInBundle(@"Cancel", nil, [NSBundle bundleForClass:c], @""), 
                      NSLocalizedStringFromTableInBundle(@"OK", nil, [NSBundle bundleForClass:c], @""), 
                      nil);
  return r;
}

void showAlertNameInUse(Class c, NSString *newname)
{
  NSRunAlertPanel(
                  NSLocalizedStringFromTableInBundle(@"Error", nil, [NSBundle bundleForClass:c], @""),
                  [NSString stringWithFormat: @"%@\"%@\" %@ ", 
                            NSLocalizedStringFromTableInBundle(@"The name ", nil, [NSBundle bundleForClass:c], @""),
                            newname,
                            NSLocalizedStringFromTableInBundle(@" is already in use!", nil, [NSBundle bundleForClass:c], @"")], 
                  NSLocalizedStringFromTableInBundle(@"Continue", nil, [NSBundle bundleForClass:c], @""), nil, nil); 
}
