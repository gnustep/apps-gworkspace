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
#include "FSNIconsView.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"

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
  //    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  //    id dictEntry;




      [scroll setBorderType: NSBezelBorder];
      [scroll setHasHorizontalScroller: YES];
      [scroll setHasVerticalScroller: YES]; 

      iconsView = [FSNIconsView new];
	    [scroll setDocumentView: iconsView];	
      
      [self activate];
      
      [iconsView showContentsOfNode: node];

      // [win setDelegate: self];

    }
  }
  
  return self;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
}

- (IBAction)popUpAction:(id)sender
{

}

- (FSNode *)shownNode
{
  return [iconsView shownNode];
}

@end
