/*
 *  wopen.m: Implementation of the wopen tool 
 *  for the GNUstep GWorkspace application
 *
 *   Copyright (C) 2002 Enrico Sersale <enrico@imago.ro>
 *
 *   Author: Enrico Sersale
 *   Date: September 2002
 *
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

int main(int argc, char** argv, char **env_c)
{
  NSAutoreleasePool *pool;
  NSArray *arguments = nil;
  NSFileManager *fm = nil;
  NSString *basePath = nil;
  NSString *fpath = nil;
  NSString *fullPath = nil;
  BOOL isDir = NO;
  id gworkspace = nil;
   
  pool = [NSAutoreleasePool new];
  fm = [NSFileManager defaultManager];
  
  if (argc < 2) {
    NSLog(@"no arguments supplied. exiting now.");
    [pool release];
    exit(0);

  } else {    
    basePath = [fm currentDirectoryPath];
    arguments = [[NSProcessInfo processInfo] arguments];
    fpath = [arguments objectAtIndex: 1];
        
    if ([fpath isAbsolutePath] && [fm fileExistsAtPath: fpath isDirectory: &isDir]) {
      fullPath = fpath;
    } else {  
      fullPath = [basePath stringByAppendingPathComponent: fpath];
        
      if ([fm fileExistsAtPath: fullPath isDirectory: &isDir] == NO) {
        NSLog(@"%@ doesn't exist. exiting now.", fpath);
        [pool release];
        exit(0);
      }
    }    

	  gworkspace = [NSConnection rootProxyForConnectionWithRegisteredName: @"GWorkspace"  
								          host: @""];
      
    if (gworkspace == nil) {
      NSLog(@"can't contact GWorkspace. exiting now.", fpath);
      [pool release];
      exit(0);
    } 
    
    [gworkspace application: gworkspace openFile: fullPath];    
  }
  
  [pool release];
  exit(0);
}
