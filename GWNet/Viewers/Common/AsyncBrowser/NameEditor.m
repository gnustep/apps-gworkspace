/* NameEditor.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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
#include "NameEditor.h"
#include "GNUstep.h"

@implementation NameEditor

- (void)dealloc
{
  TEST_RELEASE (paths);
  TEST_RELEASE (name);
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    paths = nil;
    name = nil;
  }
  
  return self;
}

- (void)setName:(NSString *)n paths:(NSArray *)p index:(int)i
{
  if (n) {
    ASSIGN (name, n);
    [super setStringValue: name];
  } else {
    DESTROY (name);
  }
  
  if (p) {
    ASSIGN (paths, p);
  } else {
    DESTROY (paths);
  }
  
  index = i;
}

- (NSString *)name
{
  return name;
}

- (NSArray *)paths 
{
  return paths;
}

- (int)index
{
  return index;
}

- (void)mouseDown:(NSEvent*)theEvent
{
	[self setAlignment: NSLeftTextAlignment];
  [super mouseDown: theEvent];
}

@end
