/* FModuleName.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Finder application
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
#include "FinderModulesProtocol.h"
#include "GNUstep.h"

static NSString *nibName = @"FModuleName";

@interface FModuleName : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet id controlsBox;
  IBOutlet id popUp;
  IBOutlet id textField;
  int index;
  BOOL used;
  
  NSString *searchStr;
  int how;
}

- (IBAction)popUpAction:(id)sender; 

@end

@implementation FModuleName

#define CONTAINS     0
#define IS           1
#define NOT_CONTAINS 2
#define STARTS       3
#define ENDS         4

- (void)dealloc
{
  TEST_RELEASE (controlsBox);
  TEST_RELEASE (searchStr);
  [super dealloc];
}

- (id)initInterface
{
	self = [super init];

  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }

    RETAIN (controlsBox);
    RELEASE (win);

    used = NO;
    index = 0;
    
    searchStr = nil;
    
    [textField setStringValue: @""];

    /* Internationalization */    
    [popUp removeAllItems];
    [popUp insertItemWithTitle: NSLocalizedString(@"contains", @"") 
                       atIndex: CONTAINS];
    [popUp insertItemWithTitle: NSLocalizedString(@"is", @"") 
                       atIndex: IS];
    [popUp insertItemWithTitle: NSLocalizedString(@"doesn't contain", @"") 
                       atIndex: NOT_CONTAINS];
    [popUp insertItemWithTitle: NSLocalizedString(@"starts with", @"") 
                       atIndex: STARTS];
    [popUp insertItemWithTitle: NSLocalizedString(@"ends with", @"") 
                       atIndex: ENDS];
                       
    [popUp selectItemAtIndex: CONTAINS]; 
  }
  
	return self;
}

- (id)initWithSearchCriteria:(NSDictionary *)criteria
{
	self = [super init];

  if (self) {
    ASSIGN (searchStr, [criteria objectForKey: @"what"]);
    how = [[criteria objectForKey: @"how"] intValue];
  }
  
	return self;
}

- (IBAction)popUpAction:(id)sender
{
}

- (id)controls
{
  return controlsBox;
}

- (NSString *)moduleName
{
  return NSLocalizedString(@"name", @"");
}

- (BOOL)used
{
  return used;
}

- (void)setInUse:(BOOL)value
{
  used = value;
}

- (int)index
{
  return index;
}

- (void)setIndex:(int)idx
{
  index = idx;
}

- (NSDictionary *)searchCriteria
{
  NSString *str = [textField stringValue];
  
  if ([str length] != 0) {
    NSMutableDictionary *criteria = [NSMutableDictionary dictionary];
    int idx = [popUp indexOfSelectedItem];
  
    [criteria setObject: str forKey: @"what"];
    [criteria setObject: [NSNumber numberWithInt: idx] forKey: @"how"];
    
    return criteria;
  }

  return nil;
}

- (BOOL)checkPath:(NSString *)path
{
  NSString *fname = [path lastPathComponent];

  switch(how) {
    case IS:
      return [fname isEqual: searchStr]; 
      break;
  
    case NOT_CONTAINS:
      return ([fname rangeOfString: searchStr].location == NSNotFound); 
      break;

    case CONTAINS:
      return ([fname rangeOfString: searchStr].location != NSNotFound); 
      break;

    case STARTS:
      return [fname hasPrefix: searchStr];
      break;

    case ENDS:
      return [fname hasSuffix: searchStr];
      break;
  }

  return NO;
}

- (int)compareModule:(id <FinderModulesProtocol>)module
{
  int i1 = [self index];
  int i2 = [module index];

  if (i1 < i2) {
    return NSOrderedAscending;
  } else if (i1 > i2) {
    return NSOrderedDescending;
  } 

  return NSOrderedSame;
}

@end
