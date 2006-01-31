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
#include "Dock.h"
#include "GWViewersManager.h"
#include "Operation.h"
#include "StartAppWin.h"
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
  NSMutableArray *launched = [NSMutableArray array];
  unsigned i;
  
  for (i = 0; i < [launchedApps count]; i++) {
    [launched addObject: [[launchedApps objectAtIndex: i] appInfo]];
  }

  return launched;
}

- (BOOL)openFile:(NSString *)fullPath
          withApplication:(NSString *)appname
            andDeactivate:(BOOL)flag
{
  NSString *appPath, *appName;
  GWLaunchedApp *app;
  id application;
  
  NSLog(@"QUA 1 %@", [fullPath lastPathComponent]);
    
  if (appname == nil) {
    NSString *ext = [fullPath pathExtension];
    
    appname = [ws getBestAppInRole: nil forExtension: ext];
    
    if (appName == nil) {
      NSWarnLog(@"No known applications for file extension '%@'", ext);
      return NO;
    }
  }

  [self applicationName: &appName andPath: &appPath forName: appname];
  
  app = [self launchedAppWithPath: appPath andName: appName];
  
  if (app == nil) {
    NSArray *args = [NSArray arrayWithObjects: @"-GSFilePath", fullPath, nil];
    
    NSLog(@"QUA 2 %@", [fullPath lastPathComponent]);
    
    return [self _launchApplication: appName arguments: args locally: NO];
  
  } else {
    application = [app application];
    
    NSLog(@"QUA 3 %@", [fullPath lastPathComponent]);
    
    if (application == nil) {
      NSArray *args = [NSArray arrayWithObjects: @"-GSFilePath", fullPath, nil];
      
      [self applicationTerminated: app];
      
      NSLog(@"QUA 4 %@", [fullPath lastPathComponent]);
       
      return [self _launchApplication: appName arguments: args locally: NO];

    } else {
      NS_DURING
	      {
	    if (flag == NO) {
	      [application application: NSApp openFileWithoutUI: fullPath];
      } else {
	      [application application: NSApp openFile: fullPath];
	    }
	      }
      NS_HANDLER
	      {
      [self applicationTerminated: app]; 
	    NSWarnLog(@"Failed to contact '%@' to open file", appName);
	    return NO;
	      }
      NS_ENDHANDLER
    }
  }
  
  if (flag) {
    [NSApp deactivate];
  }

  return YES;
}

- (BOOL)launchApplication:(NSString *)appname
		             showIcon:(BOOL)showIcon
	             autolaunch:(BOOL)autolaunch
{
  NSString *appPath, *appName;
  GWLaunchedApp *app;
  id application;
  NSArray	*args = nil;

  [self applicationName: &appName andPath: &appPath forName: appname];
 
  app = [self launchedAppWithPath: appPath andName: appName];
 
  if (app == nil) {
    if (autolaunch) {
	    args = [NSArray arrayWithObjects: @"-autolaunch", @"YES", nil];
	  }
    
    return [self _launchApplication: appName arguments: args locally: NO];
  
  } else {
    application = [app application];
 
    if (application == nil) {
      [self applicationTerminated: app];

      if (autolaunch) {
	      args = [NSArray arrayWithObjects: @"-autolaunch", @"YES", nil];
	    }
             
      return [self _launchApplication: appName arguments: args locally: NO];
    
    } else {
      [application activateIgnoringOtherApps: YES];
    }
  }

  return YES;
}

- (BOOL)openTempFile:(NSString *)fullPath
{
  NSString *ext = [fullPath pathExtension];
  NSString *name = [ws getBestAppInRole: nil forExtension: ext];
  NSString *appPath, *appName;
  GWLaunchedApp *app;
  id application;
  
  if (name == nil) {
    NSWarnLog(@"No known applications for file extension '%@'", ext);
    return NO;
  }
  
  [self applicationName: &appName andPath: &appPath forName: name];  
    
  app = [self launchedAppWithPath: appPath andName: appName];
    
  if (app == nil) {
    NSArray *args = [NSArray arrayWithObjects: @"-GSTempPath", fullPath, nil];
    
    return [self _launchApplication: appName arguments: args locally: NO];
  
  } else {
    application = [app application];
    
    if (application == nil) {
      NSArray *args = [NSArray arrayWithObjects: @"-GSTempPath", fullPath, nil];
    
      [self applicationTerminated: app];
      
      return [self _launchApplication: appName arguments: args locally: NO];
      
    } else {
      NS_DURING
	      {
	    [application application: NSApp openTempFile: fullPath];
	      }
      NS_HANDLER
	      {
      [self applicationTerminated: app];
	    NSWarnLog(@"Failed to contact '%@' to open temp file", appName);
	    return NO;
	      }
      NS_ENDHANDLER
    }
  }    

  [NSApp deactivate];

  return YES;
}

