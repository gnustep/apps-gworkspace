/* RecyclerPrefs.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "RecyclerPrefs.h"
#include "Recycler.h"
#include "GNUstep.h"

static NSString *nibName = @"PreferencesWin";

@implementation RecyclerPrefs

- (void)dealloc
{
  TEST_RELEASE (win);
  [super dealloc];
}

- (id)init
{
	self = [super init];

  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
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


