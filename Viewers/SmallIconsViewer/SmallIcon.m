/* SmallIcon.m
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
#include "SmallIcon.h"
#include "SmallIconLabel.h"
#include "GNUstep.h"

#define CHECK_LOCK if (locked) return
#define CHECK_LOCK_RET(x) if (locked) return x

@implementation SmallIcon

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
    NSString *defApp = nil, *t = nil;

		ASSIGN (path, apath);
		[self setDelegate: adelegate];

    [self setFrame: NSMakeRect(0, 0, 32, 26)];
    isSelect = NO; 
    locked = NO;

    fm = [NSFileManager defaultManager];
		
		ASSIGN (name, [path lastPathComponent]);
			
		[[NSWorkspace sharedWorkspace] getInfoForFile: path 
                                      application: &defApp 
                                             type: &t];      
		ASSIGN (type, t);
		isPakage = [GWLib isPakageAtPath: path];
		
		ASSIGN (icon, [GWLib smallIconForFile: path]); 
    ASSIGN (highlight, [NSImage imageNamed: @"SmallCellHighlight.tiff"]);

    namelabel = [[SmallIconLabel alloc] initForIcon: self];
		[namelabel setFont: [NSFont systemFontOfSize: 12]];
		[namelabel setBezeled: NO];
		[namelabel setEditable: NO];
		[namelabel setSelectable: NO];
		[namelabel setAlignment: NSLeftTextAlignment];
	  [namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
	  [namelabel setTextColor: [NSColor controlTextColor]];
		[namelabel setStringValue: name];
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];

		position = NSMakePoint(0, 0);
		center = NSMakePoint(0, 0);
		gridindex = -1;    
    dragdelay = 0;
    isDragTarget = NO;
    onSelf = NO;
  }
  
  return self;
}

- (id)initForPath:(NSString *)apath 
				gridIndex:(int)index 
				 delegate:(id)adelegate
{
	[self initForPath: apath delegate: adelegate];
	gridindex = index;
  return self;
}

- (void)setPath:(NSString *)apath
{
  NSString *defApp = nil, *t = nil;

	ASSIGN (path, apath);
	ASSIGN (icon, [GWLib smallIconForFile: path]);        
		
	[[NSWorkspace sharedWorkspace] getInfoForFile: path 
														        application: &defApp 
																		       type: &t];      
	ASSIGN (type, t);
	isPakage = [GWLib isPakageAtPath: path];
	ASSIGN (name, [path lastPathComponent]);
	[namelabel setStringValue: name];
  [self setLabelFrame]; 
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
	[self setNeedsDisplay: YES];
	[(NSView *)delegate setNeedsDisplayInRect: [namelabel frame]];
	[delegate unselectIconsDifferentFrom: self];	
	[delegate setTheCurrentSelection];	
}

- (void)unselect
{
  if (isSelect == NO) {
    return;
  }
	isSelect = NO;
	[self setNeedsDisplay: YES];
	[namelabel setBackgroundColor: [NSColor windowBackgroundColor]];
  [namelabel setEditable: NO];
  [namelabel setSelectable: NO];  
	[(NSView *)delegate setNeedsDisplayInRect: [namelabel frame]];
	[delegate setTheCurrentSelection];	
}

- (void)clickOnLabel
{
	CHECK_LOCK;
	
  if (isSelect == NO) {
    [self select];
  } else {
	  [namelabel setSelectable: YES];
    [namelabel setEditable: YES];  
  }
}

- (void)setLabelFrame
{
	NSPoint p = [namelabel frame].origin;
	labelWidth = [[NSFont systemFontOfSize: 12] widthOfString: name] + 8;
	[namelabel setFrame: NSMakeRect(p.x, p.y, labelWidth, 14)];
	[namelabel setNeedsDisplay: YES];
}

- (void)setPosition:(NSPoint)pos
{
  position = NSMakePoint(pos.x, pos.y);
	center = NSMakePoint(_frame.origin.x + (_frame.size.width / 2), 
														_frame.origin.y + (_frame.size.height / 2));
}

- (void)setPosition:(NSPoint)pos gridIndex:(int)index
{
  [self setPosition: pos];
	gridindex = index;
}

- (NSPoint)position
{
  return position;
}

- (NSPoint)center
{
	return center;
}

- (void)setGridIndex:(int)index
{
	gridindex = index;
}

- (int)gridindex
{
	return gridindex;
}

- (NSTextField *)label
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

- (int)labelWidth
{
	return labelWidth;
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
	[namelabel setEditable: !locked];
	[namelabel setSelectable: !locked];	
	[self setNeedsDisplay: YES];		
	[namelabel setNeedsDisplay: YES];
}

- (BOOL)isLocked
{
	return locked;
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

- (void)setFrame:(NSRect)frameRect
{
	[super setFrame: frameRect];
	[self setLabelFrame];
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
		if (locked) {
			[icon dissolveToPoint: p fraction: 0.3];
		} else {
			[icon compositeToPoint: p operation: NSCompositeSourceOver];
		}
	}
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
	int count = [theEvent clickCount];    

  CHECK_LOCK;
	
	if(count == 1) {
		if([theEvent modifierFlags] == 2)  {
			[delegate setShiftClickValue: YES];     
			if (isSelect == YES) {
				[self unselect];
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
	}  
}

- (void)mouseDragged:(NSEvent *)theEvent
{
  if ([fm fileExistsAtPath: path] == NO) {
    return;
  }
  
	if(dragdelay < 5) {
    dragdelay++;
    return;
  }
  
  [self startExternalDragOnEvent: theEvent];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if (([theEvent type] == NSRightMouseDown) && isSelect) {
    return [delegate menuForRightMouseEvent: theEvent];
  }
  
  return [super menuForEvent: theEvent]; 
}

//
// SmallIconLabel delegate methods
//
- (BOOL)control:(NSControl *)control 
                textShouldBeginEditing:(NSText *)fieldEditor
{
  NSArray *selection = [delegate getTheCurrentSelection];
  
  if ([selection count] == 1) {
    NSString *selected = [[selection objectAtIndex: 0] lastPathComponent];

    if ([selected isEqual: name]) {
      return YES;
    } 
  }
  
  return NO;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSDictionary *info = [aNotification userInfo];
  NSText *text = [info objectForKey: @"NSFieldEditor"];  
  NSString *current = [text string];
	NSPoint p = [namelabel frame].origin;

	labelWidth = [[NSFont systemFontOfSize: 12] widthOfString: current] + 8;
	[namelabel setFrame: NSMakeRect(p.x, p.y, labelWidth, 14)];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSDictionary *info;
  NSString *basePath, *newpath, *newname;
	NSString *title, *msg1, *msg2;
  NSMutableDictionary *notifObj;  
  NSArray *dirContents;
  NSCharacterSet *notAllowSet;
  NSRange range;
  BOOL samename;
//  NSEvent *e;
  int i;

#define CLEAREDITING \
	[namelabel setStringValue: name]; \
  [self setLabelFrame]; \
  return

  info = [aNotification userInfo];
  newname = [[info objectForKey: @"NSFieldEditor"] string];

  basePath = [path stringByDeletingLastPathComponent];  // QUA

	if ([fm fileExistsAtPath: path] == NO) {
		notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];		
		[notifObj setObject: NSWorkspaceDestroyOperation forKey: @"operation"];	
  	[notifObj setObject: basePath forKey: @"source"];	
  	[notifObj setObject: basePath forKey: @"destination"];	
  	[notifObj setObject: [NSArray arrayWithObjects: path, nil] forKey: @"files"];	

	  [[NSNotificationCenter defaultCenter]
 				   postNotificationName: GWFileSystemWillChangeNotification
	 								  object: notifObj];

    RETAIN (self);

	  [[NSNotificationCenter defaultCenter]
 				   postNotificationName: GWFileSystemDidChangeNotification
	 								  object: notifObj];

    AUTORELEASE (self);                               

		return;
	}
  
	title = NSLocalizedString(@"Error", @"");
	msg1 = NSLocalizedString(@"You have not write permission\nfor ", @"");
	msg2 = NSLocalizedString(@"Continue", @"");		
  if ([fm isWritableFileAtPath: path] == NO) {
    NSRunAlertPanel(title, [NSString stringWithFormat: @"%@\"%@\"!\n", msg1, path], msg2, nil, nil);   
		CLEAREDITING;
  } else if ([fm isWritableFileAtPath: basePath] == NO) {	
    NSRunAlertPanel(title, [NSString stringWithFormat: @"%@\"%@\"!\n", msg1, basePath], msg2, nil, nil);   
		CLEAREDITING;
  }  
      
  notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*$|~\'\"`^!?"];
  range = [newname rangeOfCharacterFromSet: notAllowSet];
  
  if (range.length > 0) {
		msg1 = NSLocalizedString(@"Invalid char in name", @"");
    NSRunAlertPanel(title, msg1, msg2, nil, nil);
    CLEAREDITING;
  }	

  dirContents = [fm directoryContentsAtPath: basePath];

  samename = NO;			
  for (i = 0; i < [dirContents count]; i++) {
    if ([newname isEqualToString: [dirContents objectAtIndex:i]]) {    
      if ([newname isEqualToString: name]) {
        CLEAREDITING;
      } else {
        samename = YES;
        break;
      }
    }
  }	
  if (samename == YES) {
		NSString *msg3 = NSLocalizedString(@"The name ", @"");
		msg1 = NSLocalizedString(@" is already in use!", @"");	
    NSRunAlertPanel(title, [NSString stringWithFormat: @"%@'%@'%@!", msg3, newname, msg1], msg2, nil, nil);   
    CLEAREDITING;
  }

//  e = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSKeyUpMask];
//  [[self window] flushWindow];   

  newpath = [basePath stringByAppendingPathComponent: newname];

	notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];		
	[notifObj setObject: GWorkspaceRenameOperation forKey: @"operation"];	
  [notifObj setObject: path forKey: @"source"];	
  [notifObj setObject: newpath forKey: @"destination"];	
  [notifObj setObject: [NSArray arrayWithObjects: @"", nil] forKey: @"files"];	

	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWFileSystemWillChangeNotification
	 								object: notifObj];
    
  [fm movePath: path toPath: newpath handler: self];

  RETAIN (self);
    
	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWFileSystemDidChangeNotification
	 								object: notifObj];
                  
  AUTORELEASE (self);                               
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSString *title = NSLocalizedString(@"Error", @"");
	NSString *msg1 = NSLocalizedString(@"Cannot rename ", @"");
	NSString *msg2 = NSLocalizedString(@"Continue", @"");

  NSRunAlertPanel(title, [NSString stringWithFormat: @"%@'%@'!", msg1, name], msg2, nil, nil);   
	return NO;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

@end

@implementation SmallIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
{
	NSEvent *nextEvent;
  NSPoint dragPoint;
  NSPasteboard *pb;
	NSArray *selection;
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

@implementation SmallIcon (DraggingDestination)

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
        NSSize size = [img size];
        [img setScalesWhenResized: YES];
        [img setSize: NSMakeSize(size.width / 2, size.height / 2)];
        ASSIGN (icon, img);
        RELEASE (img);
      } else {
        ASSIGN (icon, [NSImage imageNamed: GWSmallOpenFolderIconName]);
      }      
    } else {
	    ASSIGN (icon, [NSImage imageNamed: GWSmallOpenFolderIconName]);    
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
  if(isDragTarget == YES) {
    isDragTarget = NO;
    if (onSelf == NO) {      
      ASSIGN (icon, [GWLib smallIconForFile: path]);
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
  
  ASSIGN (icon, [GWLib smallIconForFile: path]);
  [self setNeedsDisplay: YES];

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
	[opDict setObject: path forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];
	
	[[GWLib workspaceApp] performFileOperationWithDictionary: opDict];	
}

@end
