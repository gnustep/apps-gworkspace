/* ResultsPathsView.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Finder application
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
#include "ResultsPathsView.h"
#include "Finder.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"
#include "GNUstep.h"

#define ICN_H (28)
#define ICN_SIZE (24)
#define ICN_INDT (24)
#define MARGIN (2)

@implementation ResultsPathsView

- (void)dealloc
{
  RELEASE (pathSeparator);
  RELEASE (icons);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];
  
  if (self) {
    NSString *separator = path_separator();
    ASSIGN (pathSeparator, separator);
    icons = [NSMutableArray new];
    finder = [Finder finder];
  }
  
  return self;
}

- (void)showComponentsOfSelection:(NSArray *)selection
{
  NSMutableArray *allComponents = [NSMutableArray array];
  NSArray *firstComponents; 
  NSString *commonPath = pathSeparator;
  int index = 0;
  BOOL common = YES;
  NSArray *newSelection;
  FSNode *node;
  FSNIcon *icon;
  int i;

  for (i = 0; i < [selection count]; i++) {
    FSNode *node = [selection objectAtIndex: i];
    [allComponents addObject: [FSNode pathComponentsToNode: node]];
  }
  
  firstComponents = [allComponents objectAtIndex: 0];
  
  while (index < [firstComponents count]) {
    NSString *p1 = [firstComponents objectAtIndex: index];
  
    for (i = 0; i < [allComponents count]; i++) {
      NSArray *cmps2 = [allComponents objectAtIndex: i];
  
      if (index < [cmps2 count]) {
        NSString *p2 = [cmps2 objectAtIndex: index];
        
        if ([p1 isEqual: p2] == NO) {
          common = NO;
          break;
        }
        
      } else {
        common = NO;  
        break;
      }
    }
  
    if (common) {
      if ([p1 isEqual: pathSeparator] == NO) {
        commonPath = [commonPath stringByAppendingPathComponent: p1];
      }

    } else {
      break;
    }
  
    index++;
  }
    
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] removeFromSuperview];
  }
  
  [icons removeAllObjects];
  
  newSelection = [commonPath pathComponents];
  
  for (i = 0; i < [newSelection count]; i++) {   
    node = [FSNode nodeWithRelativePath: [newSelection objectAtIndex: i] 
                                 parent: ((i == 0) ? nil : node)];
    icon = [[FSNIcon alloc] initForNode: node
                           nodeInfoType: FSNInfoNameType
                           extendedType: nil
                               iconSize: ICN_SIZE
                           iconPosition: NSImageLeft
                              labelFont: [NSFont systemFontOfSize: 12]
                              textColor: [NSColor controlTextColor]
                              gridIndex: 0
                              dndSource: NO
                              acceptDnd: NO];

    [self addSubview: icon];
    [icons insertObject: icon atIndex: [icons count]];
    RELEASE (icon);
  }
  
  [self tile];
}

- (void)tile
{
  float sfw = [[self superview] frame].size.width;
  float sfh = [[self superview] frame].size.height;
	float px = MARGIN;
	float py = ICN_H;
	int count = [icons count];
	NSRect *irects = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * count);
  int i;

	py += MARGIN;  
  
	for (i = 0; i < count; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSRect irect = [icon frame];
  
    if (i != 0) {
      px += ICN_INDT;
      py += ICN_H; 
    }
    
    irects[i] = NSMakeRect(px, py, irect.size.width, ICN_H);
  }
  
	py += (ICN_H / 2);  
  py = (py < sfh) ? sfh : py;
  
  [self setFrame: NSMakeRect(0, 0, sfw, py)];
  
	for (i = 0; i < count; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    
		irects[i].origin.y = py - irects[i].origin.y;
    [icon setFrame: irects[i]];
		[icon resizeWithOldSuperviewSize: [self frame].size]; 
  }  

	NSZoneFree (NSDefaultMallocZone(), irects);
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self tile];
}

@end


@implementation ResultsPathsView (NodeRepContainer)

- (void)nodeContentsWillChange:(NSDictionary *)info
{
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
}

- (void)watchedPathChanged:(NSDictionary *)info
{
}

- (void)unselectOtherReps:(id)arep
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if (icon != arep) {
      [icon unselect];
    }
  }
}

- (NSArray *)selectedReps
{
  NSMutableArray *selectedReps = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedReps addObject: icon];
    }
  }

  return selectedReps;
}

- (NSArray *)selectedNodes
{
  NSMutableArray *selectedNodes = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedNodes addObject: [icon node]];
    }
  }

  return selectedNodes;
}

- (NSArray *)selectedPaths
{
  NSMutableArray *selectedPaths = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedPaths addObject: [[icon node] path]];
    }
  }

  return selectedPaths;
}

- (FSNSelectionMask)selectionMask
{
  return NSSingleSelectionMask;
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  NSArray *selection = [self selectedNodes];
  int i;
  
  for (i = 0; i < [selection count]; i++) {
    FSNode *node = [selection objectAtIndex: i];
    [finder openFoundSelection: [NSArray arrayWithObject: node]];
  }
}

- (NSColor *)backgroundColor
{
  return [NSColor windowBackgroundColor];
}

- (NSColor *)textColor
{
  return [NSColor controlTextColor];
}

- (NSColor *)disabledTextColor
{
  return [NSColor disabledControlTextColor];
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return NSDragOperationNone;
}

@end








