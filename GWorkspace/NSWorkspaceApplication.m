/* NSWorkspaceApplication.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2006
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
#include <math.h>
#include "GWorkspace.h"
#include "GWFunctions.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"
#include "GWorkspace.h"
#include "GWDesktopManager.h"
#include "GWViewersManager.h"
#include "Operation.h"
#include "GNUstep.h"

@implementation GWorkspace (NSWorkspaceApplication)

- (BOOL)performFileOperation:(NSString *)operation 
                      source:(NSString *)source 
                 destination:(NSString *)destination 
                       files:(NSArray *)files 
                         tag:(int *)tag
{
  NSMutableDictionary *opdict = [NSMutableDictionary dictionary];

  [opdict setObject: operation forKey: @"operation"];
  [opdict setObject: source forKey: @"source"];
  [opdict setObject: destination forKey: @"destination"];
  [opdict setObject: files forKey: @"files"];

  [fileOpsManager performOperation: opdict];
  
  *tag = 0;
  
  return YES;
}





@end
