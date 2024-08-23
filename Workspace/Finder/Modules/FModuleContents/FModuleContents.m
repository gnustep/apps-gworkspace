/* FModuleContents.m
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

#define MAXFSIZE 600000

static NSString *nibName = @"FModuleContents";

@interface FModuleContents : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet id controlsBox;
  IBOutlet id label;
  IBOutlet id textField;
  NSInteger index;
  BOOL used;

  NSString *searchStr;
  const char *searchPtr;
  NSFileManager *fm;
}

@end

@implementation FModuleContents

- (void)dealloc
{
  RELEASE (controlsBox);
  RELEASE (searchStr);
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
    [label setStringValue: NSLocalizedString(@"includes", @"")];
  }
  
  return self;
}

- (id)initWithSearchCriteria:(NSDictionary *)criteria
                  searchTool:(id)tool
{
  self = [super init];

  if (self) {
    ASSIGN (searchStr, [criteria objectForKey: @"what"]);
    searchPtr = [searchStr UTF8String];
    fm = [NSFileManager defaultManager];
  }
  
	return self;
}

- (void)setControlsState:(NSDictionary *)info
{
  NSString *str = [info objectForKey: @"what"];
  
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
    return [NSDictionary dictionaryWithObject: str forKey: @"what"];
  }

  return nil;
}

- (BOOL)checkPath:(NSString *)path 
   withAttributes:(NSDictionary *)attributes
{
  BOOL contains = NO;
  
  if (([attributes fileSize] < MAXFSIZE) 
            && ([attributes fileType] == NSFileTypeRegular)) {
    CREATE_AUTORELEASE_POOL(pool);
    NSData *contents = [NSData dataWithContentsOfFile: path];
    unsigned length = ((contents != nil) ? [contents length] : 0);
    
    if (length) {
      const char *bytesStr = (const char *)[contents bytes];
      unsigned testlen = ((length < 256) ? length : 256);
      unsigned i;
      
      for (i = 0; i < testlen; i++) {
        if (bytesStr[i] == 0x00) {
          RELEASE (pool);
          return NO; 
        } 
      }
    
      contains = (strstr(bytesStr, searchPtr) != NULL);
    }
    
    RELEASE (pool);
  }
  
  return contains;
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
  return YES;
}

- (BOOL)metadataModule
{
  return NO;
}

@end

