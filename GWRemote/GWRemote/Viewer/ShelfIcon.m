/* ShelfIcon.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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
#include <GWorkspace/GWNotifications.h>
#include "ShelfIcon.h"
#include "Shelf.h"
#include "GWRemote.h"
#include "Functions.h"
#include "GNUstep.h"

#define CHECK_LOCK if (locked) return
#define CHECK_LOCK_RET(x) if (locked) return x

@implementation ShelfIcon

- (void)dealloc
{
  RELEASE (paths);
  TEST_RELEASE (fullPath);
  RELEASE (name);
	TEST_RELEASE (hostname);
	TEST_RELEASE (remoteHostName);
  RELEASE (type);
	RELEASE (namelabel);
  RELEASE (icon);
  RELEASE (highlight);
  RELEASE (waitCursor);
  [super dealloc];
}

- (id)initForPaths:(NSArray *)fpaths 
          inShelf:(Shelf *)aShelf
       remoteHost:(NSString *)rhost
{
  self = [super init];
  if (self) {
    NSFont *font;
    int count;

    gw = [GWRemote gwremote];

    [self setFrame: NSMakeRect(0, 0, 64, 52)];
    ASSIGN (remoteHostName, rhost);    
		paths = [[NSMutableArray alloc] initWithCapacity: 1];
		[paths addObjectsFromArray: fpaths];
    shelf = aShelf;  
    labelWidth = [shelf cellsWidth] - 4;
    font = [NSFont systemFontOfSize: 12];
    isSelect = NO; 
    locked = NO;
    count = [paths count];                    

    if (count == 1) {
      singlepath = YES;
      ASSIGN (fullPath, [paths objectAtIndex: 0]);
			
			if ([fullPath isEqualToString: fixPath(@"/", 0)]) {
				ASSIGN (name, fullPath);
				isRootIcon = YES;
			} else {
    		ASSIGN (name, [fullPath lastPathComponent]);
				isRootIcon = NO;
			}

      ASSIGN (type, [gw server: remoteHostName typeOfFileAt: fullPath]);
      isPakage = [gw server: remoteHostName isPakageAtPath: fullPath];    
			
    } else {
      fullPath = nil;
      singlepath = NO;
      type = nil;
			isRootIcon = NO;
			isPakage = NO;
      name = [[NSString alloc] initWithFormat: @"%i items", count];
    }

    if (singlepath == YES) {
      ASSIGN (icon, [gw iconForFile: fullPath ofType: type]);
    } else {
      ASSIGN (icon, [NSImage imageNamed: @"MultipleSelection.tiff"]);
    }
    
    ASSIGN (highlight, [NSImage imageNamed: @"CellHighlight.tiff"]);

		if (isRootIcon == YES) {
 		  ASSIGN (hostname, remoteHostName);
		  [namelabel setStringValue: remoteHostName];
  	} else {
			hostname = nil;
		}

    namelabel = [NSTextField new];    
		[namelabel setFont: font];
		[namelabel setBezeled: NO];
		[namelabel setEditable: NO];
		[namelabel setSelectable: NO];
		[namelabel setAlignment: NSCenterTextAlignment];
	  [namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
	  [namelabel setTextColor: [NSColor blackColor]];
		[self setLabelWidth]; 

    waitCursor = [[NSCursor alloc] initWithImage: [NSImage imageNamed: @"watch.tiff"]];
    [waitCursor setHotSpot: NSMakePoint(8, 8)];
    [NSCursor setHiddenUntilMouseMoves: NO];
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: GWRemoteFilenamesPboardType, nil]];
    
		position = NSMakePoint(0, 0);
		gridindex = -1;
    dragdelay = 0;
    isDragTarget = NO;
    onSelf = NO;
  }
  
  return self;
}

- (id)initForPaths:(NSArray *)fpaths 
        atPosition:(NSPoint)pos
           inShelf:(Shelf *)aShelf
        remoteHost:(NSString *)rhost
{
	[self initForPaths: fpaths inShelf: aShelf remoteHost: rhost];
  position = NSMakePoint(pos.x, pos.y);
  return self;
}

- (id)initForPaths:(NSArray *)fpaths 
				 gridIndex:(int)index
           inShelf:(Shelf *)aShelf
        remoteHost:(NSString *)rhost
{
	[self initForPaths: fpaths inShelf: aShelf remoteHost: rhost];
	gridindex = index;
  return self;
}

- (void)setPaths:(NSArray *)fpaths
{
  int count;

	TEST_RELEASE (paths);
	paths = [[NSMutableArray alloc] initWithCapacity: 1];
	[paths addObjectsFromArray: fpaths];
  count = [paths count];                    

  if (count == 1) {
    singlepath = YES;
    ASSIGN (fullPath, [paths objectAtIndex: 0]);
		if ([fullPath isEqualToString: fixPath(@"/", 0)]) {
			ASSIGN (name, fullPath);
			isRootIcon = YES;
		} else {
    	ASSIGN (name, [fullPath lastPathComponent]);
			isRootIcon = NO;
		}

    ASSIGN (type, [gw server: remoteHostName typeOfFileAt: fullPath]);
    isPakage = [gw server: remoteHostName isPakageAtPath: fullPath];    

  } else {
    TEST_RELEASE (fullPath);
    fullPath = nil;
    singlepath = NO;
    type = nil;
		isRootIcon = NO;
		isPakage = NO;
    name = [[NSString alloc] initWithFormat: @"%i items", count];
  }

  if (singlepath == YES) {
    ASSIGN (icon, [gw iconForFile: fullPath ofType: type]);
  } else {
    ASSIGN (icon, [NSImage imageNamed: @"MultipleSelection.tiff"]);
  }

	if (isRootIcon == YES) {
    ASSIGN (hostname, remoteHostName);
    [namelabel setStringValue: remoteHostName];
  } else {
		TEST_RELEASE (hostname);
		hostname = nil;
	}

  [self setLabelWidth]; 
	[shelf setLabelRectOfIcon: self];
}

- (void)setPosition:(NSPoint)pos
{
  position = NSMakePoint(pos.x, pos.y);
}

- (void)setPosition:(NSPoint)pos gridIndex:(int)index
{
  position = NSMakePoint(pos.x, pos.y);
	gridindex = index;
}

- (NSPoint)position
{
  return position;
}

- (void)setGridIndex:(int)index
{
	gridindex = index;
}

- (int)gridindex
{
	return gridindex;
}

- (void)select
{
	isSelect = YES;
  if (locked == NO) {
    [namelabel setTextColor: [NSColor controlTextColor]];
  }
  [self setNeedsDisplay: YES];
}

- (void)unselect
{
	isSelect = NO;
  if (locked == NO) {
    [namelabel setTextColor: [NSColor controlTextColor]];
  }
	[self setNeedsDisplay: YES];
}

- (void)openWithApp:(id)sender
{
}

- (void)setLabelWidth
{
  NSFont *font = [NSFont systemFontOfSize: 12];
  NSRect rect = [namelabel frame];
	NSString *nstr = isRootIcon ? hostname : name;
  
	labelWidth = [shelf cellsWidth] - 8;
	  
  if (isSelect == YES) {
    [namelabel setFrame: NSMakeRect(0, 0, [font widthOfString: nstr] + 8, 14)];
    [namelabel setStringValue: nstr];
  } else {
    int width = (int)[[namelabel font] widthOfString: nstr] + 8;
    if (width > labelWidth) {
      width = labelWidth;
    }
    [namelabel setFrame: NSMakeRect(0, 0, width, 14)];  
    [namelabel setStringValue: cutFileLabelText(nstr, namelabel, width - 8)];  
  }

  [(NSView *)shelf setNeedsDisplayInRect: rect];
}

- (NSTextField *)myLabel
{
  return namelabel;
}

- (NSString *)type
{
  return type;
}

- (NSArray *)paths
{
  return paths;
}

- (NSString *)name
{
  return name;
}

- (NSString *)hostname
{
	return hostname;
}

- (BOOL)isSinglePath
{
  return singlepath;
}

- (BOOL)isSelect
{
  return isSelect;
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

- (BOOL)isRootIcon
{
	return isRootIcon;
}

- (BOOL)isPakage
{
	return isPakage;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent 
{
  return YES;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if ([theEvent clickCount] > 1) {  
		unsigned int modifier = [theEvent modifierFlags];
		
		if (locked == NO) {				
			[shelf openCurrentSelection: paths 
												newViewer: (modifier == NSControlKeyMask)];
		} else {
			if ((type == NSDirectoryFileType) || (type == NSFilesystemFileType)) {
				[shelf openCurrentSelection: paths 
													newViewer: (modifier == NSControlKeyMask)];
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

	if ([theEvent clickCount] == 1) {  
    if (isSelect == NO) {  
      [self select];
    }

    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
        NSSize ss = [self frame].size;
        NSSize is = [icon size];
        NSPoint p = NSMakePoint((ss.width - is.width) / 2, (ss.height - is.height) / 2);	

        p = [self convertPoint: p toView: nil];
        p = [[self window] convertBaseToScreen: p];

        [waitCursor set];
        
        [shelf setCurrentSelection: paths 
                      animateImage: icon 
                   startingAtPoint: p];

        [self unselect];
        break;

      } else if ([nextEvent type] == NSLeftMouseDragged) {
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

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)aDelegate
{
  ASSIGN (delegate, aDelegate);
	AUTORELEASE (delegate);
}

- (void)drawRect:(NSRect)rect
{
	NSPoint p;
  NSSize s;
      	
	if(isSelect) {
		[highlight compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];
	}
	
  s = [icon size];
  p = NSMakePoint((rect.size.width - s.width) / 2, (rect.size.height - s.height) / 2);	
	if (locked == NO) {
		[icon compositeToPoint: p operation: NSCompositeSourceOver];
	} else {
		[icon dissolveToPoint: p fraction: 0.3];
	}
}

@end

@implementation ShelfIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
{
	NSEvent *nextEvent;
  NSPoint dragPoint;
  NSPasteboard *pb;
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
  
  if (singlepath == YES) {
    NSArray *selection = [shelf currentSelection];
    if ([selection count] > 1) {
      dragIcon = [NSImage imageNamed: @"MultipleSelection.tiff"];
    } else {
      dragIcon = [gw iconForFile: fullPath ofType: type]; 
    }   
  } else {
    dragIcon = [NSImage imageNamed: @"MultipleSelection.tiff"];
  }

  [self dragImage: dragIcon
               at: dragPoint 
           offset: NSZeroSize
            event: event
       pasteboard: pb
           source: self
        slideBack: [gw animateSlideBack]];   
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
	if (flag == NO) {  
    NSRect r1 = [self frame];
    NSRect r2 = [namelabel frame];

    r1.origin.x = r1.origin.y = r2.origin.x = r2.origin.y = 0;

    aPoint = [[self window] convertScreenToBase: aPoint];
    aPoint = [self convertPoint: aPoint fromView: nil];
  
    if (NSPointInRect(aPoint, r1) || NSPointInRect(aPoint, r2)) {
	    dragdelay = 0;
	    onSelf = NO;
	    [self unselect];	
      return;
    }
    
    [shelf removeIcon: self];	
	} else {
	  dragdelay = 0;
	  onSelf = NO;
	  [self unselect];	
	}
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes = [NSArray arrayWithObject: GWRemoteFilenamesPboardType];
  NSMutableDictionary *pbDict = [NSMutableDictionary dictionary];    
  NSData *pbData;

  [pb declareTypes: dndtypes owner: nil];    
  [pbDict setObject: remoteHostName forKey: @"host"];
  [pbDict setObject: paths forKey: @"paths"];        
    
  pbData = [NSArchiver archivedDataWithRootObject: pbDict];
  [pb setData: pbData forType: GWRemoteFilenamesPboardType];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

@end

@implementation ShelfIcon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSData *pbData;
  NSDictionary *dndDict;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *buff;
	int i, count;

	CHECK_LOCK_RET (NSDragOperationNone);
	
	isDragTarget = NO;
	
  if ((([type isEqualToString: NSDirectoryFileType] == NO)
      && ([type isEqualToString: NSFilesystemFileType] == NO)) || isPakage) {
    return NSDragOperationNone;
  }

	pb = [sender draggingPasteboard];
  
  if ([[pb types] indexOfObject: GWRemoteFilenamesPboardType] == NSNotFound) {
    return NSDragOperationNone;
  }
  
  pbData = [pb dataForType: GWRemoteFilenamesPboardType];
  dndDict = [NSUnarchiver unarchiveObjectWithData: pbData];

  sourcePaths = [dndDict objectForKey: @"paths"]; 
  
	count = [sourcePaths count];
	fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	if (count == 0) {
		return NSDragOperationNone;
  } 

	if ([gw server: remoteHostName isWritableFileAtPath: fullPath] == NO) {
		return NSDragOperationNone;
	}

  if ([paths isEqualToArray: sourcePaths]) {
    onSelf = YES;
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
    
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;

	CHECK_LOCK_RET (NSDragOperationNone);
	
	if (isPakage) {
		return NSDragOperationNone;
	}
	if (isDragTarget == NO) {
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
		onSelf = NO;
    ASSIGN (icon, [gw iconForFile: fullPath ofType: type]); 
    [self setNeedsDisplay: YES];   
  }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	CHECK_LOCK_RET (NO);
	return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	CHECK_LOCK_RET (NO);
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSData *pbData;
  NSDictionary *dndDict;  
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
  NSString *sourceHost;  
  int i;

	CHECK_LOCK;
	
	isDragTarget = NO;  

  if (onSelf == YES) {
    onSelf = NO;
    return;
  }

  ASSIGN (icon, [gw iconForFile: fullPath ofType: type]); 
  [self setNeedsDisplay: YES];

	sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];
  
  pbData = [pb dataForType: GWRemoteFilenamesPboardType];
  dndDict = [NSUnarchiver unarchiveObjectWithData: pbData];

  sourcePaths = [dndDict objectForKey: @"paths"]; 
  sourceHost = [dndDict objectForKey: @"host"]; 
  
  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  
	if (sourceDragMask == NSDragOperationCopy) {
		operation = NSWorkspaceCopyOperation;
	} else if (sourceDragMask == NSDragOperationLink) {
		operation = NSWorkspaceLinkOperation;
	} else {
		operation = NSWorkspaceMoveOperation;
	}
  
  files = [NSMutableArray arrayWithCapacity: 1];    
  for(i = 0; i < [sourcePaths count]; i++) {    
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  }  

	opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: fullPath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [gw performFileOperationWithDictionary: opDict
                          fromSourceHost: sourceHost
                       toDestinationHost: remoteHostName];
}

@end
