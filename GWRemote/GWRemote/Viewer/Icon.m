/* Icon.m
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
#include "Functions.h"
#include "Notifications.h"
#include "Icon.h"
#include "IconLabel.h"
#include "GWRemote.h"
#include "GNUstep.h"

#define CHECK_LOCK if (locked) return
#define CHECK_LOCK_RET(x) if (locked) return x

@implementation Icon

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (paths);
  TEST_RELEASE (fullpath);
  TEST_RELEASE (name);
	TEST_RELEASE (hostname);
	TEST_RELEASE (remoteHostName);
  TEST_RELEASE (type);
  TEST_RELEASE (icon);
	RELEASE (namelabel);
  RELEASE (highlight);
  RELEASE (arrow); 	
  [super dealloc];
}

- (id)initForRemoteHost:(NSString *)rhost
{
  self = [super init];
  
  if (self) {
		gwremote = [GWRemote gwremote];

    ASSIGN (remoteHostName, rhost);

    fm = [NSFileManager defaultManager];

    ASSIGN (highlight, [NSImage imageNamed: @"CellHighlight.tiff"]);
    ASSIGN (arrow, [NSImage imageNamed: @"common_3DArrowRight.tiff"]);

    namelabel = [[IconLabel alloc] initForIcon: self];
		[namelabel setFont: [NSFont systemFontOfSize: 12]];
		[namelabel setBezeled: NO];
		[namelabel setEditable: NO];
		[namelabel setSelectable: NO];
		[namelabel setAlignment: NSCenterTextAlignment];
	  [namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
		    
		paths = nil;
		fullpath = nil;
		hostname = nil;
    icon = nil;
    isbranch = NO;
    dimmed = NO;
		locked = NO;
		isPakage = NO;
    singlepath = YES;
    isSelect = NO;
    dragdelay = 0;
    isDragTarget = NO;
		onSelf = NO;
		isRootIcon = NO;
		
    [self registerForDraggedTypes: [NSArray arrayWithObject: GWRemoteFilenamesPboardType]];    
  }
  
  return self;
}

- (void)setPaths:(NSArray *)p
{
  float width, labwidth;
  int i, count;
	
  if ([p isEqualToArray: paths]) {
    return;
  }

  if (p == nil) {
    TEST_RELEASE (paths);
    paths = nil;
    TEST_RELEASE (fullpath);
		fullpath = nil;
		ASSIGN (name, @"");
    TEST_RELEASE (type);
    type = nil;
		isPakage = NO;
    TEST_RELEASE (icon);
    icon = nil;
		dimmed = YES;
		[self setNeedsDisplay: YES];
    return;
  }
	
	dimmed = NO;
	
  ASSIGN (paths, p);
  count = [paths count];                    

  if (count == 1) {
    singlepath = YES;   
    ASSIGN (fullpath, [paths objectAtIndex: 0]); 		
		if ([fullpath isEqualToString: fixPath(@"/", 0)]) {
			ASSIGN (name, fullpath);
			isRootIcon = YES;
		} else {
    	ASSIGN (name, [fullpath lastPathComponent]);
			isRootIcon = NO;
		}
    
    ASSIGN (type, [gwremote server: remoteHostName typeOfFileAt: fullpath]);
    isPakage = [gwremote server: remoteHostName isPakageAtPath: fullpath];    
		
  } else {
		fullpath = nil;
    singlepath = NO;
    ASSIGN (name, ([NSString stringWithFormat: @"%i items", count]));
    type = nil;
		isRootIcon = NO;
		isPakage = NO;
  }

  if (singlepath == YES) {
    ASSIGN (icon, [gwremote iconForFile: fullpath ofType: type]);    
  } else {
    ASSIGN (icon, [NSImage imageNamed: @"MultipleSelection.tiff"]);
  }

  width = [self frame].size.width;
  labwidth = [[namelabel font] widthOfString: name] + 8;
  if (labwidth > width) {
    labwidth = width;
  }
	[namelabel setFrame: NSMakeRect(0, 0, labwidth, 14)];  
	
	if (isRootIcon == NO) {
  	[namelabel setStringValue: cutFileLabelText(name, namelabel, labwidth)];
  } else {
 		ASSIGN (hostname, remoteHostName);
		[namelabel setStringValue: remoteHostName];
	}

  [self setLocked: NO];
  
  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];

    if ([gwremote server: remoteHostName isLockedPath: path]) {
      [self setLocked: YES];
      break;
    }
  }
	
	[delegate icon: self setFrameOfLabel: namelabel];		
	[self setNeedsDisplay: YES];
}

- (void)setFrame:(NSRect)frameRect
{
  float width, labwidth;

  [super setFrame: frameRect];
  
  width = [self frame].size.width;
	
	if (isRootIcon == NO) {
  	labwidth = [[namelabel font] widthOfString: name] + 8;
  } else {
  	labwidth = [[namelabel font] widthOfString: hostname] + 8;
	}
  if (labwidth > width) {
    labwidth = width;
  }

  [namelabel setFrame: NSMakeRect(0, 0, labwidth, 14)];    

	if (isRootIcon == NO) {
		[namelabel setStringValue: cutFileLabelText(name, namelabel, labwidth)];
  } else {
		[namelabel setStringValue: hostname];
	}
 
	[delegate icon: self setFrameOfLabel: namelabel];
  
	[self setNeedsDisplay: YES];
}

- (void)select
{
  if (isSelect || dimmed) {
    return;
  }
  
	isSelect = YES;
	[namelabel setBackgroundColor: [NSColor whiteColor]]; 	
	[delegate unselectOtherIcons: self];
	[self setNeedsDisplay: YES];
  [namelabel setNeedsDisplay: YES];
}

- (void)unselect
{  
	isSelect = NO;
	[namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
	[self setNeedsDisplay: YES];  
  [namelabel setNeedsDisplay: YES];
}

- (void)renewIcon
{
  if (singlepath == YES) {
    ASSIGN (icon, [gwremote iconForFile: fullpath ofType: type]);    
  } else {
    ASSIGN (icon, [NSImage imageNamed: @"MultipleSelection.tiff"]);
  }
  [self setNeedsDisplay: YES];
}

- (BOOL)isSelect
{
  return isSelect;
}

- (NSTextField *)label
{
  return namelabel;
}

- (void)setBranch:(BOOL)value
{
  if (isbranch != value) {
    isbranch = value;  
    [self setDimmed: NO];
	  [self setNeedsDisplay: YES];
  }
}

- (BOOL)isBranch
{
  return isbranch;
}

- (void)setDimmed:(BOOL)value
{
  if (dimmed != value) {
    dimmed = value;
  }
}

- (BOOL)isDimmed
{
  return dimmed;
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

- (NSString *)type
{
  return type;
}

- (NSImage *)icon
{
  return icon;
}

- (NSSize)iconShift
{
	NSRect r = [self frame];
	NSSize s = [icon size];
	
	return NSMakeSize((r.size.width - s.width) / 2, (r.size.height - s.height) / 2);	
}

- (void)clickOnLabel
{
	CHECK_LOCK;
  [self select];
	[delegate clickOnIcon: self];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  CHECK_LOCK;
	
	if([theEvent clickCount] > 1) {
		unsigned int modifier = [theEvent modifierFlags];		
		[delegate doubleClickOnIcon: self newViewer: (modifier == NSControlKeyMask)];
	}  
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSEvent *nextEvent;
  BOOL startdnd = NO;
  NSPoint p;
	
	CHECK_LOCK;
		
	if (dimmed) {
		return;
	}
	
  p = [theEvent locationInWindow];
  p = [self convertPoint: p fromView: nil];
  
  if (ONICON(p, [self frame].size, [icon size]) == NO) {    
    return;  
  }

	if ([theEvent clickCount] == 1) {   
    if (isSelect == NO) {  
      [self select];
      [delegate unselectNameEditor];
    }

    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
			  [delegate clickOnIcon: self];
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
      [self startExternalDragOnEvent: theEvent];    
    } 
  }              
}

- (BOOL)isSinglePath
{
  return singlepath;
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

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent 
{
  return YES;
}

- (void)drawRect:(NSRect)rect
{
	if (dimmed == YES) {    
		return;
	}
  	
	if(isSelect) {
		[highlight compositeToPoint: ICONPOSITION(rect.size, [highlight size]) 
                      operation: NSCompositeSourceOver];
	}
	
  if (icon != nil) {
		if (locked == NO) {	
			[icon compositeToPoint: ICONPOSITION(rect.size, [icon size]) 
                  operation: NSCompositeSourceOver];
		} else {						 								 
			[icon dissolveToPoint: ICONPOSITION(rect.size, [icon size]) fraction: 0.3];						 
		}
  }
  
  if (isbranch == YES) {
		[arrow compositeToPoint: NSMakePoint(rect.size.width - 15, 26)
                  operation: NSCompositeSourceOver];
  }
}

@end


@implementation Icon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
{
  NSSize fs = [self frame].size;
  NSSize is = [icon size];
  NSPoint dragPoint = NSMakePoint((fs.width - is.width) / 2, (fs.height - is.height) / 2);	
  NSPasteboard *pb;
  
	pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  [self declareAndSetShapeOnPasteboard: pb];
	      
  [self dragImage: icon
               at: dragPoint 
           offset: NSZeroSize
            event: event
       pasteboard: pb
           source: self
        slideBack: YES];
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes;
  NSData *pbData;
  NSMutableDictionary *pbDict;	

  pbDict = [NSMutableDictionary dictionary];       
  dndtypes = [NSArray arrayWithObject: GWRemoteFilenamesPboardType];
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

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
	dragdelay = 0;
  onSelf = NO;
  [self setNeedsDisplay: YES];
  [delegate restoreSelectionAfterDndOfIcon: self];
}

@end


@implementation Icon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSData *pbData;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *buff;
	NSString *iconPath;
  NSDictionary *dndDict;
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

	if ([gwremote server: remoteHostName isWritableFileAtPath: fullpath] == NO) {
		return NSDragOperationNone;
	}

  if ([paths isEqualToArray: sourcePaths]) {
    onSelf = YES;
  }

	if ([fullpath isEqualToString: fromPath]) {
		return NSDragOperationNone;
  }  

	for (i = 0; i < count; i++) {
		if ([fullpath isEqualToString: [sourcePaths objectAtIndex: i]]) {
		  return NSDragOperationNone;
		}
	}

	buff = [NSString stringWithString: fullpath];
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

  iconPath =  [fullpath stringByAppendingPathComponent: @".opendir.tiff"];

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
    ASSIGN (icon, [gwremote iconForFile: fullpath ofType: type]); 
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
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
  NSDictionary *dndDict;
  NSString *sourceHost;  
  int i;

	CHECK_LOCK;
	
	isDragTarget = NO;  

  if (onSelf == YES) {
    onSelf = NO;
    return;
  }

  ASSIGN (icon, [gwremote iconForFile: fullpath ofType: type]); 
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
	[opDict setObject: fullpath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [gwremote performFileOperationWithDictionary: opDict
                                  fromSourceHost: sourceHost
                               toDestinationHost: remoteHostName];
}

@end

