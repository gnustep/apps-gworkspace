/* TShelfPBIcon.m
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

#import "FSNodeRep.h"
#import "GWFunctions.h"
#import "TShelfPBIcon.h"
#import "TShelfIconsView.h"
#import "GWorkspace.h"


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
    
    gridIndex = index;
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

- (void)select
{
  [tview unselectOtherIcons: self];
  [tview setCurrentPBIcon: self];
  isSelected = YES;
  [self setNeedsDisplay: YES];
}

- (void)unselect
{
  isSelected = NO;
  [self setNeedsDisplay: YES];
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
	      [[self window] postEvent: nextEvent atStart: NO];
	      [self unselect];
              break;
            }
          else if ([nextEvent type] == NSLeftMouseDragged)
            {
	      if(dragDelay < 5)
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

      if (startdnd == YES)
        {
          [self startExternalDragOnEvent: theEvent withMouseOffset: offset];    
        }
    }       
}

@end

@implementation TShelfPBIcon (DraggingSource)


- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSData *data = [NSData dataWithContentsOfFile: dataPath];

  if (data)
    {
      [pb declareTypes: [NSArray arrayWithObject: dataType] owner: nil];
      [pb setData: data forType: dataType];
    }
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationEvery;
}

@end
