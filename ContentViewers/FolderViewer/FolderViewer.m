/* FolderViewer.m
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


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWProtocol.h"
#include "GWLib.h"
#include "InspectorsProtocol.h"
  #else
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/GWLib.h>
#include <GWorkspace/InspectorsProtocol.h>
  #endif
#include "FolderViewer.h"
#include "GNUstep.h"

@implementation FolderViewer

#define byname 0
#define bykind 1
#define bydate 2
#define bysize 3
#define byowner 4

- (void)dealloc
{
	TEST_RELEASE (matrix);
	RELEASE (sortBox);
	RELEASE (label);	
  TEST_RELEASE (myPath);
  RELEASE (bundlePath);
  [super dealloc];
}

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
	self = [super init];
	if(self) {
    #ifdef GNUSTEP 
		  Class gwclass = [[NSBundle mainBundle] principalClass];
    #else
		  Class gwclass = [[NSBundle mainBundle] classNamed: @"GWorkspace"];
    #endif
    
		gworkspace = (id<GWProtocol>)[gwclass gworkspace];

		panel = (id<InspectorsProtocol>)apanel;
		ws = [NSWorkspace sharedWorkspace];
		[self setFrame: frame];
		index = idx;

		sortBox = [[NSBox alloc] initWithFrame: NSMakeRect(57, 93, 137, 125)];
  	[sortBox setBorderType: NSGrooveBorder];
		[sortBox setTitle: NSLocalizedString(@"Sort by", @"")];
  	[sortBox setTitlePosition: NSAtTop];
		[sortBox setContentViewMargins: NSMakeSize(2, 2)]; 
		[self addSubview: sortBox]; 

		label = [[NSTextField alloc] initWithFrame: NSMakeRect(8, 7, 240, 60)];	
		[label setFont: [NSFont systemFontOfSize: 12]];
		[label setAlignment: NSCenterTextAlignment];
		[label setBackgroundColor: [NSColor windowBackgroundColor]];
		[label setTextColor: [NSColor grayColor]];	
		[label setBezeled: NO];
		[label setEditable: NO];
		[label setSelectable: NO];
		localizedStr = NSLocalizedString(@"Sort method applies to the\ncontents of the selected folder,\nNOT to its parent folder", @"");
		[label setStringValue: localizedStr];
		[self addSubview: label]; 
		
		matrix = nil;
	}
	return self;
}

- (void)setBundlePath:(NSString *)path
{
  ASSIGN (bundlePath, path);
}

- (NSString *)bundlePath
{
  return bundlePath;
}

- (void)setIndex:(int)idx
{
  index = idx;
}

- (void)activateForPath:(NSString *)path
{
	id cell;
	BOOL writable;
  
  ASSIGN (myPath, path);    
  writable = [[NSFileManager defaultManager] isWritableFileAtPath: myPath];
  
	oldSortType = [gworkspace sortTypeForDirectoryAtPath: path];
	newSortType = oldSortType;  

	if (matrix != nil) {
		[matrix removeFromSuperview];
		RELEASE (matrix);
	}

  cell = [NSButtonCell new];
  [cell setButtonType: NSRadioButton];
  [cell setBordered: NO];
  [cell setImagePosition: NSImageLeft];
	AUTORELEASE (cell);
	
  matrix = [[NSMatrix alloc] 
				initWithFrame: NSMakeRect(40, 8, 80, 108)
						  		mode: NSRadioModeMatrix prototype: cell
														numberOfRows: 5 numberOfColumns: 1];

	[matrix setCellSize: NSMakeSize(80, 16)];	
	[matrix setIntercellSpacing: NSMakeSize(1, 2)];	
	[sortBox addSubview: matrix]; 


  cell = [matrix cellAtRow: 0 column: 0];
  [cell setTitle: NSLocalizedString(@"Name", @"")];
  [cell setTag: byname];
  [cell setEnabled: writable];
  cell = [matrix cellAtRow: 1 column: 0];
  [cell setTitle: NSLocalizedString(@"Kind", @"")];
  [cell setTag: bykind];
  [cell setEnabled: writable];
  cell = [matrix cellAtRow: 2 column: 0];
  [cell setTitle: NSLocalizedString(@"Date", @"")];
  [cell setTag: bydate];
  [cell setEnabled: writable];
  cell = [matrix cellAtRow: 3 column: 0];
  [cell setTitle: NSLocalizedString(@"Size", @"")];
  [cell setTag: bysize];
  [cell setEnabled: writable];
  cell = [matrix cellAtRow: 4 column: 0];
  [cell setTitle: NSLocalizedString(@"Owner", @"")];
  [cell setTag: byowner];
  [cell setEnabled: writable];
	
	[matrix sizeToCells];
	[matrix setTarget: self];
	[matrix setAction: @selector(newSortType:)];

	buttCancel = [panel revertButton];	
	[buttCancel setEnabled: NO];
  [buttCancel setTarget: self];		
	[buttCancel setAction: @selector(revertToOldSortType:)];
	
	buttOk = [panel okButton];
	[buttOk setEnabled: NO];
  [buttOk setTarget: self];		
	[buttOk setAction: @selector(setNewSortType:)];
	
	[matrix selectCellAtRow: oldSortType column: 0];
	[self setNeedsDisplay: YES];
}

- (BOOL)stopTasks
{
  return YES;
}

- (void)deactivate
{
	[self removeFromSuperview];
}

- (BOOL)canDisplayFileAtPath:(NSString *)path
{
	NSString *defApp, *fileType;
		
	[ws getInfoForFile: path application: &defApp type: &fileType];
	
	if ([fileType isEqual: NSFilesystemFileType]
          						|| [fileType isEqual: NSDirectoryFileType]) {
		if ([gworkspace isPakageAtPath: path] == NO) {
			return YES;
		}
  } 

	return NO;
}

- (int)index
{
	return index;
}

- (NSString *)winname
{
	return NSLocalizedString(@"Folder Inspector", @"");
}

- (void)newSortType:(id)sender
{
	newSortType = [[sender selectedCell] tag];
	[buttOk setEnabled: YES];
	[buttCancel setEnabled: YES];
}

- (void)setNewSortType:(id)sender
{
	if(newSortType == oldSortType) {
		return;
	}
	oldSortType = newSortType;
  [gworkspace setSortType: newSortType forDirectoryAtPath: myPath];
	[buttCancel setEnabled: NO];
	[buttOk setEnabled: NO];	
}

- (void)revertToOldSortType:(id)sender
{
	[matrix selectCellAtRow: oldSortType column: 0];
	newSortType = oldSortType;
	[buttCancel setEnabled: NO];
	[buttOk setEnabled: NO];	
}

@end
