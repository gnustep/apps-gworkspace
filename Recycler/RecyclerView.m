/* RecyclerView.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "RecyclerView.h"
#include "RecyclerIcon.h"
#include "FSNFunctions.h"
#include "GNUstep.h"

#define WIN_SIZE 64
#define ICN_SIZE 48

@implementation RecyclerWindow

- (void)setRecyclerIcon:(id)icn
{
  icon = icn;
  [[self contentView] addSubview: [icon superview]];		
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [icon draggingEntered: sender];
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
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
    node = [FSNode nodeWithRelativePath: path parent: nil];
    
    icon = [[RecyclerIcon alloc] initWithRecyclerNode: node];
    [icon setFrame: [self frame]];
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
	  win = [[RecyclerWindow alloc] initWithContentRect: NSZeroRect
					                      styleMask: NSBorderlessWindowMask  
                                  backing: NSBackingStoreBuffered 
                                    defer: NO];

    if ([win setFrameUsingName: @"recycler"] == NO) {
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
  	[win saveFrameUsingName: @"recycler"];
	}
}

- (void)drawRect:(NSRect)rect
{
	[tile compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver]; 
}


//
// FSNodeRepContainer protocol
//
- (void)showContentsOfNode:(FSNode *)anode
{
}

- (FSNode *)shownNode
{
  return nil;
}

- (void)nodeContentsWillChange:(NSDictionary *)info
{
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
	NSString *source = [info objectForKey: @"source"];	  
	NSString *destination = [info objectForKey: @"destination"];	 
  int i;
    
  if ([operation isEqual: NSWorkspaceMoveOperation]
      || [operation isEqual: NSWorkspaceCopyOperation]
			|| [operation isEqual: NSWorkspaceRecycleOperation]) { 
    NSString *trashPath = [[icon node] path];
    
    if ([destination isEqual: trashPath]) {
      [icon setTrashFull: YES];
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
        FSNode *subNode = [subNodes objectAtIndex: i];
        
        if ([[subNode name] hasPrefix: @"."]) {
          count --;
        }
      }
      
      if (count == 0) {
        [icon setTrashFull: NO];
      }
    }
  }
}

- (void)watchedPathDidChange:(NSDictionary *)info
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
        FSNode *subNode = [subNodes objectAtIndex: i];
        
        if ([[subNode name] hasPrefix: @"."]) {
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
        FSNode *subNode = [subNodes objectAtIndex: i];
        
        if ([[subNode name] hasPrefix: @"."] == NO) {
          [icon setTrashFull: YES];
          break;
        }
      }
    }
  }
}

- (void)setShowType:(FSNInfoType)type
{
}

- (void)setExtendedShowType:(NSString *)type
{
}

- (FSNInfoType)showType
{
  return FSNInfoNameType;
}

- (void)setIconSize:(int)size
{
}

- (int)iconSize
{
  return ICN_SIZE;
}

- (void)setLabelTextSize:(int)size
{
}

- (int)labelTextSize
{
  return 12;
}

- (void)setIconPosition:(int)pos
{
}

- (int)iconPosition
{
  return NSImageOnly;
}

- (void)updateIcons
{
}

- (id)repOfSubnode:(FSNode *)anode
{
  return nil;
}

- (id)repOfSubnodePath:(NSString *)apath
{
  return nil;
}

- (id)addRepForSubnode:(FSNode *)anode
{
  return nil;
}

- (id)addRepForSubnodePath:(NSString *)apath
{
  FSNode *subnode = [FSNode nodeWithRelativePath: apath parent: nil];
  return [self addRepForSubnode: subnode];
}

- (void)removeRepOfSubnode:(FSNode *)anode
{
}

- (void)removeRepOfSubnodePath:(NSString *)apath
{
}

- (void)removeRep:(id)arep
{
}

- (void)unselectOtherReps:(id)arep
{
}

- (void)selectReps:(NSArray *)reps
{
}

- (void)selectRepsOfSubnodes:(NSArray *)nodes
{
}

- (void)selectRepsOfPaths:(NSArray *)paths
{
}

- (void)selectAll
{
}

- (NSArray *)selectedReps
{
  return [NSArray array];
}

- (NSArray *)selectedNodes
{
  return [NSArray array];
}

- (NSArray *)selectedPaths
{
  return [NSArray array];
}

- (void)selectionDidChange
{
}

- (void)checkLockedReps
{
}

- (void)setSelectionMask:(FSNSelectionMask)mask
{
}

- (FSNSelectionMask)selectionMask
{
  return NSSingleSelectionMask;
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
}

- (void)restoreLastSelection
{
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted
{
  NSMutableArray *sourcePaths = [names mutableCopy];
  NSString *basePath;
  NSString *nodePath = [[icon node] path];
  NSString *prePath = [NSString stringWithString: nodePath];
	int count = [names count];
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
    FSNode *nd = [FSNode nodeWithRelativePath: srcpath parent: nil];
       
    if ([nd isMountPoint]) {
      [sourcePaths removeObject: srcpath];
      count--;
      i--;
    }
  }    
  
  if ([sourcePaths count] == 0) {
    return NO;
  }

  return cutted;
}

- (void)setBackgroundColor:(NSColor *)acolor
{
}

- (NSColor *)backgroundColor
{
  return [NSColor windowBackgroundColor];
}

- (void)setTextColor:(NSColor *)acolor
{
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

