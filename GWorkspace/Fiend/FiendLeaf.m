/* FiendLeaf.m
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
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "GWLib.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWLib.h>
  #endif
#include "FiendLeaf.h"
#include "Fiend.h"
#include "GWorkspace.h"
#include "GNUstep.h"
#include <math.h>

#define INTERVALS 40.0

@implementation LeafPosition

- (id)initWithPosX:(int)px posY:(int)py relativeToPoint:(NSPoint)p
{
  self = [super init];
  posx = px;
  posy = py;
  r = NSMakeRect((int)p.x + (64 * posx), (int)p.y + (64 * posy), 64, 64);   
  return self;
}

- (NSRect)lfrect
{
  return r;
}

- (int)posx
{
  return posx;
}

- (int)posy
{
  return posy;
}

- (BOOL)containsPoint:(NSPoint)p
{
	return NSPointInRect(p, r);
}

@end


@implementation FiendLeaf

- (void)dealloc
{
  TEST_RELEASE (myPath);
  TEST_RELEASE (myType);
  RELEASE (tile);
  TEST_RELEASE (hightile);	
  TEST_RELEASE (icon);
  TEST_RELEASE (namelabel);
	[super dealloc];
}

- (id)initWithPosX:(int)px
              posY:(int)py
   relativeToPoint:(NSPoint)p
           forPath:(NSString *)apath
           inFiend:(Fiend *)afiend 
        ghostImage:(NSImage *)ghostimage
{
  NSWindow *win;
  
	self = [super init];

  win = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 64, 64)
					                  styleMask: NSBorderlessWindowMask  
                              backing: NSBackingStoreRetained defer: NO];
  [self setFrame: [[win contentView] frame]];  
  [win setContentView: self];		
  [self setPosX: px posY: py relativeToPoint: p];
  
  if (apath != nil) {
    NSString *defApp, *type;
    
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
		gw = [GWorkspace gworkspace];

    ASSIGN (myPath, apath);
    
    [ws getInfoForFile: myPath application: &defApp type: &type];      
    ASSIGN (myType, type);
		isPakage = [GWLib isPakageAtPath: myPath];
		
    ASSIGN (icon, [GWLib iconForFile: myPath ofType: myType]); 
    
    if ([myType isEqualToString: NSApplicationFileType] == NO) {
			NSString *name;
			
			if ([myPath isEqualToString: fixPath(@"/", 0)]) {
				NSHost *host = [NSHost currentHost];
				NSString *hname = [host name];
				NSRange range = [hname rangeOfString: @"."];
				if (range.length != 0) {	
					hname = [hname substringToIndex: range.location];
				} 						
				name = hname;
			} else {
    		name = [myPath lastPathComponent];
			}
			
      namelabel = [NSTextFieldCell new];
      [namelabel setFont: [NSFont systemFontOfSize: 10]];
      [namelabel setBordered: NO];
      [namelabel setAlignment: NSCenterTextAlignment];
	    [namelabel setStringValue: cutFileLabelText(name, namelabel, 50)];   
    } else {    
      namelabel = nil;
    }    

    [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];  

  } else {
    icon = nil;
  }
  
	ASSIGN (tile, [NSImage imageNamed: @"common_Tile.tiff"]);
	
  if (ghostimage == nil) {
    tile = [NSImage imageNamed: @"common_Tile.tiff"];
    fiend = afiend;
		isGhost = NO;
  } else {
		ASSIGN (icon, ghostimage);
		ASSIGN (hightile, [NSImage imageNamed: @"TileHighlight.tiff"]);
		isGhost = YES;
	}

  isDragTarget = NO;
	dissolving = NO;
	
  return self;
}

- (void)setPosX:(int)px posY:(int)py relativeToPoint:(NSPoint)p
{
  posx = px;
  posy = py;
  [[self window] setFrameOrigin: NSMakePoint(p.x + (64 * posx), p.y + (64 * posy))];
}

- (int)posx
{
  return posx;
}

- (int)posy
{
  return posy;
}

- (NSPoint)iconPosition
{
	NSWindow *win = [self window];
	NSPoint p = [win frame].origin;
	NSSize s = [icon size];
	NSSize shift = NSMakeSize((64 - s.width) / 2, (64 - s.height) / 2);
	
	return NSMakePoint(p.x + shift.width, p.y + shift.height);
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (NSString *)myPath
{
  return myPath;
}

- (NSString *)myType
{
	return myType;
}

- (NSImage *)icon
{
	return icon;
}

- (void)startDissolve
{
	dissolving = YES;
	dissCounter = 0;
	dissFraction = 0.2;
	dissTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 target: self
		    					selector: @selector(display) userInfo: nil repeats: YES];
	RETAIN (dissTimer);
}

- (BOOL)dissolveAndReturnWhenDone
{
	dissolving = YES;
	dissCounter = 0;
	dissFraction = 0.2;

	while (1) {
		NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.02];
		[[NSRunLoop currentRunLoop] runUntilDate: date];
		[self display];
	
		if (dissolving == NO) {
			break;
		}
	}
	
	return YES;
}

- (void)mouseDown:(NSEvent*)theEvent
{  
  NSEvent *nextEvent;
  NSPoint location, lastLocation, origin;
  NSWindow *win;

	[fiend orderFrontLeaves];
	
	if ([theEvent clickCount] > 1) {   
    if ([myType isEqualToString: NSApplicationFileType]) {
//      NSArray *launched = [ws launchedApplications];
//      BOOL found = NO;
//      int i;

//      for (i = 0; i < [launched count]; i++) {
//        NSDictionary *dict = [launched objectAtIndex: i];
//        NSString *applname = [dict objectForKey: @"NSApplicationName"]; 

//        if ([applname isEqual: myPath]) {
//          found = YES;
//          break;
//        }
//      }

//      if (found == NO) {
        [ws launchApplication: myPath];
        [self startDissolve];
//      }
    
    } else if ([myType isEqualToString: NSPlainFileType]
            			|| [myType isEqualToString: NSDirectoryFileType]
            					|| [myType isEqualToString: NSFilesystemFileType]) { 
      NSArray *paths = [NSArray arrayWithObjects: myPath, nil];    
      [gw openSelectedPaths: paths newViewer: YES];   
    }    
    return;
  }  
    
  win = [self window]; 
	[win orderFront: self];
	
  nextEvent = [win nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
  if ([nextEvent type] == NSLeftMouseUp) {
		[win orderBack: self];
    return;
  }
     
  lastLocation = [theEvent locationInWindow];  

  while (1) {
	  nextEvent = [win nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];

    if ([nextEvent type] == NSLeftMouseUp) {
      break;
    }

 		location = [win mouseLocationOutsideOfEventStream];
    origin = [win frame].origin;
		origin.x += (location.x - lastLocation.x);
		origin.y += (location.y - lastLocation.y);
    [win setFrameOrigin: origin];
    
    [fiend draggedFiendLeaf: self atPoint: origin mouseUp: NO];  
  } 
	
	[win orderBack: self];
  [fiend draggedFiendLeaf: self atPoint: [win frame].origin mouseUp: YES];  
}                                                        

- (void)drawRect:(NSRect)rect
{
  NSSize iconSize;
  NSPoint iconPosn;
  NSRect textFrame;
  
  [self lockFocus];
  
	if ((isGhost == NO) && (dissolving == NO)) {
		[tile compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];
	} else if (dissolving == NO) {
		[hightile compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];
	}
	
  if (icon != nil) {
    iconSize = [icon size];

    if (isGhost || ([myType isEqualToString: NSApplicationFileType] == YES)) {
      iconPosn = NSMakePoint((64 - iconSize.width) / 2.0, (64 - iconSize.height) / 2.0);
    } else {
      iconPosn = NSMakePoint((64 - iconSize.width) / 2.0, 13);
    }

		if (dissolving) {		
			if (dissCounter++ >= 5) {
				dissFraction += 0.1;
			}
			
			[[NSColor whiteColor] set];
			NSRectFill(rect);
			[tile dissolveToPoint: NSZeroPoint fraction: fabs(dissFraction)];
			[icon dissolveToPoint: iconPosn fraction: fabs(dissFraction)];

			if (dissFraction >= 1) {
  			if (dissTimer && [dissTimer isValid]) {
      		[dissTimer invalidate];
      		DESTROY (dissTimer);
    		}
				dissolving = NO;
			} 

		  [self unlockFocus];
			return;
		}

		if (isGhost == NO) {
    	[icon compositeToPoint: iconPosn operation: NSCompositeSourceOver];
		} else {
			[icon dissolveToPoint: iconPosn fraction: 0.2];
		}
		
    if (namelabel != nil) {
      textFrame = NSMakeRect(4, 3, 56, 9);    
	    [namelabel setDrawsBackground: NO];
	    [namelabel drawWithFrame: textFrame inView: self];
    }
  }
	  
  [self unlockFocus];
}

@end

@implementation FiendLeaf (DraggingDestination)

- (BOOL)isDragTarget
{
  return isDragTarget;
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *buff;
	int i, count;

  [fiend verifyDraggingExited: self];

  if ((([myType isEqual: NSDirectoryFileType] == NO)
          && ([myType isEqual: NSFilesystemFileType] == NO)
          && ([myType isEqual: NSApplicationFileType] == NO))
          || (isPakage && ([myType isEqual: NSApplicationFileType] == NO))) {
    return NSDragOperationNone;  
  }

	pb = [sender draggingPasteboard];
  if([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
	  count = [sourcePaths count];
	  fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	  if (count == 0) {
		  return NSDragOperationNone;
    } 

    if ([myType isEqualToString: NSApplicationFileType] == NO) {

	    if ([fm isWritableFileAtPath: myPath] == NO) {
		    return NSDragOperationNone;
	    }

	    if ([myPath isEqualToString: fromPath]) {
		    return NSDragOperationNone;
      }  

	    for (i = 0; i < count; i++) {
		    if ([myPath isEqualToString: [sourcePaths objectAtIndex: i]]) {
		      return NSDragOperationNone;
		    }
	    }

	    buff = [NSString stringWithString: myPath];
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
			
      ASSIGN (icon, [NSImage imageNamed: @"FileIcon_Directory_Open.tiff"]);
      [self setNeedsDisplay: YES];
			
			sourceDragMask = [sender draggingSourceOperationMask];

			if (sourceDragMask == NSDragOperationCopy) {
				return NSDragOperationCopy;
			} else if (sourceDragMask == NSDragOperationLink) {
				return NSDragOperationLink;
			} else {
				return NSDragOperationAll;
			}

    } else {
			if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
				return NSDragOperationNone;
			}

	    for (i = 0; i < [sourcePaths count]; i++) {
				NSString *fpath, *app, *type;

				fpath = [sourcePaths objectAtIndex: i];
				[ws getInfoForFile: fpath application: &app type: &type];

				if (type != NSPlainFileType) {
					return NSDragOperationNone;
				}
	    }

      isDragTarget = YES;
  	  return NSDragOperationAll;  
    }
  }
  
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	
	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}

  if ((([myType isEqual: NSDirectoryFileType] == NO)
          && ([myType isEqual: NSFilesystemFileType] == NO)
          && ([myType isEqual: NSApplicationFileType] == NO))
          || (isPakage && ([myType isEqual: NSApplicationFileType] == NO))) {
    return NSDragOperationNone;  
  }

	if ([myType isEqualToString: NSApplicationFileType] == NO) {
		if (sourceDragMask == NSDragOperationCopy) {
			return NSDragOperationCopy;
		} else if (sourceDragMask == NSDragOperationLink) {
			return NSDragOperationLink;
		} else {
			return NSDragOperationAll;
		}
	} else {
		if ((sourceDragMask != NSDragOperationCopy) 
											&& (sourceDragMask != NSDragOperationLink)) {
			return NSDragOperationAll;
		}
	}
	
	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if(isDragTarget == YES) {
    isDragTarget = NO;  
    if ([myType isEqualToString: NSApplicationFileType] == NO) {
      ASSIGN (icon, [GWLib iconForFile: myPath ofType: myType]);
      [self setNeedsDisplay: YES];
    }
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
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  NSPasteboard *pb = [sender draggingPasteboard];  
  NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
	int i = 0;
	
  if ([myType isEqualToString: NSApplicationFileType] == NO) {
    NSString *operation, *source;
    NSMutableArray *files;
    int tag;

    ASSIGN (icon, [GWLib iconForFile: myPath ofType: myType]);
    [self setNeedsDisplay: YES];

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
							          destination: myPath files: files tag: &tag];

  } else {     
	  for(i = 0; i < [sourcePaths count]; i++) {   
      NSString *path, *defApp, *type;
      
      path = [sourcePaths objectAtIndex: i]; 
      [ws getInfoForFile: path application: &defApp type: &type];    
      if ([type isEqualToString: NSPlainFileType] == YES) {
        [ws openFile: path withApplication: myPath];
      }
    }
  }
  
	isDragTarget = NO;
}

@end
