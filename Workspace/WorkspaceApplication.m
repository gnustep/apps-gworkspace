/* WorkspaceApplication.m
 *  
 * Copyright (C) 2006-2016 Free Software Foundation, Inc.
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "GWorkspace.h"
#import "GWFunctions.h"
#import "FSNodeRep.h"
#import "FSNFunctions.h"
#import "GWorkspace.h"
#import "GWDesktopManager.h"
#import "Dock.h"
#import "GWViewersManager.h"
#import "Operation.h"
#import "StartAppWin.h"

@implementation GWorkspace (WorkspaceApplication)

- (BOOL)performFileOperation:(NSString *)operation 
                      source:(NSString *)source 
                 destination:(NSString *)destination 
                       files:(NSArray *)files 
                         tag:(NSInteger *)tag
{
  if (loggingout == NO)
    {
      NSMutableDictionary *opdict = [NSMutableDictionary dictionary];

      if (operation != nil)
	[opdict setObject: operation forKey: @"operation"];
      else
	NSLog(@"performFileOperation: operation can't be nil");
 
      if (operation != nil)
	[opdict setObject: source forKey: @"source"];
      else
	NSLog(@"performFileOperation: source is nil");

      if (destination == nil && [operation isEqualToString:NSWorkspaceRecycleOperation])
	destination = [self trashPath];
      if (destination != nil)
	[opdict setObject: destination forKey: @"destination"];

      if (files != nil)
	[opdict setObject: files forKey: @"files"];

      [fileOpsManager performOperation: opdict];

      *tag = 0;
    
      return YES;
  
    }
  else
    {
      NSRunAlertPanel(nil, 
		      NSLocalizedString(@"GWorkspace is logging out!", @""),
		      NSLocalizedString(@"Ok", @""), 
		      nil, 
		      nil);  
    }
  
  return NO;
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
  int req = (int)(requested / 1000);
  int ret;
  
  if (req > 0) {
    ret = (req < maxLogoutDelay) ? req : maxLogoutDelay;
  } else {
    ret = 0;
  }
  
  logoutDelay += ret;

  if (logoutTimer && [logoutTimer isValid]) {
    NSTimeInterval fireInterval = ([[logoutTimer fireDate] timeIntervalSinceNow] + ret);
    [logoutTimer setFireDate: [NSDate dateWithTimeIntervalSinceNow: fireInterval]];
  }
  
  return (ret * 1000);
}

- (NSArray *)launchedApplications
{
  NSMutableArray *launched = [NSMutableArray array];
  NSUInteger i;
  
  for (i = 0; i < [launchedApps count]; i++)
    {
      [launched addObject: [[launchedApps objectAtIndex: i] appInfo]];
    }

  return [launched makeImmutableCopyOnFail: NO];
}

- (NSDictionary *)activeApplication
{
  if (activeApplication != nil) {
    return [activeApplication appInfo];
  }
  return nil;
}

- (BOOL)openFile:(NSString *)fullPath
          withApplication:(NSString *)appname
            andDeactivate:(BOOL)flag
{
  NSString *appPath, *appName;
  GWLaunchedApp *app;
  id application;

  if (loggingout) {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"GWorkspace is logging out!", @""),
					        NSLocalizedString(@"Ok", @""), 
                  nil, 
                  nil);  
    return NO;
  }
      
  if (appname == nil) {
    NSString *ext = [[fullPath pathExtension] lowercaseString];
    
    appname = [ws getBestAppInRole: nil forExtension: ext];
    
    if (appname == nil) {
      appname = defEditor;      
    }
  }

  [self applicationName: &appName andPath: &appPath forName: appname];
  
  app = [self launchedAppWithPath: appPath andName: appName];
  
  if (app == nil) {
    NSArray *args = [NSArray arrayWithObjects: @"-GSFilePath", fullPath, nil];
    
    return [self launchApplication: appname arguments: args];
  
  } else {  
    NSDate *delay = [NSDate dateWithTimeIntervalSinceNow: 0.1];
    
    /*
    * If we are opening many files together and our app is a wrapper,
    * we must wait a little for the last launched task to terminate.
    * Else we'd end waiting two seconds in -connectApplication.
    */
    [[NSRunLoop currentRunLoop] runUntilDate: delay];
    
    application = [app application];
    
    if (application == nil) {
      NSArray *args = [NSArray arrayWithObjects: @"-GSFilePath", fullPath, nil];
      
      [self applicationTerminated: app];
      
      return [self launchApplication: appname arguments: args];

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

  if (loggingout) {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"GWorkspace is logging out!", @""),
					        NSLocalizedString(@"Ok", @""), 
                  nil, 
                  nil);  
    return NO;
  }

  [self applicationName: &appName andPath: &appPath forName: appname];
 
  app = [self launchedAppWithPath: appPath andName: appName];
 
  if (app == nil) {
    if (autolaunch) {
	    args = [NSArray arrayWithObjects: @"-autolaunch", @"YES", nil];
	  }
    
    return [self launchApplication: appname arguments: args];
  
  } else {
    application = [app application];
 
    if (application == nil) {
      [self applicationTerminated: app];

      if (autolaunch) {
	      args = [NSArray arrayWithObjects: @"-autolaunch", @"YES", nil];
	    }
             
      return [self launchApplication: appname arguments: args];
    
    } else {
      [application activateIgnoringOtherApps: YES];
    }
  }

  return YES;
}