@end


@implementation GWorkspace (Applications)

- (void)applicationName:(NSString **)appName
                andPath:(NSString **)appPath
                forName:(NSString *)name
{
  *appName = [[name lastPathComponent] stringByDeletingPathExtension];
  *appPath = [ws fullPathForApplication: *appName];
}
                
- (BOOL)_launchApplication:(NSString *)appname
		             arguments:(NSArray *)args
                   locally:(BOOL)locally
{
  NSString *appPath, *appName;
  NSTask *task;
  GWLaunchedApp *app;
  NSString *path;
  NSDictionary *userinfo;
  NSString *host;

  [self applicationName: &appName andPath: &appPath forName: appname];

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
  
  app = [GWLaunchedApp appWithApplicationPath: appPath
                              applicationName: appName
                                 launchedTask: task];

  [launchedApps addObject: app];
  
  return YES;    
}

- (void)applicationWillLaunch:(NSNotification *)notif
{  
  [[dtopManager dock] applicationWillLaunch: [notif userInfo]];
}

- (void)applicationDidLaunch:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *name = [info objectForKey: @"NSApplicationName"];
  NSString *path = [info objectForKey: @"NSApplicationPath"];
  NSNumber *ident = [info objectForKey: @"NSApplicationProcessIdentifier"];
  GWLaunchedApp *app = [self launchedAppWithPath: path andName: name];

  if (app) {
    [app setIdentifier: ident];
    
  } else { // if launched by an other process
    app = [GWLaunchedApp appWithApplicationPath: path
                                applicationName: name
                              processIdentifier: ident
                                   checkRunning: NO];
  
    if ([app application] != nil) {
      [launchedApps addObject: app];
    }  
  }

  if ([app application] != nil) {
    [[dtopManager dock] applicationDidLaunch: info];
  }
}








- (void)applicationTerminated:(GWLaunchedApp *)app
{
  [[dtopManager dock] applicationTerminated: [app appInfo]];
  [launchedApps removeObject: app];
}

- (GWLaunchedApp *)launchedAppWithPath:(NSString *)path
                               andName:(NSString *)name
{
  unsigned i;

  for (i = 0; i < [launchedApps count]; i++) {
    GWLaunchedApp *app = [launchedApps objectAtIndex: i];
    
    if (([[app path] isEqual: path]) && ([[app name] isEqual: name])) {
      return app;
    }
  }
  
  return nil;
}

