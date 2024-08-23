/* GWViewerIconsView.m
 *  
 * Copyright (C) 2004-2022 Free Software Foundation, Inc.
 *
 * Authora: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <AppKit/AppKit.h>
#import "GWViewerIconsView.h"
#import "FSNIcon.h"
#import "GWViewer.h"
#import "GWViewersManager.h"

@implementation GWViewerIconsView

- (void)dealloc
{
  [super dealloc];
}

- (id)initForViewer:(id)vwr
{
  self = [super init];
  
  if (self)
    {
      viewer = vwr;
      manager = [GWViewersManager viewersManager];
    }
  
  return self;
}

- (void)selectionDidChange
{
  if (!(selectionMask & FSNCreatingSelectionMask))
    {
      NSArray *selection = [self selectedNodes];
		
      if ([selection count] == 0)
        selection = [NSArray arrayWithObject: node];

      if ((lastSelection == nil) || ([selection isEqual: lastSelection] == NO))
        {
          ASSIGN (lastSelection, selection);
          [viewer selectionChanged: selection];
        }
    
      [self updateNameEditor];
    }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [viewer openSelectionInNewViewer: newv];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  if ([theEvent modifierFlags] != NSShiftKeyMask)
    {
      selectionMask = NSSingleSelectionMask;
      selectionMask |= FSNCreatingSelectionMask;
      [self unselectOtherReps: nil];
      selectionMask = NSSingleSelectionMask;
    
      DESTROY (lastSelection);
      [self selectionDidChange];
      [self stopRepNameEditing];
   
    }
}

@end




