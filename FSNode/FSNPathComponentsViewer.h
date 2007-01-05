/* FSNPathComponentsViewer.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2005
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

#ifndef FSN_PATH_COMPONENTS_VIEWER_H
#define FSN_PATH_COMPONENTS_VIEWER_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "FSNodeRep.h"

@class NSImage;
@class NSTextFieldCell;
@class FSNPathComponentView;

@interface FSNPathComponentsViewer: NSView 
{
  NSMutableArray *components;
  FSNPathComponentView *lastComponent;
  FSNPathComponentView *openComponent;
}

- (void)showComponentsOfSelection:(NSArray *)selection;

- (void)mouseMovedOnComponent:(FSNPathComponentView *)component;

- (void)doubleClickOnComponent:(FSNPathComponentView *)component;

- (void)tile;

@end


@interface FSNPathComponentView: NSView 
{
  FSNode *node;
  NSString *hostname;
  BOOL isLeaf;

  NSImage *icon;
  int iconSize;
  NSRect iconRect;  
  NSTextFieldCell *label;
  NSDictionary *fontAttr;
  NSRect labelRect;
  NSRect brImgRect;

  FSNodeRep *fsnodeRep;
  FSNPathComponentsViewer *viewer;
}

- (id)initForNode:(FSNode *)anode
         iconSize:(int)isize;

- (FSNode *)node;

- (void)setLeaf:(BOOL)value;

+ (float)minWidthForIconSize:(int)isize;

- (float)fullWidth;

- (float)uncuttedLabelLenght;

- (void)tile;

@end

#endif // FSN_PATH_COMPONENTS_VIEWER_H