- (NSArray *)storedAppInfo
{
  NSDictionary *runningInfo = nil;
  NSDictionary *apps = nil;
  
  if ([storedAppinfoLock tryLock] == NO) {
    unsigned sleeps = 0;

    if ([[storedAppinfoLock lockDate] timeIntervalSinceNow] < -20.0) {
	    NS_DURING
	      {
	    [storedAppinfoLock breakLock];
	      }
	    NS_HANDLER
	      {
      NSLog(@"Unable to break lock %@ ... %@", storedAppinfoLock, localException);
	      }
	    NS_ENDHANDLER
    }
    
    for (sleeps = 0; sleeps < 10; sleeps++) {
	    if ([storedAppinfoLock tryLock] == YES) {
	      break;
	    }
	    
      sleeps++;
	    [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	  }
    
    if (sleeps >= 10) {
      NSLog(@"Unable to obtain lock %@", storedAppinfoLock);
      return nil;
	  }
  }

  if ([fm isReadableFileAtPath: storedAppinfoPath]) {
    runningInfo = [NSDictionary dictionaryWithContentsOfFile: storedAppinfoPath];
  }
        
  [storedAppinfoLock unlock];
  
  if (runningInfo == nil) {
    return nil;
  }
  
  apps = [runningInfo objectForKey: @"GSLaunched"];
  
  return ((apps != nil) ? [apps allValues] : nil);
}

- (void)updateStoredAppInfoWithLaunchedApps:(NSArray *)apps
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *runningInfo = nil;
  NSDictionary *oldapps = nil;
  NSMutableDictionary *newapps = nil;
  BOOL modified = NO;
  unsigned i;
    
  if ([storedAppinfoLock tryLock] == NO) {
    unsigned sleeps = 0;

    if ([[storedAppinfoLock lockDate] timeIntervalSinceNow] < -20.0) {
	    NS_DURING
	      {
	    [storedAppinfoLock breakLock];
	      }
	    NS_HANDLER
	      {
      NSLog(@"Unable to break lock %@ ... %@", storedAppinfoLock, localException);
	      }
	    NS_ENDHANDLER
    }
    
    for (sleeps = 0; sleeps < 10; sleeps++) {
	    if ([storedAppinfoLock tryLock] == YES) {
	      break;
	    }
	    
      sleeps++;
	    [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	  }
    
    if (sleeps >= 10) {
      NSLog(@"Unable to obtain lock %@", storedAppinfoLock);
      return;
	  }
  }

  if ([fm isReadableFileAtPath: storedAppinfoPath]) {
    runningInfo = [NSMutableDictionary dictionaryWithContentsOfFile: storedAppinfoPath];
  }

  if (runningInfo == nil) {
    runningInfo = [NSMutableDictionary dictionary];
    modified = YES;
  }

  oldapps = [runningInfo objectForKey: @"GSLaunched"];
  
  if (oldapps == nil) {
    newapps = [NSMutableDictionary new];
    modified = YES;
  } else {
    newapps = [oldapps mutableCopy];
  }
  
  for (i = 0; i < [apps count]; i++) {
    GWLaunchedApp *app = [apps objectAtIndex: i];
    NSString *appname = [app name];
    NSDictionary *oldInfo = [newapps objectForKey: appname];

    if ([app isRunning] == NO) {
      if (oldInfo != nil) {
        [newapps removeObjectForKey: appname];
	      modified = YES;
	    }

    } else {
      NSDictionary *info = [app appInfo];

      if ([info isEqual: oldInfo] == NO) {
        [newapps setObject: info forKey: appname];
	      modified = YES;
      }
    }
  }
  
  if (modified) {
    [runningInfo setObject: newapps forKey: @"GSLaunched"];
    [runningInfo writeToFile: storedAppinfoPath atomically: YES];
  }

  RELEASE (newapps);  
  [storedAppinfoLock unlock];
  RELEASE (arp);
}

- (void)checkLastRunningApps
{
  NSArray *oldrunning = [self storedAppInfo];

  if (oldrunning && [oldrunning count]) {
    NSMutableArray *toremove = [NSMutableArray array];
    unsigned i;
    
    for (i = 0; i < [oldrunning count]; i++) {
      NSDictionary *dict = [oldrunning objectAtIndex: i];
      NSString *name = [dict objectForKey: @"NSApplicationName"];
      NSString *path = [dict objectForKey: @"NSApplicationPath"];
      NSNumber *ident = [dict objectForKey: @"NSApplicationProcessIdentifier"];
    
      if (name && path && ident) {
        GWLaunchedApp *app = [GWLaunchedApp appWithApplicationPath: path
                                                   applicationName: name
                                                 processIdentifier: ident
                                                      checkRunning: YES];
        
        if ([app isRunning]) {
          [launchedApps addObject: app];
          [[dtopManager dock] applicationDidLaunch: [app appInfo]];
        } else {
          [toremove addObject: app];
        }
      }
    }
    
    if ([toremove count]) {
      [self updateStoredAppInfoWithLaunchedApps: toremove];
    }
  }
}

@end


@implementation GWLaunchedApp

+ (id)appWithApplicationPath:(NSString *)apath
             applicationName:(NSString *)aname
                launchedTask:(NSTask *)atask
{
  GWLaunchedApp *app = [GWLaunchedApp new];
  
  [app setPath: apath];
  [app setName: aname];
  [app setTask: atask];

  return AUTORELEASE (app);  
}

+ (id)appWithApplicationPath:(NSString *)apath
             applicationName:(NSString *)aname
           processIdentifier:(NSNumber *)ident
                checkRunning:(BOOL)check
{
  GWLaunchedApp *app = [GWLaunchedApp new];
  
  [app setPath: apath];
  [app setName: aname];
  [app setIdentifier: ident];
  
  if (check) {
    [app connectApplication: YES];
  }
  
  return AUTORELEASE (app);  
}

- (void)dealloc
{
  if (application) {
    NSConnection *conn = [(NSDistantObject *)application connectionForProxy];
  
    if (conn && [conn isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: conn];
      DESTROY (application);
    }
  }
  
  TEST_RELEASE (name);
  TEST_RELEASE (path);
  TEST_RELEASE (identifier);
  TEST_RELEASE (task);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    task = nil;
    name = nil;
    path = nil; 
    identifier = nil;
    application = nil;
    
    gw = [GWorkspace gworkspace];
    nc = [NSNotificationCenter defaultCenter];      
  }
  
  return self;
}

