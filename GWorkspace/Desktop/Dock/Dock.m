/* Dock.m
 *  
 * Copyright (C) 2005-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Dock.h"
#import "DockIcon.h"
#import "GWDesktopView.h"
#import "GWorkspace.h"

#define MAX_ICN_SIZE 48
#define MIN_ICN_SIZE 16
#define ICN_INCR 4

/* small category to access NSNUmericSearch through a selector */

@interface NSString (NumericSort)
- (NSComparisonResult)numericCompare:(NSString *)s;
@end

@implementation NSString (NumericSort)
- (NSComparisonResult)numericCompare:(NSString *)s
{
  return [self compare:s options:NSNumericSearch];
}
@end

@implementation Dock

- (void)dealloc
{
  RELEASE (icons);
  RELEASE (backColor);
  
  [super dealloc];
}

- (id)initForManager:(id)mngr
{
  self = [super initWithFrame: NSMakeRect(0, 0, 64, 64)];
  
  if (self)
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
      NSDictionary *appsdict;
      NSArray *pbTypes;
      int i;
      id defEntry;

      manager = mngr;
      position = [manager dockPosition];

      defEntry = [defaults objectForKey: @"dockstyle"];
      style = DockStyleClassic;
      if ([defEntry intValue] == DockStyleModern)
	style = DockStyleModern;

      singleClickLaunch = [defaults boolForKey: @"singleclicklaunch"];
 
      gw = [GWorkspace gworkspace];
      fm = [NSFileManager defaultManager];
      ws = [NSWorkspace sharedWorkspace];

      icons = [NSMutableArray new];
      iconSize = MAX_ICN_SIZE;
                                
      dndSourceIcon = nil;
      isDragTarget = NO;
      dragdelay = 0;
      targetIndex = -1;
      targetRect = NSZeroRect;
    
      pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType,
			 @"DockIconPboardType",
			 nil];
      [self registerForDraggedTypes: pbTypes];

      if (style == DockStyleModern)
	[self setBackColor: [[NSColor grayColor] colorWithAlphaComponent: 0.33]];
      else
	[self setBackColor: [NSColor grayColor]];
      
      [self createWorkspaceIcon];

      appsdict = [defaults objectForKey: @"applications"];
      
      if (appsdict)
	{
	  NSArray *indexes = [appsdict allKeys];
    
	  indexes = [indexes sortedArrayUsingSelector: @selector(numericCompare:)];
    
	  for (i = 0; i < [indexes count]; i++)
	    {
	      NSNumber *index = [indexes objectAtIndex: i];
	      NSString *name = [[appsdict objectForKey: index] stringByDeletingPathExtension];
	      NSString *path = [ws fullPathForApplication: name];
        
	      if (path)
		{
		  DockIcon *icon = [self addIconForApplicationAtPath: path
							    withName: name
							     atIndex: [index intValue]];
		  [icon setDocked: YES];
		}
	    }
	}

      [self createTrashIcon];
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
    wsname = [gw gworkspaceProcessName];
  }

  path = [ws fullPathForApplication: wsname];
  node = [FSNode nodeWithPath: path];
  
  icon = [[DockIcon alloc] initForNode: node 
                               appName: wsname
                              iconSize: iconSize];
  [icon setHighlightColor: backColor];
  [icon setWsIcon: YES];   
  [icon setDocked: YES];   
  [icons insertObject: icon atIndex: 0];
  [self addSubview: icon];
  RELEASE (icon);
}

- (void)createTrashIcon
{
  NSString *path = [manager trashPath];
  FSNode *node = [FSNode nodeWithPath: path];
  DockIcon *icon = [[DockIcon alloc] initForNode: node 
                                         appName: nil
                                        iconSize: iconSize];

  [icon setHighlightColor: backColor];
  [icon setTrashIcon: YES];  
  [icon setDocked: YES];                         
  [icons insertObject: icon atIndex: [icons count]];
  [self addSubview: icon];
  RELEASE (icon);
  
  [manager addWatcherForPath: path];
}

