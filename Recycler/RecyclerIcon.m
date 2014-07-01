/* RecyclerIcon.m
 *  
 * Copyright (C) 2004-2014 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
 *
 * Date: June 2004
 *
 * This file is part of the GNUstep Recycler application
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

#import "Recycler.h"
#import "RecyclerIcon.h"


#define ISIZE 48

static id <DesktopApplication> desktopApp = nil;

@implementation RecyclerIcon

- (void)dealloc
{
  RELEASE (trashFullIcon);
  [super dealloc];
}

+ (void)initialize
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *appname = [defaults stringForKey: @"DesktopApplicationName"];
  NSString *selname = [defaults stringForKey: @"DesktopApplicationSelName"];

  if (appname && selname) {
		Class desktopAppClass = [[NSBundle mainBundle] principalClass];
    SEL sel = NSSelectorFromString(selname);

    desktopApp = [desktopAppClass performSelector: sel];
  }
}

- (id)initWithRecyclerNode:(FSNode *)anode
{
  self = [super initForNode: anode
               nodeInfoType: FSNInfoNameType
               extendedType: nil
                   iconSize: ISIZE
               iconPosition: NSImageOnly
                  labelFont: [NSFont systemFontOfSize: 12]
                  textColor: [NSColor controlTextColor]
                  gridIndex: 0
                  dndSource: NO
                  acceptDnd: YES
                  slideBack: NO];

  if (self) {
    NSArray *subNodes = [node subNodes];
    int count = [subNodes count];
    int i;
    
    ASSIGN (icon, [fsnodeRep trashIconOfSize: icnBounds.size.width]);
    ASSIGN (trashFullIcon, [fsnodeRep trashFullIconOfSize: icnBounds.size.width]);

    for (i = 0; i < [subNodes count]; i++) {
      if ([[subNodes objectAtIndex: i] isReserved]) {
        count--;
      }
    }
    
    trashFull = (count != 0);
      
    [self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];    
  
    ws = [NSWorkspace sharedWorkspace];
  }

  return self;
}

- (void)setTrashFull:(BOOL)value
{
  trashFull = value;
  [self setNeedsDisplay: YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  if ([theEvent clickCount] == 1) {
    if ([(Recycler *)desktopApp isDocked] == NO) {
      NSWindow *win = [self window];
      NSPoint	lastLocation = [theEvent locationInWindow];
      NSPoint	location;
      NSDate *theDistantFuture = [NSDate distantFuture];
      BOOL done = NO;
      unsigned eventMask = NSLeftMouseDownMask | NSLeftMouseUpMask
	                | NSPeriodicMask | NSOtherMouseUpMask | NSRightMouseUpMask;

      [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.02];

      while (done == NO) {
        theEvent = [NSApp nextEventMatchingMask: eventMask
					                            untilDate: theDistantFuture
					                               inMode: NSEventTrackingRunLoopMode
					                              dequeue: YES];

        switch ([theEvent type]) {
          case NSRightMouseUp:
          case NSOtherMouseUp:
          case NSLeftMouseUp:
		        done = YES;
		        break;

          case NSPeriodic:
		        location = [win mouseLocationOutsideOfEventStream];

            if (NSEqualPoints(location, lastLocation) == NO) {
		          NSPoint	origin = [win frame].origin;
		          origin.x += (location.x - lastLocation.x);
		          origin.y += (location.y - lastLocation.y);
		          [win setFrameOrigin: origin];
		        }
		        break;

          default:
		        break;
        }
      }

      [NSEvent stopPeriodicEvents];
    }
    else
      [[self nextResponder] tryToPerform:_cmd with:theEvent];
  } else {  
    id <workspaceAppProtocol> workspaceApp = [desktopApp workspaceApplication];

    if (workspaceApp) {
      NSString *path = [node path];
      [workspaceApp selectFile: path inFileViewerRootedAtPath: path];
    }      
  }
}

- (void)drawRect:(NSRect)rect
{   
  if (trashFull) {
    [trashFullIcon compositeToPoint: icnPoint operation: NSCompositeSourceOver];
  } else {
    [icon compositeToPoint: icnPoint operation: NSCompositeSourceOver];
  }
}

@end


@implementation RecyclerIcon (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
              
  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    isDragTarget = YES;  
    return NSDragOperationAll;
  }
  
  isDragTarget = NO; 
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];

  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    isDragTarget = YES;  
    [self select];
    return NSDragOperationAll;
  }
  
  isDragTarget = NO; 
  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  isDragTarget = NO;  
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  return isDragTarget;
}

// FIXME: this code is now very similar to what is in DockIcon, it should be generalized

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];

  [self unselect];
  isDragTarget = NO;
  
  if ([[pb types] containsObject: NSFilenamesPboardType])
    {
      NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
      NSString *source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
      NSArray *vpaths = [ws mountedLocalVolumePaths];
      NSMutableArray *files = [NSMutableArray array];
      NSMutableArray *umountPaths = [NSMutableArray array];
      NSUInteger i;


      for (i = 0; i < [sourcePaths count]; i++)
        {
          NSString *srcpath = [sourcePaths objectAtIndex: i];

          if ([vpaths containsObject: srcpath])
            {
              [umountPaths addObject: srcpath];
            }
          else
            {
              [files addObject: [srcpath lastPathComponent]];
            }
        }


      for (i = 0; i < [umountPaths count]; i++)
        {
          NSString *umpath = [umountPaths objectAtIndex: i];
      
          if (![ws unmountAndEjectDeviceAtPath: umpath])
            {
              NSString *err = NSLocalizedString(@"Error", @"");
              NSString *msg = NSLocalizedString(@"You are not allowed to umount\n", @"");
              NSString *buttstr = NSLocalizedString(@"Continue", @"");
              NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, umpath], buttstr, nil, nil);         
            }
        }


      if ([files count])
        {
          if ([[NSFileManager defaultManager] isWritableFileAtPath: source] == NO)
            {
              NSString *err = NSLocalizedString(@"Error", @"");
              NSString *msg = NSLocalizedString(@"You do not have write permission\nfor", @"");
              NSString *buttstr = NSLocalizedString(@"Continue", @"");
              NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, source], buttstr, nil, nil);   
              return;
            }

          [desktopApp performFileOperation: NSWorkspaceRecycleOperation
                                    source: source
                               destination: [node path]
                                     files: files];
        }
    }
}

@end

