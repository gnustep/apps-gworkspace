/* FSNBrowserCell.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
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

#ifndef FSN_BROWSER_CELL_H
#define FSN_BROWSER_CELL_H

#include <Foundation/Foundation.h>
#include <AppKit/NSBrowserCell.h>
#include "FSNodeRep.h"

typedef NSString *(*cutIMP)(id, SEL, id, float);

@class FSNode;
@class NSImage;
@class NSBezierPath;

@interface FSNBrowserCell : NSBrowserCell <FSNodeRep>
{
  FSNode *node;
  NSArray *selection;
  NSString *selectionTitle; 
  NSString *uncuttedTitle; 
  NSString *extInfoType;
  
  NSImage *icon;
  NSImage *openicon;
  int icnsize;
  
  NSRect hlightRect;
  
  NSRect titleRect;
  
  FSNInfoType showType;
  
  BOOL isLocked;
  BOOL iconSelected;
  BOOL isOpened;

  BOOL nameEdited;
  
	SEL cutTitleSel;
	cutIMP cutTitle;
}

- (void)setIcon;

- (NSString *)path;

- (BOOL)selectIcon;

- (BOOL)unselectIcon;

- (NSString *)cutTitle:(NSString *)title 
            toFitWidth:(float)width;
            
@end


@interface FSNCellNameEditor : NSTextField
{
  FSNode *node;
  int index;
}  

- (void)setNode:(FSNode *)anode 
    stringValue:(NSString *)str
          index:(int)idx;

- (FSNode *)node;

- (int)index;

@end

#endif // FSN_BROWSER_CELL_H