- (DockIcon *)addIconForApplicationAtPath:(NSString *)path
                                 withName:(NSString *)name
                                  atIndex:(int)index
{
  if ([fm fileExistsAtPath: path]) {
    FSNode *node = [FSNode nodeWithPath: path];
    
    if ([node isApplication]) {
      int icnindex;
      DockIcon *icon = [[DockIcon alloc] initForNode: node 
                                             appName: name
                                            iconSize: iconSize];

      if (index == -1) {
        icnindex = ([icons count]) ? ([icons count] - 1) : 0;
      } else {
        icnindex = (index < [icons count]) ? (index + 1) : [icons count];
      }

      [icon setHighlightColor: backColor];
      [icons insertObject: icon atIndex: icnindex];
      [icon setSingleClickLaunch: singleClickLaunch];
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
  NSString *name = [dict objectForKey: @"name"];
  NSString *path = [dict objectForKey: @"path"];
  DockIcon *icon = [self addIconForApplicationAtPath: path 
                                            withName: name 
                                             atIndex: index];

  [icon setDocked: [[dict objectForKey: @"docked"] boolValue]];
  [icon setLaunched: [[dict objectForKey: @"launched"] boolValue]];
  [icon setHidden: [[dict objectForKey: @"hidden"] boolValue]];
}

- (void)removeIcon:(DockIcon *)icon
{
  [manager removeWatcherForPath: [[icon node] path]];
  
  if ([icon superview]) {
    [icon removeFromSuperview];
  }
  if ([icon isLaunched]) {
    [icon setLaunched: NO];
  }
  [icons removeObject: icon];
  [self tile];
}

- (DockIcon *)iconForApplicationName:(NSString *)name
{
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];
    
    if ([[icon appName] isEqual: name]) {
      return icon;
    }
  }
  
  return nil;
}

