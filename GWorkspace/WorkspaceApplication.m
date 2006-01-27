/* WorkspaceApplication.m
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

@implementation GWorkspace (WorkspaceApplication)

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

- (BOOL)selectFile:(NSString *)fullPath
											inFileViewerRootedAtPath:(NSString *)rootFullpath
{
  FSNode *node = [FSNode nodeWithPath: fullPath];
  
  if (node && [node isValid]) {
    FSNode *base;
  
    if ((rootFullpath == nil) || ([rootFullpath length] == 0)) {
      base = [FSNode nodeWithPath: path_separator()];
    } else {
      base = [FSNode nodeWithPath: rootFullpath];
    }
  
    if (base && [base isValid]) {
      if (([base isDirectory] == NO) || [base isPackage]) {
        return NO;
      }
    
      [vwrsManager selectRepOfNode: node inViewerWithBaseNode: base];
      return YES;
    }
  }
   
  return NO;
}

- (int)extendPowerOffBy:(int)requested
{
  return 0;
}

- (NSArray *)launchedApplications
{
  return [dtopManager launchedApplications];
}

- (BOOL)_launchApplication:(NSString *)appName
		             arguments:(NSArray *)args
{
  NSTask *task;
  NSString *path;
  NSDictionary *userinfo;
  NSString *host;

  path = [ws locateApplicationBinary: appName];
  
  if (path == nil) {
	  return NO;
	}

  // Try to ensure that apps we launch display in this workspace
  // ie they have the same -NSHost specification.
  host = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSHost"];
      
  if (host != nil) {
    NSHost *h = [NSHost hostWithName: host];
    
    if ([h isEqual: [NSHost currentHost]] == NO) {
      if ([args containsObject: @"-NSHost"] == NO) {
		    NSMutableArray *a;

		    if (args == nil) {
		      a = [NSMutableArray arrayWithCapacity: 2];
		    } else {
		      a = AUTORELEASE ([args mutableCopy]);
		    }
		    
        [a insertObject: @"-NSHost" atIndex: 0];
		    [a insertObject: host atIndex: 1];
		    args = a;
		  }
    }
	}
  
  // App being launched, send
  // NSWorkspaceWillLaunchApplicationNotification
  userinfo = [NSDictionary dictionaryWithObjectsAndKeys:
	              [[appName lastPathComponent] stringByDeletingPathExtension], 
			           @"NSApplicationName",
	               appName, 
                 @"NSApplicationPath",
	               nil];
                 
  [wsnc postNotificationName: NSWorkspaceWillLaunchApplicationNotification
	                    object: ws
	                  userInfo: userinfo];

  task = [NSTask launchedTaskWithLaunchPath: path arguments: args];
  
  if (task == nil) {
	  return NO;
	}

  // The NSWorkspaceDidLaunchApplicationNotification will be
  // sent by the started application itself.
  [launchedApps setObject: task forKey: appName];
  
  return YES;    
}

- (id)_connectApplication:(NSString *)appName
{
  NSString *host;
  NSString *port;
  NSDate *when = nil;
  id app = nil;

  while (app == nil) {
    host = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSHost"];
    
    if (host == nil) {
	    host = @"";
	  } else {
	    NSHost *h;

	    h = [NSHost hostWithName: host];
	    
      if ([h isEqual: [NSHost currentHost]] == YES) {
	      host = @"";
	    }
	  }
    
    port = [[appName lastPathComponent] stringByDeletingPathExtension];
      /*
       *	Try to contact a running application.
       */
    NS_DURING
	    {
	  app = [NSConnection rootProxyForConnectionWithRegisteredName: port host: host];
	    }
    NS_HANDLER
	    {
	    /* Fatal error in DO	*/
	  app = nil;
	    }
    NS_ENDHANDLER

    if (app == nil) {
	    NSTask *task = [launchedApps objectForKey: appName];
	    NSDate *limit;

	    if (task == nil || [task isRunning] == NO) {
	      if (task != nil) { // Not running
		      [launchedApps removeObjectForKey: appName];
		    }
	      
        break;  // Need to launch the app
	    }

	    if (when == nil) {
	      when = [[NSDate alloc] init];
      } else if ([when timeIntervalSinceNow] < -5.0) {
	      int result;

	      DESTROY (when);
        
        result = NSRunAlertPanel(appName,
                      [NSString stringWithFormat: @"%@ %@", 
                            [appName lastPathComponent],
                            NSLocalizedString(@"seems to have hung", @"")], 
		                  NSLocalizedString(@"Continue", @""), 
                      NSLocalizedString(@"Terminate", @""), 
                      NSLocalizedString(@"Wait", @""));

	      if (result == NSAlertDefaultReturn) {
		      break;		// Finished without app
		    } else if (result == NSAlertOtherReturn) {
		      // Continue to wait for app startup.
		    } else {
		      [task terminate];
		      [launchedApps removeObjectForKey: appName];
		      break;		// Terminate hung app
		    }
	    }

	    // Give it another 0.5 of a second to start up.
	    limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 0.5];
	    [[NSRunLoop currentRunLoop] runUntilDate: limit];
	    RELEASE(limit);
	  }
  }
  
  TEST_RELEASE (when);
  
  return app;
}

