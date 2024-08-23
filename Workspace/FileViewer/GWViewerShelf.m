/* GWViewerShelf.h
 *  
 * Copyright (C) 2004-2024 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale
 *          Riccardo Mottola <rm@gnu.org>
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

#include <math.h>

#import <AppKit/AppKit.h>

#import "GWViewerShelf.h"
#import "GWViewer.h"
#import "GWorkspace.h"
#import "FSNTextCell.h"
#import "FSNBrowser.h"
#import "FSNIconsView.h"
#import "FSNIcon.h"
#import "FSNFunctions.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

#define DEF_GRID_WIDTH 90
#define Y_MARGIN (4)
#define EDIT_MARGIN (4)

@interface GWTextField : NSTextField
@end

@implementation GWTextField

- (id) initWithFrame: (NSRect)aFrame
{
  NSTextFieldCell *cell;

  self = [super initWithFrame: aFrame];
  if (self)
    {
      cell =  [[[FSNTextCell alloc] init] autorelease];
      [cell setDrawsBackground: YES];
      [self setCell: cell];
    }
  return self;
}

@end


@implementation GWViewerShelf

- (void)dealloc
{
  [self unsetWatchers];
  RELEASE (watchedPaths);
  RELEASE (icons);
  RELEASE (extInfoType);
  if (grid != NULL)
    {
      NSZoneFree (NSDefaultMallocZone(), grid);
    }
  RELEASE (dragIcon);
  RELEASE (focusedIconLabel);  
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
    focusedIcon = nil;

    [self calculateGridSize];    
    [self makeIconsGrid];
 
    [self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];

    watchedPaths = [[NSCountedSet alloc] initWithCapacity: 1];

    focusedIconLabel = [GWTextField new];
    [focusedIconLabel setFont: [NSFont systemFontOfSize: 12]];
    [focusedIconLabel setBezeled: NO];
    [focusedIconLabel setAlignment: NSCenterTextAlignment];
    [focusedIconLabel setEditable: NO];
    [focusedIconLabel setSelectable: NO];
    [focusedIconLabel setBackgroundColor: backColor];
    [focusedIconLabel setTextColor: [NSColor controlTextColor]];
    [focusedIconLabel setFrame: NSMakeRect(0, 0, 0, 14)];    
  }
  
  return self;
}

- (void)setContents:(NSArray *)iconsInfo
{
  FSNode *baseNode = [viewer baseNode];
  NSInteger i;

  for (i = 0; i < [iconsInfo count]; i++)
    { 
      NSDictionary *info = [iconsInfo objectAtIndex: i];
      NSArray *paths = [info objectForKey: @"paths"];
      NSInteger index = [[info objectForKey: @"index"] intValue];
      NSMutableArray *icnnodes = [NSMutableArray array];
      NSInteger j;

      for (j = 0; j < [paths count]; j++)
	{
	  FSNode *node = [FSNode nodeWithPath: [paths objectAtIndex: j]];

	  if ([node isValid] && [baseNode isParentOfNode: node])
	    {
	      [icnnodes addObject: node];
	    }
	}

      if ([icnnodes count] && (index != -1))
	{
	  if ([icnnodes count] == 1)
	    {
	      [self addIconForNode: [icnnodes objectAtIndex: 0] atIndex: index];
	    }
	  else
	    {
	      [self addIconForSelection: icnnodes atIndex: index];
	    }
	}
    }

  [self tile];
}

- (NSArray *)contentsInfo
{
  NSMutableArray *iconsInfo = [NSMutableArray array]; 
  NSInteger i;

  for (i = 0; i < [icons count]; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
      if ([icon isShowingSelection])
	{
	  NSArray *selection = [icon selection];
	  NSMutableArray *paths = [NSMutableArray array];
	  NSInteger j;
      
	  for (j = 0; j < [selection count]; j++)
	    {
	      [paths addObject: [[selection objectAtIndex: j] path]];
	    }

	  [dict setObject: paths forKey: @"paths"];
	}
      else
	{
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
             atIndex:(NSInteger)index
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

    if ([watchedPaths containsObject: watched] == NO)
      {
	[self setWatcherForPath: watched];
      }
    [watchedPaths addObject: watched];
  }
  
  return icon;
}

- (id)addIconForSelection:(NSArray *)selection
                  atIndex:(NSInteger)index
{
  FSNIcon *icon = [self addIconForNode: [selection objectAtIndex: 0] 
                               atIndex: index];
  [icon showSelection: selection];
  return icon;
}

- (id)iconForNode:(FSNode *)node
{
  NSInteger i;
	
  for (i = 0; i < [icons count]; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];
    
      if ([[icon node] isEqual: node] && ([icon selection] == nil))
	{
	  return icon;
	}
    }
  
  return nil;
}

- (id)iconForPath:(NSString *)path
{
  NSUInteger i;
	
  for (i = 0; i < [icons count]; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];

      if ([[[icon node] path] isEqual: path] && ([icon selection] == nil)) {
	return icon;
      }
    }
  
  return nil;
}

- (id)iconForNodesSelection:(NSArray *)selection
{
  NSInteger i;
	
  for (i = 0; i < [icons count]; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];
      NSArray *selnodes = [icon selection];
    
    if (selnodes && [selnodes isEqual: selection])
      {
	return icon;
      }
    }
  
  return nil;
}

- (id)iconForPathsSelection:(NSArray *)selection
{
  NSUInteger i;
	
  for (i = 0; i < [icons count]; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];
      NSArray *selnodes = [icon selection];
    
      if (selnodes)
	{
	  NSMutableArray *selpaths = [NSMutableArray array];
	  NSUInteger j;
      
	  for (j = 0; j < [selnodes count]; j++)
	    {
	      [selpaths addObject: [[selnodes objectAtIndex: j] path]];
	    }
      
	  if ([selpaths isEqual: selection])
	    {
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

  labelSize.height = myrintf([fsnodeRep heightOfFont: labelFont]);
  labelSize.width = gridSize.width;
  gridSize.height = highlightSize.height + labelSize.height;
}

- (void)makeIconsGrid
{
  NSRect gridrect = [self bounds];
  NSPoint gpnt;
  NSInteger i;

  if (grid != NULL)
    {
      NSZoneFree (NSDefaultMallocZone(), grid);
    }
  
  colCount = (int)(gridrect.size.width / gridSize.width);  
  rowCount = (int)(gridrect.size.height / gridSize.height);
  gridCount = colCount * rowCount;

  grid = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * gridCount);	

  gpnt.x = 0;
  gpnt.y = gridrect.size.height - gridSize.height - Y_MARGIN;

  for (i = 0; i < gridCount; i++)
    {
      if (i > 0)
	{
	  gpnt.x += gridSize.width;      
	}

      if (gpnt.x >= (gridrect.size.width - gridSize.width))
	{
	  gpnt.x = 0;
	  gpnt.y -= (gridSize.height + Y_MARGIN);
	}
 
      grid[i].origin = gpnt;
      grid[i].size = gridSize;
      grid[i] = NSIntegralRect(grid[i]);    
    }
}

- (NSInteger)firstFreeGridIndex
{
  NSInteger i;

  for (i = 0; i < gridCount; i++) {
    if ([self isFreeGridIndex: i]) {
      return i;
    }
  }
  
  return -1;
}

- (NSInteger)firstFreeGridIndexAfterIndex:(NSInteger)index
{
  NSInteger newind = index;

  while (1)
    {
      newind++;
    
    if (newind >= gridCount)
      {
	return [self firstFreeGridIndex];
      }
    
    if ([self isFreeGridIndex: newind])
      {
	return newind;
      }
    } 
 
  return -1;
}

- (BOOL)isFreeGridIndex:(NSInteger)index
{
  NSUInteger i;
	
  if ((index < 0) || (index >= gridCount)) {
    return NO;
  }
  
  for (i = 0; i < [icons count]; i++) {
    if ([[icons objectAtIndex: i] gridIndex] == index) {
      return NO;
    }
  }
  
  return YES;
}

- (id)iconWithGridIndex:(NSInteger)index
{
  NSInteger i;
	
  for (i = 0; i < [icons count]; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];
    
      if ([icon gridIndex] == index) {
	return icon;
      }
  }
  
  return nil;
}

- (NSInteger)indexOfGridRectContainingPoint:(NSPoint)p
{
  NSInteger i;

  for (i = 0; i < gridCount; i++)
    {
      if (NSPointInRect(p, grid[i]))
	{ 
	  return i;
	}
    }

  return -1;
}

- (NSRect)iconBoundsInGridAtIndex:(NSInteger)index
{
  NSRect icnBounds = NSMakeRect(grid[index].origin.x, grid[index].origin.y, iconSize, iconSize);
  NSRect hlightRect = NSZeroRect;
  
  hlightRect.size.width = ceil(iconSize / 3 * 4);
  hlightRect.size.height = ceil(hlightRect.size.width * [fsnodeRep highlightHeightFactor]);
  hlightRect.origin.x = ceil((gridSize.width - hlightRect.size.width) / 2);   
  hlightRect.origin.y = floor([fsnodeRep heightOfFont: labelFont]);
  
  icnBounds.origin.x += hlightRect.origin.x + ((hlightRect.size.width - iconSize) / 2);
  icnBounds.origin.y += hlightRect.origin.y + ((hlightRect.size.height - iconSize) / 2);

  return icnBounds;
}

- (void)tile
{
  NSArray *subviews = [self subviews];
  NSUInteger i;

  [self makeIconsGrid];
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSUInteger index = [icon gridIndex];
    
    if (index < gridCount) {
      if ([subviews containsObject: icon] == NO) {
        [self addSubview: icon];
      }
      if (NSEqualRects(grid[index], [icon frame]) == NO) {
        [icon setFrame: grid[index]];
      }
    } else {
      if (focusedIcon == icon) {
        focusedIcon = nil;
      }

      [icon removeFromSuperview];
    }
  }
  
  [self updateFocusedIconLabel];
}

- (void)updateFocusedIconLabel
{
  if ([[self subviews] containsObject: focusedIconLabel]) {
    NSRect rect = [focusedIconLabel frame];

    [focusedIconLabel removeFromSuperview];
    [self setNeedsDisplayInRect: rect];
  }

  if (focusedIcon) {
    NSRect icnr = [focusedIcon frame];
    float centerx = icnr.origin.x + (icnr.size.width / 2);
    NSRect edrect = [self convertRect: [focusedIcon labelRect] fromView: focusedIcon];
    int margin = [fsnodeRep labelMargin];
    float bw = [self bounds].size.width - EDIT_MARGIN;
    NSString *nodeDescr = [focusedIcon shownInfo]; 
    float edwidth = [[focusedIconLabel font] widthOfString: nodeDescr];
    
    edwidth += margin;

    if ((centerx + (edwidth / 2)) >= bw) {
      centerx -= (centerx + (edwidth / 2) - bw);
    } else if ((centerx - (edwidth / 2)) < margin) {
      centerx += fabs(centerx - (edwidth / 2)) + margin;
    }    
    
    edrect.origin.x = centerx - (edwidth / 2);
    edrect.size.width = edwidth;
    edrect = NSIntegralRect(edrect);

    [focusedIconLabel setFrame: edrect];
    [focusedIconLabel setStringValue: nodeDescr];

    if ([focusedIcon isLocked] == NO) {
      [focusedIconLabel setTextColor: [NSColor controlTextColor]];    
    } else {
      [focusedIconLabel setTextColor: [NSColor disabledControlTextColor]];    
    }

    [focusedIcon setNameEdited: YES];
    
    [self addSubview: focusedIconLabel];  
    [self setNeedsDisplayInRect: edrect];
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
  NSEnumerator *enumerator = [watchedPaths objectEnumerator]; 
  NSString *wpath;

  while ((wpath = [enumerator nextObject])) {
    [self unsetWatcherForPath: wpath]; 
  }
}

- (NSArray *)watchedPaths
{
  return [watchedPaths allObjects];
}

- (void)checkIconsAfterDotsFilesChange
{
  NSUInteger count = [icons count]; 
  BOOL updated = NO;
  NSInteger i;

  for (i = 0; i < count; i++) {
    FSNIcon *icon = [icons objectAtIndex: i]; 
  
    if ([icon isShowingSelection] == NO) {
      if ([[[icon node] path] rangeOfString: @"."].location != NSNotFound) {
        [self removeRep: icon];
        updated = YES;
        count--;
        i--;
      }
      
    } else {
      NSArray *iconpaths = [icon pathsSelection];
      NSInteger j;
  
      for (j = 0; j < [iconpaths count]; j++) {
        NSString *iconpath = [iconpaths objectAtIndex: j];

        if ([iconpath rangeOfString: @"."].location != NSNotFound) {
          [self removeRep: icon];
          updated = YES;
          count--;
          i--;
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

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths
{
  NSInteger count = [icons count]; 
  BOOL updated = NO;
  NSInteger i;

  for (i = 0; i < count; i++) {
    FSNIcon *icon = [icons objectAtIndex: i]; 
    NSInteger j, m;
  
    if ([icon isShowingSelection] == NO) {
      NSString *iconpath = [[icon node] path];

      for (m = 0; m < [hpaths count]; m++) {
        NSString *hpath = [hpaths objectAtIndex: m]; 
      
        if (isSubpathOfPath(hpath, iconpath) || [hpath isEqual: iconpath]) {
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

	      for (m = 0; m < [hpaths count]; m++) {
          NSString *hpath = [hpaths objectAtIndex: m]; 
        
          if (isSubpathOfPath(hpath, iconpath) || [hpath isEqual: iconpath]) {
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
  
  if (dragIcon)
    {
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
    
    if ([watchedPaths containsObject: watched] == NO) {
      [self unsetWatcherForPath: watched];
	  }
  }

  if ([[self subviews] containsObject: arep]) {
    [arep removeFromSuperviewWithoutNeedingDisplay];
  }
  
  if (focusedIcon == arep) {
    focusedIcon = nil;
    [self updateFocusedIconLabel];
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
  NSInteger i;

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
  NSUInteger i, j;
  
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

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [viewer openSelectionInNewViewer: newv];
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
  NSInteger i;

  if ([operation isEqual: NSWorkspaceRecycleOperation]) {
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

  if ([operation isEqual: NSWorkspaceMoveOperation] 
      || [operation isEqual: NSWorkspaceDestroyOperation]
      || [operation isEqual: @"GWorkspaceRenameOperation"]
      || [operation isEqual: NSWorkspaceRecycleOperation]
      || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
      || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    NSMutableArray *oppaths = [NSMutableArray array];
    NSUInteger count = [icons count];
    BOOL updated = NO;

    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fpath = [source stringByAppendingPathComponent: fname];
      [oppaths addObject: fpath];
    }

    for (i = 0; i < count; i++) {
      FSNIcon *icon = [icons objectAtIndex: i]; 
      NSInteger j, m;
      
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
  NSEnumerator *enumerator;
  NSString *wpath;
  BOOL contained = NO;
  
  if ([event isEqual: @"GWFileCreatedInWatchedDirectory"])
    {
      return;
    }
  
  enumerator = [watchedPaths objectEnumerator];
  
  while ((wpath = [enumerator nextObject]))
    {
      if (([wpath isEqual: path]) || (isSubpathOfPath(path, wpath)))
        {
          contained = YES;
          break;
        }
    }

  if (contained)
    {
      NSUInteger count = [icons count];
      BOOL updated = NO;
      FSNIcon *icon;
      NSInteger i;
      
      if ([event isEqual: @"GWWatchedPathDeleted"])
        {		
          for (i = 0; i < count; i++)
            {
              icon = [icons objectAtIndex: i];
              
              if ([[icon node] isSubnodeOfPath: path])
                {
                  [self removeRep: icon];
                  updated = YES;
                  count--;
                  i--;        
                }
            }
          
          if (updated)
            {
              [self tile];
              [self setNeedsDisplay: YES];
            }
          
          return;
        }		

      if ([event isEqual: @"GWFileDeletedInWatchedDirectory"])
        { 
          NSArray *files = [info objectForKey: @"files"];
          
          for (i = 0; i < count; i++)
            {
              NSUInteger j;
				
              icon = [icons objectAtIndex: i];

              if ([icon isShowingSelection] == NO)
                {
                  FSNode *node = [icon node];
                  
                  for (j = 0; j < [files count]; j++)
                    {
                      NSString *fname = [files objectAtIndex: j];
                      NSString *fpath = [path stringByAppendingPathComponent: fname];
                      
                      if ([[node path] isEqual: fpath] || [node isSubnodeOfPath: fpath])
                        {
                          [self removeRep: icon];
                          updated = YES;
                          count--;
                          i--;
                          break;
                        }
                    }
                  
                }
              else
                {
                  FSNode *node = [icon node];
                  NSArray *selection = [icon selection];
                  
                  for (j = 0; j < [files count]; j++)
                    {
                      NSString *fname = [files objectAtIndex: j];
                      NSString *fpath = [path stringByAppendingPathComponent: fname];
                      BOOL deleted = NO;
                      NSUInteger m;
                      
                      if (deleted)
                        {
                          break;
                        }

                      if ([node isSubnodeOfPath: fpath])
                        {
                          [self removeRep: icon];
                          updated = YES;
                          count--;
                          i--;
                          break;
                        }

                      for (m = 0; m < [selection count]; m++)
                        {
                          node = [selection objectAtIndex: m];
                          
                          if ([[node path] isEqual: fpath])
                            {
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
          
          if (updated)
            {
              [self tile];
              [self setNeedsDisplay: YES];
            }
        }
    }
}

- (void)checkLockedReps
{
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++)
    {
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

- (void)setFocusedRep:(id)arep
{
  if (arep == nil) {
    if (focusedIcon) {
      [focusedIcon setNameEdited: NO];
    }
  } 

  focusedIcon = arep;  
  [self updateFocusedIconLabel];
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

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

  DESTROY (dragIcon);
  isDragTarget = NO;	
  dragLocalIcon = NO;    

  if ((sourceDragMask & NSDragOperationCopy)
      || (sourceDragMask & NSDragOperationLink))
    {
      return NSDragOperationNone;
    }
  
  if (pb && [[pb types] containsObject: NSFilenamesPboardType])
    {
      NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
      NSUInteger count = [sourcePaths count];
      FSNode *baseNode = [viewer baseNode];
      NSString *basePath;
      NSUInteger i;
      
      if (count == 0)
        {
          return NSDragOperationNone;
        } 
      
      for (i = 0; i < count; i++)
        {
          NSString *path = [sourcePaths objectAtIndex: i];
          
          if ([baseNode isParentOfPath: path] == NO)
            {
              return NSDragOperationNone;
            } 
        }  
      
      basePath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
      if ([basePath isEqual: [gworkspace trashPath]])
        {
          return NSDragOperationNone;
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
    
    return NSDragOperationEvery;
  }
  
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;
  NSPoint dpoint;
  NSInteger index;

  if (isDragTarget == NO) {
    return NSDragOperationNone;
  }
  
  sourceDragMask = [sender draggingSourceOperationMask];
  
  if ((sourceDragMask & NSDragOperationCopy)
      || (sourceDragMask & NSDragOperationLink)) {
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
  
  if ((sourceDragMask & NSDragOperationCopy)
      || (sourceDragMask & NSDragOperationLink))
    {
      return NSDragOperationNone;
    }

  return NSDragOperationEvery;
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
  NSInteger count = [sourcePaths count];
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
      NSInteger i;
    
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


