- (BOOL)openTempFile:(NSString *)fullPath
{
  NSString *ext = [[fullPath pathExtension] lowercaseString];
  NSString *name = [ws getBestAppInRole: nil forExtension: ext];
  NSString *appPath, *appName;
  GWLaunchedApp *app;
  id application;

  if (loggingout) {
    NSRunAlertPanel(nil, 
                  NSLocalizedString(@"GWorkspace is logging out!", @""),
					        NSLocalizedString(@"Ok", @""), 
                  nil, 
                  nil);  
    return NO;
  }
  
  if (name == nil) {
    NSWarnLog(@"No known applications for file extension '%@'", ext);
    return NO;
  }
  
  [self applicationName: &appName andPath: &appPath forName: name];  
    
  app = [self launchedAppWithPath: appPath andName: appName];
    
  if (app == nil) {
    NSArray *args = [NSArray arrayWithObjects: @"-GSTempPath", fullPath, nil];
    
    return [self launchApplication: name arguments: args];
  
  } else {
    application = [app application];
    
    if (application == nil) {
      NSArray *args = [NSArray arrayWithObjects: @"-GSTempPath", fullPath, nil];
    
      [self applicationTerminated: app];
      
      return [self launchApplication: name arguments: args];
      
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

- (void)initializeWorkspace
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  autoLogoutDelay = [defaults integerForKey: @"GSAutoLogoutDelay"];
  
  if (autoLogoutDelay == 0) {
    autoLogoutDelay = 120;
  }

  maxLogoutDelay = [defaults integerForKey: @"GSMaxLogoutDelay"];
  
  if (autoLogoutDelay == 0) {
    maxLogoutDelay = 30;
  }  

  wsnc = [ws notificationCenter];
  
  [wsnc addObserver: self
	         selector: @selector(appWillLaunch:)
		           name: NSWorkspaceWillLaunchApplicationNotification
		         object: nil];

  [wsnc addObserver: self
	         selector: @selector(appDidLaunch:)
		           name: NSWorkspaceDidLaunchApplicationNotification
		         object: nil];    

  [wsnc addObserver: self
	         selector: @selector(appDidTerminate:)
		           name: NSWorkspaceDidTerminateApplicationNotification
		         object: nil];    

  [wsnc addObserver: self
	         selector: @selector(appDidBecomeActive:)
		           name: NSApplicationDidBecomeActiveNotification
		         object: nil];

  [wsnc addObserver: self
	         selector: @selector(appDidResignActive:)
		           name: NSApplicationDidResignActiveNotification
		         object: nil];    

  [wsnc addObserver: self
	         selector: @selector(appDidHide:)
		           name: NSApplicationDidHideNotification
		         object: nil];

  [wsnc addObserver: self
	         selector: @selector(appDidUnhide:)
		           name: NSApplicationDidUnhideNotification
		         object: nil];    
    
  [self checkLastRunningApps];

  logoutTimer = nil;
  logoutDelay = 0;
  loggingout = NO;
}

- (void)applicationName:(NSString **)appName
                andPath:(NSString **)appPath
                forName:(NSString *)name
{
  *appName = [[name lastPathComponent] stringByDeletingPathExtension];
  *appPath = [ws fullPathForApplication: *appName];
}
                
- (BOOL)launchApplication:(NSString *)appname
		            arguments:(NSArray *)args
{
  NSString *appPath, *appName;
  NSTask *task;
  GWLaunchedApp *app;
  NSString *path;
  NSDictionary *userinfo;
  NSString *host;

  path = [ws locateApplicationBinary: appname];
  
  if (path == nil) {
	  return NO;
	}

  /*
  * Try to ensure that apps we launch display in this workspace
  * ie they have the same -NSHost specification.
  */
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

  [self applicationName: &appName andPath: &appPath forName: appname];
  
  if (appPath == nil) {
    [ws findApplications];
    [self applicationName: &appName andPath: &appPath forName: appname];
  }

  if (appPath == nil && [appname isAbsolutePath] == YES)
    {
      appPath = appname;
    }
  
  userinfo = [NSDictionary dictionaryWithObjectsAndKeys: appName, 
			                                                   @"NSApplicationName",
	                                                       appPath, 
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
  
  if (app) {
    [launchedApps addObject: app];
    return YES;
  }
  
  return NO;    
}

- (void)appWillLaunch:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *path = [info objectForKey: @"NSApplicationPath"];
  NSString *name = [info objectForKey: @"NSApplicationName"];
  
  if (path && name) {
    [[dtopManager dock] appWillLaunch: path appName: name];
    GWDebugLog(@"appWillLaunch: \"%@\" %@", name, path);
  } else {
    GWDebugLog(@"appWillLaunch: unknown application!");
  }
}

- (void)appDidLaunch:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *name = [info objectForKey: @"NSApplicationName"];
  NSString *path = [info objectForKey: @"NSApplicationPath"];
  NSNumber *ident = [info objectForKey: @"NSApplicationProcessIdentifier"];
  GWLaunchedApp *app = [self launchedAppWithPath: path andName: name];

  if (app) {
    [app setIdentifier: ident];
    
  } else { 
    /*
    * if launched by an other process
    */
    app = [GWLaunchedApp appWithApplicationPath: path
                                applicationName: name
                              processIdentifier: ident
                                   checkRunning: NO];
    
    if (app && [app application]) {
      [launchedApps addObject: app];
    }  
  }

  if (app && [app application]) {
    [[dtopManager dock] appDidLaunch: path appName: name];
    GWDebugLog(@"\"%@\" appDidLaunch (%@)", name, path);
  }
}

- (void)appDidTerminate:(NSNotification *)notif
{
  /*
  * we do nothing here because we will know that the app has terminated 
  * from the connection.
  */
}

- (void)appDidBecomeActive:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *name = [info objectForKey: @"NSApplicationName"];
  NSString *path = [info objectForKey: @"NSApplicationPath"];
  GWLaunchedApp *app = [self launchedAppWithPath: path andName: name];

  if (app) {
    NSUInteger i;
    
    for (i = 0; i < [launchedApps count]; i++) {
      GWLaunchedApp *a = [launchedApps objectAtIndex: i];
      [a setActive: (a == app)];
    }
    
    activeApplication = app;
    GWDebugLog(@"\"%@\" appDidBecomeActive", name);

  } else {
    activeApplication = nil;
    GWDebugLog(@"appDidBecomeActive: \"%@\" unknown running application.", name);
  }
}

