 /*  -*-objc-*-
 *  DesktopViewIcon.m: Implementation of the DesktopViewIcon Class 
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
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "IconViewsIcon.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#define CHECK_LOCK if (locked) return
#define CHECK_LOCK_RET(x) if (locked) return x

@implementation DesktopViewIcon

- (void)setPaths:(NSArray *)fpaths
{
  [super setPaths: fpaths];
  [(NSView *)container resizeWithOldSuperviewSize: [(NSView *)container frame].size]; 
}

- (void)select
{
  NSTimer *t;

  isSelect = YES;
	[self setNeedsDisplay: YES];

  t = [NSTimer timerWithTimeInterval: 0.5 target: self 
          selector: @selector(unselectFromTimer:) userInfo: nil repeats: NO];                                             
  [[NSRunLoop currentRunLoop] addTimer: t forMode: NSDefaultRunLoopMode];
}

- (void)unselect
{
	isSelect = NO;
	[self setNeedsDisplay: YES];
}

- (void)unselectFromTimer:(id)sender
{
  [self unselect];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if ([theEvent clickCount] > 1) { 
		int i;
	
		for (i = 0; i < [paths count]; i++) {
			NSString *path, *defApp, *tp;
			
	  	path = [paths objectAtIndex: i];
	  	[ws getInfoForFile: path application: &defApp type: &tp]; 
	 
	  	if ((tp == NSApplicationFileType) && (locked == NO)) {
				unsigned int modifier = [theEvent modifierFlags];
		
				[container openCurrentSelection: [NSArray arrayWithObject: path] 
															newViewer: (modifier == NSControlKeyMask)];
			} else {
				if (locked == NO) {		
    			[container openCurrentSelection: [NSArray arrayWithObject: path] 
																newViewer: YES]; 
				} else {				
					if ((tp == NSDirectoryFileType) || (tp == NSFilesystemFileType)) {
    				[container openCurrentSelection: [NSArray arrayWithObject: path] 
																	newViewer: YES]; 
					}				
				}
			}
		}
		
		[self unselect];
		return;
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSEvent *nextEvent;
  BOOL startdnd = NO;

  [container unselectOtherIcons: self];
  
	if ([theEvent clickCount] == 1) {     
    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];
    if ([nextEvent type] == NSLeftMouseUp) {
      NSSize ss = [self frame].size;
      NSSize is = [icon size];
      NSPoint p = NSMakePoint((ss.width - is.width) / 2, (ss.height - is.height) / 2);	

      p = [self convertPoint: p toView: nil];
      p = [[self window] convertBaseToScreen: p];

      [self select];

      [container setCurrentSelection: paths 
                        animateImage: icon 
                     startingAtPoint: p];
      return;    
    }

    [self unselect];

    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
        return;
      }

      if ([nextEvent type] == NSLeftMouseDragged) {
	      if(dragdelay < 5) {
          dragdelay++;
        } else {        
          startdnd = YES;        
          break;
        }
      }
    }

    if (startdnd == YES) {  
      [self startExternalDragOnEvent: nextEvent];    
    }   
  }            
}

- (void)startExternalDragOnEvent:(NSEvent *)event
{
	NSEvent *nextEvent;
  NSPoint dragPoint;
  NSPasteboard *pb;

	nextEvent = [[self window] nextEventMatchingMask:
    							NSLeftMouseUpMask | NSLeftMouseDraggedMask];

  if([nextEvent type] != NSLeftMouseDragged) {
    [self unselect];
   	return;
  }
  
  dragPoint = [nextEvent locationInWindow];
  dragPoint = [self convertPoint: dragPoint fromView: nil];

	pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  [self declareAndSetShapeOnPasteboard: pb];
      
  [self dragImage: icon
               at: dragPoint 
           offset: NSZeroSize
            event: event
       pasteboard: pb
           source: self
        slideBack: NO];
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
  if (flag == NO) {
    aPoint = [self convertPoint: aPoint toView: self];
    
    if (NSPointInRect(aPoint, [self frame]) 
                      || NSPointInRect(aPoint, [namelabel frame])) {
      dragdelay = 0;
      onSelf = NO;
      [self unselect];
      return;
    }
  
    [container removeIcon: self];
    
  } else {
    dragdelay = 0;
    onSelf = NO;
    [self unselect];
  }
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  [pb declareTypes: dndtypes owner: nil];
    
  if ([pb setPropertyList: paths forType: NSFilenamesPboardType] == NO) {
    return;
  }
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *buff;
	NSString *iconPath;
	int i, count;

	CHECK_LOCK_RET (NSDragOperationNone);

	pb = [sender draggingPasteboard];
  if([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
    
    if ([paths isEqualToArray: sourcePaths]) {
      onSelf = YES;
      isDragTarget = YES;
			[self setNeedsDisplay: YES];
      return NSDragOperationAll;
    }

    if ((([type isEqualToString: NSDirectoryFileType] == NO)
       && ([type isEqualToString: NSFilesystemFileType] == NO)) || isPakage) {
      return NSDragOperationNone;
    }
    
	  count = [sourcePaths count];
	  fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
    
	  if (count == 0) {
		  return NSDragOperationNone;
    } 
  
	  if ([fm isWritableFileAtPath: fullPath] == NO) {
		  return NSDragOperationNone;
	  }
  
	  if ([fullPath isEqualToString: fromPath]) {
		  return NSDragOperationNone;
    }  
  
	  for (i = 0; i < count; i++) {
		  if ([fullPath isEqualToString: [sourcePaths objectAtIndex: i]]) {
		    return NSDragOperationNone;
		  }
	  }
       
	  buff = [NSString stringWithString: fullPath];
	  while (1) {
		  for (i = 0; i < count; i++) {
			  if ([buff isEqualToString: [sourcePaths objectAtIndex: i]]) {
 		      return NSDragOperationNone;
			  }
		  }
      if ([buff isEqualToString: fixPath(@"/", 0)] == YES) {
        break;
      }            
		  buff = [buff stringByDeletingLastPathComponent];
	  }

    isDragTarget = YES;
		
    iconPath =  [fullPath stringByAppendingPathComponent: @".opendir.tiff"];

    if ([fm isReadableFileAtPath: iconPath]) {
      NSImage *img = [[NSImage alloc] initWithContentsOfFile: iconPath];
	    
      if (img) {
        ASSIGN (icon, img);
        RELEASE (img);
      } else {
        ASSIGN (icon, [NSImage imageNamed: @"FileIcon_Directory_Open.tiff"]);
      }      
    } else {
	    ASSIGN (icon, [NSImage imageNamed: @"FileIcon_Directory_Open.tiff"]);    
    }

    [self setNeedsDisplay: YES];

		sourceDragMask = [sender draggingSourceOperationMask];
	
		if (sourceDragMask == NSDragOperationCopy) {
			return NSDragOperationCopy;
		} else if (sourceDragMask == NSDragOperationLink) {
			return NSDragOperationLink;
		} else {
			return NSDragOperationAll;
		}
  }
      
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;
	
	if (!isDragTarget || locked || isPakage) {
		return NSDragOperationNone;
	}

	sourceDragMask = [sender draggingSourceOperationMask];
	
	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}

	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if(isDragTarget == YES) {
    isDragTarget = NO;
    if (onSelf == NO) {      
      ASSIGN (icon, [gw iconForFile: fullPath ofType: type]);
      [self setNeedsDisplay: YES];
    }
    onSelf = NO;
  }
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
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
  int i, tag;

  isDragTarget = NO;

  if (onSelf == YES) {
		NSView *view = (NSView *)container;
		[view resizeWithOldSuperviewSize: [view frame].size]; 
    onSelf = NO;		
    return;
  }
  
  ASSIGN (icon, [gw iconForFile: fullPath ofType: type]);
  [self setNeedsDisplay: YES];

	sourceDragMask = [sender draggingSourceOperationMask];  
  pb = [sender draggingPasteboard];
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];  	 
  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	if ([source isEqualToString: [gw trashPath]]) {
		operation = GWorkspaceRecycleOutOperation;
	} else {
		if (sourceDragMask == NSDragOperationCopy) {
			operation = NSWorkspaceCopyOperation;
		} else if (sourceDragMask == NSDragOperationLink) {
			operation = NSWorkspaceLinkOperation;
		} else {
			operation = NSWorkspaceMoveOperation;
		}
  }
  
  files = [NSMutableArray arrayWithCapacity: 1];    
  for(i = 0; i < [sourcePaths count]; i++) {    
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  }  
    
  [gw performFileOperation: operation source: source
							  destination: fullPath files: files tag: &tag];
}

@end
