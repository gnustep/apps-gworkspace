 /*  -*-objc-*-
 *  History.m: Implementation of the History Class 
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
  #else
#include <GWorkspace/GWFunctions.h>
  #endif
#include "History.h"
#include "ViewersWindow.h"
#include "GNUstep.h"

@implementation History

- (void)dealloc
{
  RELEASE (matrix);
	RELEASE (scrollView);
  RELEASE (win);
  [super dealloc];
}

- (id)init
{
	self = [super init];
  
  if (self) {
		id cell;
	  unsigned int style = NSTitledWindowMask | NSClosableWindowMask				
							                                    | NSResizableWindowMask;

	  win = [[NSWindow alloc] initWithContentRect: NSZeroRect
						  styleMask: style backing: NSBackingStoreBuffered defer: YES];

    if ([win setFrameUsingName: @"History"] == NO) {
      [win setFrame: NSMakeRect(100, 100, 250, 400) display: NO];
    }            

    [win setTitle: NSLocalizedString(@"History",@"")];
    [win setReleasedWhenClosed: NO]; 
    [win setDelegate: self];

  	scrollView = [NSScrollView new];
    [scrollView setBorderType: NSBezelBorder];
    [scrollView setHasHorizontalScroller: YES];
    [scrollView setHasVerticalScroller: YES]; 
  	[scrollView setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
		[scrollView setFrame: [[win contentView] frame]];
    [[win contentView] addSubview: scrollView];

    cell = AUTORELEASE ([NSButtonCell new]);
    [cell setButtonType: NSPushOnPushOffButton];
    [cell setBordered: NO];
    [cell setFont: [NSFont systemFontOfSize: 12]];
    [cell setAlignment: NSLeftTextAlignment]; 

    matrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
			      	    mode: NSRadioModeMatrix prototype: cell
		       							        numberOfRows: 0 numberOfColumns: 0];

    [matrix setIntercellSpacing: NSZeroSize];
    [matrix setTarget: self];		
    [matrix setDoubleAction: @selector(setViewerPath:)];	
    [scrollView setDocumentView: matrix];

		viewer = nil;
}

  return self;
}

- (void)activate
{
	[win makeKeyAndOrderFront: nil];
}

- (void)setViewer:(id)aviewer
{
	viewer = aviewer;
}

- (void)setHistoryPaths:(NSArray *)paths
{
	NSArray *cellList;
	BOOL isnew;
	int i;
		
	cellList = [matrix cells];
  isnew = (cellList == nil);
				
  if((!isnew) && ([cellList count] > 0)) { 
    while (1) {
      int count = [[matrix cells] count];
      if (count == 0) {
        break;
      }
      [matrix removeRow: count - 1];
    }
  }
	
	if ((paths == nil) || ([paths count] == 0)) {
		[matrix sizeToCells];
		if ([win isVisible]) {
  		[matrix setNeedsDisplay: YES];  
		}
		return;
	}

	if (isnew) {
		[matrix addColumn]; 
	}
	
  for (i = 0; i < [paths count]; ++i) {
		NSString *fullpath = [paths objectAtIndex: i];	
		NSString *basepath = [fullpath stringByDeletingLastPathComponent];		
		NSString *name = [fullpath lastPathComponent];
		NSString *title = [NSString stringWithFormat: @"%@ - %@", name, basepath];
    id cell;

		if (isnew) {
      if (i != 0) {
		    [matrix insertRow: i];
			} 
    } else {
      [matrix insertRow: i];
    }
    
    cell = [matrix cellAtRow: i column: 0];  
    [cell setStringValue: title];
	}

	[matrix sizeToCells];
	[self setMatrixWidth];
	
	if ([win isVisible]) {
  	[matrix setNeedsDisplay: YES];  
	}
}

- (void)setHistoryPosition:(int)position
{
	NSRect rect = [matrix cellFrameAtRow: position column: 0];
	rect = NSMakeRect(rect.origin.x, rect.origin.y, 10, 10);
	[matrix scrollRectToVisible: rect];	
	[matrix selectCellAtRow: position column: 0];
}

- (void)setHistoryPaths:(NSArray *)paths position:(int)position
{
	[self setHistoryPaths: paths];
	[self setHistoryPosition: position];
}

- (void)setViewerPath:(id)sender
{
	int row, col;

	[matrix getRow: &row column: &col ofCell: [matrix selectedCell]];
	if (viewer) {
		[viewer goToHistoryPosition: row];
	}
}

- (void)setMatrixWidth
{
	NSFont *font = [NSFont systemFontOfSize: 12];
	NSArray *cells = [matrix cells];
	float mh = [font defaultLineHeightForFont];
	float maxw = [[scrollView contentView] frame].size.width;
	int i;
	
	for (i = 0; i < [cells count]; i++) {
		NSString *s = [[cells objectAtIndex: i] stringValue];
		float w = [font widthOfString: s];
		maxw = (maxw < w) ? w : maxw;
	}
	
	[matrix setCellSize: NSMakeSize(maxw, mh)];
}

- (void)updateDefaults
{
	if ([win isVisible]) {
		[win saveFrameUsingName: @"History"];
	}
}

- (NSWindow *)myWin
{
	return win;
}

- (id)viewer
{
	return viewer;
}

- (void)windowDidResize:(NSNotification *)aNotification
{
	if ([aNotification object] == win) {
		[self setMatrixWidth];
	}
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

@end
