/* DeskTopPref.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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


#ifndef DESKTOP_PREF_H
#define DESKTOP_PREF_H

#include <Foundation/NSObject.h>
#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include "PreferencesProtocol.h"
  #else
#include <GWorkspace/PreferencesProtocol.h>
  #endif

@class NSColor;
@class ColorsView;
@class GWorkspace;

@interface ColorView : NSView
{
  NSColor *color;
}

- (void)setColor:(NSColor *)c;

@end

@interface DeskTopPref : NSObject <PreferencesProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;

  IBOutlet id controlsbox;

  IBOutlet id redlabel;
  IBOutlet id greenlabel;
  IBOutlet id bluelabel;
  
  IBOutlet id redSlider;
  IBOutlet id greenSlider;
  IBOutlet id blueSlider;

  IBOutlet id redField;
  IBOutlet id greenField;
  IBOutlet id blueField;

  IBOutlet id colorsBox;

  ColorView *colorsView;
  NSColor *color;
  float r, g, b, alpha;
  
  IBOutlet id setColorButt;
  
  IBOutlet id setImageButt;
  IBOutlet id chooseDeskButt;
    
	BOOL deskactive;

	GWorkspace *gw;  
}

- (IBAction)setDeskState:(id)sender;

- (IBAction)makeColor:(id)sender;

- (IBAction)setColor:(id)sender;

- (IBAction)chooseImage:(id)sender;

- (IBAction)unsetImage:(id)sender;

@end

#endif // DESKTOP_PREF_H