/*
- (unsigned)hash
{
  return 0;
//  return [super hash];
}

- (BOOL)isEqual:(id)other
{
  if (other == self) {
    return YES;
  }
  
  if ([other isKindOfClass: [GWLaunchedApp class]]) {
    if (identifier != nil) {
      NSNumber *ident = [(GWLaunchedApp *)other identifier];
      return (ident && [ident isEqual: identifier]);
    }

    if (name != nil) {
      NSString *aname = [(GWLaunchedApp *)other name];
      return (aname && [aname isEqual: name]);
    }
  }
  
  return NO;
}
*/

- (NSDictionary *)appInfo
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  
  if (name != nil) {
    [dict setObject: name forKey: @"NSApplicationName"];
  }
  if (path != nil) {
    [dict setObject: path forKey: @"NSApplicationPath"];
  }
  if (identifier != nil) {
    [dict setObject: identifier forKey: @"NSApplicationProcessIdentifier"];
  }

  return dict;
}

- (void)setTask:(NSTask *)atask
{
  ASSIGN (task, atask);
}

- (NSTask *)task
{
  return task;
}

- (void)setPath:(NSString *)apath
{
  ASSIGN (path, apath);
}

- (NSString *)path
{
  return path;
}

- (void)setName:(NSString *)aname
{
  ASSIGN (name, aname);
}

- (NSString *)name
{
  return name;
}

- (void)setIdentifier:(NSNumber *)ident
{
  ASSIGN (identifier, ident);
}

- (NSNumber *)identifier
{
  return identifier;
}

- (id)application
{
  [self connectApplication: NO];
  return application;
}

- (BOOL)gwlaunched
{
  return (task != nil);
}

- (BOOL)isRunning
{
  return (application != nil);
}

- (void)connectApplication:(BOOL)showProgress
{
  if (application == nil) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *host = [defaults stringForKey: @"NSHost"];

    if (host == nil) {
	    host = @"";
	  } else {
	    NSHost *h = [NSHost hostWithName: host];

      if ([h isEqual: [NSHost currentHost]]) {
	      host = @"";
	    }
	  }
  
    id app = [NSConnection rootProxyForConnectionWithRegisteredName: name
                                                               host: host];

    if (app) {
      NSConnection *conn = [app connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(connectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: conn];
      
      application = app;
      RETAIN (application);
      
	  } else {
      StartAppWin *startAppWin;
      int i;

	    if ((task == nil || [task isRunning] == NO) && (showProgress == NO)) {
   //     if ((task != nil) && (showProgress == NO)) {
   //       [gw applicationTerminated: self];
   //     }
        return;
	    }

      if (showProgress) {
        startAppWin = [gw startAppWin];
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: name
                               operation: NSLocalizedString(@"contacting:", @"")         
                            maxProgValue: 20.0];
      }

      for (i = 1; i <= 20; i++) {
        if (showProgress) {
          [startAppWin updateProgressBy: 1.0];
        }

	      [[NSRunLoop currentRunLoop] runUntilDate:
		                     [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        app = [NSConnection rootProxyForConnectionWithRegisteredName: name
                                                                host: host];                  
        if (app) {
          NSConnection *conn = [app connectionForProxy];

	        [nc addObserver: self
	               selector: @selector(connectionDidDie:)
		                 name: NSConnectionDidDieNotification
		               object: conn];

          application = app;
          RETAIN (application);
          break;
        }
      }

      if (showProgress) {
        [[startAppWin win] close];
      }
      
      if ((application == nil) && (showProgress == NO)) {
        NSRunAlertPanel(NSLocalizedString(@"error", @""),
                      [NSString stringWithFormat: @"%@ %@", 
                          name, NSLocalizedString(@"seems to have hung", @"")], 
		                                      NSLocalizedString(@"OK", @""), 
                                          nil, 
                                          nil);
      }
	  }
  }
}

- (void)connectionDidDie:(NSNotification *)notif
{
  id conn = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: conn];

  NSAssert(conn == [application connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (application);
  application = nil;
  
  if (task && [task isRunning]) {
    [task terminate];
  }
  
  [gw applicationTerminated: self];
}

@end


@implementation NSWorkspace (WorkspaceApplication)

- (id)_workspaceApplication
{
  return [GWorkspace gworkspace];
}

@end


