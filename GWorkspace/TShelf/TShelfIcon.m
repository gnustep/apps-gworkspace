/*  -*-objc-*-
 *  TShelfIcon.m: Implementation of the TShelfIcon Class 
 *  of the GNUstep TShelf application
 *
 *  Copyright (c) 2003 Enrico Sersale <enrico@dtedu.net>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2003
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
#include "GWLib.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWLib.h>
  #endif
#include "TShelfIcon.h"
#include "TShelfIconsView.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#define CHECK_LOCK if (locked) return
#define CHECK_LOCK_RET(x) if (locked) return x

@implementation TShelfIcon

- (void)dealloc
{
  RELEASE (paths);
  TEST_RELEASE (fullPath);
  RELEASE (name);
	TEST_RELEASE (hostname);
  RELEASE (type);
	RELEASE (namelabel);
  RELEASE (icon);
  RELEASE (highlight);
  [super dealloc];
}

- (id)initForPaths:(NSArray *)fpaths 
       inIconsView:(TShelfIconsView *)aview
{
  self = [super init];
  if (self) {
    NSFont *font;
    NSString *defApp = nil, *t = nil;
    int count;

    fm = [NSFileManager defaultManager];
		ws = [NSWorkspace sharedWorkspace];
    gw = [GWorkspace gworkspace];

    [self setFrame: NSMakeRect(0, 0, 64, 52)];
		paths = [[NSMutableArray alloc] initWithCapacity: 1];
		[paths addObjectsFromArray: fpaths];
    tview = aview;  
    labelWidth = [tview cellsWidth] - 4;
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
			
      [ws getInfoForFile: fullPath application: &defApp type: &t];      
      ASSIGN (type, t);			
			isPakage = [gw isPakageAtPath: fullPath];
			
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
			NSHost *host = [NSHost currentHost];
			NSString *hname = [host name];
			NSRange range = [hname rangeOfString: @"."];

			if (range.length != 0) {	
				hname = [hname substringToIndex: range.location];
			} 			
			ASSIGN (hostname, hname);			
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
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
    
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
       inIconsView:(TShelfIconsView *)aview
{
	[self initForPaths: fpaths inIconsView: aview];
  position = NSMakePoint(pos.x, pos.y);
  return self;
}

- (id)initForPaths:(NSArray *)fpaths 
				 gridIndex:(int)index
       inIconsView:(TShelfIconsView *)aview
{
	[self initForPaths: fpaths inIconsView: aview];
	gridindex = index;
  return self;
}

- (void)setPaths:(NSArray *)fpaths
{
  NSString *defApp = nil, *t = nil;
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
    [ws getInfoForFile: fullPath application: &defApp type: &t];      
    ASSIGN (type, t);
		isPakage = [gw isPakageAtPath: fullPath];
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
		NSHost *host = [NSHost currentHost];
		NSString *hname = [host name];
		NSRange range = [hname rangeOfString: @"."];

		if (range.length != 0) {	
			hname = [hname substringToIndex: range.location];
		} 			
		ASSIGN (hostname, hname);			
  } else {
		TEST_RELEASE (hostname);
		hostname = nil;
	}

  [self setLabelWidth]; 
	[tview setLabelRectOfIcon: self];
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

- (void)renewIcon
{
  if (singlepath == YES) {
    ASSIGN (icon, [gw iconForFile: fullPath ofType: type]);    
  } else {
    ASSIGN (icon, [NSImage imageNamed: @"MultipleSelection.tiff"]);
  }
  [self setNeedsDisplay: YES];
}

- (void)setLabelWidth
{
  NSFont *font = [NSFont systemFontOfSize: 12];
  NSRect rect = [namelabel frame];
	NSString *nstr = isRootIcon ? hostname : name;
  
	labelWidth = [tview cellsWidth] - 8;
	  
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

  [(NSView *)tview setNeedsDisplayInRect: rect];
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
		if (locked == NO) {				
			[tview openCurrentSelection: paths];
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

        [tview setCurrentSelection: paths];

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

- (void)mouseDragged:(NSEvent *)theEvent
{
  CHECK_LOCK;

	if(dragdelay < 5) {
    dragdelay++;
    return;
  }

  [self startExternalDragOnEvent: theEvent];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  return [super menuForEvent: theEvent];
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

@implementation TShelfIcon (DraggingSource)

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

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  [pb declareTypes: dndtypes owner: nil];
  
  if ([pb setPropertyList: paths forType: NSFilenamesPboardType] == NO) {
    return;
  }
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
    
    [tview removeIcon: self];	
	} else {
	  dragdelay = 0;
	  onSelf = NO;
	  [self unselect];	
	}
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

@end

@implementation TShelfIcon (DraggingDestination)

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
	
	isDragTarget = NO;

	pb = [sender draggingPasteboard];
  if([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
    
    if ([paths isEqualToArray: sourcePaths]) {
      onSelf = YES;
      isDragTarget = YES;
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
  NSMutableDictionary *opDict;
  int i;

  isDragTarget = NO;

  if (onSelf == YES) {
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

	opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: fullPath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];
    
  [gw performFileOperationWithDictionary: opDict];
}

@end
