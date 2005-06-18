/* FModuleOwner.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "FinderModulesProtocol.h"

static NSString *nibName = @"FModuleOwner";

@interface FModuleOwner : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet id controlsBox;
  IBOutlet id popUp;
  IBOutlet id textField;
  int index;
  BOOL used;

  NSFileManager *fm;
  NSString *owner;
  int how;
}

- (IBAction)popUpAction:(id)sender; 

@end

@implementation FModuleOwner

#define IS     0               
#define IS_NOT 1         

- (void)dealloc
{
  TEST_RELEASE (controlsBox);
  TEST_RELEASE (owner);
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
    
    owner = nil;
    
    [textField setStringValue: @""];

    /* Internationalization */    
    [popUp removeAllItems];
    [popUp insertItemWithTitle: NSLocalizedString(@"is", @"") atIndex: 0];
    [popUp insertItemWithTitle: NSLocalizedString(@"is not", @"") atIndex: 2];
    [popUp selectItemAtIndex: 0]; 
  }
  
	return self;
}

- (id)initWithSearchCriteria:(NSDictionary *)criteria
                  searchTool:(id)tool
{
	self = [super init];

  if (self) {
    ASSIGN (owner, [criteria objectForKey: @"what"]);
    how = [[criteria objectForKey: @"how"] intValue];
    fm = [NSFileManager defaultManager];
  }
  
	return self;
}

- (IBAction)popUpAction:(id)sender
{
}

- (void)setControlsState:(NSDictionary *)info
{
  NSNumber *num = [info objectForKey: @"how"];
  NSString *str = [info objectForKey: @"what"];

  if (num) {
    [popUp selectItemAtIndex: [num intValue]];
  }
  
  if (str && [str length]) {
    [textField setStringValue: str];
  }    
}

- (id)controls
{
  return controlsBox;
}

- (NSString *)moduleName
{
  return NSLocalizedString(@"owner", @"");
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
   withAttributes:(NSDictionary *)attributes
{
  BOOL found = [owner isEqual: [attributes fileOwnerAccountName]];
  return (how == IS) ? found : !found;
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

- (BOOL)reliesOnModDate
{
  return NO;
}

- (BOOL)metadataModule
{
  return NO;
}

@end















