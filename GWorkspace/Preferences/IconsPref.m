/* IconsPref.m
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
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "IconsPref.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#define ANIM_CHPAT 0
#define ANIM_SLIDEBACK 1

static NSString *nibName = @"IconsPref";

@implementation IconsPref

- (void)dealloc
{
  TEST_RELEASE (prefbox);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {  
  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {  
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
      id cell;

      RETAIN (prefbox);
      RELEASE (win); 
     
      gw = [GWorkspace gworkspace];
  
      [thumbCheck setState: [defaults boolForKey: @"usesthumbnails"] ? NSOnState : NSOffState];  

      cell = [animMatrix cellAtRow: ANIM_CHPAT column: 0];
      [cell setState: [defaults boolForKey: @"nochdiranim"] ? NSOffState : NSOnState];  

      cell = [animMatrix cellAtRow: ANIM_SLIDEBACK column: 0];
      [cell setState: [defaults boolForKey: @"noslidebackanim"] ? NSOffState : NSOnState];  
      
      /* Internationalization */
      [thumbbox setTitle: NSLocalizedString(@"Thumbnails", @"")];
      [thumbCheck setTitle: NSLocalizedString(@"use thumbnails", @"")];
      [[animMatrix cellAtRow: ANIM_CHPAT column: 0] setTitle: NSLocalizedString(@"when changing a path", @"")];
      [[animMatrix cellAtRow: ANIM_SLIDEBACK column: 0] setTitle: NSLocalizedString(@"sliding back after file operation", @"")];       
      [selectbox setTitle: NSLocalizedString(@"Animate icons", @"")];
      [actChangesButt setTitle: NSLocalizedString(@"Activate changes", @"")];
    }  
  }
  
  return self;
}

- (NSView *)prefView
{
  return prefbox;
}

- (NSString *)prefName
{
  return NSLocalizedString(@"Icons", @"");
}

- (IBAction)setUnsetAnimation:(id)sender
{
	[actChangesButt setEnabled: YES];
}

- (IBAction)activateChanges:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
  NSArray *cells = [animMatrix cells];
  unsigned int state;
  
  state = [[cells objectAtIndex: ANIM_CHPAT] state];
  [defaults setBool: ((state == NSOnState) ? NO : YES) 
             forKey: @"nochdiranim"];

  state = [[cells objectAtIndex: ANIM_SLIDEBACK] state];
  [defaults setBool: ((state == NSOnState) ? NO : YES) 
             forKey: @"noslidebackanim"];

  [defaults synchronize];
  
	[[NSNotificationCenter defaultCenter]
 				postNotificationName: GWIconAnimationChangedNotification
	 								    object: nil];	
  
	[actChangesButt setEnabled: NO];
}

- (IBAction)setUnsetThumbnails:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
  unsigned int state = [sender state];

  [defaults setBool: ((state == NSOnState) ? YES : NO) 
             forKey: @"usesthumbnails"];
  [defaults synchronize];  
  
  [gw setUsesThumbnails: ((state == NSOnState) ? YES : NO)];
}

@end
