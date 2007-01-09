/* MDKAttribute.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
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

#ifndef MDK_ATTRIBUTE_H
#define MDK_ATTRIBUTE_H

#include <Foundation/Foundation.h>

@class MDKWindow;

@interface MDKAttribute : NSObject 
{
  NSString *name;
  NSString *menuName;
  NSString *description;
  
  int type;
  int numberType;
  int elementsType;
  NSString *typeDescription;
  
  BOOL searchable;
  BOOL fsattribute;  
  NSString *fsfilter;
  
  NSDictionary *editorInfo;  
  BOOL inuse;  
  id editor;
  id window;
}

- (id)initWithAttributeInfo:(NSDictionary *)info
                  forWindow:(MDKWindow *)win;

- (BOOL)inUse;

- (void)setInUse:(BOOL)value;

- (NSString *)name;

- (NSString *)menuName;

- (NSString *)description;

- (int)type;

- (int)numberType;

- (int)elementsType;

- (NSString *)typeDescription;

- (BOOL)isSearchable;

- (BOOL)isFsattribute;

- (NSString *)fsFilterClassName;

- (NSDictionary *)editorInfo;

- (id)editor;

@end

#endif // MDK_ATTRIBUTE_H

