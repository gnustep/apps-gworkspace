/* PathIcon.m
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
#include "PathIcon.h"
#include "PathIconLabel.h"
#include "IconsPath.h"
#include "GNUstep.h"

#define ICONPOSITION(s1, s2) (NSMakePoint(((int)(s1).width - (int)(s2).width) >> 1, \
((int)(s1).height - (int)(s2).height) >> 1))

#define ONICON(p, s1, s2) ([self mouse: (p) \
inRect: NSMakeRect(((int)(s1).width - (int)(s2).width) >> 1,\
((int)(s1).height - (int)(s2).height) >> 1, 48, 48)])

#define CHECK_LOCK if (locked) return
#define CHECK_LOCK_RET(x) if (locked) return x

@implementation PathIcon

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (paths);
  TEST_RELEASE (fullpath);
  TEST_RELEASE (name);
	TEST_RELEASE (hostname);
  TEST_RELEASE (type);
	RELEASE (namelabel);
  TEST_RELEASE (icon);
  RELEASE (highlight);
  RELEASE (arrow); 
  [super dealloc];
}

- (id)initWithDelegate:(id)aDelegate
{
  self = [super init];
  
  if (self) {
    fm = [NSFileManager defaultManager];
		ws = [NSWorkspace sharedWorkspace];
		
    [self setDelegate: aDelegate];    
		
    ASSIGN (highlight, [NSImage imageNamed: GWCellHighlightIconName]);
    ASSIGN (arrow, [NSImage imageNamed: @"common_3DArrowRight.tiff"]);
    icon = nil;

    namelabel = [[PathIconLabel alloc] initForPathIcon: self];
		[namelabel setFont: [NSFont systemFontOfSize: 12]];
		[namelabel setBezeled: NO];
		[namelabel setEditable: NO];
		[namelabel setSelectable: NO];
		[namelabel setAlignment: NSCenterTextAlignment];
	  [namelabel setBackgroundColor: [NSColor windowBackgroundColor]];

    contestualMenu = [[GWLib workspaceApp] usesContestualMenu];

		hostname = nil;
    isbranch = NO;
    locked = NO;
    singlepath = YES;
    isSelect = NO;
    dragdelay = 0;
    isDragTarget = NO;
		isRootIcon = NO;
		isPakage = NO;
		
    [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];    
  }
  
  return self;
}

- (void)setPaths:(NSArray *)p
{
	NSString *defapp = nil, *t = nil;
  float width, labwidth;
  int i, count;

  if ([p isEqualToArray: paths]) {
    return;
  }

  if (p == nil) {
    TEST_RELEASE (paths);
    paths = nil;
    TEST_RELEASE (fullpath);
    TEST_RELEASE (name);
    TEST_RELEASE (type);
    type = nil;
		isPakage = NO;
    TEST_RELEASE (icon);
    icon = nil;
    return;
  }

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
    [ws getInfoForFile: fullpath application: &defapp type: &t];      
    ASSIGN (type, t);
		isPakage = [GWLib isPakageAtPath: fullpath];
		
  } else {
    singlepath = NO;
    ASSIGN (name, ([NSString stringWithFormat: @"%i items", count]));
    type = nil;
		isRootIcon = NO;
		isPakage = NO;
  }

  if (singlepath == YES) {
    ASSIGN (icon, [GWLib iconForFile: fullpath ofType: type]);    
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
		NSHost *host = [NSHost currentHost];
		NSString *hname = [host name];
		NSRange range = [hname rangeOfString: @"."];
			
		if (range.length != 0) {	
			hname = [hname substringToIndex: range.location];
		} 			
		ASSIGN (hostname, hname);
		[namelabel setStringValue: hostname];
	}

  [self setLocked: NO];
  
  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];

    if ([GWLib isLockedPath: path]) {
      [self setLocked: YES];
      break;
    }
  }

	[delegate setLabelFrameOfIcon: self];	
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

  [delegate setLabelFrameOfIcon: self];
  
	[self setNeedsDisplay: YES];
}

- (void)select
{
  if (isSelect) {
    return;
  }

	isSelect = YES;
	[namelabel setBackgroundColor: [NSColor whiteColor]]; 
	[delegate setLabelFrameOfIcon: self];
	[delegate unselectIconsDifferentFrom: self];
	[self setNeedsDisplay: YES];
}

- (void)unselect
{  
  if (isSelect == NO) {
    return;
  }
      
	isSelect = NO;
	[namelabel setBackgroundColor: [NSColor windowBackgroundColor]];  
	[self setNeedsDisplay: YES];  
}

- (void)renewIcon
{
  if (singlepath == YES) {
    ASSIGN (icon, [GWLib iconForFile: fullpath ofType: type]);    
  } else {
    ASSIGN (icon, [NSImage imageNamed: @"MultipleSelection.tiff"]);
  }
  [self setNeedsDisplay: YES];
}

- (void)openWithApp:(id)sender
{
  NSString *appName = [[sender representedObject] objectForKey: @"appName"];
  NSString *fullPath = [[sender representedObject] objectForKey: @"fullPath"];
    
  [ws openFile: fullPath withApplication: appName]; 
}

- (void)openWith:(id)sender
{
  [[GWLib workspaceApp] openSelectedPathsWith];
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
  isbranch = value;  
}

- (BOOL)isBranch
{
  return isbranch;
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
	[delegate clickedIcon: self];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSEvent *nextEvent;
  BOOL startdnd = NO;
  NSPoint p;
  
	CHECK_LOCK;
	
  p = [theEvent locationInWindow];
  p = [self convertPoint: p fromView: nil];
  
  if (ONICON(p, [self frame].size, [icon size]) == NO) {    
    return;  
  }

	if ([theEvent clickCount] > 1) { 
		unsigned int modifier = [theEvent modifierFlags];
		
		[delegate doubleClickedIcon: self newViewer: (modifier == NSControlKeyMask)];
    return;
	}  
    
  if (isSelect == NO) {  
    [self select];
    [delegate unselectNameEditor];
  }
   
  while (1) {
	  nextEvent = [[self window] nextEventMatchingMask:
    							            NSLeftMouseUpMask | NSLeftMouseDraggedMask];

    if ([nextEvent type] == NSLeftMouseUp) {
			[delegate clickedIcon: self];
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

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if (([theEvent type] != NSRightMouseDown) || (isSelect == NO)) {
    return [super menuForEvent: theEvent];
  } else if ([theEvent modifierFlags] == NSControlKeyMask) {
    return [super menuForEvent: theEvent];
  }
  if ((name == nil) || ([[name pathExtension] length] == 0) ) {
    return [super menuForEvent: theEvent];
  }
  if (contestualMenu == NO) {
    return [super menuForEvent: theEvent];
  }
  
  if ((type == NSPlainFileType) || ([type isEqual: NSShellCommandFileType])) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle: NSLocalizedString(@"Open with", @"")];
    NSString *ext = [name pathExtension];    
    NSDictionary *apps = [ws infoForExtension: ext];
    NSEnumerator *app_enum = [[apps allKeys] objectEnumerator];
    NSMenuItem *menuItem;
    id key;
    
    while ((key = [app_enum nextObject])) {
      NSDictionary *dict = [apps objectForKey: key];
      NSString *role = [dict objectForKey: @"NSRole"];
      NSMutableDictionary *repObjDict = [NSMutableDictionary dictionary];

      menuItem = [NSMenuItem new];    
      
      if (role) {
        [menuItem setTitle: [NSString stringWithFormat: @"%@ - %@", key, role]];
      } else {
        [menuItem setTitle: [NSString stringWithFormat: @"%@", key]];
      }
      
      [menuItem setTarget: self];      
      [menuItem setAction: @selector(openWithApp:)];      
      [repObjDict setObject: key forKey: @"appName"];
      [repObjDict setObject: fullpath forKey: @"fullPath"];      
      [menuItem setRepresentedObject: repObjDict];            
      [menu addItem: menuItem];
      RELEASE (menuItem);
    }

    menuItem = [NSMenuItem new]; 
    [menuItem setTitle:  NSLocalizedString(@"Open with...", @"")];
    [menuItem setTarget: self];      
    [menuItem setAction: @selector(openWith:)];          
    [menu addItem: menuItem];
    RELEASE (menuItem);

    AUTORELEASE (menu);
    return menu;
  }
  
  return [super menuForEvent: theEvent];
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
	delegate = aDelegate;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent 
{
  return YES;
}

- (void)drawRect:(NSRect)rect
{
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


@implementation PathIcon (DraggingSource)

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

  dragdelay = 0;
      
  [self dragImage: icon
               at: dragPoint 
           offset: NSZeroSize
            event: event
       pasteboard: pb
           source: self
        slideBack: [[GWLib workspaceApp] animateSlideBack]];
}

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  
  [pb declareTypes: dndtypes owner: nil];  
  
  if ([pb setPropertyList: paths forType: NSFilenamesPboardType] == NO) {
    return;
  }
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
  [self setNeedsDisplay: YES];
  [delegate restoreSelectionAfterDndOfIcon: self];
}

@end


@implementation PathIcon (DraggingDestination)

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
	
  if ((([type isEqualToString: NSDirectoryFileType] == NO)
      && ([type isEqualToString: NSFilesystemFileType] == NO)) || isPakage) {
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
  
	  if ([fm isWritableFileAtPath: fullpath] == NO) {
		  return NSDragOperationNone;
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
  if (isDragTarget == YES) {
    isDragTarget = NO;  
    ASSIGN (icon, [GWLib iconForFile: fullpath ofType: type]);
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
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
	NSString *trashPath;
  int i;

	CHECK_LOCK;
	
  ASSIGN (icon, [GWLib iconForFile: fullpath ofType: type]);
  [self setNeedsDisplay: YES];
	isDragTarget = NO;  

	sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];
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
	[opDict setObject: fullpath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];
	
	[[GWLib workspaceApp] performFileOperationWithDictionary: opDict];	
}

@end

