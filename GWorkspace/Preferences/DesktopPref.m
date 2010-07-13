/* DesktopPref.m
 *  
 * Copyright (C) 2005-2010 Free Software Foundation, Inc.
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
#import <AppKit/AppKit.h>
#import "DesktopPref.h"
#import "GWDesktopManager.h"
#import "GWorkspace.h"
#import "GWDesktopView.h"
#import "Dock.h"
#import "TShelf/TShelfWin.h"

static NSString *nibName = @"DesktopPref";

@implementation DesktopPref

- (void)dealloc
{
  RELEASE (prefbox);
  RELEASE (imagePath);
  RELEASE (imagesDir);

  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self)
  {  
    if ([NSBundle loadNibNamed: nibName owner: self] == NO)
    {
      NSLog(@"failed to load %@!", nibName);
    } else
    {
      NSString *impath;
      DockPosition dockpos;
      id cell;
      NSRect r;

      RETAIN (prefbox);
      RELEASE (win);

      manager = [GWDesktopManager desktopManager];
      gworkspace = [GWorkspace gworkspace];

      // Color
      r = [[currColorBox contentView] bounds];
      colorView = [[ColorView alloc] initWithFrame: r];
      [colorView setColor: [[manager desktopView] currentColor]]; 
      [currColorBox setContentView: colorView];
      RELEASE (colorView);

      [NSColorPanel setPickerMask: NSColorPanelWheelModeMask 
                                  | NSColorPanelRGBModeMask 
                                  | NSColorPanelColorListModeMask];
      [NSColorPanel setPickerMode: NSWheelModeColorPanel];
      panel = [NSColorPanel sharedColorPanel];
      [panel setTarget: self];
      [panel setContinuous: YES];

      // Background image  
      [imageView setEditable: NO];
      [imageView setImageScaling: NSScaleProportionally];

      impath = [[manager desktopView] backImagePath];
      if (impath) {
        ASSIGN (imagePath, impath);
      }
      
      if (imagePath)
      {
        CREATE_AUTORELEASE_POOL (pool);
        NSImage *image = [[NSImage alloc] initWithContentsOfFile: imagePath];
        
        if (image)
	{
          [imageView setImage: image];
          RELEASE (image);
        }
        RELEASE (pool);
      }
      
      [imagePosMatrix selectCellAtRow: [[manager desktopView] backImageStyle] column: 0];
      
      [useImageSwitch setState: [[manager desktopView] useBackImage] ? NSOnState : NSOffState];

      // General
      [omnipresentCheck setState: ([manager usesXBundle] ? NSOnState : NSOffState)];
      [useDockCheck setState: ([manager dockActive] ? NSOnState : NSOffState)];
      dockpos = [manager dockPosition];
      [dockPosMatrix selectCellAtRow: 0 column: dockpos];
      [hideTShelfCheck setState: (([[gworkspace tabbedShelf] autohide]) ? NSOnState : NSOffState)];


      /* Internationalization */
      [[tabView tabViewItemAtIndex: 0] setLabel: NSLocalizedString(@"Back Color", @"")];
      [[tabView tabViewItemAtIndex: 1] setLabel: NSLocalizedString(@"Back Image", @"")];
      [[tabView tabViewItemAtIndex: 2] setLabel: NSLocalizedString(@"General", @"")];

      [currColorBox setTitle: NSLocalizedString(@"Current color", @"")];      
      [chooseColorButt setTitle: NSLocalizedString(@"Choose", @"")];      
      [setColorButt setTitle: NSLocalizedString(@"Set", @"")];    
      
      cell = [imagePosMatrix cellAtRow: BackImageCenterStyle column: 0];
      [cell setTitle: NSLocalizedString(@"center", @"")];
      cell = [imagePosMatrix cellAtRow: BackImageFitStyle column: 0];
      [cell setTitle: NSLocalizedString(@"fit", @"")];
      cell = [imagePosMatrix cellAtRow: BackImageTileStyle column: 0];
      [cell setTitle: NSLocalizedString(@"tile", @"")];
      [useImageSwitch setTitle: NSLocalizedString(@"Use image", @"")];  
      [chooseImageButt setTitle: NSLocalizedString(@"Choose", @"")]; 
      [setImageButt setTitle: NSLocalizedString(@"Set", @"")]; 

      [useDockCheck setTitle: NSLocalizedString(@"Show Dock", @"")];
      [dockPosLabel setStringValue: NSLocalizedString(@"Dock position:", @"")];
      cell = [dockPosMatrix cellAtRow: 0 column: 0];
      [cell setTitle: NSLocalizedString(@"Left", @"")];
      cell = [dockPosMatrix cellAtRow: 0 column: 1];
      [cell setTitle: NSLocalizedString(@"Right", @"")];
   
      [hideTShelfCheck setTitle: NSLocalizedString(@"Autohide Tabbed Shelf", @"")];
    }
  }

  return self;
}

