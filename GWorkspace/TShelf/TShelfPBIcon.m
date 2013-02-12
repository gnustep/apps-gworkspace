/* TShelfPBIcon.m
 *  
 * Copyright (C) 2003-2010 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "FSNodeRep.h"
#import "GWFunctions.h"
#import "TShelfPBIcon.h"
#import "TShelfIconsView.h"
#import "GWorkspace.h"

#define ICON_SIZE 48

@implementation TShelfPBIcon

+ (NSArray *)dataTypes
{
  return [NSArray arrayWithObjects: NSStringPboardType,
                                    NSRTFPboardType,
                                    NSRTFDPboardType,
                                    NSTIFFPboardType,
                                    NSFileContentsPboardType,
                                    NSColorPboardType,
                                    @"IBViewPboardType",
                                    nil];
}

- (void)dealloc
{
  RELEASE (dataPath);
  RELEASE (dataType);
  RELEASE (highlightPath);
  RELEASE (icon);

  [super dealloc];
}

- (id)initForPBDataAtPath:(NSString *)dpath
                   ofType:(NSString *)type
                gridIndex:(NSUInteger)index
              inIconsView:(TShelfIconsView *)aview
{
  self = [super init];
  if (self) {
    NSRect hlightRect;

    [self setFrame: NSMakeRect(0, 0, 64, 52)];

    ASSIGN (dataPath, dpath);
    ASSIGN (dataType, type);

    hlightRect = NSZeroRect;
    hlightRect.size.width = (float)ICON_SIZE / 3 * 4;
    hlightRect.size.height = hlightRect.size.width * [[FSNodeRep sharedInstance] highlightHeightFactor];
    if ((hlightRect.size.height - ICON_SIZE) < 4) {
      hlightRect.size.height = ICON_SIZE + 4;
    }
    hlightRect = NSIntegralRect(hlightRect);
    ASSIGN (highlightPath, [[FSNodeRep sharedInstance] highlightPathOfSize: hlightRect.size]);

    if ([dataType isEqual: NSStringPboardType]) {
      ASSIGN (icon, [NSImage imageNamed: @"stringPboard.tiff"]);
    } else if ([dataType isEqual: NSRTFPboardType]) {
      ASSIGN (icon, [NSImage imageNamed: @"rtfPboard.tiff"]);
    } else if ([dataType isEqual: NSRTFDPboardType]) {
      ASSIGN (icon, [NSImage imageNamed: @"rtfdPboard.tiff"]);
    } else if ([dataType isEqual: NSTIFFPboardType]) {
      ASSIGN (icon, [NSImage imageNamed: @"tiffPboard.tiff"]);
    } else if ([dataType isEqual: NSFileContentsPboardType]) {
      ASSIGN (icon, [NSImage imageNamed: @"filecontsPboard.tiff"]);
    } else if ([dataType isEqual: NSColorPboardType]) {
      ASSIGN (icon, [NSImage imageNamed: @"colorPboard.tiff"]);
    } else if ([dataType isEqual: @"IBViewPboardType"]) {
      ASSIGN (icon, [NSImage imageNamed: @"gormPboard.tiff"]);
    } else {
      ASSIGN (icon, [NSImage imageNamed: @"Pboard.tiff"]);
    }
    
    gridindex = index;
    position = NSMakePoint(0, 0);
    isSelect = NO; 
    dragdelay = 0;
    tview = aview;  
  }
  
  return self;
}

- (NSString *)dataPath
{
  return dataPath;
}

- (NSString *)dataType
{
  return dataType;
}

- (NSData *)data
{
  return [NSData dataWithContentsOfFile: dataPath];
}

- (NSImage *)icon
{
  return icon;
}

- (void)select
{
  [tview unselectOtherIcons: self];
  [tview setCurrentPBIcon: self];
	isSelect = YES;
  [self setNeedsDisplay: YES];
}

- (void)unselect
{
	isSelect = NO;
	[self setNeedsDisplay: YES];
}

- (BOOL)isSelect
{
  return isSelect;
}

- (void)setPosition:(NSPoint)pos
{
  position = NSMakePoint(pos.x, pos.y);
}

- (NSPoint)position
{
  return position;
}

- (void)setGridIndex:(NSUInteger)index
{
  gridindex = index;
}

- (NSUInteger)gridindex
{
  return gridindex;
}

- (NSTextField *)myLabel
{
  return nil;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent 
{
  return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  if ([theEvent clickCount] == 1) { 
    NSEvent *nextEvent;
    NSPoint location;
    NSSize offset;
    BOOL startdnd = NO;
   
    [self select];

    location = [theEvent locationInWindow];
    
    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
        break;
      } else if ([nextEvent type] == NSLeftMouseDragged) {
	      if(dragdelay < 5) {
          dragdelay++;
        } else {      
          NSPoint p = [nextEvent locationInWindow];
          offset = NSMakeSize(p.x - location.x, p.y - location.y); 
          startdnd = YES;        
          break;
        }
      }
    }

    if (startdnd == YES) {  
      [self startExternalDragOnEvent: theEvent withMouseOffset: offset];    
    }    
  }           
}

- (void)drawRect:(NSRect)rect
{
  NSPoint p;
  NSSize s;
      	
  if(isSelect) {
    [[NSColor selectedControlColor] set];
    [highlightPath fill];
  }
	
  s = [icon size];
  p = NSMakePoint((rect.size.width - s.width) / 2, (rect.size.height - s.height) / 2);	
  [icon compositeToPoint: p operation: NSCompositeSourceOver];
}

@end

@implementation TShelfPBIcon (DraggingSource)

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
  NSData *data = [NSData dataWithContentsOfFile: dataPath];

  if (data) {
    [pb declareTypes: [NSArray arrayWithObject: dataType] owner: nil];
    [pb setData: data forType: dataType];
  }
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
  dragdelay = 0;
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

@end
