/* Inspector.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
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
#include "Inspector.h"
#include "ContentViewersProtocol.h"
#include "Contents.h"
#include "Attributes.h"
#include "Tools.h"
#include "Functions.h"

#define ATTRIBUTES 0
#define CONTENTS   1
#define TOOLS      2

static NSString *nibName = @"InspectorWin";

@implementation Inspector

- (void)dealloc
{
  [nc removeObserver: self];
  TEST_RELEASE (watchedPath);
  TEST_RELEASE (currentPaths);
  RELEASE (inspectors);
  TEST_RELEASE (win);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
    NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];
  
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } 
    
    if (appName && selName) {
		  Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
      SEL sel = NSSelectorFromString(selName);
      desktopApp = [desktopAppClass performSelector: sel];
    }
   
    [win setFrameUsingName: @"inspector"];
    [win setDelegate: self];
  
    inspectors = [NSMutableArray new];
    watchedPath = nil;
    currentPaths = nil;
    nc = [NSNotificationCenter defaultCenter];

    while ([[popUp itemArray] count] > 0) {
      [popUp removeItemAtIndex: 0];
    }

    currentInspector = [[Attributes alloc] initForInspector: self];
    [inspectors insertObject: currentInspector atIndex: ATTRIBUTES]; 
    [popUp insertItemWithTitle: NSLocalizedString(@"Attributes", @"") 
                       atIndex: ATTRIBUTES];
    [[popUp itemAtIndex: ATTRIBUTES] setKeyEquivalent: @"1"];
    DESTROY (currentInspector);

    currentInspector = [[Contents alloc] initForInspector: self];
    [inspectors insertObject: currentInspector atIndex: CONTENTS]; 
    [popUp insertItemWithTitle: NSLocalizedString(@"Contents", @"") 
                       atIndex: CONTENTS];
    [[popUp itemAtIndex: CONTENTS] setKeyEquivalent: @"2"];
    DESTROY (currentInspector);

    currentInspector = [[Tools alloc] initForInspector: self];
    [inspectors insertObject: currentInspector atIndex: TOOLS]; 
    [popUp insertItemWithTitle: NSLocalizedString(@"Tools", @"") 
                       atIndex: TOOLS];
    [[popUp itemAtIndex: TOOLS] setKeyEquivalent: @"3"];
    DESTROY (currentInspector);

    [nc addObserver: self 
           selector: @selector(watcherNotification:) 
               name: @"GWFileWatcherFileDidChangeNotification"
             object: nil];    
  }
  
  return self;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];

  if (currentInspector == nil) {
    [popUp selectItemAtIndex: 0];
    [self activateInspector: popUp];
  }
}

/*
- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  
  if ([[self contents] prepareToTerminate] == NO) {
    return NO;
  }
  
  [self updateDefaults];
}
*/

/*
	GSAppKitUserBundles = (
	    "/usr/GNUstep/Local/Library/Bundles/Camaelon.themeEngine"
	);
*/


- (void)setCurrentSelection:(NSArray *)selection
{
  if (selection) {
    ASSIGN (currentPaths, selection);
    if (currentInspector) {
      [currentInspector activateForPaths: currentPaths];
    }
  }
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return [[self contents] canDisplayDataOfType: type];
}

- (void)showData:(NSData *)data 
          ofType:(NSString *)type
{
  [[self contents] showData: data ofType: type];
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

- (void)showAttributes
{
  if ([win isVisible] == NO) {
    [self activate];
  }
  [popUp selectItemAtIndex: ATTRIBUTES];
  [self activateInspector: popUp];
}

- (id)attributes
{
  return [inspectors objectAtIndex: ATTRIBUTES];
}

- (void)showContents
{
  if ([win isVisible] == NO) {
    [self activate];
  }
  [popUp selectItemAtIndex: CONTENTS];
  [self activateInspector: popUp];
}

- (id)contents
{
  return [inspectors objectAtIndex: CONTENTS];
}

- (void)showTools
{
  if ([win isVisible] == NO) {
    [self activate];
  }
  [popUp selectItemAtIndex: TOOLS];
  [self activateInspector: popUp];
}

- (id)tools
{
  return [inspectors objectAtIndex: TOOLS];
}

- (NSWindow *)win
{
  return win;
}

- (void)updateDefaults
{
  [[self attributes] updateDefaults];
  [win saveFrameUsingName: @"inspector"];
}

- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"inspector"];
	return YES;
}

- (void)addWatcherForPath:(NSString *)path
{
  if ((watchedPath == nil) || ([watchedPath isEqual: path] == NO)) {
    [desktopApp addWatcherForPath: path];
    ASSIGN (watchedPath, path);
  }
}

- (void)removeWatcherForPath:(NSString *)path
{
  if (watchedPath && [watchedPath isEqual: path]) {
    [desktopApp removeWatcherForPath: path];
    DESTROY (watchedPath);
  }
}

- (void)watcherNotification:(NSNotification *)notif
{
  NSDictionary *info = (NSDictionary *)[notif object];
  NSString *path = [info objectForKey: @"path"];
  
  if (watchedPath && [watchedPath isEqual: path]) {
    int i;

    for (i = 0; i < [inspectors count]; i++) {
      [[inspectors objectAtIndex: i] watchedPathDidChange: info];
    }
  }
}

@end

