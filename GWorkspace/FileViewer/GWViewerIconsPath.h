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

@class GWViewerScroll;
@class FSNIcon;
@class FSNIconNameEditor;

@interface GWViewerIconsPath : NSView
{
  NSMutableArray *icons;
  
  FSNIconNameEditor *nameEditor;
  FSNIcon *editIcon;
  
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
  
  BOOL ownScroller;
  
  NSColor *backColor;
  NSColor *textColor;
  NSColor *disabledTextColor;
  
  id viewer;
}

- (id)initWithFrame:(NSRect)frameRect
       visibleIcons:(int)vicns
          forViewer:(id)vwr
       ownsScroller:(BOOL)ownscr;

- (void)setOwnsScroller:(BOOL)ownscr;

- (void)showPathComponents:(NSArray *)components
                 selection:(NSArray *)selection;

- (void)setSelectableIconsRange:(NSRange)range;

- (id)lastIcon;

- (void)calculateGridSize;

- (void)tile;

- (void)gwviewerScroll:(GWViewerScroll *)sender 
    scrollViewScrolled:(NSClipView *)clip
               hitPart:(NSScrollerPart)hitpart;

@end


@interface GWViewerIconsPath (NodeRepContainer)

- (id)repOfSubnode:(FSNode *)anode;
- (id)repOfSubnodePath:(NSString *)apath;

- (id)addRepForSubnode:(FSNode *)anode;
- (id)addRepForSubnodePath:(NSString *)apath;

- (void)removeRep:(id)arep;

- (void)repSelected:(id)arep;
- (void)unselectOtherReps:(id)arep;
- (NSArray *)selectedPaths;  

- (void)checkLockedReps;
- (void)restoreLastSelection;

- (NSColor *)backgroundColor;
- (NSColor *)textColor;
- (NSColor *)disabledTextColor;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

@end


@interface GWViewerIconsPath (IconNameEditing)

- (void)setNameEditorForRep:(id)arep;

- (void)stopRepNameEditing;

- (void)controlTextDidChange:(NSNotification *)aNotification;

- (void)controlTextDidEndEditing:(NSNotification *)aNotification;

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict;

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path;

@end


@interface GWViewerScroll : NSScrollView
{
  id delegate;
}

- (void)setDelegate:(id)anObject;

- (id)delegate;

@end

@interface NSObject(GWViewerScrollDelegateMethods)

- (void)gwviewerScroll:(GWViewerScroll *)sender 
    scrollViewScrolled:(NSClipView *)clip
               hitPart:(NSScrollerPart)hitpart;

@end

#endif // GWVIEWER_ICONS_PATH_H

