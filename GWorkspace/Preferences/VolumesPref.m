/* VolumesPref.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "VolumesPref.h"
#include "FSNodeRep.h"

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

static NSString *nibName = @"VolumesPref";


@implementation VolumesPref

- (void)dealloc
{
  TEST_RELEASE (prefbox);
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
	    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      
      NSString *mtabpath;
      NSArray *removables;
      NSSize cs, ms;
      id cell;
      int i;
      
      RETAIN (prefbox);
      RELEASE (win);

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

      fsnoderep = [FSNodeRep sharedInstance];
      [fsnoderep setVolumes: removables];

      /* Internationalization */
      [mtabBox setTitle: NSLocalizedString(@"mtab path", @"")];
      [mediaBox setTitle: NSLocalizedString(@"mount points for removable media", @"")];
      [remMediaButt setTitle: NSLocalizedString(@"remove", @"")];  
      [addMediaButt setTitle: NSLocalizedString(@"add", @"")];  
      [setMediaButt setTitle: NSLocalizedString(@"Set", @"")];  
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
  return NSLocalizedString(@"Volumes", @"");
}

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

  [fsnoderep setVolumes: mpoints];
}

@end















