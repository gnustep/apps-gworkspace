/* Inspector.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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
#include "Inspector.h"
#include "ContentViewersProtocol.h"
#include "Contents.h"
#include "Preferences/InspectorPref.h"
#include "Dialogs/StartAppWin.h"
#include "Functions.h"
#include "GNUstep.h"

static Inspector *inspector = nil;
static NSString *nibName = @"InspectorWin";

@implementation Inspector

+ (Inspector *)inspector
{
	if (inspector == nil) {
		inspector = [[Inspector alloc] init];
	}	
  return inspector;
}

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (initialized == YES) {
		return;
  }
	
	initialized = YES;
}

- (void)dealloc
{
  if (fswatcher && [[(NSDistantObject *)fswatcher connectionForProxy] isValid]) {
    [fswatcher unregisterClient: (id <FSWClientProtocol>)self];
    DESTROY (fswatcher);
  }
  
  TEST_RELEASE (watchedPath);
  TEST_RELEASE (currentPaths);
  RELEASE (inspectors);
  TEST_RELEASE (win);
  RELEASE (preferences);
  RELEASE (startAppWin);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    inspectors = [NSMutableArray new];
    watchedPath = nil;
    currentPaths = nil;
    nc = [NSNotificationCenter defaultCenter];
  }
  
  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
    NSLog(@"failed to load %@!", nibName);
    [NSApp terminate: self];
  } 

  [win setFrameUsingName: @"inspector"];
  [win setDelegate: self];
  
  preferences = [[InspectorPref alloc] initForInspector: self];
  startAppWin = [[StartAppWin alloc] init];
  fswatcher = nil;
  fswnotifications = YES;
  [self connectFSWatcher];
  
  while ([[popUp itemArray] count] > 0) {
    [popUp removeItemAtIndex: 0];
  }





  currentInspector = [[Contents alloc] initForInspector: self];
  [inspectors insertObject: currentInspector atIndex: 0]; 
  [popUp insertItemWithTitle: NSLocalizedString(@"Contents", @"") atIndex: 0];
  DESTROY (currentInspector);
  contents = [inspectors objectAtIndex: 0];






    //
    //
    //
    //      STOPPARE I CONTENTS  !!!!!!!!!!!!!!!!!!!!!!!!!!
    //
    //
    //



    
  [win makeKeyAndOrderFront: nil];
  [popUp selectItemAtIndex: 0];
  [self activateInspector: popUp];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
#define TEST_CLOSE(o, w) if ((o) && ([w isVisible])) [w close]
  
  if ([contents prepareToTerminate] == NO) {
    return NO;
  }
  
  [self updateDefaults];

  TEST_CLOSE (startAppWin, [startAppWin win]);
  TEST_CLOSE (preferences, [preferences win]);

  if (fswatcher) {
    NSConnection *fswconn = [(NSDistantObject *)fswatcher connectionForProxy];
  
    if ([fswconn isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: fswconn];
      [fswatcher unregisterClient: (id <FSWClientProtocol>)self];  
      DESTROY (fswatcher);
    }
  }
    		
	return YES;
}

- (IBAction)activateInspector:(id)sender
{
  id insp = [inspectors objectAtIndex: [sender indexOfSelectedItem]];
  
	if (currentInspector != insp) {
    currentInspector = insp;
	  [win setTitle: [insp winname]];
	  [(NSBox *)inspBox setContentView: [insp inspView]];	 
	}
  
  if (currentPaths) {
	  [insp activateForPaths: currentPaths];
  }
}

- (void)setPaths:(NSArray *)paths
{
  if (paths) {
    ASSIGN (currentPaths, paths);
    if (currentInspector) {
      [currentInspector activateForPaths: currentPaths];
    }
  } else {
    DESTROY (currentPaths);
  }
}

- (NSWindow *)inspWin
{
  return win;
}

- (InspectorPref *)preferences
{
  return preferences;
}

- (void)updateDefaults
{
  [preferences updateDefaults];
  [win saveFrameUsingName: @"inspector"];
}

- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"inspector"];
	return YES;
}


//
// Contents Inspector methods 
//
- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return [contents canDisplayDataOfType: type];
}

- (void)showData:(NSData *)data 
          ofType:(NSString *)type
{
  [contents showData: data ofType: type];
}

- (id)contentViewerWithWindowName:(NSString *)wname
{
  return [contents viewerWithWindowName: wname];
}

- (void)disableContentViewer:(id)vwr
{
  [contents disableViewer: vwr];
}

- (BOOL)saveExternalContentViewer:(id)vwr 
                         withName:(NSString *)vwrname
{
  return [contents saveExternalViewer: vwr withName: vwrname];
}


//
// FSWatcher methods 
//
- (void)connectFSWatcher
{
  if (fswatcher == nil) {
    id fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                               host: @""];

    if (fsw) {
      NSConnection *c = [fsw connectionForProxy];
      
	    [nc addObserver: self
	           selector: @selector(fswatcherConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];
      
      fswatcher = fsw;
	    [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
      RETAIN (fswatcher);
                                   
	    [fswatcher registerClient: (id <FSWClientProtocol>)self];
      
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
            cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"fswatcher"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
        [startAppWin showWindowWithTitle: @"Inspector"
                                 appName: @"fswatcher"
                            maxProgValue: 40.0];

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        RELEASE (cmd);
        
        for (i = 1; i <= 40; i++) {
          [startAppWin updateProgressBy: 1 * 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectFSWatcher];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        fswnotifications = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact fswatcher\nfswatcher notifications disabled!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)fswatcherConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [fswatcher connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (fswatcher);
  fswatcher = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The fswatcher connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectFSWatcher];                
  } else {
    fswnotifications = NO;
    NSRunAlertPanel(nil,
                    NSLocalizedString(@"fswatcher notifications disabled!", @""),
                    NSLocalizedString(@"Ok", @""),
                    nil, 
                    nil);  
  }
}

- (void)addWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    
    if ((watchedPath == nil) || ([watchedPath isEqual: path] == NO)) {
      ASSIGN (watchedPath, path);
      [fswatcher client: self addWatcherForPath: path];
    }
  }
}

- (void)removeWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: self removeWatcherForPath: path];
  }
}

- (void)watchedPathDidChange:(NSData *)dirinfo
{
  int i;
  for (i = 0; i< [inspectors count]; i++) {
    [[inspectors objectAtIndex: i] watchedPathDidChange: dirinfo];
  }
}


//
// Menu Operations
//
- (void)closeMainWin:(id)sender
{
  [[[NSApplication sharedApplication] keyWindow] performClose: sender];
}

- (void)showPreferences:(id)sender
{
  [preferences activate];
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"Inspector" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"-----------------------", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"Inspector 0.3" forKey: @"ApplicationRelease"];
  [d setObject: @"01 2004" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: @"Enrico Sersale <enrico@imago.ro>.", nil]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gworkspace", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2004 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
#ifdef GNUSTEP	
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
#else
	[NSApp orderFrontStandardAboutPanel: d];
#endif
}

#ifndef GNUSTEP
- (void)terminate:(id)sender
{
  [NSApp terminate: self];
}
#endif

@end

