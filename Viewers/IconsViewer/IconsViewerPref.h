/*
 *  Interface and declarations for the IconsViewerPref Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef ICONS_VIEWER_PREF_H
#define ICONS_VIEWER_PREF_H

#include <AppKit/NSView.h>

#include <Foundation/NSObject.h>
  #ifdef GNUSTEP 
#include "PreferencesProtocol.h"
  #else
#include <GWorkspace/PreferencesProtocol.h>
  #endif

typedef enum { 
	leftarrow,
	rightarrow
} ResizerPosition;

@class NSEvent;
@class NSNotification;
@class NSWorkspace;

@interface LabelResizer : NSView
{
  NSImage *arrow;
  ResizerPosition position;
  id controller;
}

- (id)initForController:(id)acontroller 
           withPosition:(ResizerPosition)pos;

- (ResizerPosition)position;

@end

@interface IconsViewerPref : NSObject <PreferencesProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;
  IBOutlet id iconbox;
  IBOutlet id imView;
  IBOutlet id leftResBox;
  IBOutlet id rightResBox;
  IBOutlet id nameField;
  IBOutlet id setButt;

  LabelResizer *leftResizer; 
  LabelResizer *rightResizer;
  NSString *fname;    
  int cellsWidth;
	NSWorkspace *ws;
  id gw;
}

- (void)tile;

- (void)selectionChanged:(NSNotification *)n;

- (void)startMouseEvent:(NSEvent *)event 
              onResizer:(LabelResizer *)resizer;

- (void)setNewWidth:(int)w;

- (IBAction)setDefaultWidth:(id)sender;

@end

#endif // ICONS_VIEWER_PREF_H
