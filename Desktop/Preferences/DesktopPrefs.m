/* DesktopPrefs.m
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "DesktopPrefs.h"
#include "Desktop.h"
#include "DesktopView.h"
#include "GNUstep.h"

static NSString *nibName = @"PreferencesWin";

#define ISIZES 9
static int icnSizes[ISIZES] = { 16, 20, 24, 28, 32, 36, 40, 44, 48 };

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

int nearestIconSize(float sz)
{
  int isz = floor(sz);
  int i;
  
  for (i = 0; i < ISIZES; i++) {
    if (i != (ISIZES - 1)) {
      int dwndiff = abs(isz - icnSizes[i]);
      int updiff = abs(icnSizes[i + 1] - isz);
  
      if ((dwndiff <= 4) && (updiff <= 4)) {
        return (dwndiff <= updiff) ? icnSizes[i] : icnSizes[i + 1];
      }
  
    } else {
      if (abs(icnSizes[i] - isz) <= 4) {
        return icnSizes[i];
      }
    }
  }
  
  return icnSizes[0];
}


@implementation DesktopPrefs

- (void)dealloc
{
  TEST_RELEASE (win);
  TEST_RELEASE (imagePath);
  TEST_RELEASE (imagesDir);
  
  [super dealloc];
}

- (id)init
{
	self = [super init];

  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } else {
      int isize;
      int txtsize;
      int itemindex;
      int iconpos;
      NSString *sizeStr;
      id cell;
      NSRect r;
      NSString *impath;
      DockPosition dockpos;
      NSSize cs, ms;
      NSUserDefaults *defaults;
      NSString *mtabpath;
      NSArray *removables;
      int i;
            
      [win setFrameUsingName: @"desktopprefs"];
      [win setDelegate: self];
    
      desktop = [Desktop desktop];
      desktopView = [desktop desktopView];
      
      // Icons
      isize = [desktopView iconSize];
      sizeStr = NSLocalizedString(@"Icon size:", @"");
      sizeStr = [NSString stringWithFormat: @"%@ %i x %i", sizeStr, isize, isize];
      [icnSizeLabel setStringValue: sizeStr];
      [icnSizeSlider setFloatValue: isize * 1.0];  
      
      txtsize = [desktopView labelTextSize];
      itemindex = [textSizePopUp indexOfItemWithTag: txtsize];
      [textSizePopUp selectItemAtIndex: (itemindex != -1) ? itemindex : 0];      
      
      iconpos = [desktopView iconPosition];
      [labelMatrix selectCellAtRow: 0 column: (iconpos == NSImageAbove) ? 0 : 1];
      
      // Color
      r = [[(NSBox *)currColorBox contentView] frame];
      colorView = [[ColorView alloc] initWithFrame: r];
      [colorView setColor: [desktopView currentColor]];      
      [(NSBox *)currColorBox setContentView: colorView];
      RELEASE (colorView);

      [NSColorPanel setPickerMask: NSColorPanelWheelModeMask 
                                  | NSColorPanelRGBModeMask 
                                  | NSColorPanelColorListModeMask];
      [NSColorPanel setPickerMode: NSWheelModeColorPanel];
      panel = [NSColorPanel sharedColorPanel];
      [panel setColor: [colorView color]];
      [panel setTarget: self];
      [panel setAction: @selector(colorChoosen:)];
      [panel setContinuous: YES];
      
      // Background image  
      [imageView setEditable: NO];
      [imageView setImageScaling: NSScaleProportionally];

      impath = [desktopView backImagePath];
      if (impath) {
        ASSIGN (imagePath, impath);
      }
      
      if (imagePath) {
        CREATE_AUTORELEASE_POOL (pool);
        NSImage *image = [[NSImage alloc] initWithContentsOfFile: imagePath];
        
        if (image) {
          [imageView setImage: image];
          RELEASE (image);
        }
        RELEASE (pool);
      }
      
      [imagePosMatrix selectCellAtRow: [desktopView backImageStyle] column: 0];
      
      [useImageSwitch setState: [desktopView useBackImage] ? NSOnState : NSOffState];
      
      // Dock
      dockpos = [desktop dockPosition];
      [dockPosMatrix selectCellAtRow: 0 column: dockpos];
      
      // Volumes
      defaults = [NSUserDefaults standardUserDefaults];
      mtabpath = [defaults stringForKey: @"GSMtabPath"];
      
      if (mtabpath == nil) {
        mtabpath = @"/etc/mtab";
        NSRunAlertPanel(nil, 
               NSLocalizedString(@"The mtab path is not set. Using default value.", @""), 
               NSLocalizedString(@"OK", @""), 
               nil, 
               nil);                                     
      }

      [mtabField setStringValue: mtabpath];
      
      [mediaScroll setBorderType: NSBezelBorder];
      [mediaScroll setHasHorizontalScroller: NO];
      [mediaScroll setHasVerticalScroller: YES]; 
      
      mediaMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            	                mode: NSRadioModeMatrix 
                                 prototype: [[NSBrowserCell new] autorelease]
			       							    numberOfRows: 0 
                           numberOfColumns: 0];
      [mediaMatrix setIntercellSpacing: NSZeroSize];
      [mediaMatrix setCellSize: NSMakeSize(1, 16)];
      [mediaMatrix setAutoscroll: YES];
	    [mediaMatrix setAllowsEmptySelection: NO];
      cs = [mediaScroll contentSize];
      ms = [mediaMatrix cellSize];
      ms.width = cs.width;
      CHECKSIZE (ms);
      [mediaMatrix setCellSize: ms];
	    [mediaScroll setDocumentView: mediaMatrix];	
      RELEASE (mediaMatrix);
      
      removables = [defaults arrayForKey: @"GSRemovableMediaPaths"];
      
      if ((removables == nil) || ([removables count] == 0)) {
        removables = [NSArray arrayWithObjects: @"/mnt/floppy", @"/mnt/cdrom", nil];
        NSRunAlertPanel(nil, 
               NSLocalizedString(@"The mount points for removable media are not defined. Using default values.", @""), 
               NSLocalizedString(@"OK", @""), 
               nil, 
               nil);                                     
      }
      
      for (i = 0; i < [removables count]; i++) {
        NSString *mpoint = [removables objectAtIndex: i];
        int count = [[mediaMatrix cells] count];

        [mediaMatrix insertRow: count];
        cell = [mediaMatrix cellAtRow: count column: 0];   
        [cell setStringValue: mpoint];
        [cell setLeaf: YES];  
      }

      [mediaMatrix sizeToCells]; 
      
      /* Internationalization */
      [win setTitle: NSLocalizedString(@"Desktop Preferences", @"")];

      [[tabView tabViewItemAtIndex: 0] setLabel: NSLocalizedString(@"Icons", @"")];
      [[tabView tabViewItemAtIndex: 1] setLabel: NSLocalizedString(@"Back Color", @"")];
      [[tabView tabViewItemAtIndex: 2] setLabel: NSLocalizedString(@"Back Image", @"")];
      [[tabView tabViewItemAtIndex: 3] setLabel: NSLocalizedString(@"Dock", @"")];
      [[tabView tabViewItemAtIndex: 4] setLabel: NSLocalizedString(@"Volumes", @"")];

      [textSizeLabel setStringValue: NSLocalizedString(@"Text size:", @"")];
      [labelLabel setStringValue: NSLocalizedString(@"Label position:", @"")];
      cell = [labelMatrix cellAtRow: 0 column: 0];
      [cell setTitle: NSLocalizedString(@"Bottom", @"")];
      cell = [labelMatrix cellAtRow: 0 column: 1];
      [cell setTitle: NSLocalizedString(@"Right", @"")];

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
      
      [dockPosLabel setStringValue: NSLocalizedString(@"Dock position:", @"")];
      cell = [dockPosMatrix cellAtRow: 0 column: 0];
      [cell setTitle: NSLocalizedString(@"Left", @"")];
      cell = [dockPosMatrix cellAtRow: 0 column: 1];
      [cell setTitle: NSLocalizedString(@"Right", @"")];
      
      [mtabBox setTitle: NSLocalizedString(@"mtab path", @"")];
      [mediaBox setTitle: NSLocalizedString(@"mount points for removable media", @"")];
      [remMediaButt setTitle: NSLocalizedString(@"remove", @"")];  
      [addMediaButt setTitle: NSLocalizedString(@"add", @"")];  
      [setMediaButt setTitle: NSLocalizedString(@"Set", @"")];  
	  }			
  }
  
	return self;
}

