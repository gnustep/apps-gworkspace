/* RecyclerIcon.m
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
#include "GWLib.h"
#include "GWFunctions.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
  #endif
#include "RecyclerIcon.h"
#include "RecyclerViews.h"
#include "GWorkspace.h"
#include "GNUstep.h"

@implementation RecyclerIcon

- (void)dealloc
{
  RELEASE (path);
  RELEASE (name);
  RELEASE (icon);
  RELEASE (highlight);
  [super dealloc];
}

- (id)initWithPath:(NSString *)apath inIconsView:(id)aview
{
  self = [super init];
  if (self) {
    NSFont *font;
    NSString *defApp;
    NSString *type;

		ws = [NSWorkspace sharedWorkspace];

    [self setFrame: NSMakeRect(0, 0, 64, 52)];
		
		ASSIGN (path, apath);
		ASSIGN (name, [path lastPathComponent]);    
    [ws getInfoForFile: path application: &defApp type: &type];      
		ASSIGN (icon, [GWLib iconForFile: path ofType: type]);    
    ASSIGN (highlight, [NSImage imageNamed: @"CellHighlight.tiff"]);
    iconsView = (IconsView *)aview;  

    namelabel = [NSTextField new];
    AUTORELEASE (namelabel);

    labelWidth = [iconsView cellsWidth] - 4;
    font = [NSFont systemFontOfSize: 12];    
		[namelabel setFont: font];
		[namelabel setBezeled: NO];
		[namelabel setEditable: NO];
		[namelabel setSelectable: NO];
		[namelabel setAlignment: NSCenterTextAlignment];
	  [namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
	  [namelabel setTextColor: [NSColor blackColor]];
		[self setLabelWidth]; 
        
    isSelect = NO; 
  }
  return self;
}

- (void)select
{
	isSelect = YES;
  [namelabel setTextColor: [NSColor blackColor]];
	[iconsView unselectOtherIcons: self];
  [iconsView setCurrentSelection: path];
	[self display];
}

- (void)unselect
{
	isSelect = NO;
  [namelabel setTextColor: [NSColor blackColor]];
	[self display];
}

- (void)setLabelWidth
{
  NSFont *font = [NSFont systemFontOfSize: 12];
  NSRect rect = [namelabel frame];
  labelWidth = [iconsView cellsWidth] - 8;
    
  if (isSelect == YES) {
    [namelabel setFrame: NSMakeRect(0, 0, [font widthOfString: name] + 8, 14)];
    [namelabel setStringValue: name];
  } else {
    int width = (int)[[namelabel font] widthOfString: name] + 8;
    if (width > labelWidth) {
      width = labelWidth;
    }
    [namelabel setFrame: NSMakeRect(0, 0, width, 14)];  
    [namelabel setStringValue: cutFileLabelText(name, namelabel, width - 8)];  
  }

  [(NSView *)iconsView setNeedsDisplayInRect: rect];
}

- (NSTextField *)label
{
  return namelabel;
}

- (NSString *)path
{
  return path;
}

- (NSString *)name
{
  return name;
}

- (BOOL)isSelect
{
  return isSelect;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if (isSelect == NO) {
		[self select];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if(dragdelay < 5) {
    dragdelay++;
    return;
  }

  [self startExternalDragOnEvent: theEvent];
}

- (void)drawRect:(NSRect)rect
{
	NSPoint p;
  NSSize s;
      
	if(isSelect) {
  	s = [highlight size];
  	p = NSMakePoint((rect.size.width - s.width) / 2, (rect.size.height - s.height) / 2);	
		[highlight compositeToPoint: p operation: NSCompositeSourceOver];
	}	
	
  s = [icon size];
  p = NSMakePoint((rect.size.width - s.width) / 2, (rect.size.height - s.height) / 2);	
	[icon compositeToPoint: p operation: NSCompositeSourceOver];
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)aDelegate
{
  ASSIGN (delegate, aDelegate);
	AUTORELEASE (delegate);
}

@end

@implementation RecyclerIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
{
	NSEvent *nextEvent;
  NSPoint dragPoint;
  NSPasteboard *pb;
  NSString *defApp;
  NSString *type;
  NSImage *dragIcon;
  
	nextEvent = [[self window] nextEventMatchingMask:
    							NSLeftMouseUpMask | NSLeftMouseDraggedMask];

  if([nextEvent type] != NSLeftMouseDragged) {
   	return;
  }
  
  dragPoint = [nextEvent locationInWindow];
  dragPoint = [self convertPoint: dragPoint fromView: nil];

	pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  [self declareAndSetShapeOnPasteboard: pb];

	dragdelay = 0;

  [ws getInfoForFile: path application: &defApp type: &type];      
	dragIcon = [GWLib iconForFile: path ofType: type];
	
  [self dragImage: dragIcon
               at: dragPoint 
           offset: NSZeroSize
            event: event
       pasteboard: pb
           source: self
        slideBack: NO];
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes;
  NSArray *selection;

  dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  [pb declareTypes: dndtypes owner: nil];	
  selection = [NSArray arrayWithObjects: path, nil];	

  if ([pb setPropertyList: selection forType: NSFilenamesPboardType] == NO) {
    return;
  }
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

@end
