/* FModuleKind.m
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

static NSString *nibName = @"FModuleKind";

@interface FModuleKind : NSObject <FinderModulesProtocol>
{  
  IBOutlet id win;
  IBOutlet id controlsBox;
  IBOutlet id isPopUp;
  IBOutlet id typePopUp;
  NSInteger index;
  BOOL used;

  NSFileManager *fm;
  NSWorkspace *ws;
  NSInteger kind;
  NSInteger how;
}

- (IBAction)popUpAction:(id)sender; 

@end

@implementation FModuleKind

#define IS     0               
#define IS_NOT 1         

#define PLAIN 0         
#define DIR   1         
#define EXEC  2       
#define LINK  3        
#define APP   4        

- (void)dealloc
{
  RELEASE (controlsBox);
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
    
    /* Internationalization */    
    [isPopUp removeAllItems];
    [isPopUp insertItemWithTitle: NSLocalizedString(@"is", @"") atIndex: 0];
    [isPopUp insertItemWithTitle: NSLocalizedString(@"is not", @"") atIndex: 1];
    [isPopUp selectItemAtIndex: 0]; 

    [typePopUp removeAllItems];
    [typePopUp insertItemWithTitle: NSLocalizedString(@"plain file", @"") atIndex: 0];
    [typePopUp insertItemWithTitle: NSLocalizedString(@"folder", @"") atIndex: 1];
    [typePopUp insertItemWithTitle: NSLocalizedString(@"tool", @"") atIndex: 2];
    [typePopUp insertItemWithTitle: NSLocalizedString(@"symbolic link", @"") atIndex: 3];
    [typePopUp insertItemWithTitle: NSLocalizedString(@"application", @"") atIndex: 4];
    [typePopUp selectItemAtIndex: 0]; 
  }
  
	return self;
}

- (id)initWithSearchCriteria:(NSDictionary *)criteria
                  searchTool:(id)tool
{
	self = [super init];

  if (self) {
    kind = [[criteria objectForKey: @"what"] integerValue];
    how = [[criteria objectForKey: @"how"] integerValue];
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
  }
  
	return self;
}

- (IBAction)popUpAction:(id)sender
{
}

- (void)setControlsState:(NSDictionary *)info
{
  NSNumber *num = [info objectForKey: @"how"];
  
  if (num) {
    [isPopUp selectItemAtIndex: [num intValue]];
  }
  
  num = [info objectForKey: @"what"];  
  
  if (num) {
    [typePopUp selectItemAtIndex: [num intValue]];
  }  
}

- (id)controls
{
  return controlsBox;
}

- (NSString *)moduleName
{
  return NSLocalizedString(@"type", @"");
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
  NSInteger is = [isPopUp indexOfSelectedItem];
  NSInteger type = [typePopUp indexOfSelectedItem];
  NSMutableDictionary *criteria = [NSMutableDictionary dictionary];

  [criteria setObject: [NSNumber numberWithInteger: is] forKey: @"how"];
  [criteria setObject: [NSNumber numberWithInteger: type] forKey: @"what"];

  return criteria;
}

#define PosixExecutePermission	(0111)

- (BOOL)checkPath:(NSString *)path 
   withAttributes:(NSDictionary *)attributes
{
  NSString *fileType = [attributes fileType];
  BOOL found = NO;
  
  if (fileType == NSFileTypeRegular) {
    if ([attributes filePosixPermissions] & PosixExecutePermission) {  
      found = (kind == EXEC);
    } else {
      found = (kind == PLAIN);
    }
  } else if (fileType == NSFileTypeDirectory) {
    CREATE_AUTORELEASE_POOL(arp);
	  NSString *defApp = nil, *type = nil;
		
	  [ws getInfoForFile: path application: &defApp type: &type];  
    
	  if (type == NSApplicationFileType) {
      found = (kind == APP);
	  } else if (type == NSPlainFileType) {
      found = (kind == PLAIN);  
    } else {
      found = (kind == DIR);  
	  }
    RELEASE (arp);
  } else if (fileType == NSFileTypeSymbolicLink) {
    found = (kind == LINK);  
  } else {
    found = (kind == PLAIN);  
  }

  return (how == IS) ? found : !found;
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


















