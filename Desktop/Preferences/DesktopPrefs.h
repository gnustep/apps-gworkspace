/* DesktopPrefs.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: May 2004
 *
 * This file is part of the GNUstep Desktop application
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

#ifndef DESKTOP_PREFS_H
#define DESKTOP_PREFS_H

#include <Foundation/Foundation.h>

@class NSColor;
@class NSColorPanel;
@class NSMatrix;
@class Desktop;
@class DesktopView;

@interface ColorView : NSView
{
  NSColor *color;
}

- (void)setColor:(NSColor *)c;

- (NSColor *)color;

@end


@interface DesktopPrefs: NSObject
{
  IBOutlet id win;
  IBOutlet id tabView;

  // Icons
  IBOutlet id icnSizeLabel;
  IBOutlet id icnSizeSlider;
  IBOutlet id textSizeLabel;
  IBOutlet id textSizePopUp;
  IBOutlet id labelLabel;
  IBOutlet id labelMatrix;

  // Color
  NSColorPanel *panel;
  IBOutlet id currColorBox;
  ColorView *colorView;
  IBOutlet id chooseColorButt;
  IBOutlet id setColorButt;

  // Background image
  NSString *imagePath;
  NSString *imagesDir;  
  IBOutlet id imageView;
  IBOutlet id imagePosMatrix;
  IBOutlet id chooseImageButt;
  IBOutlet id setImageButt;
  IBOutlet id useImageSwitch;
  
  // Dock
  IBOutlet id dockPosLabel;
  IBOutlet id dockPosMatrix;    

  // Volumes
  IBOutlet id mtabBox;
  IBOutlet id mtabField;
  IBOutlet id mediaBox;
  IBOutlet id mediaScroll;
  NSMatrix *mediaMatrix;
  IBOutlet id mediaField;
  IBOutlet id remMediaButt;
  IBOutlet id addMediaButt;
  IBOutlet id setMediaButt;
  
  Desktop *desktop;
  DesktopView *desktopView;
}

// Icons
- (IBAction)setIconSize:(id)sender;

- (IBAction)setTextSize:(id)sender;

- (IBAction)setLabelPosition:(id)sender;


// Color
- (IBAction)chooseColor:(id)sender;

- (void)colorChoosen:(id)sender;

- (IBAction)setColor:(id)sender;


// Background image
- (IBAction)chooseImage:(id)sender;

- (IBAction)setImage:(id)sender;

- (IBAction)setImageStyle:(id)sender;

- (IBAction)setUseImage:(id)sender;


// Dock
- (IBAction)setDockPosition:(id)sender;


// Volumes
- (IBAction)addMediaMountPoint:(id)sender;

- (IBAction)removeMediaMountPoint:(id)sender;

- (IBAction)setMediaMountPoints:(id)sender;


- (void)activate;

- (void)updateDefaults;

- (NSWindow *)win;

@end 

#endif // DESKTOP_PREFS_H
