/* DesktopPref.h
 *  
 * Copyright (C) 2005-2012 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */
 

#import <Foundation/Foundation.h>
#import "PrefProtocol.h"

@class GWDesktopManager;

@interface ColorView : NSView
{
  NSColor *color;
}

- (void)setColor:(NSColor *)c;

- (NSColor *)color;

@end

@interface DesktopPref : NSObject <PrefProtocol>
{
  IBOutlet id win;
  IBOutlet NSBox *prefbox;
  
  IBOutlet id tabView;
  
  // Color
  NSColorPanel *panel;
  IBOutlet NSColorWell *colorWell;
  ColorView *colorView;

  // Background image
  NSString *imagePath;
  NSString *imagesDir;  
  IBOutlet NSImageView *imageView;
  IBOutlet id imagePosMatrix;
  IBOutlet id chooseImageButt;
  IBOutlet id useImageSwitch;
  
  // General
  IBOutlet id omnipresentCheck;
  IBOutlet id useDockCheck;
  IBOutlet id dockPosLabel;
  IBOutlet id dockPosMatrix;
  IBOutlet id dockStyleLabel;
  IBOutlet id dockStyleMatrix;
  IBOutlet id hideTShelfCheck;

  GWDesktopManager *manager;
  id gworkspace;
}

// Color
- (IBAction)setColor:(id)sender;


// Background image
- (IBAction)chooseImage:(id)sender;

- (IBAction)setImage:(id)sender;

- (IBAction)setImageStyle:(id)sender;

- (IBAction)setUseImage:(id)sender;


// General
- (IBAction)setOmnipresent:(id)sender;

- (IBAction)setUsesDock:(id)sender;

- (IBAction)setDockPosition:(id)sender;

- (IBAction)setDockStyle:(id)sender;

- (IBAction)setTShelfAutohide:(id)sender;

@end

