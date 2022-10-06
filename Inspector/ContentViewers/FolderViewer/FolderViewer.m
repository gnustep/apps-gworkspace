/* FolderViewer.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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

#include <AppKit/AppKit.h>
#include "FolderViewer.h"

#define byname 0
#define bykind 1
#define bydate 2
#define bysize 3
#define byowner 4

#define STYPES 5

@implementation FolderViewer

- (void)dealloc
{
  TEST_RELEASE (currentPath);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
  self = [super initWithFrame: frameRect];
  
	if (self) {
	  id cell;
    id label;
  
		sortBox = [[NSBox alloc] initWithFrame: NSMakeRect(57, 125, 137, 135)];
  	[sortBox setBorderType: NSGrooveBorder];
		[sortBox setTitle: NSLocalizedString(@"Sort by", @"")];
  	[sortBox setTitlePosition: NSAtTop];
		[sortBox setContentViewMargins: NSMakeSize(2, 2)]; 
		[self addSubview: sortBox]; 
    RELEASE (sortBox);
    
    cell = [NSButtonCell new];
    [cell setButtonType: NSRadioButton];
    [cell setBordered: NO];
    [cell setImagePosition: NSImageLeft];
    
    matrix = [[NSMatrix alloc] 
				  initWithFrame: NSMakeRect(40, 12, 80, 95)
						  		  mode: NSRadioModeMatrix prototype: cell
														  numberOfRows: 5 numberOfColumns: 1];
    RELEASE (cell);
    
	  [matrix setCellSize: NSMakeSize(80, 16)];	
	  [matrix setIntercellSpacing: NSMakeSize(1, 2)];	
	  [sortBox setContentView: matrix]; 
    [matrix setFrame: NSMakeRect(40, 12, 80, 95)];
    RELEASE (matrix);

    cell = [matrix cellAtRow: byname column: 0];
    [cell setTitle: NSLocalizedString(@"Name", @"")];
    [cell setTag: byname];
    cell = [matrix cellAtRow: bykind column: 0];
    [cell setTitle: NSLocalizedString(@"Type", @"")];
    [cell setTag: bykind];
    cell = [matrix cellAtRow: bydate column: 0];
    [cell setTitle: NSLocalizedString(@"Date", @"")];
    [cell setTag: bydate];
    cell = [matrix cellAtRow: bysize column: 0];
    [cell setTitle: NSLocalizedString(@"Size", @"")];
    [cell setTag: bysize];
    cell = [matrix cellAtRow: byowner column: 0];
    [cell setTitle: NSLocalizedString(@"Owner", @"")];
    [cell setTag: byowner];

	  [matrix sizeToCells];
	  [matrix setTarget: self];
	  [matrix setAction: @selector(setNewSortType:)];

		label = [[NSTextField alloc] initWithFrame: NSMakeRect(8, 55, 240, 60)];	
		[label setFont: [NSFont systemFontOfSize: 12]];
		[label setAlignment: NSCenterTextAlignment];
		[label setBackgroundColor: [NSColor windowBackgroundColor]];
		[label setTextColor: [NSColor darkGrayColor]];	
		[label setBezeled: NO];
		[label setEditable: NO];
		[label setSelectable: NO];
		[label setStringValue: NSLocalizedString(@"Sort method applies to the\ncontents of the selected folder,\nNOT to its parent folder", @"")];
		[self addSubview: label]; 
    RELEASE (label);
    
	  okButt = [[NSButton alloc] initWithFrame: NSMakeRect(141, 10, 115, 25)];
	  [okButt setButtonType: NSMomentaryLight];
    [okButt setImage: [NSImage imageNamed: @"common_ret.tiff"]];
    [okButt setImagePosition: NSImageRight];
	  [okButt setTitle: NSLocalizedString(@"Ok", @"")];
    [okButt setEnabled: NO];		
		[self addSubview: okButt]; 
    RELEASE (okButt);
    
    currentPath = nil;

    inspector = insp;
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
				
		valid = YES;
    
    [self setContextHelp];
	}
  
	return self;
}

- (void)displayPath:(NSString *)path
{
	BOOL writable;
  int i;
  
  if ([self superview]) {      
    [inspector contentsReadyAt: path];
  }

  ASSIGN (currentPath, path);    
  writable = [fm isWritableFileAtPath: currentPath];
  
  for (i = 0; i < STYPES; i++) {
    [[matrix cellAtRow: i column: 0] setEnabled: writable];
  }

	[matrix selectCellAtRow: [self sortTypeForPath: path] column: 0];
}

- (void)displayData:(NSData *)data 
             ofType:(NSString *)type
{
}

- (NSString *)currentPath
{
  return currentPath;
}

- (void)stopTasks
{
}

- (BOOL)canDisplayPath:(NSString *)path
{
	NSString *defApp, *fileType;
	[ws getInfoForFile: path application: &defApp type: &fileType];
  return ([fileType isEqual: NSFilesystemFileType]
                          || [fileType isEqual: NSDirectoryFileType]);
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return NO;
}

- (NSString *)winname
{
	return NSLocalizedString(@"Folder Inspector", @"");
}

- (NSString *)description
{
	return NSLocalizedString(@"This Inspector allow you to sort the contents of a Folder", @"");	
}

- (int)sortTypeForPath:(NSString *)path
{
  if ([fm isWritableFileAtPath: path]) {
    NSString *dictPath = [path stringByAppendingPathComponent: @".gwsort"];
    
    if ([fm fileExistsAtPath: dictPath]) {
      NSDictionary *sortDict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
       
      if (sortDict) {
        return [[sortDict objectForKey: @"sort"] intValue];
      }   
    }
  } 
  
	return byname;
}

- (void)setNewSortType:(id)sender
{
	sortType = [[sender selectedCell] tag];

  if ([fm isWritableFileAtPath: currentPath]) {
    NSString *sortstr = [NSString stringWithFormat: @"%i", sortType];
    NSDictionary *dict = [NSDictionary dictionaryWithObject: sortstr 
                                                     forKey: @"sort"];

    [dict writeToFile: [currentPath stringByAppendingPathComponent: @".gwsort"] 
           atomically: YES];

    [[NSDistributedNotificationCenter defaultCenter]
          postNotificationName: @"GWSortTypeDidChangeNotification"
                        object: currentPath
                      userInfo: dict];
  }	
}

- (void)setContextHelp
{
  NSString *bpath = [[NSBundle bundleForClass: [self class]] bundlePath];
  NSString *resPath = [bpath stringByAppendingPathComponent: @"Resources"];
  NSArray *languages = [NSUserDefaults userLanguages];
  unsigned i;
     
  for (i = 0; i < [languages count]; i++) {
    NSString *language = [languages objectAtIndex: i];
    NSString *langDir = [NSString stringWithFormat: @"%@.lproj", language];  
    NSString *helpPath = [langDir stringByAppendingPathComponent: @"Help.rtfd"];
  
    helpPath = [resPath stringByAppendingPathComponent: helpPath];
  
    if ([fm fileExistsAtPath: helpPath]) {
      NSAttributedString *help = [[NSAttributedString alloc] initWithPath: helpPath
                                                       documentAttributes: NULL];
      if (help) {
        [[NSHelpManager sharedHelpManager] setContextHelp: help forObject: self];
        RELEASE (help);
      }
    }
  }
}

@end


