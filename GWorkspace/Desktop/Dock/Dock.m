/* Dock.m
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "Dock.h"
#include "DockIcon.h"
#include "GWDesktopView.h"

#define MAX_ICN_SIZE 48
#define MIN_ICN_SIZE 16
#define ICN_INCR 4

@implementation Dock

- (void)dealloc
{
  [wsnc removeObserver: self];
  RELEASE (icons);
  RELEASE (backColor);
  TEST_RELEASE (backImage);
  
	[super dealloc];
}

- (id)initForManager:(id)mngr
{
	self = [super initWithFrame: NSMakeRect(0, 0, 64, 64)];
  
  if (self) {
	  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSArray *launched;
    NSDictionary *appsdict;
    NSArray *pbTypes;
    int i;

    manager = mngr;
    position = [manager dockPosition];
    
    ws = [NSWorkspace sharedWorkspace];
    wsnc = [ws notificationCenter];   
    launched = [ws launchedApplications];

    icons = [NSMutableArray new];
    iconSize = MAX_ICN_SIZE;
    
    [self createWorkspaceIcon];
          
    appsdict = [defaults objectForKey: @"applications"];
      
    if (appsdict) {
      NSArray *indexes = [appsdict allKeys];
    
      indexes = [indexes sortedArrayUsingSelector: @selector(compare:)];
    
      for (i = 0; i < [indexes count]; i++) {
        NSNumber *index = [indexes objectAtIndex: i];
        NSString *appname = [appsdict objectForKey: index];
        DockIcon *icon = [self addIconForApplicationWithName: appname 
                                                     atIndex: [index intValue]];
        [icon setIsDocked: YES];
      }
    }

    [self createTrashIcon];
          
    for (i = 0; i < [launched count]; i++) {
    //  NSDictionary *dict = [launched objectAtIndex: i];
    //  NSString *appname = [dict objectForKey: @"NSApplicationName"];
    //  DockIcon *icon = [self iconForApplicationName: appname];
      
    //  if (icon) {
    //    [icon setIsLaunched: YES];
    //  }
    }       
          
    [self setBackColor: [[manager desktopView] currentColor]];
        
    dndSourceIcon = nil;
    isDragTarget = NO;  
    dragdelay = 0;
    targetIndex = -1;
    targetRect = NSZeroRect;
    
    pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, 
                                         @"DockIconPboardType", 
                                         nil];
    [self registerForDraggedTypes: pbTypes];    
    
    [wsnc addObserver: self
	           selector: @selector(applicationWillLaunch:)
		             name: NSWorkspaceWillLaunchApplicationNotification
		           object: nil];
    
    [wsnc addObserver: self
	           selector: @selector(applicationLaunched:)
		             name: NSWorkspaceDidLaunchApplicationNotification
		           object: nil];    
  }
  
  return self;  
}

- (void)createWorkspaceIcon;
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	  
  NSString *wsname = [defaults stringForKey: @"GSWorkspaceApplication"];
  NSString *path;
  FSNode *node;
  DockIcon *icon;
  
  if (wsname == nil) {
    wsname = @"GWorkspace";
  }

  path = [ws fullPathForApplication: wsname];
  node = [FSNode nodeWithPath: path];
  
  icon = [[DockIcon alloc] initForNode: node iconSize: iconSize];
  [icon setWsIcon: YES];   
  [icon setIsDocked: YES];                        
  [icons insertObject: icon atIndex: 0];
  [self addSubview: icon];
  RELEASE (icon);
}

- (void)createTrashIcon
{
  NSString *path = [manager trashPath];
  FSNode *node = [FSNode nodeWithPath: path];
  DockIcon *icon = [[DockIcon alloc] initForNode: node iconSize: iconSize];
  
  [icon setTrashIcon: YES];  
  [icon setIsDocked: YES];                         
  [icons insertObject: icon atIndex: [icons count]];
  [self addSubview: icon];
  RELEASE (icon);
  
  [manager addWatcherForPath: path];
}

- (DockIcon *)addIconForApplicationWithName:(NSString *)name
                                    atIndex:(int)index
{
  NSString *path = [ws fullPathForApplication: name];

  if (path) {
    FSNode *node = [FSNode nodeWithPath: path];
    
    if ([node isApplication]) {
      DockIcon *icon = [[DockIcon alloc] initForNode: node iconSize: iconSize];
      int icnindex;

      if (index == -1) {
        icnindex = ([icons count]) ? ([icons count] - 1) : 0;
      } else {
        icnindex = (index < [icons count]) ? (index + 1) : [icons count];
      }

      [icon setHighlightColor: backColor];
      [icon setUseHlightImage: useBackImage];
      [icons insertObject: icon atIndex: icnindex];
      [self addSubview: icon];
      RELEASE (icon);
      
      [manager addWatcherForPath: [node path]];
      
      return icon;
    }
  }
  
  return nil;
}

- (void)addDraggedIcon:(NSData *)icondata
               atIndex:(int)index
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: icondata];
  NSString *appname = [dict objectForKey: @"name"];
  DockIcon *icon = [self addIconForApplicationWithName: appname atIndex: index];

  [icon setIsDocked: [[dict objectForKey: @"docked"] boolValue]];
  [icon setIsLaunched: [[dict objectForKey: @"launched"] boolValue]];
}

- (void)removeIcon:(DockIcon *)icon
{
  [manager removeWatcherForPath: [[icon node] path]];
  
  if ([icon superview]) {
    [icon removeFromSuperview];
  }
  if ([icon isLaunched]) {
    [icon setIsLaunched: NO];
  }
  [icons removeObject: icon];
  [self tile];
}

- (DockIcon *)iconForApplicationName:(NSString *)name
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];
    NSString *nodename = [[icon node] name];
    
    if ([[nodename stringByDeletingPathExtension] isEqual: name]) {
      return icon;
    }
  }
  
  return nil;
}

- (DockIcon *)workspaceAppIcon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];
    
    if ([icon isWsIcon]) {
      return icon;
    }
  }
  
  return nil;
}

- (DockIcon *)trashIcon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];
    
    if ([icon isTrashIcon]) {
      return icon;
    }
  }
  
  return nil;
}

- (DockIcon *)iconContainingPoint:(NSPoint)p
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];
    NSRect r = [icon frame];
    
    if (NSPointInRect(p, NSInsetRect(r, 0.0, 2.0))) {
      return icon;
    }
  }
  
  return nil;
}

- (void)setDndSourceIcon:(DockIcon *)icon
{
  dndSourceIcon = icon;
}

- (void)applicationWillLaunch:(NSNotification *)notif
{
  NSString *appname = [[notif userInfo] objectForKey: @"NSApplicationName"];
  DockIcon *icon = [self iconForApplicationName: appname];
  
  if (icon == nil) {
    icon = [self addIconForApplicationWithName: appname atIndex: -1];
  } 
  
  if (icon) {
    [self tile];
    [icon animateLaunch];
  }
}

- (void)applicationLaunched:(NSNotification *)notif
{
  NSString *appname = [[notif userInfo] objectForKey: @"NSApplicationName"];
  DockIcon *icon = [self iconForApplicationName: appname];

  if ((icon == nil) && ([appname isEqual: @"Desktop"] == NO)) {
    icon = [self addIconForApplicationWithName: appname atIndex: -1];
    [self tile];
  } 
  
  if (icon) {
    [icon setIsLaunched: YES];
  }
}

- (void)setPosition:(DockPosition)pos
{
  position = pos;
  [self tile];
}

- (void)setBackColor:(NSColor *)color
{
  NSColor *hlgtcolor = [color highlightWithLevel: 0.2];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setHighlightColor: hlgtcolor];
  }
  
  ASSIGN (backColor, hlgtcolor);
  if ([self superview]) {
    [self tile];
  }
}

- (void)setBackImage
{
  NSImage *image = [[manager desktopView] backImage];
  int i;

  DESTROY (backImage);

  if (image) {
    NSSize size = [self frame].size;
    
    backImage = [[NSImage alloc] initWithSize: size];
    [backImage lockFocus]; 
    [image compositeToPoint: NSZeroPoint 
                   fromRect: [self frame]
                  operation: NSCompositeCopy];
    [backImage unlockFocus];
    [self setNeedsDisplay: YES];
  }
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setHighlightImage: backImage];
  }
}

- (void)setUseBackImage:(BOOL)value
{
  int i;

  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setUseHlightImage: value];
  }
  
  useBackImage = value;
  [self setNeedsDisplay: YES];
}

- (void)tile
{
  NSView *view = [self superview];
  NSRect scrrect = [[NSScreen mainScreen] frame];
  int oldIcnSize = iconSize;
  float maxheight = scrrect.size.height;
  NSRect icnrect = NSZeroRect;  
  NSRect rect = NSZeroRect;
  int i;

  iconSize = MAX_ICN_SIZE;
  
  icnrect.origin.x = 0;
  icnrect.origin.y = 0;
  icnrect.size.width = ceil(iconSize / 3 * 4);
  icnrect.size.height = icnrect.size.width;
    
  rect.size.height = [icons count] * icnrect.size.height;
  if (targetIndex != -1) {
    rect.size.height += icnrect.size.height;
  }
  
  maxheight -= (icnrect.size.height * 2);  
  
  while (rect.size.height > maxheight) {
    iconSize -= ICN_INCR;
    icnrect.size.height = ceil(iconSize / 3 * 4);
    icnrect.size.width = icnrect.size.height;
    rect.size.height = [icons count] * icnrect.size.height;

    if (targetIndex != -1) {
      rect.size.height += icnrect.size.height;
    }
      
    if (iconSize <= MIN_ICN_SIZE) {
      break;
    }
  }

  rect.size.width = icnrect.size.width;
  rect.origin.x = (position == DockPositionLeft) ? 0 : scrrect.size.width - rect.size.width;
  rect.origin.y = (scrrect.size.height - rect.size.height) / 2;
  
  if (view) {
    [view setNeedsDisplayInRect: [self frame]];
  }
  [self setFrame: rect];
  [self setBackImage];
  
  icnrect.origin.y = rect.size.height;
  
  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];
  
    if (oldIcnSize != iconSize) {
      [icon setIconSize: iconSize];
    }
    
    icnrect.origin.y -= icnrect.size.height;
    [icon setFrame: icnrect];
    [icon setHighlightImage: backImage];
    
    if ((targetIndex != -1) && (targetIndex == i)) {
      icnrect.origin.y -= icnrect.size.height;
      targetRect = icnrect;
    }
  } 
  
  [self setNeedsDisplay: YES];
  if (view) {
    [view setNeedsDisplayInRect: [self frame]];
  }
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  int i;  

  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];    

    if (([icon isSpecialIcon] == NO) && [icon isDocked]) {
      [dict setObject: [[icon node] name] forKey: [NSNumber numberWithInt: i]];
      [manager removeWatcherForPath: [[icon node] path]];
    }
  }

  [defaults setObject: dict forKey: @"applications"];
  
  [manager removeWatcherForPath: [manager trashPath]];
}

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];
  
  [backColor set];
  NSRectFill(rect);
  
  if (backImage && useBackImage) {
    [backImage dissolveToPoint: NSZeroPoint fraction: 0.5];
  }
}

@end


@implementation Dock (NodeRepContainer)

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
	NSString *source = [info objectForKey: @"source"];	  
	NSString *destination = [info objectForKey: @"destination"];	 
	NSArray *files = [info objectForKey: @"files"];	 
  int i, count;
  
  if ([operation isEqual: NSWorkspaceMoveOperation]
        || [operation isEqual: NSWorkspaceDestroyOperation]
		    || [operation isEqual: NSWorkspaceRecycleOperation]
        || [operation isEqual: @"GWorkspaceRenameOperation"]) {
    count = [icons count];
    
    for (i = 0; i < count; i++) {
      DockIcon *icon = [icons objectAtIndex: i];
      FSNode *node = [icon node];
      
      if ([source isEqual: [node parentPath]]) {
        if ([files containsObject: [node name]]) {
          if ([icon isSpecialIcon] == NO) {
            [self removeIcon: icon];
            count--;
            i--;
          }
        }
      }
    }
  }  
  
  if ([operation isEqual: NSWorkspaceMoveOperation]
      || [operation isEqual: NSWorkspaceCopyOperation]
			|| [operation isEqual: NSWorkspaceRecycleOperation]) { 
    DockIcon *icon = [self trashIcon];
    NSString *trashPath = [[icon node] path];
    
    if ([destination isEqual: trashPath]) {
      [icon setTrashFull: YES];
    }
  }

  if ([operation isEqual: @"GWorkspaceRecycleOutOperation"]
			    || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]
          || [operation isEqual: NSWorkspaceMoveOperation]
          || [operation isEqual: NSWorkspaceDestroyOperation]) { 
    DockIcon *icon = [self trashIcon];
    FSNode *node = [icon node];
    NSString *trashPath = [node path];
    NSString *basePath;
    
    if ([operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]
                || [operation isEqual: NSWorkspaceDestroyOperation]) { 
      basePath = destination;  
    } else {
      basePath = source;  
    }
    
    if ([basePath isEqual: trashPath]) {
      NSArray *subNodes = [node subNodes];
      int count = [subNodes count];
    
      for (i = 0; i < [subNodes count]; i++) {
        if ([[subNodes objectAtIndex: i] isReserved]) {
          count --;
        }
      }
      
      if (count == 0) {
        [icon setTrashFull: NO];
      }
    }
  }
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  NSString *event = [info objectForKey: @"event"];
  NSString *path = [info objectForKey: @"path"];
    
  if ([event isEqual: @"GWWatchedPathDeleted"]) {
    int count = [icons count];
    int i;

    for (i = 0; i < count; i++) {
      DockIcon *icon = [icons objectAtIndex: i];
      
      if ([icon isSpecialIcon] == NO) {
        FSNode *node = [icon node];
        
        if ([path isEqual: [node path]]) {
          [self removeIcon: icon];
          count--;
          i--;
        }
      }
    }
    
  } else if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    if ([path isEqual: [manager trashPath]]) {
      DockIcon *icon = [self trashIcon];  
      FSNode *node = [icon node];
      NSArray *subNodes = [node subNodes];
      int count = [subNodes count];
      int i;

      for (i = 0; i < [subNodes count]; i++) {
        if ([[subNodes objectAtIndex: i] isReserved]) {
          count --;
        }
      }
      
      if (count == 0) {
        [icon setTrashFull: NO];
      }
    }
    
  } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    if ([path isEqual: [manager trashPath]]) {
      DockIcon *icon = [self trashIcon];  
      FSNode *node = [icon node];
      NSArray *subNodes = [node subNodes];
      int i;

      for (i = 0; i < [subNodes count]; i++) {
        if ([[subNodes objectAtIndex: i] isReserved] == NO) {
          [icon setTrashFull: YES];
          break;
        }
      }
    }
  }
}

- (void)unselectOtherReps:(id)arep
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];    

    if (icon != arep) {
      [icon unselect];
    }
  }
}

- (FSNSelectionMask)selectionMask
{
  return NSSingleSelectionMask;
}

- (void)setBackgroundColor:(NSColor *)acolor
{
  NSColor *hlgtcolor = [acolor highlightWithLevel: 0.2];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setHighlightColor: hlgtcolor];
  }
  
  ASSIGN (backColor, hlgtcolor);
  if ([self superview]) {
    [self tile];
  }
}

- (NSColor *)backgroundColor
{
  return backColor;
}

- (NSColor *)textColor
{
  return [NSColor controlTextColor];
}

- (NSColor *)disabledTextColor
{
  return [NSColor disabledControlTextColor];
}

@end


@implementation Dock (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPoint location = [sender draggingLocation];
  DockIcon *icon;
        
  isDragTarget = YES;  
  targetIndex = -1;
  targetRect = NSZeroRect;
  dragdelay = 0;     

  location = [self convertPoint: location fromView: nil];
  icon = [self iconContainingPoint: location];
                 
  if (icon) {
    int index = [icons indexOfObjectIdenticalTo: icon];
        
    if (dndSourceIcon && ([sender draggingSource] == dndSourceIcon)) {
      if (icon != dndSourceIcon) {
        RETAIN (dndSourceIcon);
        [icons removeObject: dndSourceIcon];
        [icons insertObject: dndSourceIcon atIndex: index];
        RELEASE (dndSourceIcon);
        [self tile];  
        return NSDragOperationMove;    
      }

    } else {
      NSPasteboard *pb = [sender draggingPasteboard];
      
      if ([[pb types] containsObject: @"DockIconPboardType"]) {
        if ([icon isTrashIcon] == NO) {
          targetIndex = index;        
          return NSDragOperationMove;
        }
        
      } else if ([[pb types] containsObject: NSFilenamesPboardType]) {
        NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
        NSString *path = [sourcePaths objectAtIndex: 0];
        FSNode *node = [FSNode nodeWithPath: path];
      
        if ([node isApplication] && ([icon isSpecialIcon] == NO)) {
          int i;
          
          for (i = 0; i < [icons count]; i++) {
            if ([[[icons objectAtIndex: i] node] isEqualToNode: node]) {
              isDragTarget = NO;
              return NSDragOperationNone;
            }
          }
          
          targetIndex = index;
          return NSDragOperationMove;
          
        } else {
          if ([icon acceptsDraggedPaths: sourcePaths]) {
            return NSDragOperationMove;
          } else {
            [icon unselect];
          }
        }
      }
    }
  }

  isDragTarget = NO;    
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSPoint location;
  DockIcon *icon;
 
  if (dragdelay < 2) {
    dragdelay++;
    return NSDragOperationNone;
  }
  
  isDragTarget = YES;  
  location = [sender draggingLocation];  
  icon = [self iconContainingPoint: location];
 
  if (targetIndex != -1) {
    if (NSEqualRects(targetRect, NSZeroRect)) {
      [self tile];
      return NSDragOperationMove;
    }
  }

  if (targetIndex != -1) {
    if (NSPointInRect(location, NSInsetRect(targetRect, 0.0, 2.0))) {
      return NSDragOperationMove;
    }
  }
  
  location = [self convertPoint: location fromView: nil];
  
  if (NSPointInRect(location, NSInsetRect(targetRect, 0.0, 2.0))) {
    return NSDragOperationMove;
  }
  
  if (icon == nil) {
    icon = [self iconContainingPoint: location];
  }
    
  if (icon) {
    int index = [icons indexOfObjectIdenticalTo: icon];

    if (dndSourceIcon && ([sender draggingSource] == dndSourceIcon)) {
      if ((icon != dndSourceIcon) && ([icon isSpecialIcon] == NO)) {
        RETAIN (dndSourceIcon);
        [icons removeObject: dndSourceIcon];
        [icons insertObject: dndSourceIcon atIndex: index];
        RELEASE (dndSourceIcon);
        [self tile];
      } 
      
      return NSDragOperationMove;
    
    } else {
      NSPasteboard *pb = [sender draggingPasteboard];

      if (pb && [[pb types] containsObject: @"DockIconPboardType"]) {
        if ((targetIndex != index) && ([icon isTrashIcon] == NO)) {
          targetIndex = index;
          [self tile]; 
          return NSDragOperationMove;
        }

      } else if (pb && [[pb types] containsObject: NSFilenamesPboardType]) {
        NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
        NSString *path = [sourcePaths objectAtIndex: 0];
        FSNode *node = [FSNode nodeWithPath: path];

        if (([node isApplication] == NO) 
                          || ([node isApplication] && [icon isTrashIcon])) {
          if ([icon acceptsDraggedPaths: sourcePaths]) {
            return NSDragOperationMove;
          } else {
            [icon unselect];
          }
         
        } else if ((targetIndex != index) && ([icon isTrashIcon] == NO)) { 
          targetIndex = index;
          [self tile]; 
          return NSDragOperationMove;
        } 
      }
    }   
  }

	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  isDragTarget = NO;  
  dragdelay = 0;
  
  [self unselectOtherReps: nil];
      
  if (dndSourceIcon && [dndSourceIcon superview]) {
    [self removeIcon: dndSourceIcon];
    [self setDndSourceIcon: nil];
  }
  if (targetIndex != -1) {
    targetIndex = -1;
    targetRect = NSZeroRect;
    [self tile];
  }
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
  [self unselectOtherReps: nil];

  if (dndSourceIcon && ([sender draggingSource] == dndSourceIcon)) {
    [dndSourceIcon setIsDndSourceIcon: NO];
    [self setDndSourceIcon: nil];

  } else {
    NSPasteboard *pb = [sender draggingPasteboard];

    if ([[pb types] containsObject: @"DockIconPboardType"]) { 
      [self addDraggedIcon: [pb dataForType: @"DockIconPboardType"] 
                   atIndex: targetIndex];

    } else if ([[pb types] containsObject: NSFilenamesPboardType]) {
      NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
      NSPoint location = [sender draggingLocation];
      DockIcon *icon;
      BOOL concluded = NO;

      location = [self convertPoint: location fromView: nil];
      icon = [self iconContainingPoint: location];

      if ([sourcePaths count] == 1) {
        NSString *path = [sourcePaths objectAtIndex: 0];
        FSNode *node = [FSNode nodeWithPath: path];

        if ([node isApplication]) {
          if ((icon == nil) || (icon && ([icon isTrashIcon] == NO))) {
            BOOL duplicate = NO;
            int i;

            for (i = 0; i < [icons count]; i++) {
              DockIcon *icon = [icons objectAtIndex: i];

              if ([[icon node] isEqualToNode: node]) {
                RETAIN (icon);
                [icons removeObject: icon];
                [icons insertObject: icon atIndex: targetIndex];
                RELEASE (icon);
                duplicate = YES;      
                break;
              }
            }

            if (duplicate == NO) {
              DockIcon *icon = [self addIconForApplicationWithName: [node name] 
                                                           atIndex: targetIndex];
              [icon setIsDocked: YES];
            }

            concluded = YES;
          }
        }
      } 
      
      if (concluded == NO) {
        if (icon) {
          [icon setDraggedPaths: sourcePaths];
        }
      }    
    }
  }

  isDragTarget = NO;
  targetIndex = -1;
  targetRect = NSZeroRect;
  
  [self tile];
}

- (BOOL)isDragTarget
{
  return isDragTarget;
}

@end







