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

#ifndef GWVIEWER_ICONS_PATH_H
#define GWVIEWER_ICONS_PATH_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "FSNodeRep.h"

// @class PathIcon;

@interface GWViewerIconsPath : NSView
{
  NSMutableArray *icons;
  
  int iconSize;
  int labelTextSize;
  NSFont *labelFont;
  int iconPosition;

  FSNInfoType infoType;
  NSString *extInfoType;
  
	int visibleIcons;
  int firstVisibleIcon;
  int lastVisibleIcon;	
  int shift;  
  NSSize gridSize;

  NSColor *backColor;
  NSColor *textColor;
  NSColor *disabledTextColor;
}

- (id)initWithFrame:(NSRect)frameRect
       visibleIcons:(int)vicns;
     
- (void)showPathComponents:(NSArray *)components
                 selection:(NSArray *)selection;

- (void)setSelectableIconsRange:(NSRange)range;

- (id)lastIcon;






- (void)calculateGridSize;

- (void)tile;

@end


@interface GWViewerIconsPath (NodeRepContainer)

- (id)repOfSubnode:(FSNode *)anode;
- (id)repOfSubnodePath:(NSString *)apath;

- (id)addRepForSubnode:(FSNode *)anode;
- (id)addRepForSubnodePath:(NSString *)apath;

- (void)removeRepOfSubnode:(FSNode *)anode;
- (void)removeRepOfSubnodePath:(NSString *)apath;
- (void)removeRep:(id)arep;

- (void)unselectOtherReps:(id)arep;
- (NSArray *)reps;
- (NSArray *)selectedReps;
- (NSArray *)selectedNodes;
- (NSArray *)selectedPaths;  

- (void)selectionDidChange;  
- (void)checkLockedReps;
- (void)setSelectionMask:(FSNSelectionMask)mask;
- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)restoreLastSelection;

- (NSColor *)backgroundColor;
- (NSColor *)textColor;
- (NSColor *)disabledTextColor;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

@end

#endif // GWVIEWER_ICONS_PATH_H

