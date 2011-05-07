/* MDKAttribute.m
 *  
 * Copyright (C) 2006-2011 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: December 2006
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
#import "MDKAttribute.h"
#import "MDKAttributeEditor.h"
#import "MDKWindow.h"
#import "MDKQuery.h"

@implementation MDKAttribute

- (void)dealloc
{
  RELEASE (name);
  RELEASE (menuName);
  RELEASE (description);
  RELEASE (typeDescription);
  RELEASE (editorInfo);
  TEST_RELEASE (fsfilter);
  TEST_RELEASE (editor);
  
  [super dealloc];
}

- (id)initWithAttributeInfo:(NSDictionary *)info
                  forWindow:(MDKWindow *)win
{
  self = [super init];

  if (self) {
    id entry;
    
    ASSIGN (name, [info objectForKey: @"attribute_name"]);
    
    entry = NSLocalizedString([info objectForKey: @"menu_name"], @"");
    ASSIGN (menuName, entry);
    
    entry = NSLocalizedString([info objectForKey: @"description"], @"");
    ASSIGN (description, entry);   
     
    type = [[info objectForKey: @"type"] intValue];
         
    entry = [info objectForKey: @"number_type"];    
    numberType = (entry ? [entry intValue] : -1);   
         
    elementsType = [[info objectForKey: @"elements_type"] intValue];        
    
    entry = NSLocalizedString([info objectForKey: @"type_description"], @"");
    ASSIGN (typeDescription, entry);      
    
    searchable = [[info objectForKey: @"searchable"] boolValue];    
    
    fsattribute = [[info objectForKey: @"fsattribute"] boolValue];        
    fsfilter = fsattribute ? [info objectForKey: @"fsfilter"] : nil;
    TEST_RETAIN (fsfilter);
    
    ASSIGN (editorInfo, [info objectForKey: @"editor"]);
    
    window = win;
    editor = nil;    
    inuse = NO;
  }
  
  return self;
}

- (NSUInteger)hash
{
  return [name hash];
}

- (BOOL)isEqual:(id)other
{
  if (other == self) {
    return YES;
  }
  if ([other isKindOfClass: [MDKAttribute class]]) {
    return [name isEqual: [other name]];
  }
  return NO;
}

- (BOOL)inUse
{
  return inuse;
}

- (void)setInUse:(BOOL)value
{
  inuse = value;
}

- (NSString *)name
{
  return name;
}

- (NSString *)menuName
{
  return menuName;
}

- (NSString *)description
{
  return description;
}

- (int)type
{
  return type;
}

- (int)numberType
{
  return numberType;
}

- (int)elementsType
{
  return elementsType;
}

- (NSString *)typeDescription
{
  return typeDescription;
}

- (BOOL)isSearchable
{
  return searchable;
}

- (BOOL)isFsattribute
{
  return fsattribute;
}

- (NSString *)fsFilterClassName
{
  return fsfilter;
}

- (NSDictionary *)editorInfo
{
  return editorInfo;
}

- (id)editor
{
  if (editor == nil) {
    ASSIGN (editor, [MDKAttributeEditor editorForAttribute: self 
                                                  inWindow: window]);
  }

  return editor;
}

@end

