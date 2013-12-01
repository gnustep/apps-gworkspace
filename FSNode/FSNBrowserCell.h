/* FSNBrowserCell.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef FSN_BROWSER_CELL_H
#define FSN_BROWSER_CELL_H

#import <Foundation/Foundation.h>
#import <AppKit/NSBrowserCell.h>
#import "FSNodeRep.h"

@class FSNode;
@class NSImage;
@class NSTextFieldCell;

@interface FSNBrowserCell : NSBrowserCell <FSNodeRep>
{
  FSNode *node;
  NSArray *selection;
  NSString *selectionTitle; 
  NSString *uncutTitle; 
  NSString *extInfoType;

  FSNInfoType showType;
  NSCell *infoCell;
  NSRect titleRect;
  NSRect infoRect;

  NSImage *icon;
  NSImage *selectedicon;
  int icnsize;
  float icnh;
  
  BOOL isLocked;
  BOOL iconSelected;
  BOOL isOpened;

  BOOL nameEdited;
    
  FSNodeRep *fsnodeRep;  
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
