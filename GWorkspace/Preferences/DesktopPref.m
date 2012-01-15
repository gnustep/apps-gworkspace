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
      [NSColorPanel setPickerMask: NSColorPanelWheelModeMask 
                                  | NSColorPanelRGBModeMask 
                                  | NSColorPanelColorListModeMask];
      [NSColorPanel setPickerMode: NSWheelModeColorPanel];
      [colorWell setColor: [[manager desktopView] currentColor]];

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
      
      BOOL useImage = [[manager desktopView] useBackImage];
      [imageView setEnabled: useImage];
      [chooseImageButt setEnabled: useImage];
      [imagePosMatrix setEnabled: useImage];
      [useImageSwitch setState: useImage ? NSOnState : NSOffState];

      // General
      [omnipresentCheck setState: ([manager usesXBundle] ? NSOnState : NSOffState)];
      [useDockCheck setState: ([manager dockActive] ? NSOnState : NSOffState)];
      dockpos = [manager dockPosition];
      [dockPosMatrix selectCellAtRow: 0 column: dockpos];
      [hideTShelfCheck setState: (([[gworkspace tabbedShelf] autohide]) ? NSOnState : NSOffState)];


      /* Internationalization */
      [[tabView tabViewItemAtIndex: 0] setLabel: NSLocalizedString(@"Background", @"")];
      [[tabView tabViewItemAtIndex: 1] setLabel: NSLocalizedString(@"General", @"")];

      cell = [imagePosMatrix cellAtRow: BackImageCenterStyle column: 0];
      [cell setTitle: NSLocalizedString(@"center", @"")];
      cell = [imagePosMatrix cellAtRow: BackImageFitStyle column: 0];
      [cell setTitle: NSLocalizedString(@"fit", @"")];
      cell = [imagePosMatrix cellAtRow: BackImageTileStyle column: 0];
      [cell setTitle: NSLocalizedString(@"tile", @"")];
      [useImageSwitch setTitle: NSLocalizedString(@"Use image", @"")];  
      [chooseImageButt setTitle: NSLocalizedString(@"Choose", @"")]; 

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

- (IBAction)setColor:(id)sender
{
  [[manager desktopView] setCurrentColor: [colorWell color]];
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

  if (imagePath) {  
    [[manager desktopView] setBackImageAtPath: imagePath];
    [imagePosMatrix selectCellAtRow: [[manager desktopView] backImageStyle] 
                             column: 0];
    [gworkspace tshelfBackgroundDidChange];
  }
}

- (IBAction)setImage:(id)sender
{
  // FIXME: Handle image dropped on image view?
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
  BOOL useImage = ([sender state] == NSOnState);
  [[manager desktopView] setUseBackImage: useImage];
  [gworkspace tshelfBackgroundDidChange];
  [imageView setEnabled: useImage];
  [chooseImageButt setEnabled: useImage];
  [imagePosMatrix setEnabled: useImage];
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
