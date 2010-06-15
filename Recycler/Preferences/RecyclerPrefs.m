/* RecyclerPrefs.m
 *  
 * Copyright (C) 2004-2010 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
 *
 * This file is part of the GNUstep Recycler application
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

#import "RecyclerPrefs.h"
#import "Recycler.h"



static NSString *nibName = @"PreferencesWin";

@implementation RecyclerPrefs

- (void)dealloc
{
  RELEASE (win);
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self)
    {
      if ([NSBundle loadNibNamed: nibName owner: self] == NO)
	{
	  NSLog(@"failed to load %@!", nibName);
	  DESTROY (self);
	  return self;
	} else {
	[win setFrameUsingName: @"recyclerprefs"];
	[win setDelegate: self];
    
	recycler = [Recycler recycler];
      
	[dockButt setState: ([recycler isDocked] ? NSOnState: NSOffState)];
      
	/* Internationalization */
	[win setTitle: NSLocalizedString(@"Recycler Preferences", @"")];
	[dockButt setTitle: NSLocalizedString(@"Dockable", @"")];    
	[explLabel setStringValue: NSLocalizedString(@"Select to allow docking on the WindowMaker Dock", @"")];
      }			
    }
  
  return self;
}

- (IBAction)setDockable:(id)sender
{
  [recycler setDocked: ([sender state] == NSOnState) ? YES : NO];
}

- (void)activate
{
  [win orderFrontRegardless];
}

- (void)updateDefaults
{
  [win saveFrameUsingName: @"recyclerprefs"];
}
                 
- (NSWindow *)win
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
  return YES;
}

@end