- (BOOL)openFile:(NSString *)fullPath
          withApplication:(NSString *)appName
            andDeactivate:(BOOL)flag
{
  id app;

  if (appName == nil) {
    NSString *ext = [fullPath pathExtension];
    
    appName = [ws getBestAppInRole: nil forExtension: ext];
    
    if (appName == nil) {
      NSWarnLog(@"No known applications for file extension '%@'", ext);
      return NO;
    }
  }

  app = [self _connectApplication: appName];
  
  if (app == nil) {
    NSArray *args = [NSArray arrayWithObjects: @"-GSFilePath", fullPath, nil];
    
    return [self _launchApplication: appName arguments: args];
  
  } else {
    NS_DURING
	    {
	  if (flag == NO) {
	    [app application: NSApp openFileWithoutUI: fullPath];
    } else {
	    [app application: NSApp openFile: fullPath];
	  }
	    }
    NS_HANDLER
	    {
	  NSWarnLog(@"Failed to contact '%@' to open file", appName);
	  return NO;
	    }
    NS_ENDHANDLER
  }

  if (flag) {
    [NSApp deactivate];
  }

  return YES;
}

- (BOOL)launchApplication:(NSString *)appName
		             showIcon:(BOOL)showIcon
	             autolaunch:(BOOL)autolaunch
{
  id app = [self _connectApplication: appName];
  
  if (app == nil) {
    NSArray	*args = nil;

    if (autolaunch) {
	    args = [NSArray arrayWithObjects: @"-autolaunch", @"YES", nil];
	  }
    
    return [self _launchApplication: appName arguments: args];

  } else {
    [app activateIgnoringOtherApps: YES];
  }

  return YES;
}

- (BOOL)openTempFile:(NSString *)fullPath
{
  NSString *ext = [fullPath pathExtension];
  NSString *appName = [ws getBestAppInRole: nil forExtension: ext];
  id app;
  
  if (appName == nil) {
    NSWarnLog(@"No known applications for file extension '%@'", ext);
    return NO;
  }
    
  app = [self _connectApplication: appName];
  
  if (app == nil) {
    NSArray *args = [NSArray arrayWithObjects: @"-GSTempPath", fullPath, nil];
    
    return [self _launchApplication: appName arguments: args];
  
  } else {
    NS_DURING
	    {
	  [app application: NSApp openTempFile: fullPath];
	    }
    NS_HANDLER
	    {
	  NSWarnLog(@"Failed to contact '%@' to open temp file", appName);
	  return NO;
	    }
    NS_ENDHANDLER
  }

  [NSApp deactivate];

  return YES;
}

@end