- (void)appDidResignActive:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *name = [info objectForKey: @"NSApplicationName"];
  NSString *path = [info objectForKey: @"NSApplicationPath"];
  GWLaunchedApp *app = [self launchedAppWithPath: path andName: name];
  
  if (app) {
    [app setActive: NO];
    
    if (app == activeApplication) {
      activeApplication = nil;
    }
    
  } else {
    GWDebugLog(@"appDidResignActive: \"%@\" unknown running application.", name);
  }
}

- (void)activateAppWithPath:(NSString *)path
                    andName:(NSString *)name
{
  GWLaunchedApp *app = [self launchedAppWithPath: path andName: name];

//  if (app && ([app isActive] == NO)) {
  if (app) {
    [app activateApplication];
  }
}

- (void)appDidHide:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *name = [info objectForKey: @"NSApplicationName"];
  NSString *path = [info objectForKey: @"NSApplicationPath"];
  GWLaunchedApp *app = [self launchedAppWithPath: path andName: name];
  
  GWDebugLog(@"appDidHide: %@", name);
   
  if (app) {
    [app setHidden: YES];
    [[dtopManager dock] appDidHide: name];
  } else {
    GWDebugLog(@"appDidHide: \"%@\" unknown running application.", name);
  }
}

- (void)appDidUnhide:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *name = [info objectForKey: @"NSApplicationName"];
  NSString *path = [info objectForKey: @"NSApplicationPath"];
  GWLaunchedApp *app = [self launchedAppWithPath: path andName: name];
    
  if (app) {
    [app setHidden: NO];
    [[dtopManager dock] appDidUnhide: name];
    GWDebugLog(@"\"%@\" appDidUnhide", name);
  } else {
    GWDebugLog(@"appDidUnhide: \"%@\" unknown running application.", name);
  }
}

