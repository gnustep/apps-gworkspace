/* GWSpatialViewer.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
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

#include <AppKit/AppKit.h>
#include "GWSpatialViewer.h"
#include "GWViewersManager.h"
#include "GWSVIconsView.h"
#include "GWSVPathsPopUp.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"

#define DEFAULT_INCR 150
#define MIN_W_HEIGHT 250


static NSString *nibName = @"ViewerWindow";


@implementation GWSpatialViewer

- (void)dealloc
{
  TEST_RELEASE (win);
  TEST_RELEASE (iconsView);
  
	[super dealloc];
}

- (id)initForNode:(FSNode *)node
{
  self = [super init];
  
  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } else {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
      id defEntry = [defaults objectForKey: @"browserColsWidth"];
      
      if (defEntry) {
        resizeIncrement = [defEntry intValue];
      } else {
        resizeIncrement = DEFAULT_INCR;
      }

      [win setMinSize: NSMakeSize(resizeIncrement * 2, MIN_W_HEIGHT)];    
      [win setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

      [win setTitle: [NSString stringWithFormat: @"%@ - %@", [node name], [node parentPath]]];   
      [win setFrameUsingName: [NSString stringWithFormat: @"spviewer_at_%@", [node path]]];

      [win setDelegate: self];

      [scroll setBorderType: NSBezelBorder];
      [scroll setHasHorizontalScroller: YES];
      [scroll setHasVerticalScroller: YES]; 

      iconsView = [[GWSVIconsView alloc] initForViewer: self];
	    [scroll setDocumentView: iconsView];	
      
      [self activate];
      
      [iconsView showContentsOfNode: node];
    }
  }
  
  return self;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
}

- (void)popUpAction:(id)sender
{

}

- (FSNode *)shownNode
{
  return [iconsView shownNode];
}

- (void)updateDefaults
{
  FSNode *node = [iconsView shownNode];
  NSString *wname = [NSString stringWithFormat: @"spviewer_at_%@", [node path]];

  [win saveFrameUsingName: wname];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{

}

- (BOOL)windowShouldClose:(id)sender
{
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  [self updateDefaults];
}











@end
















