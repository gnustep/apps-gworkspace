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
#include "FSNIcon.h"
#include "FSNFunctions.h"

#define DEFAULT_INCR 150
#define MIN_W_HEIGHT 170

static NSString *nibName = @"ViewerWindow";

@implementation GWSpatialViewer

- (void)dealloc
{
  TEST_RELEASE (win);
  TEST_RELEASE (iconsView);
  TEST_RELEASE (shownNode);
  
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
      NSString *labelstr;
      NSDictionary *attributes;
      NSNumber *freefs;
      NSArray *icons;
      NSRect r;
      
      if (defEntry) {
        resizeIncrement = [defEntry intValue];
      } else {
        resizeIncrement = DEFAULT_INCR;
      }

      manager = [GWViewersManager viewersManager];

      [win setMinSize: NSMakeSize(resizeIncrement * 2, MIN_W_HEIGHT)];    
      [win setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

      [win setTitle: [NSString stringWithFormat: @"%@ - %@", [node name], [node parentPath]]];   
      [win setFrameUsingName: [NSString stringWithFormat: @"spviewer_at_%@", [node path]]];

      [win setDelegate: self];

      r = [[(NSBox *)popUpBox contentView] frame];
      pathsPopUp = [[GWSVPathsPopUp alloc] initWithFrame: r pullsDown: NO];
      [pathsPopUp setTarget: self];
      [pathsPopUp setAction: @selector(popUpAction:)];
      [pathsPopUp setItemsToNode: node];
      [(NSBox *)popUpBox setContentView: pathsPopUp];	
      RELEASE (pathsPopUp);

      [scroll setBorderType: NSBezelBorder];
      [scroll setHasHorizontalScroller: YES];
      [scroll setHasVerticalScroller: YES]; 

      iconsView = [[GWSVIconsView alloc] initForViewer: self];
	    [scroll setDocumentView: iconsView];	
      
      ASSIGN (shownNode, node);
      
      [iconsView showContentsOfNode: node];
      
      labelstr = [NSString stringWithFormat: @"%i ", [[iconsView reps] count]];
      labelstr = [labelstr stringByAppendingString: NSLocalizedString(@"elements", @"")];
      [elementsLabel setStringValue: labelstr];
      
      attributes = [[NSFileManager defaultManager] fileSystemAttributesAtPath: [node path]];
	    freefs = [attributes objectForKey: NSFileSystemFreeSize];
      
	    if (freefs == nil) {  
		    labelstr = NSLocalizedString(@"unknown volume size", @"");    
	    } else {
		    labelstr = [NSString stringWithFormat: @"%@ %@", 
                       sizeDescription([freefs unsignedLongLongValue]),
                                            NSLocalizedString(@"free", @"")];
	    }
      
      [spaceLabel setStringValue: labelstr];
      
      icons = [iconsView reps];
      if ([icons count]) {
        [iconsView scrollIconToVisible: [icons objectAtIndex: 0]];
      }
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
  NSString *path = [[sender selectedItem] representedObject];

  if ([path isEqual: [shownNode path]] == NO) {
    BOOL close = [sender closeViewer];
  
    if (close) {
      [pathsPopUp setTarget: nil];
    }
  
    [manager newViewerForPath: path closeOldViewer: (close ? self : nil)];
  } 
}

- (void)setOpened:(BOOL)opened 
       iconOfPath:(NSString *)path
{
  FSNIcon *icon = [iconsView repOfSubnodePath: path];

  if (icon) {
    [icon setOpened: opened];
    [icon select];
  }
}

- (void)unselectAllIcons
{
  [iconsView unselectOtherReps: nil];
}

- (FSNode *)shownNode
{
  return shownNode;
}

- (NSArray *)selectedNodes
{
  return [iconsView selectedNodes];
}

- (NSArray *)icons
{
  return [iconsView reps];
}

- (NSWindow *)win
{
  return win;
}

- (void)updateDefaults
{
  NSString *wname = [NSString stringWithFormat: @"spviewer_at_%@", [shownNode path]];
  [win saveFrameUsingName: wname];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  if ([iconsView shownNode]) {
    NSArray *selection = [iconsView selectedPaths];  
  
    if (selection && [selection count]) {
      [manager selectionChanged: selection];
    
      if (([selection count] == 1)
                && ([[selection objectAtIndex: 0] isEqual: [shownNode path]])) {
        [manager viewerSelected: self];
      } else {
        [manager selectionDidChangeInViewer: self];
      }
    } else {
      [manager viewerSelected: self];
      [manager selectionChanged: [NSArray arrayWithObject: [shownNode path]]];
    }
  } else {
    [manager viewerSelected: self];
    [manager selectionChanged: [NSArray arrayWithObject: [shownNode path]]];
  }

  // [self updateInfoString]; 
}

- (BOOL)windowShouldClose:(id)sender
{
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  [self updateDefaults];
  [manager viewerWillClose: self]; 
}





// - (void)fileSystemDidChange:(NSNotification *)notif


@end
