//
// Icons
//
- (IBAction)setIconSize:(id)sender
{
  int isz = nearestIconSize([sender floatValue]);
  NSString *sizeStr = NSLocalizedString(@"Icon size:", @"");
  
  sizeStr = [NSString stringWithFormat: @"%@ %i x %i", sizeStr, isz, isz];
  [icnSizeLabel setStringValue: sizeStr];
  [icnSizeLabel displayIfNeeded];
  [sender setFloatValue: isz * 1.0]; 
  [sender displayIfNeeded];
  
  [desktopView setIconSize: isz];
}

- (IBAction)setTextSize:(id)sender
{
  [desktopView setLabelTextSize: [[sender selectedItem] tag]];
}

- (IBAction)setLabelPosition:(id)sender
{
  id cell = [labelMatrix selectedCell];
  int row, col;
  
  [labelMatrix getRow: &row column: &col ofCell: cell];
  [desktopView setIconPosition: (col == 0) ? NSImageAbove : NSImageLeft];
}


//
// Color
//
- (IBAction)chooseColor:(id)sender
{
  [NSApp orderFrontColorPanel: nil];
}

- (void)colorChoosen:(id)sender
{
  [colorView setColor: [sender color]];      
  [colorView setNeedsDisplay: YES];
}

- (IBAction)setColor:(id)sender
{
  [desktopView setCurrentColor: [colorView color]];
}

