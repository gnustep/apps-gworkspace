/*
 *  Interface and declarations for the BrowserViewerPref Class 
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

#ifndef BROWSERVIEWERPREF_H
#define BROWSERVIEWERPREF_H

#include <AppKit/NSView.h>

#include <Foundation/NSObject.h>
  #ifdef GNUSTEP 
#include "PreferencesProtocol.h"
  #else
#include <GWorkspace/PreferencesProtocol.h>
  #endif

@class NSEvent;

@interface Resizer : NSView
{
  NSImage *arrow;
  id prefview;
  id controller;  
}

- (id)initForController:(id)acontroller;

@end

@interface BrowserViewerPref : NSObject <PreferencesProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;

  IBOutlet id aspectBox;
  IBOutlet id cellIconButt;
  IBOutlet id shelfButt;

  IBOutlet id controlsbox;
  IBOutlet id colExample;
  IBOutlet id resizerBox;

  IBOutlet id setButt;

  Resizer *resizer;
  int columnsWidth;
}

- (void)tile;

- (void)mouseDownOnResizer:(NSEvent *)theEvent;

- (void)setNewWidth:(int)w;

- (IBAction)setDefaultWidth:(id)sender;

- (IBAction)setIcons:(id)sender;

- (IBAction)setShelf:(id)sender;

@end

#endif // BROWSERVIEWERPREF_H