- (NSView *)prefView
{
  return prefbox;
}

- (NSString *)prefName
{
  return NSLocalizedString(@"Desktop", @"");
}

// Color
- (IBAction)chooseColor:(id)sender
{
  [panel setAction: @selector(colorChoosen:)];
  [panel setColor: [colorView color]];
  [NSApp orderFrontColorPanel: nil];
}

- (void)colorChoosen:(id)sender
{
  [colorView setColor: [[sender color] colorUsingColorSpaceName: NSCalibratedRGBColorSpace]];      
  [colorView setNeedsDisplay: YES];
}

- (IBAction)setColor:(id)sender
{
  [[manager desktopView] setCurrentColor: [colorView color]];
  [gworkspace tshelfBackgroundDidChange];
}


// Background image
- (IBAction)chooseImage:(id)sender
{
  NSOpenPanel *openPanel;
  int result;
   
  openPanel = [NSOpenPanel openPanel];
  [openPanel setTitle: NSLocalizedString(@"Choose Image", @"")];	
  [openPanel setAllowsMultipleSelection: NO];
  [openPanel setCanChooseFiles: YES];
  [openPanel setCanChooseDirectories: NO];
  
  if (imagesDir == nil) {
    ASSIGN (imagesDir, NSHomeDirectory());
  }
  
  result = [openPanel runModalForDirectory: imagesDir
                                      file: nil 
                                     types: [NSImage imageFileTypes]];
                                     
	if (result == NSOKButton) {
    CREATE_AUTORELEASE_POOL (pool);
    NSString *impath = [openPanel filename];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile: impath];

    if (image) {
      [imageView setImage: image];
      ASSIGN (imagePath, impath);
      ASSIGN (imagesDir, [imagePath stringByDeletingLastPathComponent]);
      RELEASE (image);
    }
    
    RELEASE (pool);
  }
}

- (IBAction)setImage:(id)sender
{
  if (imagePath) {  
    [[manager desktopView] setBackImageAtPath: imagePath];
    [imagePosMatrix selectCellAtRow: [[manager desktopView] backImageStyle] 
                             column: 0];
    [gworkspace tshelfBackgroundDidChange];
  }
}

- (IBAction)setImageStyle:(id)sender
{
  id cell = [imagePosMatrix selectedCell];
  int row, col;
  
  [imagePosMatrix getRow: &row column: &col ofCell: cell];
  [[manager desktopView] setBackImageStyle: row];  
  [gworkspace tshelfBackgroundDidChange];
}

- (IBAction)setUseImage:(id)sender
{
  [[manager desktopView] setUseBackImage: ([sender state] == NSOnState) ? YES : NO];
  [gworkspace tshelfBackgroundDidChange];
}


// General
- (IBAction)setOmnipresent:(id)sender
{
  [manager setUsesXBundle: ([sender state] == NSOnState)];  
  if ([manager usesXBundle] == NO) {
    [sender setState: NSOffState];
  }
}

- (IBAction)setUsesDock:(id)sender
{
  [manager setDockActive: ([sender state] == NSOnState)];
}

- (IBAction)setDockPosition:(id)sender
{
  id cell = [dockPosMatrix selectedCell];
  int row, col;
  
  [dockPosMatrix getRow: &row column: &col ofCell: cell];
  [manager setDockPosition: (col == 0) ? DockPositionLeft : DockPositionRight];
}

- (IBAction)setTShelfAutohide:(id)sender
{
  [[gworkspace tabbedShelf] setAutohide: ([sender state] == NSOnState)];
}

@end


@implementation ColorView

- (void)dealloc
{
  RELEASE (color);
  [super dealloc];
}

- (void)setColor:(NSColor *)c
{
  ASSIGN (color, c);
}

- (NSColor *)color
{
  return color;
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  
  if (color) {
    [color set];
    NSRectFill(rect);
  } 
}

@end

