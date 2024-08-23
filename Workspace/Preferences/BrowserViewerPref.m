/* BrowserViewerPref.m
 *  
 * Copyright (C) 2003-2016 Free Software Foundation, Inc.
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

#import "BrowserViewerPref.h"


#define RESIZER_W 16
#define RESIZER_Y 48

#define MINIMUM_WIDTH 120
#define DEFAULT_WIDTH 150
#define MAXIMUM_WIDTH 362

static NSString *nibName = @"BrowserViewerPref";

@implementation Resizer

- (void)dealloc
{
  RELEASE (arrow);
  [super dealloc];
}

- (id)initForController:(id)acontroller
{
  self = [super init];
  [self setFrame: NSMakeRect(0, 0, RESIZER_W, RESIZER_W)];	  
  controller = acontroller;  
  ASSIGN (arrow, [NSImage imageNamed: @"RightArr.tiff"]);  
  return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [controller mouseDownOnResizer: theEvent];
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  [arrow compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];
}

@end

@implementation BrowserViewerPref

- (void)dealloc
{
  RELEASE (colExample);
  RELEASE (prefbox);
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
        }
      else
        { 
          NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
          NSString *widthStr = [defaults objectForKey: @"browserColsWidth"];
      
          RETAIN (prefbox);
          RELEASE (win);

          if (widthStr)
            columnsWidth = [widthStr intValue];
          else
            columnsWidth = DEFAULT_WIDTH;

          [colExample setBorderType: NSBezelBorder];
          [colExample setHasHorizontalScroller: NO];
  	  [colExample setHasVerticalScroller: YES]; 

          resizer = [[Resizer alloc] initForController: self];
          [resizer setFrame: NSMakeRect(0, 0, RESIZER_W, RESIZER_W)];
          [resizerBox setContentView: resizer];
          [self tile]; 
            
          /* Internationalization */
          [controlsbox setTitle: NSLocalizedString(@"Column Width", @"")];  
          [setButt setTitle: NSLocalizedString(@"Use Default Settings", @"")];  
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
  return NSLocalizedString(@"Browser", @"");
}

- (void)tile
{
  NSRect frameRect;

  frameRect = [colExample frame];
  frameRect.size.width = columnsWidth;
  [colExample setFrame: frameRect];    
  [resizerBox setFrameOrigin: NSMakePoint(columnsWidth + frameRect.origin.x, RESIZER_Y)];  
  [controlsbox setNeedsDisplay: YES];
}

- (void)mouseDownOnResizer:(NSEvent *)theEvent
{
  NSApplication	*app = [NSApplication sharedApplication];
  int orx = (int)[controlsbox convertPoint: [theEvent locationInWindow] fromView: nil].x;
  NSUInteger eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;
  int newWidth = (int)[colExample bounds].size.width;
  NSEvent	*e;
  
  [controlsbox lockFocus];
  [[NSRunLoop currentRunLoop] limitDateForMode: NSEventTrackingRunLoopMode];

  e = [app nextEventMatchingMask: eventMask
                       untilDate: [NSDate distantFuture]
                          inMode: NSEventTrackingRunLoopMode
                         dequeue: YES];

  while ([e type] != NSLeftMouseUp)
    {
      int x = (int)[controlsbox convertPoint: [e locationInWindow] fromView: nil].x;
      int diff = x - orx;
    
    if ((newWidth + diff < MAXIMUM_WIDTH) && (newWidth + diff > MINIMUM_WIDTH))
      {
        NSRect frameExample;

        frameExample = [colExample frame];
        newWidth += diff;      
        [resizerBox setFrameOrigin: NSMakePoint(frameExample.origin.x + newWidth, RESIZER_Y)];
        [resizerBox setNeedsDisplay: YES];
  
        frameExample.size.width = newWidth;
        [colExample setFrame: frameExample];
        [colExample setNeedsDisplay: YES];  

        [controlsbox setNeedsDisplay: YES];

        orx = x;
    }
    
    e = [app nextEventMatchingMask: eventMask
                         untilDate: [NSDate distantFuture]
                            inMode: NSEventTrackingRunLoopMode
                           dequeue: YES];
    }
  
  [controlsbox unlockFocus];
  [self setNewWidth: (int)[colExample bounds].size.width];
  [setButt setEnabled: YES];
}

- (void)setNewWidth:(int)w
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setObject: [NSString stringWithFormat: @"%i", w]
               forKey: @"browserColsWidth"];
               
  columnsWidth = w;
  
  [[NSNotificationCenter defaultCenter]
 				 postNotificationName: @"GWBrowserColumnWidthChangedNotification"
                                               object: [NSNumber numberWithInt: w]];  
  
  [defaults synchronize];                           
}

- (IBAction)setDefaultWidth:(id)sender
{
  columnsWidth = DEFAULT_WIDTH;
  [self setNewWidth: columnsWidth];
  [self tile];
  [setButt setEnabled: NO];
}

@end
