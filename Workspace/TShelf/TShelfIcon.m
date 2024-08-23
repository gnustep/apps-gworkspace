/* TShelfIcon.m
 *  
 * Copyright (C) 2003-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "FSNFunctions.h"
#import "GWFunctions.h"

#import "TShelfIcon.h"
#import "TShelfIconsView.h"

@implementation TShelfIcon

- (void)dealloc
{
  if (trectTag != -1) {
    [self removeTrackingRect: trectTag];
  }
  RELEASE (name);
  RELEASE (namelabel);
  RELEASE (icon);
  RELEASE (highlightPath);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  if (self)
    {
       isSelected = NO;
       locked = NO;
       position = NSMakePoint(0, 0);
       gridIndex = NSNotFound;
       dragDelay = 0;
       isDragTarget = NO;
       onSelf = NO;
       trectTag = -1;
       minimumLaunchClicks = 2;
    }
  return self;
}

- (void)setPosition:(NSPoint)pos
{
  position = NSMakePoint(pos.x, pos.y);
}

- (void)setPosition:(NSPoint)pos gridIndex:(NSUInteger)index
{
  position = NSMakePoint(pos.x, pos.y);
  gridIndex = index;
}

- (NSPoint)position
{
  return position;
}

- (void)setGridIndex:(NSUInteger)index
{
  gridIndex = index;
}

- (NSUInteger)gridIndex
{
  return gridIndex;
}

- (void)select
{
  isSelected = YES;
  if (locked == NO)
    {
      [namelabel setTextColor: [NSColor controlTextColor]];
    }
  [self setNeedsDisplay: YES];
}

- (void)unselect
{
  isSelected = NO;
  if (locked == NO) {
    [namelabel setTextColor: [NSColor controlTextColor]];
  }
  [self setNeedsDisplay: YES];
}

- (NSImage *)icon
{
  return icon;
}

- (void)renewIcon
{
  //
}

- (void)setLabelWidth
{
  NSFont *font = [NSFont systemFontOfSize: 12];
  NSRect rect = [namelabel frame];
  NSString *nstr = name;
  
  labelWidth = [tview cellsWidth] - 8;
	  
  if (isSelected)
  {
    [namelabel setFrame: NSMakeRect(0, 0, [font widthOfString: nstr] + 8, 14)];
    [namelabel setStringValue: nstr];
  }
  else
  {
    int width = (int)[[namelabel font] widthOfString: nstr] + 8;
    if (width > labelWidth)
    {
      width = labelWidth;
    }
    [namelabel setFrame: NSMakeRect(0, 0, width, 14)];  
    [namelabel setStringValue: cutFileLabelText(nstr, namelabel, width - 8)];  
  }

  [(NSView *)tview setNeedsDisplayInRect: rect];
}

- (NSTextField *)myLabel
{
  return namelabel;
}

- (NSString *)shownName
{
  return name;
}


- (BOOL)isSelected
{
  return isSelected;
}

- (void)setLocked:(BOOL)value
{
	if (locked == value) {
		return;
	}
	locked = value;
	[namelabel setTextColor: (locked ? [NSColor disabledControlTextColor] 
																							: [NSColor controlTextColor])];
	[self setNeedsDisplay: YES];		
	[namelabel setNeedsDisplay: YES];
}

- (BOOL)isLocked
{
  return locked;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent 
{
  return YES;
}

- (void)mouseUp:(NSEvent *)theEvent
{
  //
}

- (void)mouseDown:(NSEvent *)theEvent
{
  CHECK_LOCK;

  if ([theEvent clickCount] == 1)
    {
      NSEvent *nextEvent;
      NSPoint location;
      NSSize offset;
      BOOL startdnd = NO;
   
      if (isSelected == NO)
	{
	  [self select];
	}

      location = [theEvent locationInWindow];
    
      while (1)
	{
	  nextEvent = [[self window] nextEventMatchingMask:
				       NSLeftMouseUpMask | NSLeftMouseDraggedMask];

	  if ([nextEvent type] == NSLeftMouseUp)
	    {
	      // post again, or mouse-up gets eaten
	      [[self window] postEvent: nextEvent atStart: YES];
	      [self unselect];
	      break;

	    }
	  else if ([nextEvent type] == NSLeftMouseDragged)
	    {
	      if (dragDelay < 5)
		{
		  dragDelay++;
		}
	      else
		{
		  NSPoint p = [nextEvent locationInWindow];
		  offset = NSMakeSize(p.x - location.x, p.y - location.y);
		  startdnd = YES;
		  break;
		}
	    }
	}

      if (startdnd)
	{
	  [tview setFocusedIcon: nil];
	  [self startExternalDragOnEvent: theEvent withMouseOffset: offset];
	}
    }
}

- (void)mouseEntered:(NSEvent *)theEvent
{
  [tview setFocusedIcon: self];
}

- (void)mouseExited:(NSEvent *)theEvent
{
  [tview setFocusedIcon: nil];
}
 
- (void)setFrame:(NSRect)rect
{	
  NSSize s = [icon size];
  NSPoint ip = NSMakePoint((rect.size.width - s.width) / 2, (rect.size.height - s.height) / 2);	
  NSRect ir = NSMakeRect(ip.x, ip.y, s.width, s.height);
  
  [super setFrame: rect];	
	
  if (trectTag != -1) {
    [self removeTrackingRect: trectTag];
  }
  
  trectTag = [self addTrackingRect: ir owner: self userData: nil assumeInside: NO]; 
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  return [super menuForEvent: theEvent];
}

- (void)drawRect:(NSRect)rect
{
  NSPoint p;
  NSSize s;
  NSSize boundsSize;
      	
  if(isSelected)
    {
      [[NSColor selectedControlColor] set];
      [highlightPath fill];
    }
  
  s = [icon size];
  boundsSize = [self bounds].size;
  p = NSMakePoint((boundsSize.width - s.width) / 2, (boundsSize.height - s.height) / 2);	
  p = [self centerScanRect: NSMakeRect(p.x, p.y, 0, 0)].origin;

	if (locked == NO) {
		[icon compositeToPoint: p operation: NSCompositeSourceOver];
	} else {
		[icon dissolveToPoint: p fraction: 0.3];
	}
}

- (NSComparisonResult)iconCompare:(id)other
{
  if ([other gridIndex] == [self gridIndex])
    return NSOrderedSame;

  if ([other gridIndex] == NSNotFound)
    return NSOrderedAscending;
  if ([self gridIndex] == NSNotFound)
    return NSOrderedDescending;

  if ([other gridIndex] > [self gridIndex])
    return NSOrderedAscending;

  return NSOrderedDescending;
}

- (void)setSingleClickLaunch:(BOOL)value
{
  minimumLaunchClicks = (value == YES) ? 1 : 2;
}

@end

@implementation TShelfIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  NSPoint dragPoint;
	
  [self declareAndSetShapeOnPasteboard: pb];

  ICONCENTER (self, icon, dragPoint);
  	  
  [self dragImage: icon
               at: dragPoint 
           offset: offset
            event: event
       pasteboard: pb
           source: self
        slideBack: NO];
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
}

- (void)draggedImage:(NSImage *)anImage 
             endedAt:(NSPoint)aPoint
           deposited:(BOOL)flag
{
  if (flag == NO)
    {
      NSRect r1 = [self frame];
      NSRect r2 = [namelabel frame];

      r1.origin.x = r1.origin.y = r2.origin.x = r2.origin.y = 0;

      aPoint = [[self window] convertScreenToBase: aPoint];
      aPoint = [self convertPoint: aPoint fromView: nil];
  
      if (NSPointInRect(aPoint, r1) || NSPointInRect(aPoint, r2)) {
        dragDelay = 0;
        onSelf = NO;
        [self unselect];
        return;
      }
    
      [tview removeIcon: self];
    }
  else
    {
      dragDelay = 0;
      onSelf = NO;
      [self unselect];
    }
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationEvery;
}

@end

@implementation TShelfIcon (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  //
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
}

@end

