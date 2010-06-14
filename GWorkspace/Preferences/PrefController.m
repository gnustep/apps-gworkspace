/* PrefController.m
 *  
 * Copyright (C) 2003-2010 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "PrefController.h"
#import "DefEditorPref.h"
#import "XTermPref.h"
#import "DefSortOrderPref.h"
#import "IconsPref.h"
#import "HiddenFilesPref.h"
#import "HistoryPref.h"
#import "BrowserViewerPref.h"
#import "DesktopPref.h"
#import "OperationPrefs.h"
#import "GWorkspace.h"


static NSString *nibName = @"PrefWindow";

@implementation PrefController

- (void)dealloc
{
  RELEASE (preferences);
  RELEASE (win);
  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if(self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"Preferences: failed to load %@!", nibName);
    } 
  }
  
  return self;
}

- (void)awakeFromNib
{
#define ADD_PREF_VIEW(c) \
currentPref = (id<PrefProtocol>)[[c alloc] init]; \
[popUp addItemWithTitle: [currentPref prefName]]; \
[preferences addObject: currentPref]; \
RELEASE (currentPref)

  if ([win setFrameUsingName: @"preferencesWin"] == NO) {
    [win setFrame: NSMakeRect(100, 100, 396, 310) display: NO];
  }
  [win setDelegate: self];  

  preferences = [[NSMutableArray alloc] initWithCapacity: 1];

  while ([[popUp itemArray] count] > 0) {
    [popUp removeItemAtIndex: 0];
  }

  ADD_PREF_VIEW ([DefEditorPref class]);
  ADD_PREF_VIEW ([XTermPref class]);
  ADD_PREF_VIEW ([BrowserViewerPref class]);
  ADD_PREF_VIEW ([DefSortOrderPref class]);		
  ADD_PREF_VIEW ([IconsPref class]);
  ADD_PREF_VIEW ([HiddenFilesPref class]);
  ADD_PREF_VIEW ([DesktopPref class]);
  ADD_PREF_VIEW ([OperationPrefs class]);
  ADD_PREF_VIEW ([HistoryPref class]);

  currentPref = nil;

  [popUp selectItemAtIndex: 0];
  [self activatePrefView: popUp];

  /*  Internationalization */
  [win setTitle: NSLocalizedString(@"GWorkspace Preferences", @"")];
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
}

- (void)addPreference:(id <PrefProtocol>)anobject
{
  [preferences addObject: anobject]; 
  [popUp addItemWithTitle: [anobject prefName]];
}

- (void)removePreference:(id <PrefProtocol>)anobject
{
  NSString *prefName = [anobject prefName];
  int i = 0;
  
  for (i = 0; i < [preferences count]; i++) {
    id pref = [preferences objectAtIndex: i];
  
    if ([[pref prefName] isEqual: prefName]) {
      [preferences removeObject: pref];
      break;
    }
  }
  
  [popUp removeItemWithTitle: prefName];
}

- (IBAction)activatePrefView:(id)sender
{
  NSString *prefName = [sender titleOfSelectedItem];
  int i;
	
  if(currentPref != nil) {
    if([[currentPref prefName] isEqualToString: prefName]) {
      return;
    }
    [[currentPref prefView] removeFromSuperview];
  }
	
  for (i = 0; i < [preferences count]; i++) {
    id <PrefProtocol>pref = [preferences objectAtIndex: i];		
    if([[pref prefName] isEqualToString: prefName]) {
      currentPref = pref;
      break;
    }
  }

  [viewsBox addSubview: [currentPref prefView]];  
}

- (void)updateDefaults
{
  [win saveFrameUsingName: @"preferencesWin"];
}

- (id)myWin
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

@end