//
// Background image
//
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
    [desktopView setBackImageAtPath: imagePath];
    [imagePosMatrix selectCellAtRow: [desktopView backImageStyle] column: 0];
  }
}

- (IBAction)setImageStyle:(id)sender
{
  id cell = [imagePosMatrix selectedCell];
  int row, col;
  
  [imagePosMatrix getRow: &row column: &col ofCell: cell];
  [desktopView setBackImageStyle: row];
  
  [imagePosMatrix selectCellAtRow: [desktopView backImageStyle] column: 0];
}

- (IBAction)setUseImage:(id)sender
{
  [desktopView setUseBackImage: ([sender state] == NSOnState) ? YES : NO];
}

//
// Dock
//
- (IBAction)setDockPosition:(id)sender
{
  id cell = [dockPosMatrix selectedCell];
  int row, col;
  
  [dockPosMatrix getRow: &row column: &col ofCell: cell];
  [desktop setDockPosition: (col == 0) ? DockPositionLeft : DockPositionRight];
}


// Volumes
- (IBAction)addMediaMountPoint:(id)sender
{
  NSString *mpoint = [mediaField stringValue];
  NSArray *cells = [mediaMatrix cells];
  BOOL isdir;
  int count;
  id cell;
  int i;
  
  if ([mpoint length] == 0) {
    return;
  }
  if ([mpoint isAbsolutePath] == NO) {
    return;
  }
  if (([[NSFileManager defaultManager] fileExistsAtPath: mpoint 
                                isDirectory: &isdir] && isdir) == NO) {
    return;
  }

  count = [cells count];
  
  for (i = 0; i < count; i++) {
    if ([[[cells objectAtIndex: i] stringValue] isEqual: mpoint]) {
      return;
    }
  }
  
  [mediaMatrix insertRow: count];
  cell = [mediaMatrix cellAtRow: count column: 0];   
  [cell setStringValue: mpoint];
  [cell setLeaf: YES];  
  [mediaMatrix sizeToCells]; 
  [mediaMatrix selectCellAtRow: count column: 0]; 
  [mediaField setStringValue: @""];  
}

- (IBAction)removeMediaMountPoint:(id)sender
{
  id cell = [mediaMatrix selectedCell];
  
  if (cell) {
    int row, col;
    [mediaMatrix getRow: &row column: &col ofCell: cell];
    [mediaMatrix removeRow: row];
    [mediaMatrix sizeToCells]; 
  }
}

- (IBAction)setMediaMountPoints:(id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *mtabpath = [mtabField stringValue];
  NSArray *cells = [mediaMatrix cells];
  NSMutableArray *mpoints = [NSMutableArray array];
  int i;
  
  if ([mtabpath length] && [mtabpath isAbsolutePath]) {
    BOOL isdir;
      
    if ([[NSFileManager defaultManager] fileExistsAtPath: mtabpath 
                                             isDirectory: &isdir]) {
      if (isdir == NO) {
        [defaults setObject: mtabpath forKey: @"GSMtabPath"];
      }
    }
  }

  for (i = 0; i < [cells count]; i++) {
    [mpoints addObject: [[cells objectAtIndex: i] stringValue]];
  }
  
  [defaults setObject: mpoints forKey: @"GSRemovableMediaPaths"];
  
  [defaults synchronize];
}

- (void)activate
{
  [win orderFrontRegardless];
  [tabView selectTabViewItemAtIndex: 0];
}

- (void)updateDefaults
{
  [win saveFrameUsingName: @"desktopprefs"];
}
                 
- (NSWindow *)win
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

@end


@implementation ColorView

- (void)dealloc
{
  TEST_RELEASE (color);
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
