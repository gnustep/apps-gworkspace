/* GWViewerIconsPath.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2004
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
#include <math.h>
#include "FSNIcon.h"
#include "FSNFunctions.h"
#include "GWViewerIconsPath.h"
#include "GWViewer.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

#define X_MARGIN (10)
#define Y_MARGIN (12)

#define EDIT_MARGIN (4)


@implementation GWViewerIconsPath

- (void)dealloc
{
  RELEASE (icons);
  TEST_RELEASE (extInfoType);
  RELEASE (backColor);
  RELEASE (textColor);
  RELEASE (disabledTextColor);
  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
       visibleIcons:(int)vicns
          forViewer:(id)vwr
       ownsScroller:(BOOL)ownscr
{
  self = [super initWithFrame: frameRect]; 
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    id defentry;
    
    visibleIcons = vicns;
    viewer = vwr;
    ownScroller = ownscr;
    
    firstVisibleIcon = 0;
    lastVisibleIcon = visibleIcons - 1;
    shift = 0;
   
    defentry = [defaults dictionaryForKey: @"backcolor"];
    if (defentry) {
      float red = [[defentry objectForKey: @"red"] floatValue];
      float green = [[defentry objectForKey: @"green"] floatValue];
      float blue = [[defentry objectForKey: @"blue"] floatValue];
      float alpha = [[defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (backColor, [[NSColor windowBackgroundColor] colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    }

    defentry = [defaults dictionaryForKey: @"textcolor"];
    if (defentry) {
      float red = [[defentry objectForKey: @"red"] floatValue];
      float green = [[defentry objectForKey: @"green"] floatValue];
      float blue = [[defentry objectForKey: @"blue"] floatValue];
      float alpha = [[defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (textColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (textColor, [[NSColor controlTextColor] colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    }

    ASSIGN (disabledTextColor, [textColor highlightWithLevel: NSDarkGray]);

    iconSize = DEF_ICN_SIZE;

    defentry = [defaults objectForKey: @"labeltxtsize"];
    labelTextSize = defentry ? [defentry intValue] : DEF_TEXT_SIZE;
    ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);
    
    iconPosition = DEF_ICN_POS;
        
    defentry = [defaults objectForKey: @"fsn_info_type"];
    infoType = defentry ? [defentry intValue] : FSNInfoNameType;
    extInfoType = nil;
    
    if (infoType == FSNInfoExtendedType) {
      defentry = [defaults objectForKey: @"extended_info_type"];

      if (defentry) {
        NSArray *availableTypes = [FSNodeRep availableExtendedInfoNames];
      
        if ([availableTypes containsObject: defentry]) {
          ASSIGN (extInfoType, defentry);
        }
      }
      
      if (extInfoType == nil) {
        infoType = FSNInfoNameType;
      }
    }

    icons = [NSMutableArray new];

    [self calculateGridSize];
  }
  
  return self;
}

- (void)setOwnsScroller:(BOOL)ownscr
{
  ownScroller = ownscr;
  [self tile];
}

- (void)showPathComponents:(NSArray *)components
                 selection:(NSArray *)selection
{
  NSString *firstsel = [selection objectAtIndex: 0];
  FSNode *node = [FSNode nodeWithRelativePath: firstsel parent: nil];
  int count = [components count];
  FSNIcon *icon;
  int icncount;
  int i;

  while ([icons count] > count) {
    icon = [self lastIcon];
    if (icon) {
      [self removeRep: icon];
    }
  }

  icncount = [icons count];

  for (i = 0; i < [components count]; i++) {
    FSNode *component = [components objectAtIndex: i];
  
        NSLog(@"showPathComponents %@", [component path]);
  
  
    if (i < icncount) {
      icon = [icons objectAtIndex: i];
      [icon setNode: component];
    } else {
      icon = [self addRepForSubnode: component];
    }
    
    [icon setLeaf: NO];
  }

  if ([node isEqual: [components objectAtIndex: (count -1)]] == NO) {
    icon = [self addRepForSubnode: node];
  
    if ([selection count] > 1) {
      NSMutableArray *selnodes = [NSMutableArray array];
    
      for (i = 0; i < [selection count]; i++) {
        NSString *selpath = [selection objectAtIndex: i];
        FSNode *selnode = [FSNode nodeWithRelativePath: [selpath lastPathComponent] 
                                                parent: node];
        [selnodes addObject: selnode];
      }
      
      [icon showSelection: selnodes];
    } 
  }
  
  icon = [self lastIcon];
  [icon setLeaf: YES];
  [icon select];
  
  [self tile];
}

- (void)setSelectableIconsRange:(NSRange)range
{
  int cols = range.length;

  if (cols != visibleIcons) {
    [self setFrame: [[self superview] frame]];
    visibleIcons = cols;  
  }

  firstVisibleIcon = range.location;
  lastVisibleIcon = firstVisibleIcon + visibleIcons - 1;
  shift = 0;

  if (([icons count] - 1) < lastVisibleIcon) {
    shift = lastVisibleIcon - [icons count] + 1;
  }
  
  [self tile];
}
                         
- (id)lastIcon
{
  int count = [icons count];
  if (count) {
    return [icons objectAtIndex: (count - 1)];
  }
  return nil;
}


- (void)calculateGridSize
{
  NSSize highlightSize = NSZeroSize;
  NSSize labelSize = NSZeroSize;
  
  highlightSize.width = ceil(iconSize / 3 * 4);
  highlightSize.height = ceil(highlightSize.width * [FSNodeRep highlightHeightFactor]);
  if ((highlightSize.height - iconSize) < 4) {
    highlightSize.height = iconSize + 4;
  }

  labelSize.height = floor([labelFont defaultLineHeightForFont]);

  gridSize.height = highlightSize.height + labelSize.height;
}

- (void)tile
{
  NSClipView *clip = [self superview];
  float y = [clip frame].origin.y;
  NSScrollView *scroll = [clip superview];
//  float scrwidth = [scroll frame].size.width;
  float scrwidth = [scroll frame].size.width - (4 + visibleIcons);
  NSRect fr = [self frame];
  float posx = 0.0;
	int count = [icons count];
  int i;
  
  gridSize.width = floor(scrwidth / visibleIcons);

  for (i = 0; i < count; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
    int n = i - firstVisibleIcon;
    NSRect r = NSZeroRect;
    
    r.size = gridSize;
    
    if (i <= firstVisibleIcon) {
      r.origin.x = (n * gridSize.width);
    } else if (i <= lastVisibleIcon) {
      r.origin.x = (n * gridSize.width) + n;
    } else {
      r.origin.x = (n * gridSize.width) + 8;
    }
        
    if (i == lastVisibleIcon) {
      r.size.width = scrwidth - r.origin.x;
	  }

    r.origin.y = 0;
    posx += gridSize.width;
    
    [icon setFrame: r];
    [icon setNeedsDisplay: YES];
  }
  
  posx += (shift * gridSize.width);
  
  if (ownScroller) {
    if (posx != fr.size.width) {
      [self setFrame: NSMakeRect(fr.origin.x, fr.origin.y, posx, fr.size.height)];
    }

    if (count && (firstVisibleIcon < count)) {    
		  FSNIcon *icon = [icons objectAtIndex: firstVisibleIcon];
      [clip scrollToPoint: NSMakePoint([icon frame].origin.x, y)];
    }    
  }
  
  [self setNeedsDisplay: YES];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self tile];
}

@end


@implementation GWViewerIconsPath (NodeRepContainer)

- (id)repOfSubnode:(FSNode *)anode
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
  
    if ([[icon node] isEqualToNode: anode]) {
      return icon;
    }
  }
  
  return nil;
}

- (id)repOfSubnodePath:(NSString *)apath
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
  
    if ([[[icon node] path] isEqual: apath]) {
      return icon;
    }
  }
  
  return nil;
}

- (id)addRepForSubnode:(FSNode *)anode
{
  FSNIcon *icon = [[FSNIcon alloc] initForNode: anode
                                  nodeInfoType: infoType
                                  extendedType: extInfoType
                                      iconSize: iconSize
                                  iconPosition: iconPosition
                                     labelFont: labelFont
                                     textColor: textColor
                                     gridIndex: -1
                                     dndSource: YES
                                     acceptDnd: YES];
  [icons addObject: icon];
  [self addSubview: icon];
  RELEASE (icon);
  
  return icon;
}

- (id)addRepForSubnodePath:(NSString *)apath
{
  FSNode *subnode = [FSNode nodeWithRelativePath: apath parent: nil];
  return [self addRepForSubnode: subnode];
}

- (void)removeRepOfSubnode:(FSNode *)anode
{
  FSNIcon *icon = [self repOfSubnode: anode];

  if (icon) {
    [self removeRep: icon];
  } 
}

- (void)removeRepOfSubnodePath:(NSString *)apath
{
  FSNIcon *icon = [self repOfSubnodePath: apath];

  if (icon) {
    [self removeRep: icon];
  }
}

- (void)removeRep:(id)arep
{
//  if (arep == editIcon) {
//    editIcon = nil;
//  }
  [arep removeFromSuperviewWithoutNeedingDisplay];
  [icons removeObject: arep];
}

- (void)repSelected:(id)arep
{
  if ([arep isShowingSelection] == NO) {
    [viewer pathsViewDidSelectIcon: arep];
  }
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

- (NSArray *)reps
{
  return icons;
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

  return [NSArray arrayWithArray: selectedReps];
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

  return [NSArray arrayWithArray: selectedNodes];
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

  return [NSArray arrayWithArray: selectedPaths];
}

- (void)selectionDidChange
{
}

- (void)checkLockedReps
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] checkLocked];
  }
}

- (void)setSelectionMask:(FSNSelectionMask)mask
{
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
}

- (void)restoreLastSelection
{
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














