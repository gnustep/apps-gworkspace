/* GWLib.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GWLib.h"
#include "GWProtocol.h"
#include "GNUstep.h"
#ifndef GNUSTEP 
  #include "OSXCompatibility.h"
#endif

static id gwapp = nil;
static NSString *gwName = @"GWorkspace";

#define CHECKGW \
if (gwapp == nil) \
gwapp = (id <GWProtocol>)[[GWLib class] gworkspaceApplication]; \
if (gwapp == nil) return

#define CHECKGW_RET(x) \
if (gwapp == nil) \
gwapp = (id <GWProtocol>)[[GWLib class] gworkspaceApplication]; \
if (gwapp == nil) return x

@implementation GWLib

+ (id)gworkspaceApplication
{
	if (gwapp == nil) {
    NSString *host;
    NSString *port;
    NSDate *when = nil;
    BOOL done = NO;

    while (done == NO) {
      host = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSHost"];
      
      if (host == nil) {
	      host = @"";        
	    } else {
	      NSHost *h = [NSHost hostWithName: host];
        
	      if ([h isEqual: [NSHost currentHost]]) {
	        host = @"";
	      }
	    }
      
      port = gwName;

      NS_DURING
        {
	    gwapp = (id <GWProtocol>)[NSConnection rootProxyForConnectionWithRegisteredName: port host: host];
	    RETAIN (gwapp);  
        }
      NS_HANDLER
	      {
	    gwapp = nil;
	      }
      NS_ENDHANDLER
      
      if (gwapp) {
        done = YES;
      }
            
      if (gwapp == nil) {
	      [[NSWorkspace sharedWorkspace] launchApplication: gwName];
        
	      if (when == nil) {
		      when = [[NSDate alloc] init];
		      done = NO;
		    } else if ([when timeIntervalSinceNow] > 5.0) {
		      int result;

		      DESTROY (when);
		      result = NSRunAlertPanel(gwName,
		                @"Application seems to have hung",
		                      @"Continue", @"Terminate", @"Wait");

		      if (result == NSAlertDefaultReturn) {
		        done = YES;
		      } else if (result == NSAlertOtherReturn) {
		        done = NO;
		      } else {
		        done = YES;
		      }
		    }

	      if (done == NO) {
		      NSDate *limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 0.5];
		      [[NSRunLoop currentRunLoop] runUntilDate: limit];
		      RELEASE(limit);
		    }
	    }
    }
  
    TEST_RELEASE (when);
 	}	
  
  return gwapp;
}

+ (BOOL)selectFile:(NSString *)fullPath
							inFileViewerRootedAtPath:(NSString *)rootFullpath
{
  CHECKGW_RET(NO);
  return [gwapp selectFile: fullPath inFileViewerRootedAtPath: rootFullpath];
  return NO;
}

+ (oneway void)rootViewerSelectFiles:(NSArray *)paths
{
  CHECKGW;
  [gwapp rootViewerSelectFiles: paths];
}

+ (oneway void)openSelectedPaths:(NSArray *)paths
{
  CHECKGW;
  [gwapp openSelectedPaths: paths];
}

+ (oneway void)addWatcherForPath:(NSString *)path
{
  CHECKGW;
  [gwapp addWatcherForPath: path];
}

+ (oneway void)removeWatcherForPath:(NSString *)path
{
  CHECKGW;
  [gwapp removeWatcherForPath: path];
}

+ (BOOL)isPakageAtPath:(NSString *)path
{
  CHECKGW_RET(NO);
  return [gwapp isPakageAtPath: path];
  return NO;
}

+ (oneway void)performFileOperationWithDictionary:(NSDictionary *)dict
{
  CHECKGW;
  [gwapp performFileOperationWithDictionary: dict];
}

+ (oneway void)performServiceWithName:(NSString *)sname 
                           pasteboard:(NSPasteboard *)pboard
{
  NSPerformService(sname, pboard);
}

+ (NSString *)trashPath
{
  CHECKGW_RET(nil);
  return [gwapp trashPath];
  return nil;
}

@end
