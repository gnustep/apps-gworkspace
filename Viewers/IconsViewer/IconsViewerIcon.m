/* IconsViewerIcon.m
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
#include "GWLib.h"
#include "GWProtocol.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "IconsViewerIcon.h"
#include "GNUstep.h"

#define CHECK_LOCK if (locked) return
#define CHECK_LOCK_RET(x) if (locked) return x

@implementation IconsViewerIcon

- (void)dealloc
{
  RELEASE (path);
  RELEASE (name);
  RELEASE (type);
	RELEASE (namelabel);
  RELEASE (icon);
  RELEASE (highlight);
  [super dealloc];
}

- (id)initForPath:(NSString *)apath delegate:(id)adelegate
{
  self = [super init];
  if (self) {
    NSArray *pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, 
                                          GWRemoteFilenamesPboardType, nil];
    NSString *defApp = nil, *t = nil;
		NSFont *font;

    fm = [NSFileManager defaultManager];
		
    ASSIGN (path, apath);
		[self setDelegate: adelegate];

		labelWidth = [delegate getCellsWidth] - 4;	
    font = [NSFont systemFontOfSize: 12];
    [self setFrame: NSMakeRect(0, 0, 64, 52)];
    isSelect = NO; 
    locked = NO;

    ASSIGN (name, [path lastPathComponent]);

    [[NSWorkspace sharedWorkspace] getInfoForFile: path 
                                      application: &defApp 
                                             type: &t];      
    ASSIGN (type, t);
		isPakage = [GWLib isPakageAtPath: path];			
    ASSIGN (icon, [GWLib iconForFile: path ofType: type]);  
    ASSIGN (highlight, [NSImage imageNamed: GWCellHighlightIconName]);

    namelabel = [NSTextField new];    
		[namelabel setFont: font];
		[namelabel setBezeled: NO];
		[namelabel setEditable: NO];
		[namelabel setSelectable: NO];
		[namelabel setAlignment: NSCenterTextAlignment];
	  [namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
	  [namelabel setTextColor: [NSColor blackColor]];
		[self setLabelWidth]; 
    
    [self registerForDraggedTypes: pbTypes];

    dragdelay = 0;
    isDragTarget = NO;
    onSelf = NO;
  }
  
  return self;
}

- (void)setPath:(NSString *)apath
{
  NSString *defApp = nil, *t = nil;

	ASSIGN (path, apath);
  ASSIGN (name, [path lastPathComponent]);	
  ASSIGN (icon, [GWLib iconForFile: path ofType: type]);    

  [[NSWorkspace sharedWorkspace] getInfoForFile: path 
                                    application: &defApp 
                                           type: &t];      
  ASSIGN (type, t);
	isPakage = [delegate isPakageAtPath: path];
	
  [self setLabelWidth]; 
}

- (void)select
{
  if (isSelect) {
    return;
  }  
  if ([fm fileExistsAtPath: path] == NO) {
    return;
  }
  isSelect = YES;
	[namelabel setBackgroundColor: [NSColor whiteColor]];
	[delegate unselectIconsDifferentFrom: self];	
	[self setNeedsDisplay: YES];    
	[delegate setTheCurrentSelection: [NSArray arrayWithObject: path]];	    
  [(NSView *)delegate setNeedsDisplayInRect: [namelabel frame]];
}

- (void)unselect
{
  if (isSelect == NO) {
    return;
  }
	isSelect = NO;
	[namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
	[self setNeedsDisplay: YES];
//	[delegate setTheCurrentSelection: [NSArray array]];	
  [(NSView *)delegate setNeedsDisplayInRect: [namelabel frame]];
}

- (void)renewIcon
{
  ASSIGN (icon, [GWLib iconForFile: path ofType: type]);    
  [self setNeedsDisplay: YES];
}

- (void)setLabelWidth
{
  int width = (int)[[namelabel font] widthOfString: name] + 8;

	labelWidth = [delegate getCellsWidth] - 4;		

  if (width > labelWidth) {
    width = labelWidth;
  }
  [namelabel setFrame: NSMakeRect(0, 0, width, 14)];  
  [namelabel setStringValue: cutFileLabelText(name, namelabel, width - 8)];  
}

- (NSTextField *)myLabel
{
  return namelabel;
}

- (NSString *)type
{
  return type;
}

- (NSString *)path
{
  return path;
}

- (NSString *)myName
{
  return name;
}

- (NSSize)iconShift
{
	NSRect r = [self frame];
	NSSize s = [icon size];
	
	return NSMakeSize((r.size.width - s.width) / 2, (r.size.height - s.height) / 2);	
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

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent 
{
  return YES;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	int count = [theEvent clickCount];    

  CHECK_LOCK;
	
	if(count > 1) {  
		unsigned int modifier = [theEvent modifierFlags];		
    
    if ([fm fileExistsAtPath: path] == NO) {
      return;
    }
    
		[delegate openTheCurrentSelection: [NSArray arrayWithObject: path]
                            newViewer: (modifier == NSControlKeyMask)];
	}  
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSEvent *nextEvent;
  NSPoint location;
  NSSize offset;
  BOOL startdnd = NO;

	CHECK_LOCK;

  location = [theEvent locationInWindow];
  location = [self convertPoint: location fromView: nil];
	    
	if ([theEvent clickCount] == 1) {
		if([theEvent modifierFlags] == 2)  {
			[delegate setShiftClickValue: YES];     
			if (isSelect == YES) {
				[self unselect];
        [delegate setTheCurrentSelection: [NSArray array]];	
				return;
      } else {
				[self select];
			}
		} else {
			[delegate setShiftClickValue: NO];
      if (isSelect == NO) {       
				[self select];
			}
		}
    
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

    if (startdnd && [fm fileExistsAtPath: path]) {  
      [self startExternalDragOnEvent: nextEvent withMouseOffset: offset];    
    } 
	}  
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if (([theEvent type] == NSRightMouseDown) && isSelect) {
    return [delegate menuForRightMouseEvent: theEvent];
  }
  
  return [super menuForEvent: theEvent]; 
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)aDelegate
{
	delegate = aDelegate;
}

- (void)drawRect:(NSRect)rect
{
	NSRect r = [self bounds];
  NSSize s = [icon size];
	NSPoint p = NSMakePoint((r.size.width - s.width) / 2, (r.size.height - s.height) / 2);  
	    	
	if(isSelect) {
		[highlight compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];
	}

  if (icon != nil) {
		if (locked == NO) {	
			[icon compositeToPoint: p operation: NSCompositeSourceOver];
		} else {						 								 
			[icon dissolveToPoint: p fraction: 0.3];						 
		}
  }
}

@end

@implementation IconsViewerIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset
{
	NSEvent *nextEvent;
  NSPoint dragPoint;
  NSPasteboard *pb;
  NSImage *dragIcon;
  NSArray *selection;
  
	nextEvent = [[self window] nextEventMatchingMask:
    							NSLeftMouseUpMask | NSLeftMouseDraggedMask];

  if([nextEvent type] != NSLeftMouseDragged) {
   	return;
  }
  
  dragPoint = [nextEvent locationInWindow];
  dragPoint = [self convertPoint: dragPoint fromView: nil];

	pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  [self declareAndSetShapeOnPasteboard: pb];
	
  selection = [delegate getTheCurrentSelection];
		
  if ([selection count] > 1) {
    dragIcon = [NSImage imageNamed: @"MultipleSelection.tiff"];
  } else {
    dragIcon = [GWLib iconForFile: path ofType: type]; 
  }   

  [self dragImage: dragIcon
               at: dragPoint 
           offset: NSZeroSize
            event: event
       pasteboard: pb
           source: self
        slideBack: [[GWLib workspaceApp] animateSlideBack]];
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
	dragdelay = 0;
  onSelf = NO;
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes;
  NSArray *selection;

  dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  [pb declareTypes: dndtypes owner: nil];
	selection = [delegate getTheCurrentSelection];

  if ([pb setPropertyList: selection forType: NSFilenamesPboardType] == NO) {
    return;
  }
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

@end

@implementation IconsViewerIcon (DraggingDestination)

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
  
  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: GWRemoteFilenamesPboardType]) {
    NSData *pbData = [pb dataForType: GWRemoteFilenamesPboardType]; 
    NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
    sourcePaths = [pbDict objectForKey: @"paths"];
  } else {
    return NSDragOperationNone;
  }

	count = [sourcePaths count];

  if ((count == 1) && ([path isEqualToString: [sourcePaths objectAtIndex: 0]])) {
    onSelf = YES;
    isDragTarget = YES;
    return NSDragOperationAll;
  }

  if ((([type isEqualToString: NSDirectoryFileType] == NO)
      && ([type isEqualToString: NSFilesystemFileType] == NO)) || isPakage) {
    return NSDragOperationNone;
  }

	fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	if (count == 0) {
		return NSDragOperationNone;
  } 

	if ([fm isWritableFileAtPath: path] == NO) {
		return NSDragOperationNone;
	}

	if ([path isEqualToString: fromPath]) {
		return NSDragOperationNone;
  }  

	for (i = 0; i < count; i++) {
		if ([path isEqualToString: [sourcePaths objectAtIndex: i]]) {
		  return NSDragOperationNone;
		}
	}

	buff = [NSString stringWithString: path];
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

  iconPath =  [path stringByAppendingPathComponent: @".opendir.tiff"];

  if ([fm isReadableFileAtPath: iconPath]) {
    NSImage *img = [[NSImage alloc] initWithContentsOfFile: iconPath];

    if (img) {
      ASSIGN (icon, img);
      RELEASE (img);
    } else {
      ASSIGN (icon, [NSImage imageNamed: GWOpenFolderIconName]);
    }      
  } else {
	  ASSIGN (icon, [NSImage imageNamed: GWOpenFolderIconName]);    
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
    if (onSelf == NO) {      
      ASSIGN (icon, [GWLib iconForFile: path ofType: type]);
      [self setNeedsDisplay: YES];
    }
    onSelf = NO;
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
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
	NSString *trashPath;
  int i;

	CHECK_LOCK;
	
  isDragTarget = NO;

  if (onSelf == YES) {
    onSelf = NO;
    return;
  }
  
  ASSIGN (icon, [GWLib iconForFile: path ofType: type]);
  [self setNeedsDisplay: YES];

	sourceDragMask = [sender draggingSourceOperationMask];  
  pb = [sender draggingPasteboard];
  
  if ([[pb types] containsObject: GWRemoteFilenamesPboardType]) {  
    NSData *pbData = [pb dataForType: GWRemoteFilenamesPboardType]; 
    
    [GWLib concludeRemoteFilesDragOperation: pbData
                                atLocalPath: path];
    return;
  }  
  
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];  
  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	trashPath = [[GWLib workspaceApp] trashPath];

	if ([source isEqualToString: trashPath]) {
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

	opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: path forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];
	
	[[GWLib workspaceApp] performFileOperationWithDictionary: opDict];	
}

@end
