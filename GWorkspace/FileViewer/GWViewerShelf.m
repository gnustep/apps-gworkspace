/* GWViewerShelf.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2004
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

#include <AppKit/AppKit.h>
#include <math.h>
#include "GWViewerShelf.h"
#include "GWViewer.h"
#include "GWorkspace.h"
#include "FSNBrowser.h"
#include "FSNIconsView.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

#define DEF_GRID_WIDTH 90
#define Y_MARGIN (4)


@implementation GWViewerShelf

- (void)dealloc
{
	[self unsetWatchers];
  RELEASE (watchedPaths);
  RELEASE (icons);
  TEST_RELEASE (extInfoType);
	if (grid != NULL) {
		NSZoneFree (NSDefaultMallocZone(), grid);
	}
  TEST_RELEASE (dragIcon);
  RELEASE (backColor);
  RELEASE (textColor);
  RELEASE (disabledTextColor);

  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          forViewer:(id)vwr
{
  self = [super initWithFrame: frameRect]; 
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    id defentry;
    
    fsnodeRep = [FSNodeRep sharedInstance];
    
    defentry = [defaults dictionaryForKey: @"backcolor"];
    if (defentry) {
      float red = [[(NSDictionary *)defentry objectForKey: @"red"] floatValue];
      float green = [[(NSDictionary *)defentry objectForKey: @"green"] floatValue];
      float blue = [[(NSDictionary *)defentry objectForKey: @"blue"] floatValue];
      float alpha = [[(NSDictionary *)defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (backColor, [[NSColor windowBackgroundColor] colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    }

    defentry = [defaults dictionaryForKey: @"textcolor"];
    if (defentry) {
      float red = [[(NSDictionary *)defentry objectForKey: @"red"] floatValue];
      float green = [[(NSDictionary *)defentry objectForKey: @"green"] floatValue];
      float blue = [[(NSDictionary *)defentry objectForKey: @"blue"] floatValue];
      float alpha = [[(NSDictionary *)defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (textColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (textColor, [[NSColor controlTextColor] colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    }

    ASSIGN (disabledTextColor, [textColor highlightWithLevel: NSDarkGray]);
  
    iconSize = DEF_ICN_SIZE;

    defentry = [defaults objectForKey: @"labeltxtsize"];
    labelTextSize = defentry ? [defentry intValue] : DEF_TEXT_SIZE;
    ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);
    
    iconPosition = DEF_ICN_POS;
        
    defentry = [defaults objectForKey: @"fsn_info_type"];
    infoType = defentry ? [defentry intValue] : FSNInfoNameType;
    extInfoType = nil;
    
    if (infoType == FSNInfoExtendedType) {
      defentry = [defaults objectForKey: @"extended_info_type"];

      if (defentry) {
        NSArray *availableTypes = [fsnodeRep availableExtendedInfoNames];
      
        if ([availableTypes containsObject: defentry]) {
          ASSIGN (extInfoType, defentry);
        }
      }
      
      if (extInfoType == nil) {
        infoType = FSNInfoNameType;
      }
    }

    defentry = [defaults objectForKey: @"shelfcellswidth"];
    gridSize.width = defentry ? [defentry intValue] : DEF_GRID_WIDTH; 
     
		icons = [NSMutableArray new];
  
    viewer = vwr;
    gworkspace = [GWorkspace gworkspace];

    dragIcon = nil;

    [self calculateGridSize];    
    [self makeIconsGrid];
    
  	[self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];

		watchedPaths = [NSMutableArray new];
  }
  
  return self;
}

- (void)setContents:(NSArray *)iconsInfo
{
  FSNode *baseNode = [viewer baseNode];
  int i;

  for (i = 0; i < [iconsInfo count]; i++) { 
		NSDictionary *info = [iconsInfo objectAtIndex: i];
    NSArray *paths = [info objectForKey: @"paths"];
		int index = [[info objectForKey: @"index"] intValue];
    NSMutableArray *icnnodes = [NSMutableArray array];
    int j;
    
    for (j = 0; j < [paths count]; j++) {
      FSNode *node = [FSNode nodeWithPath: [paths objectAtIndex: j]];
    
      if ([node isValid] && [baseNode isParentOfNode: node]) {
        [icnnodes addObject: node]; 
      } 
    }

    if ([icnnodes count] && (index != -1)) {
      if ([icnnodes count] == 1) {
        [self addIconForNode: [icnnodes objectAtIndex: 0] atIndex: index];
      } else {
        [self addIconForSelection: icnnodes atIndex: index];
      }
    }
  }
  
  [self tile];
}

- (NSArray *)contentsInfo
{
  NSMutableArray *iconsInfo = [NSMutableArray array]; 
  int i;

  for (i = 0; i < [icons count]; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if ([icon isShowingSelection]) {
      NSArray *selection = [icon selection];
      NSMutableArray *paths = [NSMutableArray array];
      int j;
      
      for (j = 0; j < [selection count]; j++) {
        [paths addObject: [[selection objectAtIndex: j] path]];
      }
    
      [dict setObject: paths forKey: @"paths"];
    
    } else {
      [dict setObject: [NSArray arrayWithObject: [[icon node] path]] 
               forKey: @"paths"];
    }
  
    [dict setObject: [NSNumber numberWithInt: [icon gridIndex]] 
             forKey: @"index"];
  
    [iconsInfo addObject: dict];
  }

  return iconsInfo;
}

- (id)addIconForNode:(FSNode *)node
             atIndex:(int)index
{
  FSNIcon *icon = [[FSNIcon alloc] initForNode: node
                                  nodeInfoType: infoType
                                  extendedType: extInfoType
                                      iconSize: iconSize
                                  iconPosition: iconPosition
                                     labelFont: labelFont
                                     textColor: textColor
                                     gridIndex: index
                                     dndSource: YES
                                     acceptDnd: YES
                                     slideBack: NO];
  [icons addObject: icon];
  [self addSubview: icon];
  RELEASE (icon);

  {
  	NSString *watched = [node parentPath];	

	  if ([watchedPaths containsObject: watched] == NO) {
		  [watchedPaths addObject: watched];
		  [self setWatcherForPath: watched];
	  }
  }
  
  return icon;
}

- (id)addIconForSelection:(NSArray *)selection
                  atIndex:(int)index
{
  FSNIcon *icon = [self addIconForNode: [selection objectAtIndex: 0] 
                               atIndex: index];
  [icon showSelection: selection];
  return icon;
}

- (id)iconForNode:(FSNode *)node
{
	int i;
	
	for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    
		if ([[icon node] isEqual: node] && ([icon selection] == nil)) {
			return icon;
		}
  }
  
	return nil;
}

- (id)iconForPath:(NSString *)path
{
	int i;
	
	for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    
		if ([[[icon node] path] isEqual: path] && ([icon selection] == nil)) {
			return icon;
		}
  }
  
	return nil;
}

- (id)iconForNodesSelection:(NSArray *)selection
{
	int i;
	
	for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSArray *selnodes = [icon selection];
    
    if (selnodes && [selnodes isEqual: selection]) {
      return icon;
    }
  }
  
	return nil;
}

- (id)iconForPathsSelection:(NSArray *)selection
{
	int i;
	
	for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSArray *selnodes = [icon selection];
    
    if (selnodes) {
      NSMutableArray *selpaths = [NSMutableArray array];
      int j;
      
      for (j = 0; j < [selnodes count]; j++) {
        [selpaths addObject: [[selnodes objectAtIndex: j] path]];
      }
      
      if ([selpaths isEqual: selection]) {
        return icon;
      }
    }
  }
  
	return nil;
}

- (void)calculateGridSize
{
  NSSize highlightSize = NSZeroSize;
  NSSize labelSize = NSZeroSize;
  
  highlightSize.width = ceil(iconSize / 3 * 4);
  highlightSize.height = ceil(highlightSize.width * [fsnodeRep highlightHeightFactor]);
  if ((highlightSize.height - iconSize) < 4) {
    highlightSize.height = iconSize + 4;
  }

  labelSize.height = myrintf([fsnodeRep heighOfFont: labelFont]);
  labelSize.width = gridSize.width;
  gridSize.height = highlightSize.height + labelSize.height;
}

- (void)makeIconsGrid
{
  NSRect gridrect = [self frame];
  NSPoint gpnt;
  int i;

	if (grid != NULL) {
		NSZoneFree (NSDefaultMallocZone(), grid);
	}
  
  colcount = (int)(gridrect.size.width / gridSize.width);  
  rowcount = (int)(gridrect.size.height / gridSize.height);
	gridcount = colcount * rowcount;

	grid = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * gridcount);	

  gpnt.x = 0;
  gpnt.y = gridrect.size.height - gridSize.height - Y_MARGIN;

  for (i = 0; i < gridcount; i++) {
		if (i > 0) {
			gpnt.x += gridSize.width;      
    }

    if (gpnt.x >= (gridrect.size.width - gridSize.width)) {
      gpnt.x = 0;
      gpnt.y -= (gridSize.height + Y_MARGIN);
    }
    
    grid[i].origin = gpnt;
    grid[i].size = gridSize;
    grid[i] = NSIntegralRect(grid[i]);    
  }
}

- (int)firstFreeGridIndex
{
	int i;

	for (i = 0; i < gridcount; i++) {
    if ([self isFreeGridIndex: i]) {
      return i;
    }
	}
  
	return -1;
}

- (int)firstFreeGridIndexAfterIndex:(int)index
{
  int newind = index;

  while (1) {
    newind++;
    
    if (newind >= gridcount) {
      return [self firstFreeGridIndex];
    }
    
    if ([self isFreeGridIndex: newind]) {
      return newind;
    }
  } 
  
	return -1;
}

- (BOOL)isFreeGridIndex:(int)index
{
	int i;
	
  if ((index < 0) || (index >= gridcount)) {
    return NO;
  }
  
	for (i = 0; i < [icons count]; i++) {
		if ([[icons objectAtIndex: i] gridIndex] == index) {
			return NO;
		}
  }
  
	return YES;
}

- (id)iconWithGridIndex:(int)index
{
	int i;
	
	for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    
		if ([icon gridIndex] == index) {
			return icon;
		}
  }
  
	return nil;
}

- (int)indexOfGridRectContainingPoint:(NSPoint)p
{
	int i;

	for (i = 0; i < gridcount; i++) {  
    if (NSPointInRect(p, grid[i])) { 
      return i;
    }
  }
  
  return -1;
}

- (NSRect)iconBoundsInGridAtIndex:(int)index
{
  NSRect icnBounds = NSMakeRect(grid[index].origin.x, grid[index].origin.y, iconSize, iconSize);
  NSRect hlightRect = NSZeroRect;
  
  hlightRect.size.width = ceil(iconSize / 3 * 4);
  hlightRect.size.height = ceil(hlightRect.size.width * [fsnodeRep highlightHeightFactor]);
  hlightRect.origin.x = ceil((gridSize.width - hlightRect.size.width) / 2);   
  hlightRect.origin.y = floor([fsnodeRep heighOfFont: labelFont]);
  
  icnBounds.origin.x += hlightRect.origin.x + ((hlightRect.size.width - iconSize) / 2);
  icnBounds.origin.y += hlightRect.origin.y + ((hlightRect.size.height - iconSize) / 2);

  return icnBounds;
}

- (void)tile
{
  NSArray *subviews = [self subviews];
  int i;

  [self makeIconsGrid];
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    int index = [icon gridIndex];
    
    if (index < gridcount) {
      if ([subviews containsObject: icon] == NO) {
        [self addSubview: icon];
      }
      if (NSEqualRects(grid[index], [icon frame]) == NO) {
        [icon setFrame: grid[index]];
      }
    } else {
      [icon removeFromSuperview];
    }
  }
}

- (void)setWatcherForPath:(NSString *)path
{
	[gworkspace addWatcherForPath: path];
}

- (void)unsetWatcherForPath:(NSString *)path
{
	[gworkspace removeWatcherForPath: path];
}

- (void)unsetWatchers
{
	int i;
	
  for (i = 0; i < [watchedPaths count]; i++) {
    [self unsetWatcherForPath: [watchedPaths objectAtIndex: i]];  
  }
}

- (NSArray *)watchedPaths
{
  return watchedPaths;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self tile];
}

- (void)setFrame:(NSRect)frameRect
{
  [super setFrame: frameRect];
  [self tile];
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  
	if (dragIcon) {
		[dragIcon dissolveToPoint: dragPoint fraction: 0.3];
	}
}

@end


@implementation GWViewerShelf (NodeRepContainer)

- (void)removeRep:(id)arep
{
  NSString *watched = [[arep node] parentPath];	

	if ([watchedPaths containsObject: watched]) {
    [watchedPaths removeObject: watched];
    [self unsetWatcherForPath: watched];
	}

  if ([[self subviews] containsObject: arep]) {
    [arep removeFromSuperviewWithoutNeedingDisplay];
  }
  
  [icons removeObject: arep];
}

- (void)removeUndepositedRep:(id)arep
{
  [self removeRep: arep];
  [self setNeedsDisplay: YES];
}

- (void)repSelected:(id)arep
{
  [viewer shelfDidSelectIcon: arep]; 
  [arep unselect];
}

- (void)unselectOtherReps:(id)arep
{
  int i;

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if (icon != arep) {
      [icon unselect];
    }
  }
}

- (NSArray *)selectedPaths
{
  NSMutableArray *selectedPaths = [NSMutableArray array];
  int i, j;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      NSArray *selection = [icon selection];
    
      if (selection) {
        for (j = 0; j < [selection count]; j++) {
          [selectedPaths addObject: [[selection objectAtIndex: j] path]];
        }
      } else {
        [selectedPaths addObject: [[icon node] path]];
      }
    }
  }

  return [NSArray arrayWithArray: selectedPaths];
} 

- (void)nodeContentsWillChange:(NSDictionary *)info
{
  [self checkLockedReps];
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  int i;

  if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		files = [info objectForKey: @"origfiles"];
  }	
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {      
    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i]; 
           
      if ([icon isShowingSelection] == NO) {   
        if ([[[icon node] path] isEqual: source]) {
          [icon setNode: [FSNode nodeWithPath: destination]];
          break;
        }
      }          
    }        
  }  

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
		files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent];
  }	

  if ([operation isEqual: @"NSWorkspaceMoveOperation"] 
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				|| [operation isEqual: @"GWorkspaceRenameOperation"]
				|| [operation isEqual: @"NSWorkspaceRecycleOperation"]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    NSMutableArray *oppaths = [NSMutableArray array];
    int count = [icons count];
    BOOL updated = NO;

    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fpath = [source stringByAppendingPathComponent: fname];
      [oppaths addObject: fpath];
    }

    for (i = 0; i < count; i++) {
      FSNIcon *icon = [icons objectAtIndex: i]; 
      int j, m;
      
      if ([icon isShowingSelection] == NO) {
        NSString *iconpath = [[icon node] path];
      
	      for (m = 0; m < [oppaths count]; m++) {
          if ([iconpath hasPrefix: [oppaths objectAtIndex: m]]) {
            [self removeRep: icon];
            updated = YES;
            count--;
            i--;
            break;
          }
        }
      
      } else {
        NSArray *iconpaths = [icon pathsSelection];
        BOOL removed = NO;

        for (j = 0; j < [iconpaths count]; j++) {
          NSString *iconpath = [iconpaths objectAtIndex: j];
        
	        for (m = 0; m < [oppaths count]; m++) {
            if ([iconpath hasPrefix: [oppaths objectAtIndex: m]]) {
              [self removeRep: icon];
              updated = YES;
              count--;
              i--;
              removed = YES;
              break;
            }
          }
        
          if (removed) {
            break;
          } 
        }
      }
    }
    
    if (updated) {
      [self tile];
      [self setNeedsDisplay: YES];
    }
  }
}

- (void)watchedPathChanged:(NSDictionary *)info
{
  NSString *path = [info objectForKey: @"path"];
	NSString *event = [info objectForKey: @"event"];
	BOOL contained = NO;
	int i;

	if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
		return;
	}

	for (i = 0; i < [watchedPaths count]; i++) {
		NSString *wpath = [watchedPaths objectAtIndex: i];
		if (([wpath isEqual: path]) || (isSubpathOfPath(path, wpath))) {
			contained = YES;
			break;
		}
	}

  if (contained) {
		int count = [icons count];
    BOOL updated = NO;
    FSNIcon *icon;

		if ([event isEqual: @"GWWatchedPathDeleted"]) {		
			for (i = 0; i < count; i++) {
        icon = [icons objectAtIndex: i];
        
        if ([[icon node] isSubnodeOfPath: path]) {
          [self removeRep: icon];
          updated = YES;
					count--;
					i--;        
        }
			}

      if (updated) {
        [self tile];
        [self setNeedsDisplay: YES];
      }
      
			return;
		}		

		if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) { 
			NSArray *files = [info objectForKey: @"files"];

			for (i = 0; i < count; i++) {
				int j;
				
				icon = [icons objectAtIndex: i];

        if ([icon isShowingSelection] == NO) {
          FSNode *node = [icon node];

	        for (j = 0; j < [files count]; j++) {
						NSString *fname = [files objectAtIndex: j];
						NSString *fpath = [path stringByAppendingPathComponent: fname];
          
            if ([[node path] isEqual: fpath] || [node isSubnodeOfPath: fpath]) {
              [self removeRep: icon];
              updated = YES;
              count--;
              i--;
              break;
            }
          }
          
        } else {
          FSNode *node = [icon node];
          NSArray *selection = [icon selection];
        
	        for (j = 0; j < [files count]; j++) {
						NSString *fname = [files objectAtIndex: j];
						NSString *fpath = [path stringByAppendingPathComponent: fname];
						BOOL deleted = NO;
						int m;
        
						if (deleted) {
							break;
						}

						if ([node isSubnodeOfPath: fpath]) {
							[self removeRep: icon];
              updated = YES;
							count--;
							i--;
							break;
						}

            for (m = 0; m < [selection count]; m++) {
              node = [selection objectAtIndex: m];
        
              if ([[node path] isEqual: fpath]) {
								[self removeRep: icon];
                updated = YES;
								count--;
								i--;			
								deleted = YES;
								break;	
              }
            }
          }
        } 
      }
  
      if (updated) {
        [self tile];
        [self setNeedsDisplay: YES];
      }
    }
  }
}

- (void)checkLockedReps
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] checkLocked];
  }
}

- (FSNSelectionMask)selectionMask
{
  return NSSingleSelectionMask;
}

- (void)restoreLastSelection
{
  [self unselectOtherReps: nil];
}

- (NSColor *)backgroundColor
{
  return backColor;
}

- (NSColor *)textColor
{
  return textColor;
}

- (NSColor *)disabledTextColor
{
  return disabledTextColor;
}

@end


@implementation GWViewerShelf (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

  DESTROY (dragIcon);
  isDragTarget = NO;	
  dragLocalIcon = NO;    

	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}

  if (pb && [[pb types] containsObject: NSFilenamesPboardType]) {
    NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
    int count = [sourcePaths count];
    FSNode *baseNode = [viewer baseNode];
    int i;
        
	  if (count == 0) {
		  return NSDragOperationNone;
    } 

    for (i = 0; i < count; i++) {
      NSString *path = [sourcePaths objectAtIndex: i];
    
      if ([baseNode isParentOfPath: path] == NO) {
        return NSDragOperationNone;
      } 
    }  
  
    if (count == 1) {
      dragLocalIcon = ([self iconForPath: [sourcePaths objectAtIndex: 0]] != nil);
    } else {
      dragLocalIcon = ([self iconForPathsSelection: sourcePaths] != nil);
    }

    isDragTarget = YES;	
    dragPoint = NSZeroPoint;
    DESTROY (dragIcon);
    insertIndex = -1;
    
    return NSDragOperationAll;  
  }
  
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;
  NSPoint dpoint;
  int index;

	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}
  
  sourceDragMask = [sender draggingSourceOperationMask];
  
	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
    if (dragIcon) {
      DESTROY (dragIcon);
      if (insertIndex != -1) {
        [self setNeedsDisplayInRect: grid[insertIndex]];
      }
    }                   
		return NSDragOperationNone;
	}	
  
  dpoint = [sender draggingLocation];
  dpoint = [self convertPoint: dpoint fromView: nil];
  index = [self indexOfGridRectContainingPoint: dpoint];
  
  if ((index != -1) && ([self isFreeGridIndex: index])) {
    NSImage *img = [sender draggedImage];
    NSSize sz = [img size];
    NSRect irect = [self iconBoundsInGridAtIndex: index];
    
    dragPoint.x = ceil(irect.origin.x + ((irect.size.width - sz.width) / 2));
    dragPoint.y = ceil(irect.origin.y + ((irect.size.height - sz.height) / 2));
      
    if (dragIcon == nil) {
      ASSIGN (dragIcon, img); 
    }
  
    if (insertIndex != index) {
      [self setNeedsDisplayInRect: grid[index]];
      
      if (insertIndex != -1) {
        [self setNeedsDisplayInRect: grid[insertIndex]];
      }
    }
    
    insertIndex = index;

  } else {
    DESTROY (dragIcon);
    if (insertIndex != -1) {
      [self setNeedsDisplayInRect: grid[insertIndex]];
    }
    insertIndex = -1;
    return NSDragOperationNone;
  }
  
	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}
  
  return NSDragOperationAll;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  DESTROY (dragIcon);
  if (insertIndex != -1) {
    [self setNeedsDisplayInRect: grid[insertIndex]];
  }
	isDragTarget = NO;
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
	NSPasteboard *pb = [sender draggingPasteboard];
	NSMutableArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
  int count = [sourcePaths count];
  id icon;

  DESTROY (dragIcon);
	isDragTarget = NO;  
  
  if (insertIndex != -1) {
    if (dragLocalIcon) {
      if (count == 1) {
        icon = [self iconForPath: [sourcePaths objectAtIndex: 0]];
      } else {
        icon = [self iconForPathsSelection: sourcePaths];
      }  

      if (icon) {
        [icon setGridIndex: insertIndex];
      }

    } else {
      FSNode *baseNode = [viewer baseNode];
      NSMutableArray *icnnodes = [NSMutableArray array];
      int i;
    
      for (i = 0; i < [sourcePaths count]; i++) {
        FSNode *node = [FSNode nodeWithPath: [sourcePaths objectAtIndex: i]];

        if ([node isValid] && [baseNode isParentOfNode: node]) {
          [icnnodes addObject: node]; 
        } 
      }
    
      if ([icnnodes count]) {
        if ([icnnodes count] == 1) {
          [self addIconForNode: [icnnodes objectAtIndex: 0] atIndex: insertIndex];
        } else {
          [self addIconForSelection: icnnodes atIndex: insertIndex];
        }
      }
    }
  }
            
  [self tile];
  [self setNeedsDisplay: YES];
}

@end


































