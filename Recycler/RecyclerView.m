/* RecyclerView.m
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
 *
 * This file is part of the GNUstep Recycler application
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

#import "RecyclerView.h"
#import "RecyclerIcon.h"
#import "FSNFunctions.h"

#define WIN_SIZE 64
#define ICN_SIZE 48

@implementation RecyclerWindow

- (void)setRecyclerIcon:(id)icn
{
  icon = icn;
  [[self contentView] addSubview: [icon superview]];		
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [icon draggingEntered: sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	return [icon draggingUpdated: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[icon draggingExited: sender];  
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [icon prepareForDragOperation: sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return [icon performDragOperation: sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [icon concludeDragOperation: sender];
}

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

- (BOOL)canBecomeMainWindow
{
	return YES;
}

@end


@implementation RecyclerView

- (void)dealloc
{
  RELEASE (tile);
  RELEASE (win);
  [super dealloc];
}

- (id)init
{
	self = [super initWithFrame: NSMakeRect(0, 0, 64, 64)];
  
  if (self) {
    NSString *path;
    FSNode *node;    

    recycler = [Recycler recycler];
    path = [recycler trashPath];
    node = [FSNode nodeWithPath: path];
    
    icon = [[RecyclerIcon alloc] initWithRecyclerNode: node];
    [icon setFrame: [self bounds]];
    [self addSubview: icon];
    RELEASE (icon);

    ASSIGN (tile, [NSImage imageNamed: @"common_Tile.tiff"]);
  }
  
  return self;  
}

- (id)initWithWindow
{
  self = [self init];

  if (self) {
	  win = [[RecyclerWindow alloc] initWithContentRect: NSMakeRect(0, 0, WIN_SIZE, WIN_SIZE)
					                      styleMask: NSBorderlessWindowMask  
                                  backing: NSBackingStoreBuffered 
                                    defer: NO];

    if ([win setFrameUsingName: @"recycler_win"] == NO) {
			NSRect r = [[NSScreen mainScreen] frame];
      [win setFrame: NSMakeRect(r.size.width - WIN_SIZE, 0, WIN_SIZE, WIN_SIZE) 
            display: NO];
    }      

    [win setReleasedWhenClosed: NO]; 
    [win setRecyclerIcon: icon];
    [win registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];    
  }
  
  return self;  
}

- (void)activate
{
	[win setLevel: NSDockWindowLevel];
  [win makeKeyAndOrderFront: nil];
  [win makeMainWindow];
}

- (RecyclerIcon *)trashIcon
{
  return icon;
}

- (void)updateDefaults
{
	if (win && [win isVisible]) {
  	[win saveFrameUsingName: @"recycler_win"];
	}
}

- (void)drawRect:(NSRect)rect
{
	[tile compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver]; 
}

@end


@implementation RecyclerView (NodeRepContainer)

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
	NSString *source = [info objectForKey: @"source"];	  
	NSString *destination = [info objectForKey: @"destination"];	 
  int i;
    
  if ([operation isEqual: NSWorkspaceMoveOperation]
      || [operation isEqual: NSWorkspaceCopyOperation]
			|| [operation isEqual: NSWorkspaceRecycleOperation]) { 
    FSNode *node = [icon node];
    NSString *trashPath = [node path];
    
    if ([destination isEqual: trashPath]) {
      NSArray *subNodes = [node subNodes];
      int count = [subNodes count];
    
      for (i = 0; i < [subNodes count]; i++) {
        if ([[subNodes objectAtIndex: i] isReserved]) {
          count --;
        }
      }      
      
      [icon setTrashFull: (count > 0)];    
    }
  }

  if ([operation isEqual: @"GWorkspaceRecycleOutOperation"]
			    || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]
          || [operation isEqual: NSWorkspaceMoveOperation]
          || [operation isEqual: NSWorkspaceDestroyOperation]) { 
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
    
  if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    if ([path isEqual: [recycler trashPath]]) {
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
    if ([path isEqual: [recycler trashPath]]) {
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

- (FSNSelectionMask)selectionMask
{
  return NSSingleSelectionMask;
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCut:(BOOL)cut
{
  NSMutableArray *sourcePaths = [names mutableCopy];
  NSString *basePath;
  NSString *nodePath = [[icon node] path];
  NSString *prePath = [NSString stringWithString: nodePath];
  NSUInteger count = [names count];
  int i;
  
  AUTORELEASE (sourcePaths);

  if (count == 0) {
		return NO;
  } 

  if ([[icon node] isWritable] == NO) {
    return NO;
  }

  basePath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  if ([basePath isEqual: nodePath]) {
    return NO;
  }  

  if ([sourcePaths containsObject: nodePath]) {
    return NO;
  }

  while (1) {
    if ([sourcePaths containsObject: prePath]) {
      return NO;
    }
    if ([prePath isEqual: path_separator()]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  for (i = 0; i < count; i++) {
    NSString *srcpath = [sourcePaths objectAtIndex: i];
    FSNode *nd = [FSNode nodeWithPath: srcpath];
       
    if ([nd isMountPoint]) {
      [sourcePaths removeObject: srcpath];
      count--;
      i--;
    }
  }    
  
  if ([sourcePaths count] == 0) {
    return NO;
  }

  return cut;
}

- (NSColor *)backgroundColor
{
  return [NSColor windowBackgroundColor];
}

- (NSColor *)textColor
{
  return [NSColor controlTextColor];
}

- (NSColor *)disabledTextColor
{
  return [NSColor disabledControlTextColor];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return NSDragOperationNone;
}

@end