- (void)unhideAppWithPath:(NSString *)path
                  andName:(NSString *)name
{
  GWLaunchedApp *app = [self launchedAppWithPath: path andName: name];

  if (app && [app isHidden]) {
    [app unhideApplication];
  }
}

- (void)applicationTerminated:(GWLaunchedApp *)app
{
  NSLog(@"WorkspaceApplication applicationTerminated: %@", app);
  if (app == activeApplication) {
    activeApplication = nil;
  }
  
  [[dtopManager dock] appTerminated: [app name]];
  GWDebugLog(@"\"%@\" applicationTerminated", [app name]);  
  [launchedApps removeObject: app];  
  
  if (loggingout && ([launchedApps count] == 1)) {
    GWLaunchedApp *app = [launchedApps objectAtIndex: 0];

    if ([[app name] isEqual: gwProcessName]) {
      [NSApp terminate: self];
    }
  }
}

- (GWLaunchedApp *)launchedAppWithPath:(NSString *)path
                               andName:(NSString *)name
{
  if ((path != nil) && (name != nil))
    {
      NSUInteger i;

      for (i = 0; i < [launchedApps count]; i++)
        {
          GWLaunchedApp *app = [launchedApps objectAtIndex: i];

          if (([[app path] isEqual: path]) && ([[app name] isEqual: name]))
            {
              return app;
            }
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
  
  if (apps != nil) {
    return [apps allValues];
  }
  
  return nil;
}

- (void)updateStoredAppInfoWithLaunchedApps:(NSArray *)apps
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *runningInfo = nil;
  NSDictionary *oldapps = nil;
  NSMutableDictionary *newapps = nil;
  BOOL modified = NO;
  NSUInteger i;
    
  if ([storedAppinfoLock tryLock] == NO)
    {
      unsigned sleeps = 0;

      if ([[storedAppinfoLock lockDate] timeIntervalSinceNow] < -20.0)
        {
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
  
  for (i = 0; i < [apps count]; i++)
    {
      GWLaunchedApp *app = [apps objectAtIndex: i];
      NSString *appname = [app name];
      NSDictionary *oldInfo = [newapps objectForKey: appname];

      if ([app isRunning] == NO)
        {
          if (oldInfo != nil)
            {
              [newapps removeObjectForKey: appname];
	      modified = YES;
	    }

        }
      else
        {
          NSDictionary *info = [app appInfo];

          if ([info isEqual: oldInfo] == NO) {
            [newapps setObject: info forKey: appname];
            modified = YES;
          }
        }
    }
  
  if (modified)
    {
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

  if (oldrunning && [oldrunning count])
    {
      NSMutableArray *toremove = [NSMutableArray array];
      NSUInteger i;
    
      for (i = 0; i < [oldrunning count]; i++)
        {
          NSDictionary *dict = [oldrunning objectAtIndex: i];
          NSString *name = [dict objectForKey: @"NSApplicationName"];
          NSString *path = [dict objectForKey: @"NSApplicationPath"];
          NSNumber *ident = [dict objectForKey: @"NSApplicationProcessIdentifier"];
    
          if (name && path && ident)
            {
              GWLaunchedApp *app = [GWLaunchedApp appWithApplicationPath: path
                                                         applicationName: name
                                                       processIdentifier: ident
                                                            checkRunning: YES];
        
              if ((app != nil) && [app isRunning])
                {
                  BOOL hidden = [app isApplicationHidden];
          
                  [launchedApps addObject: app];
                  [app setHidden: hidden];
                  [[dtopManager dock] appDidLaunch: path appName: name];
          
                  if (hidden)
                    {
                      [[dtopManager dock] appDidHide: name];
                    }
          
                }
              else if (app != nil)
                {
                  [toremove addObject: app];
                }
            }
        }
    
      if ([toremove count])
        {
          [self updateStoredAppInfoWithLaunchedApps: toremove];
        }
    }
}

- (void)startLogout
{
  NSString *msg = [NSString stringWithFormat: @"%@\n%@%i %@",
        NSLocalizedString(@"Are you sure you want to quit\nall applications and log out now?", @""),
        NSLocalizedString(@"If you do nothing, the system will log out\nautomatically in ", @""),
        autoLogoutDelay,
        NSLocalizedString(@"seconds.", @"")];
  
  loggingout = YES;
  logoutDelay = 30;
  
  if (logoutTimer && [logoutTimer isValid])
    [logoutTimer invalidate];

  ASSIGN (logoutTimer, [NSTimer scheduledTimerWithTimeInterval: autoLogoutDelay
                                                        target: self 
                                                      selector: @selector(doLogout:) 
                                                      userInfo: nil 
                                                       repeats: NO]);
  /* we will display a modal panel, so we add the timer to the modal runloop */
  [[NSRunLoop currentRunLoop] addTimer: logoutTimer forMode: NSModalPanelRunLoopMode];
                                        
  if (NSRunAlertPanel(NSLocalizedString(@"Logout", @""),
                      msg,
                      NSLocalizedString(@"Log out", @""),
                      NSLocalizedString(@"Cancel", @""),
                      nil))
    {
      [logoutTimer invalidate]; 
      [self doLogout: nil];
    }
  else
    {
      [logoutTimer invalidate]; 
      DESTROY (logoutTimer);
      loggingout = NO;
    }
}

- (void)doLogout:(id)sender
{
  NSMutableArray *launched = [NSMutableArray array];
  GWLaunchedApp *gwapp = [self launchedAppWithPath: gwBundlePath andName: gwProcessName];
  NSUInteger i;
  
  [launched addObjectsFromArray: launchedApps];
  [launched removeObject: gwapp];
  
  for (i = 0; i < [launched count]; i++)
    [[launched objectAtIndex: i] terminateApplication];
  
  [launched removeAllObjects];
  [launched addObjectsFromArray: launchedApps];
  [launched removeObject: gwapp];
    
  if ([launched count])
    {
      ASSIGN (logoutTimer, [NSTimer scheduledTimerWithTimeInterval: logoutDelay
                                                            target: self 
                                                          selector: @selector(terminateTasks:) 
                                                          userInfo: nil 
                                                           repeats: NO]);
    }
  else
    {
      [NSApp terminate: self];
    }
}

- (void)terminateTasks:(id)sender
{
  BOOL canterminate = YES;

  if ([launchedApps count] > 1)
    {
      NSMutableArray *launched = [NSMutableArray array];
      GWLaunchedApp *gwapp = [self launchedAppWithPath: gwBundlePath andName: gwProcessName];
      NSMutableString *appNames = [NSMutableString string];
      NSString *msg = nil;
      NSUInteger count;
      NSUInteger i;

      [launched addObjectsFromArray: launchedApps];
      [launched removeObject: gwapp];
    
      count = [launched count];
    
      for (i = 0; i < count; i++)
        {
          GWLaunchedApp *app = [launched objectAtIndex: i];
      
          [appNames appendString: [app name]];

          if (i < (count - 1))
            [appNames appendString: @", "];
        }
    
      msg = [NSString stringWithFormat: @"%@\n%@\n%@",
                      NSLocalizedString(@"The following applications:", @""),
                      appNames, 
                      NSLocalizedString(@"refuse to terminate.", @"")];    

      if (NSRunAlertPanel(NSLocalizedString(@"Logout", @""),
                          msg,
                          NSLocalizedString(@"Kill applications", @""),
                          NSLocalizedString(@"Cancel logout", @""),
                          nil))
        {
          for (i = 0; i < [launched count]; i++)
            {
              [[launched objectAtIndex: i] terminateTask];      
            }    
      
        }
      else
        {
          canterminate = NO;
        }
    }
  
  if (canterminate)
    [NSApp terminate: self];
  else
    loggingout = NO;
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
  
  if (([app name] == nil) || ([app path] == nil)) {
    DESTROY (app);
  }
  
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
  
  if (([app name] == nil) || ([app path] == nil) || ([app identifier] == nil)) {
    DESTROY (app);
  } else if (check) {
    [app connectApplication: YES];
  }
  
  return AUTORELEASE (app);  
}

- (void)dealloc
{
  [nc removeObserver: self];

  if (conn && [conn isValid]) {
    DESTROY (application);  
    RELEASE (conn);  
  }
  
  RELEASE (name);
  RELEASE (path);
  RELEASE (identifier);
  RELEASE (task);
    
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
    conn = nil;
    application = nil;
    active = NO;
    hidden = NO;
    
    gw = [GWorkspace gworkspace];
    nc = [NSNotificationCenter defaultCenter];      
  }
  
  return self;
}

- (NSUInteger)hash
{
  return ([name hash] | [path hash]);
}

- (BOOL)isEqual:(id)other
{
  if (other == self) {
    return YES;
  }
  
  if ([other isKindOfClass: [GWLaunchedApp class]]) {
    return ([[(GWLaunchedApp *)other name] isEqual: name]
                && [[(GWLaunchedApp *)other path] isEqual: path]);
  }
  
  return NO;
}

- (NSDictionary *)appInfo
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  
  [dict setObject: name forKey: @"NSApplicationName"];
  [dict setObject: path forKey: @"NSApplicationPath"];
  
  if (identifier != nil) {
    [dict setObject: identifier forKey: @"NSApplicationProcessIdentifier"];
  }

  return [dict makeImmutableCopyOnFail: NO];
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

- (void)setActive:(BOOL)value
{
  active = value;
}

- (BOOL)isActive
{
  return active;
}

- (void)activateApplication
{
  NS_DURING
    {
      [application activateIgnoringOtherApps: YES];
    }
  NS_HANDLER
    {
      NSLog(@"Unable to activate %@", name);
      NSLog(@"GWorkspace caught exception %@: %@", 
            [localException name], [localException reason]);
    }
  NS_ENDHANDLER
}    

- (void)setHidden:(BOOL)value
{
  hidden = value;
}

- (BOOL)isHidden
{
  return hidden;
}

- (void)hideApplication
{
  NS_DURING
    {
      [application hide: nil];
    }
  NS_HANDLER
    {
      NSLog(@"Unable to hide %@", name);
      NSLog(@"GWorkspace caught exception %@: %@", 
            [localException name], [localException reason]);
    }
  NS_ENDHANDLER
}    

- (void)unhideApplication
{
  NS_DURING
    {
  [application unhideWithoutActivation];
    }
  NS_HANDLER
    {
  NSLog(@"Unable to unhide %@", name);
  NSLog(@"GWorkspace caught exception %@: %@", 
	        [localException name], [localException reason]);
    }
  NS_ENDHANDLER
}    

- (BOOL)isApplicationHidden
{
  BOOL apphidden = NO;
  
  if (application != nil) {
    NS_DURING
      {
    apphidden = [application isHidden];
      }
    NS_HANDLER
      {
    NSLog(@"GWorkspace caught exception %@: %@", 
	                      [localException name], [localException reason]);
      }
    NS_ENDHANDLER
  }
  
  return apphidden;
}

- (BOOL)gwlaunched
{
  return (task != nil);
}

- (BOOL)isRunning
{
  return (application != nil);
}

- (void)terminateApplication 
{  
  if (application) {
    NS_DURING
      {
    [application terminate: nil];
      }
    NS_HANDLER
      {
    GWDebugLog(@"GWorkspace caught exception %@: %@", 
	                      [localException name], [localException reason]);
      }
    NS_ENDHANDLER
  } else { 
    /* if the app is a wrapper */
    [gw applicationTerminated: self];
  }
}

- (void)terminateTask 
{
  if (task && [task isRunning]) {
    NS_DURING
      {
    [task terminate];      
      }
    NS_HANDLER
      {
    GWDebugLog(@"GWorkspace caught exception %@: %@", 
	                      [localException name], [localException reason]);
      }
    NS_ENDHANDLER
  }
}

- (void)connectApplication:(BOOL)showProgress
{
  if (application == nil) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *host = [defaults stringForKey: @"NSHost"];
    id app = nil;
    
    if (host == nil) {
	    host = @"";
	  } else {
	    NSHost *h = [NSHost hostWithName: host];

      if ([h isEqual: [NSHost currentHost]]) {
	      host = @"";
	    }
	  }
  
    app = [NSConnection rootProxyForConnectionWithRegisteredName: name
                                                            host: host];

    if (app) {
      NSConnection *c = [app connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(connectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];
      
      application = app;
      RETAIN (application);
      ASSIGN (conn, c);
      
	  } else {
      StartAppWin *startAppWin = nil;
      int i;

	    if ((task == nil || [task isRunning] == NO) && (showProgress == NO)) {
        DESTROY (task);
        return;
	    }

      if (showProgress) {
        startAppWin = [gw startAppWin];
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: name
                               operation: NSLocalizedString(@"contacting:", @"")         
                            maxProgValue: 20.0];
      }

      for (i = 0; i < 20; i++) {
        if (showProgress) {
          [startAppWin updateProgressBy: 1.0];
        }

	      [[NSRunLoop currentRunLoop] runUntilDate:
		                     [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        app = [NSConnection rootProxyForConnectionWithRegisteredName: name
                                                                host: host];                  
        if (app) {
          NSConnection *c = [app connectionForProxy];

	        [nc addObserver: self
	               selector: @selector(connectionDidDie:)
		                 name: NSConnectionDidDieNotification
		               object: c];

          application = app;
          RETAIN (application);
          ASSIGN (conn, c);
          break;
        }
      }

      if (showProgress) {
        [[startAppWin win] close];
      }
      
      if (application == nil) {          
        if (task && [task isRunning]) {
          [task terminate];
        }
        DESTROY (task);
          
        if (showProgress == NO) {
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
}

- (void)connectionDidDie:(NSNotification *)notif
{
  if (conn == (NSConnection *)[notif object]) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification
	              object: conn];

    DESTROY (application);
    DESTROY (conn);
    
    GWDebugLog(@"\"%@\" application connection did die", name);

    [gw applicationTerminated: self];
  }
}

@end


@implementation NSWorkspace (WorkspaceApplication)

- (id)_workspaceApplication
{
  return [GWorkspace gworkspace];
}

@end