- (DockIcon *)workspaceAppIcon
{
  NSUInteger i;
  
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
  NSUInteger i;
  
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
  NSUInteger i;
  
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

- (void)appWillLaunch:(NSString *)appPath
              appName:(NSString *)appName
{
  if ([appName isEqual: [gw gworkspaceProcessName]] == NO) {
    DockIcon *icon = [self iconForApplicationName: appName];
  
    if (icon == nil) {
      icon = [self addIconForApplicationAtPath: appPath
                                      withName: appName
                                       atIndex: -1];
    } 
  
    [self tile];
    [icon animateLaunch];
  }
}

- (void)appDidLaunch:(NSString *)appPath
             appName:(NSString *)appName
{
  if ([appName isEqual: [gw gworkspaceProcessName]] == NO) {
    DockIcon *icon = [self iconForApplicationName: appName];

    if (icon == nil) {
      icon = [self addIconForApplicationAtPath: appPath
                                      withName: appName
                                       atIndex: -1];
      [self tile];
    } 
  
    [icon setLaunched: YES];
  }
}

- (void)appTerminated:(NSString *)appName
{
  if ([appName isEqual: [gw gworkspaceProcessName]] == NO) {
    DockIcon *icon = [self iconForApplicationName: appName];

    if (icon) {
      if (([icon isDocked] == NO) && ([icon isSpecialIcon] == NO)) {
        [self removeIcon: icon];
      } else {
        [icon setAppHidden: NO];
        [icon setLaunched: NO];
      }
    }
  }
}

- (void)appDidHide:(NSString *)appName
{
  if ([appName isEqual: [gw gworkspaceProcessName]] == NO) {
    DockIcon *icon = [self iconForApplicationName: appName];

    if (icon) {
      [icon setAppHidden: YES];
    }
  }
}

- (void)appDidUnhide:(NSString *)appName
{
  if ([appName isEqual: [gw gworkspaceProcessName]] == NO) {
    DockIcon *icon = [self iconForApplicationName: appName];

    if (icon) {
      [icon setAppHidden: NO];
    }
  }
}

- (void)iconMenuAction:(id)sender
{
  NSString *title = [(NSMenuItem *)sender title];
  
  if ([title isEqual: NSLocalizedString(@"Show In File Viewer", @"")]) {
    NSString *path = [(NSMenuItem *)sender representedObject];
    NSString *basePath = [path stringByDeletingLastPathComponent];
  
    [gw selectFile: path inFileViewerRootedAtPath: basePath];
  
  } else {
    GWLaunchedApp *app = (GWLaunchedApp *)[(NSMenuItem *)sender representedObject];
  
    if ([app isRunning] == NO) {
      /* terminated while the icon menu is open */
      return;
    }
  
    if ([title isEqual: NSLocalizedString(@"Hide", @"")]) {
      [app hideApplication];
    } else if ([title isEqual: NSLocalizedString(@"Unhide", @"")]) {
      [app unhideApplication];
    } else if ([title isEqual: NSLocalizedString(@"Quit", @"")]) {
      [app terminateApplication];
    }  
  }
}

- (void)setSingleClickLaunch:(BOOL)value
{
  NSUInteger i;

  singleClickLaunch = value;
  for (i = 0; i < [icons count]; i++)
    {
      DockIcon *icon = [icons objectAtIndex: i];

      [icon setSingleClickLaunch: singleClickLaunch];
    }
}

- (void)setPosition:(DockPosition)pos
{
  position = pos;
  [self tile];
}

- (void)setStyle:(DockStyle)s
{
  if(style != s)
    {
      if (s == DockStyleClassic)
	{
	  [self setBackColor: [NSColor grayColor]];
	}
      else if (s == DockStyleModern)
	{
	  [self setBackColor: [[NSColor grayColor] colorWithAlphaComponent: 0.33]];
	}
    }
  style = s;
}

- (DockStyle)style
{
  return style;
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

- (void)tile
{
  NSView *view = [self superview];
  NSRect scrrect = [[NSScreen mainScreen] frame];
  int oldIcnSize = iconSize;
  CGFloat maxheight = scrrect.size.height;
  NSRect icnrect = NSZeroRect;  
  NSRect rect = NSZeroRect;
  NSUInteger i;

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
  rect.origin.y = ceil((scrrect.size.height - rect.size.height) / 2);
  
  if (view) {
    [view setNeedsDisplayInRect: [self frame]];
  }
  [self setFrame: rect];
  
  icnrect.origin.y = rect.size.height;
  
  for (i = 0; i < [icons count]; i++) {
    DockIcon *icon = [icons objectAtIndex: i];
  
    if (oldIcnSize != iconSize) {
      [icon setIconSize: iconSize];
    }
    
    icnrect.origin.y -= icnrect.size.height;
    [icon setFrame: icnrect];
    
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
  NSUInteger i;  

  [defaults setObject: [NSNumber numberWithInt: style]
               forKey: @"dockstyle"];
  [defaults setBool: singleClickLaunch forKey: @"singleclicklaunch"];

  for (i = 0; i < [icons count]; i++)
    {
      DockIcon *icon = [icons objectAtIndex: i];    

      if (([icon isSpecialIcon] == NO) && [icon isDocked])
	{
	  [dict setObject: [icon appName] forKey: [[NSNumber numberWithInt: i] stringValue]];
	  [manager removeWatcherForPath: [[icon node] path]];
	}

      [icon setSingleClickLaunch: singleClickLaunch];
    }

  [defaults setObject: dict forKey: @"applications"];
  
  [manager removeWatcherForPath: [manager trashPath]];
}

- (void)checkRemovedApp:(id)sender
{
  DockIcon *icon = (DockIcon *)[sender userInfo];
  
  if ([[icon node] isValid] == NO) {
    [self removeIcon: icon];
  }
}

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];
  
  [backColor set];
  NSRectFill(rect);
}

@end


@implementation Dock (NodeRepContainer)

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
	NSString *source = [info objectForKey: @"source"];	  
	NSString *destination = [info objectForKey: @"destination"];	 
	NSArray *files = [info objectForKey: @"files"];	 
  NSUInteger i, count;
  
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
      NSUInteger count = [subNodes count];
    
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
  CREATE_AUTORELEASE_POOL(arp);
  NSString *event = [info objectForKey: @"event"];
  NSString *path = [info objectForKey: @"path"];
    
  if ([event isEqual: @"GWWatchedPathDeleted"])
    {
      NSUInteger i;

      for (i = 0; i < [icons count]; i++) {
	DockIcon *icon = [icons objectAtIndex: i];
      
	if ([icon isSpecialIcon] == NO) {
	  FSNode *node = [icon node];
        
	  if ([path isEqual: [node path]]) {
	    [NSTimer scheduledTimerWithTimeInterval: 1.0
					     target: self
					   selector: @selector(checkRemovedApp:)
					   userInfo: icon
					    repeats: NO];
	  }
	}
      }
    
    }
  else if ([event isEqual: @"GWFileDeletedInWatchedDirectory"])
    {
      NSArray *files = [info objectForKey: @"files"];
      NSUInteger i;
    
      for (i = 0; i < [files count]; i++)
	{
	  NSString *fname = [files objectAtIndex: i];
	  NSString *fullpath = [path stringByAppendingPathComponent: fname];
	  int j;
      
	  for (j = 0; j < [icons count]; j++)
	    {
	      DockIcon *icon = [icons objectAtIndex:j];

	      if ([icon isSpecialIcon] == NO) {
		FSNode *node = [icon node];

		if ([fullpath isEqual: [node path]])
		  {
		    [NSTimer scheduledTimerWithTimeInterval: 1.0
						     target: self
						   selector: @selector(checkRemovedApp:)
						   userInfo: icon
						    repeats: NO];
		  }
	      }
	    }
	}
    
      if ([path isEqual: [manager trashPath]])
	{
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
    
    }
  else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"])
    {
      if ([path isEqual: [manager trashPath]])
	{
	  DockIcon *icon = [self trashIcon];
	  FSNode *node = [icon node];
	  NSArray *subNodes = [node subNodes];
	  NSUInteger i;

	  for (i = 0; i < [subNodes count]; i++)
	    {
	      if ([[subNodes objectAtIndex: i] isReserved] == NO)
		{
		  [icon setTrashFull: YES];
		  break;
		}
	    }
	}
    }
  
  RELEASE (arp);
}

- (void)unselectOtherReps:(id)arep
{
  NSUInteger i;
  
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
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++)
    [[icons objectAtIndex: i] setHighlightColor: hlgtcolor];
  
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

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
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
    NSUInteger index = [icons indexOfObjectIdenticalTo: icon];
        
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
          NSUInteger i;
          
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

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
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
    NSUInteger index = [icons indexOfObjectIdenticalTo: icon];

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
        NSString *appName = [[node name] stringByDeletingPathExtension];
        
        if ([node isApplication]) {
          if ((icon == nil) || (icon && ([icon isTrashIcon] == NO))) {
            BOOL duplicate = NO;
            NSUInteger i;

            for (i = 0; i < [icons count]; i++) {
              DockIcon *icon = [icons objectAtIndex: i];

              if ([[icon node] isEqual: node] 
                          && [[icon appName] isEqual: appName]) {
                RETAIN (icon);
                [icons removeObject: icon];
                [icons insertObject: icon atIndex: targetIndex];
                RELEASE (icon);
                duplicate = YES;      
                break;
              }
            }

            if (duplicate == NO) {
              DockIcon *icon = [self addIconForApplicationAtPath: path
                                                        withName: appName 
                                                         atIndex: targetIndex];
              [icon setDocked: YES];
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







