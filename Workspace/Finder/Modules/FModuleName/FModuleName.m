/* FModuleName.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FinderModulesProtocol.h"

static NSString *nibName = @"FModuleName";

@interface FModuleName : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet id controlsBox;
  IBOutlet id popUp;
  IBOutlet id textField;
  NSInteger index;
  BOOL used;
  
  NSString *searchStr;
  NSInteger how;
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
  RELEASE (controlsBox);
  RELEASE (searchStr);
  [super dealloc];
}

- (id)initInterface
{
  self = [super init];

  if (self)
    {
      if ([NSBundle loadNibNamed: nibName owner: self] == NO)
	{
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
      [popUp insertItemWithTitle: NSLocalizedString(@"contains not", @"") 
			 atIndex: NOT_CONTAINS];
      [popUp insertItemWithTitle: NSLocalizedString(@"starts with", @"") 
			 atIndex: STARTS];
      [popUp insertItemWithTitle: NSLocalizedString(@"ends with", @"") 
			 atIndex: ENDS];
                       
      [popUp selectItemAtIndex: CONTAINS]; 
    }
  
  return self;
}

- (IBAction)popUpAction:(id)sender
{
}

- (id)initWithSearchCriteria:(NSDictionary *)criteria
                  searchTool:(id)tool
{
  self = [super init];

  if (self) {
    ASSIGN (searchStr, [criteria objectForKey: @"what"]);
    how = [[criteria objectForKey: @"how"] integerValue];
  }
  
  return self;
}

- (void)setControlsState:(NSDictionary *)info
{
  NSNumber *num = [info objectForKey: @"how"];
  NSString *str = [info objectForKey: @"what"];

  if (num) {
    [popUp selectItemAtIndex: [num integerValue]];
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

- (NSInteger)index
{
  return index;
}

- (void)setIndex:(NSInteger)idx
{
  index = idx;
}

- (NSDictionary *)searchCriteria
{
  NSString *str = [textField stringValue];
  
  if ([str length] != 0) {
    NSMutableDictionary *criteria = [NSMutableDictionary dictionary];
    NSInteger idx = [popUp indexOfSelectedItem];
  
    [criteria setObject: str forKey: @"what"];
    [criteria setObject: [NSNumber numberWithInteger: idx] forKey: @"how"];
    
    return criteria;
  }

  return nil;
}

- (BOOL)checkPath:(NSString *)path 
   withAttributes:(NSDictionary *)attributes
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString *fname = [path lastPathComponent];
  BOOL pathok = NO;
  
  switch(how) {
    case IS:
      pathok = [fname isEqual: searchStr]; 
      break;
  
    case NOT_CONTAINS:
      pathok = ([fname rangeOfString: searchStr].location == NSNotFound); 
      break;

    case CONTAINS:
      pathok = ([fname rangeOfString: searchStr].location != NSNotFound); 
      break;

    case STARTS:
      pathok = [fname hasPrefix: searchStr];
      break;

    case ENDS:
      pathok = [fname hasSuffix: searchStr];
      break;
  }
  
  RELEASE (pool);
  
  return pathok;
}

- (NSComparisonResult)compareModule:(id <FinderModulesProtocol>)module
{
  NSInteger i1 = [self index];
  NSInteger i2 = [module index];

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
