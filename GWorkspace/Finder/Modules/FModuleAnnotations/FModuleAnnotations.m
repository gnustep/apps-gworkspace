/* FModuleAnnotations.m
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

static NSString *nibName = @"FModuleAnnotations";

@interface FModuleAnnotations : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet id controlsBox;
  IBOutlet id popUp;
  IBOutlet id textField;
  int index;
  BOOL used;

  NSString *contentsStr;
  int how;
  
  id searchtool;
}

- (IBAction)popUpAction:(id)sender; 

@end

@implementation FModuleAnnotations

#define ONE_WORD      0
#define ALL_WORDS     1
#define EXACT_PHRASE  2
#define WITHOUT_WORDS 3

- (void)dealloc
{
  TEST_RELEASE (controlsBox);
  TEST_RELEASE (contentsStr);
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
    
    contentsStr = nil;
    
    [textField setStringValue: @""];

    /* Internationalization */    
    [popUp removeAllItems];
    [popUp insertItemWithTitle: NSLocalizedString(@"with one of the words", @"") 
                       atIndex: ONE_WORD];
    [popUp insertItemWithTitle: NSLocalizedString(@"with all the words", @"") 
                       atIndex: ALL_WORDS];
    [popUp insertItemWithTitle: NSLocalizedString(@"with the exact phrase", @"") 
                       atIndex: EXACT_PHRASE];
    [popUp insertItemWithTitle: NSLocalizedString(@"without the words", @"") 
                       atIndex: WITHOUT_WORDS];
                       
    [popUp selectItemAtIndex: ONE_WORD]; 
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
    ASSIGN (contentsStr, [criteria objectForKey: @"what"]);
    how = [[criteria objectForKey: @"how"] intValue];
    searchtool = tool;
  }
  
	return self;
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
  return NSLocalizedString(@"annotations", @"");
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
  CREATE_AUTORELEASE_POOL(pool);
  NSString *annotations = [searchtool ddbdGetAnnotationsForPath: path];
  NSRange range;
  BOOL found = NO;
  
  if (annotations) {
    if (how == EXACT_PHRASE) {
      range = [annotations rangeOfString: contentsStr
                                 options: NSCaseInsensitiveSearch];
      found = (range.location != NSNotFound);    
    } else {
      NSArray *words = [contentsStr componentsSeparatedByString: @" "];
      unsigned i;

      for (i = 0; i < [words count]; i++) {
        NSString *word = [words objectAtIndex: i];

        if ([word length] && ([word isEqual: @" "] == NO)) {
          range = [annotations rangeOfString: word
                                     options: NSCaseInsensitiveSearch];
          if (how == ONE_WORD) {
            if (range.location != NSNotFound) {
              found = YES;
              break;
            }

          } else if (how == ALL_WORDS) {
            found = YES;
            if (range.location == NSNotFound) {
              found = NO;
              break;
            }

          } else if (how == WITHOUT_WORDS) {
            found = YES;
            if (range.location != NSNotFound) {
              found = NO;
              break;
            }
          }      
        }
      }    
    }
  }
  
  RELEASE (pool);
    
  return found;
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
  return YES;
}

@end

