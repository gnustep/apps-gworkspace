/* FModuleContents.m
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

static NSString *nibName = @"FModuleContents";

@interface FModuleContents : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet id controlsBox;
  IBOutlet id label;
  IBOutlet id textField;
  int index;
  BOOL used;

  NSString *contentsStr;
  NSFileManager *fm;
}

@end

@implementation FModuleContents

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
    [label setStringValue: NSLocalizedString(@"includes", @"")];
  }
  
	return self;
}

- (id)initWithSearchCriteria:(NSDictionary *)criteria
{
	self = [super init];

  if (self) {
    ASSIGN (contentsStr, [criteria objectForKey: @"what"]);
    fm = [NSFileManager defaultManager];
  }
  
	return self;
}

- (id)controls
{
  return controlsBox;
}

- (NSString *)moduleName
{
  return NSLocalizedString(@"contents", @"");
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
    return [NSDictionary dictionaryWithObject: str forKey: @"what"];
  }

  return nil;
}

- (BOOL)checkPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes) {
    NSString *fileType = [attributes fileType];

    if (fileType == NSFileTypeRegular) {
      NSData *contents = [NSData dataWithContentsOfFile: path];
      const char *bytesStr = (const char *)[contents bytes];
    
      return (strstr(bytesStr, [contentsStr lossyCString]) != NULL);
    }
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

