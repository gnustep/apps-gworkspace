/* DockIcon.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: May 2004
 *
 * This file is part of the GNUstep Desktop application
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
#include <math.h>
#include "DockIcon.h"
#include "Dock.h"
#include "GNUstep.h"

static id <DesktopApplication> desktopApp = nil;

@implementation DockIcon

- (void)dealloc
{
  if (application) {
    NSConnection *conn = [(NSDistantObject *)application connectionForProxy];
  
    if (conn && [conn isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: conn];
      DESTROY (application);
    }
  }
  
  RELEASE (appName);
  TEST_RELEASE (highlightColor);
  TEST_RELEASE (darkerColor);
  TEST_RELEASE (highlightImage);
  TEST_RELEASE (trashFullIcon);
  RELEASE (dragIcon);
  
  [super dealloc];
}

+ (void)initialize
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *appname = [defaults stringForKey: @"DesktopApplicationName"];
  NSString *selname = [defaults stringForKey: @"DesktopApplicationSelName"];

  if (appname && selname) {
    #ifdef GNUSTEP 
		Class desktopAppClass = [[NSBundle mainBundle] principalClass];
    #else
		Class desktopAppClass = [[NSBundle mainBundle] classNamed: appname];
    #endif
    SEL sel = NSSelectorFromString(selname);

    desktopApp = [desktopAppClass performSelector: sel];
  }
}

- (id)initForNode:(FSNode *)anode
         iconSize:(int)isize
{
  self = [super initForNode: anode
                   iconSize: isize
               iconPosition: NSImageOnly
                  labelFont: [NSFont systemFontOfSize: 12]
                  gridIndex: 0
                  dndSource: NO
                  acceptDnd: NO];

  if (self) {
    ASSIGN (appName, [[node name] stringByDeletingPathExtension]);
    isDocked = NO;
    isLaunched = NO;
    nc = [NSNotificationCenter defaultCenter];
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    dragIcon = [icon copy];
    [self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];    
  }

  return self;
}

- (void)setWsIcon:(BOOL)value
{
  isWsIcon = value;
}

- (BOOL)isWsIcon
{
  return isWsIcon;
}

- (void)setTrashIcon:(BOOL)value
{
  if (value != isTrashIcon) {
    isTrashIcon = value;

    if (isTrashIcon) {
      NSArray *subNodes;
      int i, count;

      ASSIGN (icon, [FSNodeRep trashIconOfSize: icnBounds.size.width]);
      ASSIGN (trashFullIcon, [FSNodeRep trashFullIconOfSize: icnBounds.size.width]);
      
      subNodes = [node subNodes];
      count = [subNodes count];
      
      for (i = 0; i < [subNodes count]; i++) {
        FSNode *subNode = [subNodes objectAtIndex: i];
        
        if ([[subNode name] hasPrefix: @"."]) {
          count --;
        }
      }
      
      [self setTrashFull: !(count == 0)];
    
    } else {
      ASSIGN (icon, [FSNodeRep iconOfSize: icnBounds.size.width forNode: node]);
    }
  }
}

- (void)setTrashFull:(BOOL)value
{
  trashFull = value;
  [self setNeedsDisplay: YES];
}

- (BOOL)isTrashIcon
{
  return isTrashIcon;
}

- (BOOL)isSpecialIcon
{
  return (isWsIcon || isTrashIcon);
}

- (void)setIsDocked:(BOOL)value
{
  isDocked = value;
}

- (BOOL)isDocked
{
  return isDocked;
}

- (void)setIsLaunched:(BOOL)value
{
  isLaunched = value;

  if (isLaunched) {
    if (application == nil) {
      [self connectApplication];
    }
    
    if (application) {
      [self setNeedsDisplay: YES];
    }
        
  } else {
    if (application) {
      NSConnection *conn = [(NSDistantObject *)application connectionForProxy];

      if (conn && [conn isValid]) {
        [nc removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: conn];
        DESTROY (application);
      }
    }
  
    [self setNeedsDisplay: YES];
    
    if ((isDocked == NO) && ([self isSpecialIcon] == NO)) {
      [(Dock *)container removeIcon: self];
    }
  }
}

- (void)connectApplication
{
  if (application == nil) {
    id app = [NSConnection rootProxyForConnectionWithRegisteredName: appName
                                                               host: @""];

    if (app) {
      NSConnection *conn = [app connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(applicationConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: conn];
      
      application = app;
      RETAIN (application);
      
	  } else {
	    static BOOL recursion = NO;
	  
      if (recursion == NO) {
        int i;
        
        for (i = 1; i <= 80; i++) {
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          app = [NSConnection rootProxyForConnectionWithRegisteredName: appName
                                                                  host: @""];                  
          if (app) {
            break;
          }
        }
        
	      recursion = YES;
	      [self connectApplication];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        NSLog(@"unable to contact %@!", appName);  
      }
	  }
  }
}

- (void)applicationConnectionDidDie:(NSNotification *)notif
{
  id conn = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: conn];

  NSAssert(conn == [application connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (application);
  application = nil;
  
  [self setIsLaunched: NO];
}

- (BOOL)isLaunched
{
  return isLaunched;
}

- (void)animateLaunch
{
	launching = YES;
	dissFract = 0.2;
    
	while (1) {
		NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.02];
		[[NSRunLoop currentRunLoop] runUntilDate: date];
		[self display];

    dissFract += 0.05;
	  if (dissFract >= 1) {
		  launching = NO;
      break;
	  }
	}
  
  [self setNeedsDisplay: YES];
}

- (void)setHighlightColor:(NSColor *)color
{
  ASSIGN (highlightColor, [color highlightWithLevel: 0.2]);
  ASSIGN (darkerColor, [color shadowWithLevel: 0.4]);
}

- (void)setHighlightImage:(NSImage *)image
{
  DESTROY (highlightImage);
  
  if (image) {
    NSSize size = [self frame].size;
    
    highlightImage = [[NSImage alloc] initWithSize: size];
    [highlightImage lockFocus]; 
    [image compositeToPoint: NSZeroPoint 
                   fromRect: [self frame]
                  operation: NSCompositeCopy];
    [highlightImage unlockFocus];
  }
}

- (void)setUseHlightImage:(BOOL)value
{
  useHligtImage = value;
}

- (void)setIsDndSourceIcon:(BOOL)value
{
  if (isDndSourceIcon != value) {
    isDndSourceIcon = value;
    [self setNeedsDisplay: YES];
  }
}

- (void)setIconSize:(int)isize
{
  icnBounds = NSMakeRect(0, 0, isize, isize);
  if (isTrashIcon) {
    ASSIGN (icon, [FSNodeRep trashIconOfSize: icnBounds.size.width]);
    ASSIGN (trashFullIcon, [FSNodeRep trashFullIconOfSize: icnBounds.size.width]);
  } else {
    ASSIGN (icon, [FSNodeRep iconOfSize: icnBounds.size.width forNode: node]);
  }
  hlightRect.size.width = ceil(isize / 3 * 4);
  hlightRect.size.height = ceil(hlightRect.size.width * [FSNodeRep highlightHeightFactor]);
  if ((hlightRect.size.height - isize) < 4) {
    hlightRect.size.height = isize + 4;
  }
  hlightRect.origin.x = 0;
  hlightRect.origin.y = 0;
  ASSIGN (highlightPath, [FSNodeRep highlightPathOfSize: hlightRect.size]); 
  [self tile];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  if ([theEvent clickCount] > 1) {  
    if ((isLaunched == NO) && ([self isSpecialIcon] == NO)) {
      [ws launchApplication: appName];
      
    } else if (isWsIcon) {
      id <workspaceAppProtocol> workspaceApp = [desktopApp workspaceApplication];
      
      if (workspaceApp) {
        [workspaceApp showRootViewer];
      }      
    
    } else if (isTrashIcon) {
      id <workspaceAppProtocol> workspaceApp = [desktopApp workspaceApplication];
      
      if (workspaceApp) {
        NSString *path = [node path];
        [workspaceApp selectFile: path inFileViewerRootedAtPath: path];
      }      
    }
  }  
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSEvent *nextEvent = nil;
  BOOL startdnd = NO;
    
	if ([theEvent clickCount] == 1) {
    [self select];
    
    dragdelay = 0;
    [(Dock *)container setDndSourceIcon: nil];
    
    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
	      [self unselect];
        break;

      } else if (([nextEvent type] == NSLeftMouseDragged)
                                          && ([self isSpecialIcon] == NO)) {
	      if (dragdelay < 5) {
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
  NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [dict setObject: [node name] forKey: @"name"];
  [dict setObject: [NSNumber numberWithBool: isDocked] 
           forKey: @"docked"];
  [dict setObject: [NSNumber numberWithBool: isLaunched] 
           forKey: @"launched"];
  
  [pb declareTypes: [NSArray arrayWithObject: @"DockIconPboardType"] 
             owner: nil];
    
  if ([pb setData: [NSArchiver archivedDataWithRootObject: dict] 
          forType: @"DockIconPboardType"]) {
    [self unselect];  
    [self setIsDndSourceIcon: YES];
    [(Dock *)container setDndSourceIcon: self];
    [(Dock *)container tile];
    
    [[self window] dragImage: dragIcon
                          at: NSZeroPoint 
                      offset: NSZeroSize
                       event: event
                  pasteboard: pb
                      source: self
                   slideBack: NO];
  }
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
	dragdelay = 0;
  [self setIsDndSourceIcon: NO];
  [(Dock *)container setDndSourceIcon: nil];
}

- (void)drawRect:(NSRect)rect
{   
#define DRAWDOTS(c1, c2, p) \
{ \
int i, x = p.x, y = p.y; \
for (i = 0; i < 3; i++) { \
[c1 set]; \
NSRectFill(NSMakeRect(x, y, 3, 2)); \
[c2 set]; \
NSRectFill(NSMakeRect(x + 1, y, 2, 1)); \
NSRectFill(NSMakeRect(x + 2, y + 1, 1, 1)); \
x += 6; \
} \
}
 	 
  if (isSelected || launching) {
    [highlightColor set];
    NSRectFill(rect);

    if (highlightImage && useHligtImage) {
      [highlightImage dissolveToPoint: NSZeroPoint fraction: 0.2];
    }
  }
  
  if (launching) {		
	  [icon dissolveToPoint: icnBounds.origin fraction: dissFract];
	  return;
  }
  
  if (isDndSourceIcon == NO) {
    if (isTrashIcon == NO) {
      [icon compositeToPoint: icnBounds.origin operation: NSCompositeSourceOver];
    } else {
      if (trashFull) {
        [trashFullIcon compositeToPoint: icnBounds.origin operation: NSCompositeSourceOver];
      } else {
        [icon compositeToPoint: icnBounds.origin operation: NSCompositeSourceOver];
      }
    }
    
    if ((isWsIcon == NO) && (isTrashIcon == NO) && (isLaunched == NO)) {
      DRAWDOTS (darkerColor, [NSColor whiteColor], NSMakePoint(4, 2));
    }
  }
}

@end


@implementation DockIcon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];

  isDragTarget = YES;  
              
  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
  
    if ((isTrashIcon == NO) && (isWsIcon == NO)) {
      int i;
    
      for (i = 0; i < [sourcePaths count]; i++) {
        NSString *path = [sourcePaths objectAtIndex: i];
        FSNode *nod = [FSNode nodeWithRelativePath: path parent: nil];

        if (([nod isPlain] || ([nod isPackage] && ([nod isApplication] == NO))) == NO) {
          return NSDragOperationNone;
        }
      }
      
      isDragTarget = YES; 
      [self select]; 
      return NSDragOperationAll;
      
    } else if (isTrashIcon) {
      isDragTarget = YES;  
      [self select];
      return NSDragOperationAll;
    }
  }
  
  isDragTarget = NO; 
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];

  isDragTarget = YES;  
              
  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
  
    if ((isTrashIcon == NO) && (isWsIcon == NO)) {
      int i;
    
      for (i = 0; i < [sourcePaths count]; i++) {
        NSString *path = [sourcePaths objectAtIndex: i];
        FSNode *nod = [FSNode nodeWithRelativePath: path parent: nil];

        if (([nod isPlain] || ([nod isPackage] && ([nod isApplication] == NO))) == NO) {
          return NSDragOperationNone;
        }
      }

      isDragTarget = YES;  
      [self select];
      return NSDragOperationAll;
      
    } else if (isTrashIcon) {
      isDragTarget = YES;  
      [self select];
      return NSDragOperationAll;
    }
  }
  
  isDragTarget = NO; 
  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  [self unselect];
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

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];

  [self unselect];
  isDragTarget = NO;
        
  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
    int i;
  
    if ([self isSpecialIcon] == NO) {
      for (i = 0; i < [sourcePaths count]; i++) {
        NSString *path = [sourcePaths objectAtIndex: i];
        FSNode *nod = [FSNode nodeWithRelativePath: path parent: nil];

        if ([nod isPlain] || ([nod isPackage] && ([nod isApplication] == NO))) {
          [ws openFile: [sourcePaths objectAtIndex: i] withApplication: appName];
        }
      }

    } else if (isTrashIcon) {
      NSArray *vpaths = [ws mountedLocalVolumePaths];
      NSMutableArray *files = [NSMutableArray array];
      NSMutableArray *umountPaths = [NSMutableArray array];
      NSMutableDictionary *opinfo = [NSMutableDictionary dictionary];

      for (i = 0; i < [sourcePaths count]; i++) {
        NSString *srcpath = [sourcePaths objectAtIndex: i];
      
        if ([vpaths containsObject: srcpath]) {
          [umountPaths addObject: srcpath];
        } else {
          [files addObject: [srcpath lastPathComponent]];
        }
      }
      
      for (i = 0; i < [umountPaths count]; i++) {
        [ws unmountAndEjectDeviceAtPath: [umountPaths objectAtIndex: i]];
      }
      
      if ([files count]) {
        [opinfo setObject: @"NSWorkspaceRecycleOperation" forKey: @"operation"];
        [opinfo setObject: [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent]
                   forKey: @"source"];
        [opinfo setObject: [node path] forKey: @"destination"];
        [opinfo setObject: files forKey: @"files"];

        [desktopApp performFileOperation: opinfo];
      }
    }
  }
}

@end

