/* MDModuleAnnotations.m
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2005
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
#include "MDModulesProtocol.h"

@interface MDModuleAnnotations: NSObject <MDModulesProtocol>
{
  NSString *mdtype;
  NSString *extension;
  NSFileManager *fm;
}

@end


@implementation	MDModuleAnnotations

- (void)dealloc
{
  RELEASE (mdtype);            
  RELEASE (extension);   
           
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {   
    ASSIGN (mdtype, @"GSMDItemFinderComment");  
    ASSIGN (extension, @"annotations");  
    fm = [NSFileManager defaultManager];
  }
  
  return self;    
}

- (NSString *)mdtype
{
  return mdtype;
}

- (BOOL)duplicable
{
  return YES;
}

- (void)saveData:(id)mdata withBasePath:(NSString *)bpath
{
  NSString *path = [bpath stringByAppendingPathExtension: extension];
  
  [(NSString *)mdata writeToFile: path atomically: YES];
}

- (id)dataWithBasePath:(NSString *)bpath
{
  NSString *path = [bpath stringByAppendingPathExtension: extension];
  
  if ([fm fileExistsAtPath: path]) {
    return [NSString stringWithContentsOfFile: path];
  }
  
  return nil;
}

@end








