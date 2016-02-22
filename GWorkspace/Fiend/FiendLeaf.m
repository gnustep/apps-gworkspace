/* FiendLeaf.m
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "GWFunctions.h"
#import "FiendLeaf.h"
#import "Fiend.h"
#import "GWorkspace.h"
#import "FSNodeRep.h"
#import "FSNFunctions.h"


#define ICON_SIZE 48
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
  RELEASE (node);
  RELEASE (layerName);
  RELEASE (tile);
  RELEASE (hightile);	
  RELEASE (icon);
  RELEASE (namelabel);
  [super dealloc];
}

- (id)initWithPosX:(int)px
              posY:(int)py
   relativeToPoint:(NSPoint)p
           forPath:(NSString *)apath
           inFiend:(Fiend *)afiend 
         layerName:(NSString *)lname 
        ghostImage:(NSImage *)ghostimage
{
  NSWindow *win;
  
  self = [super init];

  win = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 64, 64)
					                  styleMask: NSBorderlessWindowMask  
                              backing: NSBackingStoreBuffered defer: NO];
  [win setExcludedFromWindowsMenu: YES];
  [self setFrame: [[win contentView] bounds]];  
  [win setContentView: self];		
  [self setPosX: px posY: py relativeToPoint: p];
  
  if (apath && lname) {
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
		gw = [GWorkspace gworkspace];

    ASSIGN (layerName, lname);

    ASSIGN (node, [FSNode nodeWithPath: apath]);
    
    ASSIGN (icon, [[FSNodeRep sharedInstance] iconOfSize: ICON_SIZE 
                                                 forNode: node]); 
    
    if ([node isApplication] == NO) {
			NSString *name;
			
			if ([[node path] isEqual: path_separator()]) {
				NSHost *host = [NSHost currentHost];
				NSString *hname = [host name];
				NSRange range = [hname rangeOfString: @"."];
				if (range.length != 0) {	
					hname = [hname substringToIndex: range.location];
				} 						
				name = hname;
			} else {
    		name = [node name];
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

- (FSNode *)node
{
  return node;
}

- (NSImage *)icon
{
	return icon;
}

- (NSString *)layerName
{
  return layerName;
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
	[fiend orderFrontLeaves];
	
  if ([node isValid]) {
    NSEvent *nextEvent;
    NSPoint location, lastLocation, origin;
    NSWindow *win;
  
	  if ([theEvent clickCount] > 1) {   
      if ([node isApplication]) {
        NS_DURING
          {
        [ws launchApplication: [node path]];
        [self startDissolve];
          }
        NS_HANDLER
          {
        NSRunAlertPanel(NSLocalizedString(@"error", @""), 
            [NSString stringWithFormat: @"%@ %@!", 
                  NSLocalizedString(@"Can't open ", @""), [node name]],
                                          NSLocalizedString(@"OK", @""), 
                                          nil, 
                                          nil);                                     
          }
        NS_ENDHANDLER  

      } else if ([node isPlain] || [node isDirectory] || [node isMountPoint]) { 
        NSArray *paths = [NSArray arrayWithObjects: [node path], nil];    
        [gw openSelectedPaths: paths newViewer: YES];   
      }    
      return;
    }  

    win = [self window]; 
	  [win orderFront: self];

    nextEvent = [win nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
    if ([nextEvent type] == NSLeftMouseUp) {
#if 0 // Ordering a window back after a single mouse click is outright annoying
		  [win orderBack: self];
#endif
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

#if 0 // Ordering a window back after a single mouse click is outright annoying
	  [win orderBack: self];
#endif
    [fiend draggedFiendLeaf: self atPoint: [win frame].origin mouseUp: YES];
  
  } else {  
    [fiend removeInvalidLeaf: self];
  }
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

    if (isGhost || [node isApplication]) {
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

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask = 0;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *buff;
	int i, count;

  [fiend verifyDraggingExited: self];

  if ((([node isDirectory] == NO) && ([node isMountPoint] == NO) && ([node isApplication] == NO))
            || ([node isPackage] && ([node isApplication] == NO))) {
    return NSDragOperationNone;  
  }

	pb = [sender draggingPasteboard];
  
  if ([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
	  count = [sourcePaths count];
	  fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	  if (count == 0) {
		  return NSDragOperationNone;
    } 

    if ([node isApplication] == NO) {
	    if ([node isWritable] == NO) {
		    return NSDragOperationNone;
	    }

	    if ([[node path] isEqual: fromPath]) {
		    return NSDragOperationNone;
      }  

	    for (i = 0; i < count; i++) {
		    if ([[node path] isEqual: [sourcePaths objectAtIndex: i]]) {
		      return NSDragOperationNone;
		    }
	    }

	    buff = [NSString stringWithString: [node path]];
      
	    while (1) {
		    for (i = 0; i < count; i++) {
			    if ([buff isEqual: [sourcePaths objectAtIndex: i]]) {
 		        return NSDragOperationNone;
			    }
		    }
        if ([buff isEqual: path_separator()]) {
          break;
        }            
		    buff = [buff stringByDeletingLastPathComponent];
	    }

      if ([node isDirectory] && [node isParentOfPath: fromPath]) {
        NSArray *subNodes = [node subNodes];

        for (i = 0; i < [subNodes count]; i++) {
          FSNode *nd = [subNodes objectAtIndex: i];

          if ([nd isDirectory]) {
            int j;

            for (j = 0; j < count; j++) {
              NSString *fname = [[sourcePaths objectAtIndex: j] lastPathComponent];

              if ([[nd name] isEqual: fname]) {
                return NSDragOperationNone;
              }
            }
          }
        }
      }	

      isDragTarget = YES;
      forceCopy = NO;
			
      ASSIGN (icon, [[FSNodeRep sharedInstance] openFolderIconOfSize: ICON_SIZE 
                                                             forNode: node]);
      [self setNeedsDisplay: YES];
			
			sourceDragMask = [sender draggingSourceOperationMask];

			if (sourceDragMask == NSDragOperationCopy) {
				return NSDragOperationCopy;
			} else if (sourceDragMask == NSDragOperationLink) {
				return NSDragOperationLink;
			} else {
        if ([fm isWritableFileAtPath: fromPath]) {
          return NSDragOperationAll;			
        } else {
          forceCopy = YES;
			    return NSDragOperationCopy;			
        }
			}

    } else {
			if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
				return NSDragOperationNone;
			}

	    for (i = 0; i < [sourcePaths count]; i++) {
        FSNode *fnode = [FSNode nodeWithPath: [sourcePaths objectAtIndex: i]];
        
				if ([fnode isPlain] == NO) {
					return NSDragOperationNone;
				}
	    }

      ASSIGN (icon, [[FSNodeRep sharedInstance] openFolderIconOfSize: ICON_SIZE 
                                                             forNode: node]);
      [self setNeedsDisplay: YES];
      isDragTarget = YES;
  	  return NSDragOperationAll;  
    }
  }
  
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	
	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}

  if ((([node isDirectory] == NO) && ([node isMountPoint] == NO) && ([node isApplication] == NO))
            || ([node isPackage] && ([node isApplication] == NO))) {
    return NSDragOperationNone;  
  }

	if ([node isApplication] == NO) {
		if (sourceDragMask == NSDragOperationCopy) {
			return NSDragOperationCopy;
		} else if (sourceDragMask == NSDragOperationLink) {
			return NSDragOperationLink;
		} else {
		  return forceCopy ? NSDragOperationCopy : NSDragOperationAll;
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
  if (isDragTarget) {
    isDragTarget = NO;  
    ASSIGN (icon, [[FSNodeRep sharedInstance] iconOfSize: ICON_SIZE 
                                                 forNode: node]);
    [self setNeedsDisplay: YES];
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
  NSUInteger i = 0;

  ASSIGN (icon, [[FSNodeRep sharedInstance] iconOfSize: ICON_SIZE 
                                               forNode: node]);
  [self setNeedsDisplay: YES];
	
  if ([node isApplication] == NO) {
    NSString *operation, *source;
    NSMutableArray *files;
    NSInteger tag;
    
    source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

		if ([source isEqual: [gw trashPath]]) {
			operation = @"GWorkspaceRecycleOutOperation";
		} else {
			if (sourceDragMask == NSDragOperationCopy) {
				operation = NSWorkspaceCopyOperation;
			} else if (sourceDragMask == NSDragOperationLink) {
				operation = NSWorkspaceLinkOperation;
			} else {
        if ([fm isWritableFileAtPath: source]) {
			    operation = NSWorkspaceMoveOperation;
        } else {
			    operation = NSWorkspaceCopyOperation;
        }
			}
  	}
  
    files = [NSMutableArray arrayWithCapacity: 1];    
	  for(i = 0; i < [sourcePaths count]; i++) {    
      [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
    }  

    [gw performFileOperation: operation source: source
							          destination: [node path] files: files tag: &tag];

  } else {     
	  for(i = 0; i < [sourcePaths count]; i++) {   
      FSNode *draggednode = [FSNode nodeWithPath: [sourcePaths objectAtIndex: i]];
      
      if ([draggednode isPlain]) {
        NS_DURING
          {
        [ws openFile: [draggednode path] withApplication: [node path]];
          }
        NS_HANDLER
          {
        NSRunAlertPanel(NSLocalizedString(@"error", @""), 
            [NSString stringWithFormat: @"%@ %@!", 
                  NSLocalizedString(@"Can't open ", @""), [draggednode name]],
                                          NSLocalizedString(@"OK", @""), 
                                          nil, 
                                          nil);                                     
          }
        NS_ENDHANDLER  
      }
    }
  }
  
  isDragTarget = NO;
}

@end
