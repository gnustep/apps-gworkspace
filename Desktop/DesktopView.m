/* DesktopView.m
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
#include <GNUstepGUI/GSDisplayServer.h>
#include <math.h>
#include "FSNIcon.h"
#include "FSNFunctions.h"
#include "DesktopView.h"
#include "Desktop.h"
#include "Dock.h"
#include "GNUstep.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

#define LABEL_W_FACT (8)

#define X_MARGIN (10)
#define Y_MARGIN (12)

#define EDIT_MARGIN (4)

#ifndef max
  #define max(a,b) ((a) >= (b) ? (a):(b))
#endif

#ifndef min
  #define min(a,b) ((a) <= (b) ? (a):(b))
#endif

#define DEF_COLOR [NSColor colorWithCalibratedRed: 0.39 green: 0.51 blue: 0.57 alpha: 1.00]

NSMenuItem *addItemToMenu(NSMenu *menu, NSString *str, 
																NSString *comm, NSString *sel, NSString *key)
{
	NSMenuItem *item = [menu addItemWithTitle: NSLocalizedString(str, comm)
												action: NSSelectorFromString(sel) keyEquivalent: key]; 
	return item;
}


@implementation DesktopView

- (void)dealloc
{
  TEST_RELEASE (node);
  TEST_RELEASE (infoPath);
  TEST_RELEASE (nodeInfo);
  RELEASE (icons);
  RELEASE (nameEditor);
  RELEASE (horizontalImage);
  RELEASE (verticalImage);
  TEST_RELEASE (lastSelection);
	NSZoneFree (NSDefaultMallocZone(), grid);
  TEST_RELEASE (dragIcon);
  RELEASE (backColor);
  TEST_RELEASE (backImage);
  TEST_RELEASE (imagePath);

  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    id defentry;
    NSSize size;
    NSCachedImageRep *rep;

    screenFrame = [[NSScreen mainScreen] frame];
    [self setFrame: screenFrame];

    size = NSMakeSize(screenFrame.size.width, 2);
    horizontalImage = [[NSImage allocWithZone: (NSZone *)[(NSObject *)self zone]] 
                                 initWithSize: size];

    rep = [[NSCachedImageRep allocWithZone: (NSZone *)[(NSObject *)self zone]]
                              initWithSize: size
                                     depth: [NSWindow defaultDepthLimit] 
                                  separate: YES 
                                     alpha: YES];

    [horizontalImage addRepresentation: rep];
    RELEASE (rep);

    size = NSMakeSize(2, screenFrame.size.height);
    verticalImage = [[NSImage allocWithZone: (NSZone *)[(NSObject *)self zone]] 
                               initWithSize: size];

    rep = [[NSCachedImageRep allocWithZone: (NSZone *)[(NSObject *)self zone]]
                              initWithSize: size
                                     depth: [NSWindow defaultDepthLimit] 
                                  separate: YES 
                                     alpha: YES];

    [verticalImage addRepresentation: rep];
    RELEASE (rep);

    desktop = [Desktop desktop];

    defentry = [defaults dictionaryForKey: @"backcolor"];
    if (defentry) {
      float red = [[defentry objectForKey: @"red"] floatValue];
      float green = [[defentry objectForKey: @"green"] floatValue];
      float blue = [[defentry objectForKey: @"blue"] floatValue];
      float alpha = [[defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (backColor, DEF_COLOR);
    }

    defentry = [defaults objectForKey: @"imagestyle"];
    if (defentry) {
      backImageStyle = [defentry intValue];
    } else {
      backImageStyle = BackImageCenterStyle;
    }    

    defentry = [defaults objectForKey: @"imagepath"];
    if (defentry) {
      NSImage *image = [[NSImage alloc] initWithContentsOfFile: defentry];
    
      if (image) {
        ASSIGN (imagePath, defentry);
        [self createBackImage: image];
        RELEASE (image);
      }
    }
    
    useBackImage = [defaults boolForKey: @"usebackimage"];

    defentry = [defaults objectForKey: @"iconsize"];
    iconSize = defentry ? [defentry intValue] : DEF_ICN_SIZE;

    defentry = [defaults objectForKey: @"labeltxtsize"];
    labelTextSize = defentry ? [defentry intValue] : DEF_TEXT_SIZE;
    
    defentry = [defaults objectForKey: @"iconposition"];
    iconPosition = defentry ? [defentry intValue] : DEF_ICN_POS;
    
    infoType = FSNInfoNameType;
    
    [self makeIconsGrid];

    icons = [NSMutableArray new];
        
    nameEditor = [FSNIconNameEditor new];
    [nameEditor setDelegate: self];  
		[nameEditor setFont: [FSNIcon labelFont]];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSCenterTextAlignment];
	  [nameEditor setBackgroundColor: backColor];
    editIcon = nil;

    selectionMask = NSSingleSelectionMask;
    
    dragIcon = nil;
    isDragTarget = NO;
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                                NSFilenamesPboardType, 
                                                @"GWRemoteFilenamesPboardType", 
                                                nil]];    
                                                
    [FSNodeRep setUseThumbnails: YES];
  }
   
  return self;
}

- (void)fileSystemWillChange:(NSDictionary *)info
{
  [self checkLockedReps];
}

- (void)fileSystemDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  int i; 

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent]; 
  }

  if ([[node path] isEqual: source]
        && ([operation isEqual: @"NSWorkspaceMoveOperation"]
            || [operation isEqual: @"NSWorkspaceDestroyOperation"]
            || [operation isEqual: @"GWorkspaceRenameOperation"]
			      || [operation isEqual: @"NSWorkspaceRecycleOperation"]
			      || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) {
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      
      if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
        FSNIcon *icon = [self repOfSubnode: subnode];
        
        if (icon) {
          insertIndex = [icon gridIndex];
        }
      }
      
      [self removeRepOfSubnode: subnode];
    }
  }

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([[node path] isEqual: destination]
          && ([operation isEqual: @"NSWorkspaceMoveOperation"]   
              || [operation isEqual: @"NSWorkspaceCopyOperation"]
              || [operation isEqual: @"NSWorkspaceLinkOperation"]
              || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
              || [operation isEqual: @"GWorkspaceCreateDirOperation"]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
				      || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) { 
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      FSNIcon *icon = [self repOfSubnode: subnode];
      int index;

      if (i == 0) {
        if (insertIndex != -1) {
          if ([self isFreeGridIndex: insertIndex]) {
            index = insertIndex;
          } else {
            index = [self firstFreeGridIndexAfterIndex: insertIndex];

            if (index == -1) {
              index = [self firstFreeGridIndex];
            }
          }
        
        } else {
          index = [self firstFreeGridIndex];
        }
        
      } else {
        index = [self firstFreeGridIndexAfterIndex: index];
        
        if (index == -1) {
          index = [self firstFreeGridIndex];
        }
      }
      
      if (icon) {
        [icon setNode: subnode];
        [icon setGridIndex: index];
      } else {
        icon = [self addRepForSubnode: subnode];
        [icon setGridIndex: index];
      }
    }
    
  }
  
  [self checkLockedReps];
  [self tile];
  [self setNeedsDisplay: YES];
  [self selectionDidChange];
}

- (void)watchedPathDidChange:(NSDictionary *)info
{
  NSString *event = [info objectForKey: @"event"];
  NSArray *files = [info objectForKey: @"files"];
  NSString *ndpath = [node path];
  NSString *fname;
  NSString *fpath;
  int i;

  if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      fname = [files objectAtIndex: i];
      fpath = [ndpath stringByAppendingPathComponent: fname];  
      [self removeRepOfSubnodePath: fpath];
    }
    
  } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      fname = [files objectAtIndex: i];
      fpath = [ndpath stringByAppendingPathComponent: fname];  
      
      if ([self repOfSubnodePath: fpath] == nil) {
        [self addRepForSubnodePath: fpath];
      }
    }
    
  } else if ([event isEqual: @"GWWatchedFileModified"]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *mtabpath = [defaults stringForKey: @"GSMtabPath"];

    if (mtabpath == nil) {
      mtabpath = @"/etc/mtab";
    }
  
    fpath = [info objectForKey: @"path"];
  
    if ([fpath isEqual: mtabpath]) {
      [self showMountedVolumes];
    }
  }
  
  [self tile];
  [self setNeedsDisplay: YES];
  [self selectionDidChange];
}

- (void)thumbnailsDidChange
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    FSNode *inode = [icon node];
    [icon setNode: inode];
  }  
}

- (void)newVolumeMountedAtPath:(NSString *)vpath
{
  FSNode *vnode = [FSNode nodeWithRelativePath: vpath parent: nil];

  [vnode setMountPoint: YES];
  [self removeRepOfSubnode: vnode];
  [self addRepForSubnode: vnode]; 
  [self tile];
}

- (void)workspaceWillUnmountVolumeAtPath:(NSString *)vpath
{
  [self checkLockedReps];
}

- (void)workspaceDidUnmountVolumeAtPath:(NSString *)vpath
{
  FSNIcon *icon = [self repOfSubnodePath: vpath];
   
  if (icon) {
    [self removeRep: icon];
    [self tile];
  }
}

- (void)readNodeInfo
{
  ASSIGN (infoPath, [[node path] stringByAppendingPathComponent: @".dirinfo"]);
  DESTROY (nodeInfo);
  
  if ([[NSFileManager defaultManager] fileExistsAtPath: infoPath]) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: infoPath];
  
    if (dict) {
      nodeInfo = [dict mutableCopy];
    } else {
      nodeInfo = [NSMutableDictionary new];
    }
  } else {
    nodeInfo = [NSMutableDictionary new];
  }
}

- (void)updateNodeInfo
{
  if ([node isWritable]) {
    NSMutableDictionary *indexes = [NSMutableDictionary dictionary];
    int i;
    
    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];
    
      [indexes setObject: [NSNumber numberWithInt: [icon gridIndex]]
                  forKey: [[icon node] name]];
    }
    
    [nodeInfo setObject: indexes forKey: @"indexes"];
    [nodeInfo writeToFile: infoPath atomically: YES];
  }
}

- (void)showMountedVolumes
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *mtabpath = [defaults stringForKey: @"GSMtabPath"];
  NSArray *vpaths = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
  int count = [icons count];
  int i;

  if (mtabpath == nil) {
    mtabpath = @"/etc/mtab";
  }

  [desktop removeWatcherForPath: mtabpath];

  for (i = 0; i < count; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
  
    if ([[icon node] isMountPoint]) {
      [self removeRep: icon];
      count--;
      i--;
    }
  }

  for (i = 0; i < [vpaths count]; i++) {
    NSString *vpath = [vpaths objectAtIndex: i];
    FSNode *vnode = [FSNode nodeWithRelativePath: vpath parent: nil];
  
    [vnode setMountPoint: YES];
    [self addRepForSubnode: vnode];
  }
  
  [self tile];  
  
  [desktop addWatcherForPath: mtabpath];
}

- (void)dockPositionDidChange
{
  [self makeIconsGrid];
  [self tile];
  [self setNeedsDisplay: YES];
}

- (void)tile
{
  int i;

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    int index = [icon gridIndex];
  
    if (NSEqualRects(grid[index], [icon frame]) == NO) {
      [icon setFrame: grid[index]];
    }
  }
  
  [self updateNameEditor];
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
  int ind = index;
  int newind = index;

  while (1) {
    newind -= rowcount;
    
    if (newind < 0) {
      newind = ind++;
    }
    
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
  hlightRect.size.height = ceil(hlightRect.size.width * [FSNodeRep highlightHeightFactor]);
  if ((hlightRect.size.height - iconSize) < 2) {
    hlightRect.size.height = iconSize + 2;
  }

  if (iconPosition == NSImageAbove) {  
    hlightRect.origin.x = ceil((gridSize.width - hlightRect.size.width) / 2);   
    hlightRect.origin.y = floor([[FSNIcon labelFont] defaultLineHeightForFont]);
  } else {
    hlightRect.origin.x = 0;
    hlightRect.origin.y = 0;
  }
  
  icnBounds.origin.x += hlightRect.origin.x + ((hlightRect.size.width - iconSize) / 2);
  icnBounds.origin.y += hlightRect.origin.y + ((hlightRect.size.height - iconSize) / 2);

  return icnBounds;
}

- (void)calculateGridSize
{
  NSSize highlightSize = NSZeroSize;
  NSSize labelSize = NSZeroSize;
  
  highlightSize.width = ceil(iconSize / 3 * 4);
  highlightSize.height = ceil(highlightSize.width * [FSNodeRep highlightHeightFactor]);
  if ((highlightSize.height - iconSize) < 4) {
    highlightSize.height = iconSize + 4;
  }

  [FSNIcon setLabelFont: [NSFont systemFontOfSize: labelTextSize]];
  labelSize.height = floor([[FSNIcon labelFont] defaultLineHeightForFont]);
  labelSize.width = LABEL_W_FACT * labelTextSize;

  gridSize.height = highlightSize.height;

  if (iconPosition == NSImageAbove) {
    gridSize.height += labelSize.height;
    gridSize.width = labelSize.width;
  } else {
    gridSize.width = highlightSize.width + labelSize.width + [FSNodeRep labelMargin];
  }
}

- (void)makeIconsGrid
{
  NSRect dckr = [desktop dockReservedFrame];
  NSRect tshfr = [desktop tshelfReservedFrame];
  NSRect gridrect = screenFrame;
  NSPoint gpnt;
  int i;
  
	if (grid != NULL) {
		NSZoneFree (NSDefaultMallocZone(), grid);
	}
  
  [self calculateGridSize];
  
  gridrect.origin.y += tshfr.size.height;
  gridrect.size.height -= tshfr.size.height;
  gridrect.size.width -= dckr.size.width;
  if ([desktop dockPosition] == DockPositionLeft) {
    gridrect.origin.x += dckr.size.width;
  }
  
  colcount = (int)(gridrect.size.width / (gridSize.width + X_MARGIN));  
  rowcount = (int)(gridrect.size.height / (gridSize.height + Y_MARGIN));
	gridcount = colcount * rowcount;

	grid = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * gridcount);	
    
  gpnt.x = gridrect.size.width + gridrect.origin.x;
  gpnt.y = gridrect.size.height + gridrect.origin.y;
                     
  gpnt.x -= (gridSize.width + X_MARGIN);
  
  for (i = 0; i < gridcount; i++) {
    gpnt.y -= (gridSize.height + Y_MARGIN);
    
    if (gpnt.y <= gridrect.origin.y) {
      gpnt.y = gridrect.size.height + gridrect.origin.y;    
      gpnt.y -= (gridSize.height + Y_MARGIN);
      gpnt.x -= (gridSize.width + X_MARGIN);
    }
  
    grid[i].origin = gpnt;
    grid[i].size = gridSize;
  }
  
  gpnt = grid[gridcount - 1].origin;
  
  if (gpnt.x != (gridrect.origin.x + X_MARGIN)) {
    float diffx = gpnt.x - (gridrect.origin.x + X_MARGIN);
    float xshft = 0.0;
    
    diffx /= (int)(gridrect.size.width / (gridSize.width + X_MARGIN));  
  
    for (i = 0; i < gridcount; i++) {
      if (div(i, rowcount).rem == 0) {
        xshft += diffx;
      }
      grid[i].origin.x -= xshft;
    }
  }
  
  if (gpnt.y != (gridrect.origin.y + Y_MARGIN)) {
    float diffy = gpnt.y - (gridrect.origin.y + Y_MARGIN);
    float yshft = 0.0;
    
    diffy /= rowcount;  

    for (i = 0; i < gridcount; i++) {
      if (div(i, rowcount).rem == 0) {
        yshft = 0.0;
      }
      yshft += diffy;
      grid[i].origin.y -= yshft;
    }
  }
  
  for (i = 0; i < gridcount; i++) {
    grid[i] = NSIntegralRect(grid[i]);
  }
}

- (int)iconSize
{
  return iconSize;
}

- (void)setIconSize:(int)size
{
  int i;
  
  iconSize = size;
  [self makeIconsGrid];
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setIconSize: iconSize];
  }
  
  [self tile];
  [self setNeedsDisplay: YES];
}

- (int)labelTextSize
{
  return labelTextSize;
}

- (void)setLabelTextSize:(int)size
{
  int i;

  labelTextSize = size;
  [self makeIconsGrid];

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setFont: [FSNIcon labelFont]];
  }

  [nameEditor setFont: [FSNIcon labelFont]];

  [self tile];
  [self setNeedsDisplay: YES];
}

- (int)iconPosition
{
  return iconPosition;
}

- (void)setIconPosition:(int)pos
{
  int i;
  
  iconPosition = pos;
  [self makeIconsGrid];
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setIconPosition: iconPosition];
  }
    
  [self tile];
  [self setNeedsDisplay: YES];
}

- (NSImage *)tshelfBackground
{
  NSSize size = NSMakeSize([self frame].size.width, 112);
  NSImage *image = [[NSImage alloc] initWithSize: size];
  NSCachedImageRep *rep = [[NSCachedImageRep alloc] initWithSize: size
                                    depth: [NSWindow defaultDepthLimit] 
                                                separate: YES alpha: YES];

  [image addRepresentation: rep];
  RELEASE (rep);

  [image lockFocus];  
  NSCopyBits([[self window] gState], 
            NSMakeRect(0, 0, size.width, size.height),
			                              NSMakePoint(0.0, 0.0));
  [image unlockFocus];
 
  return AUTORELEASE(image);
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  NSMutableDictionary *colorDict = [NSMutableDictionary dictionary];
  float red, green, blue, alpha;
	
  [backColor getRed: &red green: &green blue: &blue alpha: &alpha];
  [colorDict setObject: [NSString stringWithFormat: @"%.2f", red] forKey: @"red"];
  [colorDict setObject: [NSString stringWithFormat: @"%.2f", green] forKey: @"green"];
  [colorDict setObject: [NSString stringWithFormat: @"%.2f", blue] forKey: @"blue"];
  [colorDict setObject: [NSString stringWithFormat: @"%.2f", alpha] forKey: @"alpha"];

  [defaults setObject: colorDict forKey: @"backcolor"];

  [defaults setBool: useBackImage forKey: @"usebackimage"];

  [defaults setObject: [NSNumber numberWithInt: backImageStyle] 
               forKey: @"imagestyle"];

  if (backImage) {
    [defaults setObject: imagePath forKey: @"imagepath"];
  }

  [defaults setObject: [NSNumber numberWithInt: iconSize] 
               forKey: @"iconsize"];
               
  [defaults setObject: [NSNumber numberWithInt: labelTextSize] 
               forKey: @"labeltxtsize"];
               
  [defaults setObject: [NSNumber numberWithInt: iconPosition] 
               forKey: @"iconposition"];

  [defaults synchronize];
  
  [self updateNodeInfo];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSWindow *win = [self window];
  GSDisplayServer *srv = GSServerForWindow(win);
  
  [srv setinputstate: GSTitleBarKey : [win windowNumber]];
//  [srv setinputstate: GSTitleBarMain : [win windowNumber]];
  [srv setinputfocus: [win windowNumber]];

  [NSApp setWindowsNeedUpdate: YES];
  
  if ([theEvent modifierFlags] != NSShiftKeyMask) {
    selectionMask = NSSingleSelectionMask;
    selectionMask |= FSNCreatingSelectionMask;
		[self unselectOtherReps: nil];
    selectionMask = NSSingleSelectionMask;
    
    DESTROY (lastSelection);
    [self selectionDidChange];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
  unsigned int eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;
  NSPoint	locp;
  NSPoint	startp;
  NSRect oldRect; 
  NSRect r;
  float x, y, w, h;
  int i;

  locp = [theEvent locationInWindow];
  locp = [self convertPoint: locp fromView: nil];
  startp = locp;

  oldRect = NSZeroRect;  

	[[self window] disableFlushWindow];
  [self lockFocus];

  while ([theEvent type] != NSLeftMouseUp) {
    CREATE_AUTORELEASE_POOL (arp);

    theEvent = [[self window] nextEventMatchingMask: eventMask];

    locp = [theEvent locationInWindow];
    locp = [self convertPoint: locp fromView: nil];
    
    x = (locp.x >= startp.x) ? startp.x : locp.x;
    y = (locp.y >= startp.y) ? startp.y : locp.y;
    w = max(locp.x, startp.x) - min(locp.x, startp.x);
    w = (w == 0) ? 1 : w;
    h = max(locp.y, startp.y) - min(locp.y, startp.y);
    h = (h == 0) ? 1 : h;

    r = NSMakeRect(x, y, w, h);
    
    if (NSEqualRects(oldRect, NSZeroRect) == NO) {
		  [verticalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		                         fromRect: NSMakeRect(0.0, 0.0, 1.0, oldRect.size.height)
		                        operation: NSCompositeCopy];

		  [verticalImage compositeToPoint: NSMakePoint(NSMaxX(oldRect)-1, NSMinY(oldRect))
		                         fromRect: NSMakeRect(1.0, 0.0, 1.0, oldRect.size.height)
		                        operation: NSCompositeCopy];

		  [horizontalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		                           fromRect: NSMakeRect(0.0, 0.0, oldRect.size.width, 1.0)
		                          operation: NSCompositeCopy];

      [horizontalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMaxY(oldRect)-1)
		                           fromRect: NSMakeRect(0.0, 1.0, oldRect.size.width, 1.0)
		                          operation: NSCompositeCopy];
    }
    [self displayIfNeeded];

    [verticalImage lockFocus];
    NSCopyBits([[self window] gState], 
            NSMakeRect(NSMinX(r), NSMinY(r), 
                          1.0, r.size.height),
			                          NSMakePoint(0.0, 0.0));
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMaxX(r) -1, NSMinY(r),
				                  1.0, r.size.height),
			                          NSMakePoint(1.0, 0.0));
    [verticalImage unlockFocus];

    [horizontalImage lockFocus];
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMinX(r), NSMinY(r),
				                  r.size.width, 1.0),
			                          NSMakePoint(0.0, 0.0));
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMinX(r), NSMaxY(r) -1,
				                  r.size.width, 1.0),
			                          NSMakePoint(0.0, 1.0));
    [horizontalImage unlockFocus];

    [[NSColor darkGrayColor] set];
    NSFrameRect(r);
    oldRect = r;

    [[self window] enableFlushWindow];
    [[self window] flushWindow];
    [[self window] disableFlushWindow];

    DESTROY (arp);
  }

  [[self window] postEvent: theEvent atStart: NO];
  
  if (NSEqualRects(oldRect, NSZeroRect) == NO) {
		[verticalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		                       fromRect: NSMakeRect(0.0, 0.0, 1.0, oldRect.size.height)
		                      operation: NSCompositeCopy];

		[verticalImage compositeToPoint: NSMakePoint(NSMaxX(oldRect)-1, NSMinY(oldRect))
		                       fromRect: NSMakeRect(1.0, 0.0, 1.0, oldRect.size.height)
		                      operation: NSCompositeCopy];

		[horizontalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		                         fromRect: NSMakeRect(0.0, 0.0, oldRect.size.width, 1.0)
		                        operation: NSCompositeCopy];

    [horizontalImage compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMaxY(oldRect)-1)
		                         fromRect: NSMakeRect(0.0, 1.0, oldRect.size.width, 1.0)
		                        operation: NSCompositeCopy];
  }
  
  [[self window] enableFlushWindow];
  [[self window] flushWindow];
  [self unlockFocus];

  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  x = (locp.x >= startp.x) ? startp.x : locp.x;
  y = (locp.y >= startp.y) ? startp.y : locp.y;
  w = max(locp.x, startp.x) - min(locp.x, startp.x);
  w = (w == 0) ? 1 : w;
  h = max(locp.y, startp.y) - min(locp.y, startp.y);
  h = (h == 0) ? 1 : h;

  r = NSMakeRect(x, y, w, h);

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
      
    if (NSIntersectsRect(r, [icon frame])) {
      [icon select];
    } 
  }  

  selectionMask = NSSingleSelectionMask;
  
  [self selectionDidChange];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  NSArray *selnodes;
  NSMenu *menu;
  NSMenuItem *menuItem;
  NSString *firstext; 
  NSDictionary *apps;
  NSEnumerator *app_enum;
  id key; 
  int i;

  if ([theEvent modifierFlags] == NSControlKeyMask) {
    return [super menuForEvent: theEvent];
  } 

  selnodes = [self selectedNodes];

  if ([selnodes count]) {
    firstext = [[[selnodes objectAtIndex: 0] path] pathExtension];

    for (i = 0; i < [selnodes count]; i++) {
      FSNode *snode = [selnodes objectAtIndex: i];
      NSString *selpath = [snode path];
      NSString *ext = [selpath pathExtension];   

      if ([ext isEqual: firstext] == NO) {
        return [super menuForEvent: theEvent];  
      }

      if ([snode isDirectory] == NO) {
        if ([snode isPlain] == NO) {
          return [super menuForEvent: theEvent];
        }
      } else {
        if (([snode isPackage] == NO) || [snode isApplication]) {
          return [super menuForEvent: theEvent];
        } 
      }
    }
    
    menu = [[NSMenu alloc] initWithTitle: NSLocalizedString(@"Open with", @"")];
    apps = [[NSWorkspace sharedWorkspace] infoForExtension: firstext];
    app_enum = [[apps allKeys] objectEnumerator];

    while ((key = [app_enum nextObject])) {
      NSDictionary *dict = [apps objectForKey: key];
      NSString *role = [dict objectForKey: @"NSRole"];

      menuItem = [NSMenuItem new];    

      if (role) {
        [menuItem setTitle: [NSString stringWithFormat: @"%@ - %@", key, role]];
      } else {
        [menuItem setTitle: [NSString stringWithFormat: @"%@", key]];
      }

      [menuItem setTarget: desktop];      
      [menuItem setAction: @selector(openSelectionWithApp:)];      
      [menuItem setRepresentedObject: key];            
      [menu addItem: menuItem];
      RELEASE (menuItem);
    }

    menuItem = [NSMenuItem new]; 
    [menuItem setTitle:  NSLocalizedString(@"Open with...", @"")];
    [menuItem setTarget: desktop];      
    [menuItem setAction: @selector(openSelectionWith:)];          
    [menu addItem: menuItem];
    RELEASE (menuItem);

    return [menu autorelease];
  }
   
  return [super menuForEvent: theEvent]; 
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
	[self tile];
}

- (void)viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];
  [[self window] setBackgroundColor: backColor];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];
  [backColor set];
  NSRectFill(rect);
    
  if (backImage && useBackImage) {
    [backImage compositeToPoint: imagePoint 
                      operation: NSCompositeSourceOver];  
  }

	if (dragIcon) {
		[dragIcon dissolveToPoint: dragPoint fraction: 0.3];
	}
}


//
// FSNodeRepContainer protocol
//
- (void)showContentsOfNode:(FSNode *)anode
{
  NSArray *subNodes = [anode subNodes];
  NSMutableArray *unsorted = [NSMutableArray array];
  int count = [icons count];
  NSDictionary *indexes;
  int i;

  for (i = 0; i < count; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
  
    if ([[icon node] isMountPoint] == NO) {
      [icon removeFromSuperview];
      [icons removeObject: icon]; 
      count--;
      i--;
    }
  }
   
  if (node) {
    [desktop removeWatcherForPath: [node path]];
  }
  
  ASSIGN (node, anode);
  [desktop addWatcherForPath: [node path]];
  [self readNodeInfo];
    
  for (i = 0; i < [subNodes count]; i++) {
    FSNode *subnode = [subNodes objectAtIndex: i];
    FSNIcon *icon = [[FSNIcon alloc] initForNode: subnode
                                        iconSize: iconSize
                                    iconPosition: iconPosition
                                       gridIndex: -1
                                       dndSource: YES
                                       acceptDnd: YES];
    [unsorted addObject: icon];
    RELEASE (icon);
  }

  indexes = [nodeInfo objectForKey: @"indexes"];

  if (indexes) {
    for (i = 0; i < [unsorted count]; i++) {
      FSNIcon *icon = [unsorted objectAtIndex: i];
      NSString *name = [[icon node] name];
      NSNumber *indnum = [indexes objectForKey: name];

      if (indnum) {
        int index = [indnum intValue];
        
        if (index >= gridcount) {
          index = [self firstFreeGridIndex];
        }
        
        if (index != -1) {
          [icon setGridIndex: index];
          [icons addObject: icon];
          [self addSubview: icon];
        }
      }
    }
  }
    
  for (i = 0; i < [unsorted count]; i++) {
    FSNIcon *icon = [unsorted objectAtIndex: i];
    int index = [icon gridIndex];
  
    if (index == -1) {
      index = [self firstFreeGridIndex];
          
      if (index != -1) {
        [icon setGridIndex: index];
        [icons addObject: icon];
        [self addSubview: icon];
      }
    }
  }
  
  [self tile];
}

- (FSNode *)shownNode
{
  return node;
}

- (void)setShowType:(FSNInfoType)type
{
  if (infoType != type) {
    int i;
    
    infoType = type;

    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];
      
      [icon setNodeInfoShowType: infoType];
      [icon tile];
    }
    
    [self updateNameEditor];
    [self tile];
  }
}

- (FSNInfoType)showType
{
  return infoType;
}

- (id)repOfSubnode:(FSNode *)anode
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
  
    if ([[icon node] isEqualToNode: anode]) {
      return icon;
    }
  }
  
  return nil;
}

- (id)repOfSubnodePath:(NSString *)apath
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
  
    if ([[[icon node] path] isEqual: apath]) {
      return icon;
    }
  }
  
  return nil;
}

- (id)addRepForSubnode:(FSNode *)anode
{
  FSNIcon *icon = [[FSNIcon alloc] initForNode: anode
                                      iconSize: iconSize
                                  iconPosition: iconPosition
                                     gridIndex: [self firstFreeGridIndex]
                                     dndSource: YES
                                     acceptDnd: YES];
  [icons addObject: icon];
  [self addSubview: icon];
  RELEASE (icon);
  
  return icon;
}

- (id)addRepForSubnodePath:(NSString *)apath
{
  FSNode *subnode = [FSNode nodeWithRelativePath: apath parent: node];
  return [self addRepForSubnode: subnode];
}

- (void)removeRepOfSubnode:(FSNode *)anode
{
  FSNIcon *icon = [self repOfSubnode: anode];

  if (icon) {
    [self removeRep: icon];
  } 
}

- (void)removeRepOfSubnodePath:(NSString *)apath
{
  FSNIcon *icon = [self repOfSubnodePath: apath];

  if (icon) {
    [self removeRep: icon];
  }
}

- (void)removeRep:(id)arep
{
  if (arep == editIcon) {
    editIcon = nil;
  }
  [arep removeFromSuperview];
  [icons removeObject: arep];
}

- (void)unselectOtherReps:(id)arep
{
  int i;

  if (selectionMask & FSNMultipleSelectionMask) {
    return;
  }
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if (icon != arep) {
      [icon unselect];
    }
  }
}

- (void)selectRepsOfSubnodes:(NSArray *)nodes
{
  int i;
  
  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	[self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
      
    if ([nodes containsObject: [icon node]]) {  
      [icon select];
    } 
  }  

  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (void)selectRepsOfPaths:(NSArray *)paths
{
  int i;
  
  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	[self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
      
    if ([paths containsObject: [[icon node] path]]) {  
      [icon select];
    } 
  }  

  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (void)selectAll
{
	int i;

  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	[self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
	for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] select];
	}
  
  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (NSArray *)selectedReps
{
  NSMutableArray *selectedReps = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedReps addObject: icon];
    }
  }

  return selectedReps;
}

- (NSArray *)selectedNodes
{
  NSMutableArray *selectedNodes = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedNodes addObject: [icon node]];
    }
  }

  return selectedNodes;
}

- (NSArray *)selectedPaths
{
  NSMutableArray *selectedPaths = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedPaths addObject: [[icon node] path]];
    }
  }

  return selectedPaths;
}

- (void)selectionDidChange
{
	if (!(selectionMask & FSNCreatingSelectionMask)) {
    NSArray *selection = [self selectedPaths];
		
    if ([selection count] == 0) {
      selection = [NSArray arrayWithObject: [node path]];
    }

    if ((lastSelection == nil) || ([selection isEqual: lastSelection] == NO)) {
      ASSIGN (lastSelection, selection);
      [desktop selectionChanged: selection];
    }
    
    [self updateNameEditor];
	}
}

- (void)checkLockedReps
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] checkLocked];
  }
}

- (void)setSelectionMask:(FSNSelectionMask)mask
{
  selectionMask = mask;  
}

- (FSNSelectionMask)selectionMask
{
  return selectionMask;
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [desktop openSelectionInNewViewer: newv];
}

- (void)restoreLastSelection
{
  if (lastSelection) {
    [self selectRepsOfPaths: lastSelection];
  }
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted
{
  NSMutableArray *sourcePaths = [names mutableCopy];
  NSString *basePath;
  NSString *nodePath = [node path];
  NSString *prePath = [NSString stringWithString: nodePath];
	int count = [names count];
  int i;
  
  AUTORELEASE (sourcePaths);

	if (count == 0) {
		return NO;
  } 

  if ([node isWritable] == NO) {
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
    FSNIcon *icon = [self repOfSubnodePath: srcpath];
    
    if (icon && [[icon node] isMountPoint]) {
      [sourcePaths removeObject: srcpath];
      count--;
      i--;
    }
  }    
  
  if ([sourcePaths count] == 0) {
    return NO;
  }

  return YES;
}
                       
- (NSColor *)backgroundColor
{
  return backColor;
}

@end


@implementation DesktopView (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
  NSString *nodePath;
  NSString *prePath;
	int count;
  int i;
  
	isDragTarget = NO;	
    
 	pb = [sender draggingPasteboard];

  if (pb && [[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 
    NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
    sourcePaths = [pbDict objectForKey: @"paths"];
  } else {
    return NSDragOperationNone;
  }

	count = [sourcePaths count];
	if (count == 0) {
		return NSDragOperationNone;
  } 
    
  dragLocalIcon = YES;    
    
  for (i = 0; i < [sourcePaths count]; i++) {
    NSString *srcpath = [sourcePaths objectAtIndex: i];
  
    if ([self repOfSubnodePath: srcpath] == nil) {
      dragLocalIcon = NO;
    }
  }    
    
  if (dragLocalIcon) {  
    isDragTarget = YES;	
    dragPoint = NSZeroPoint;
    DESTROY (dragIcon);
    insertIndex = -1;
    return NSDragOperationAll;
  }

  if ([node isWritable] == NO) {
    return NSDragOperationNone;
  }
    
  nodePath = [node path];

  if ([sourcePaths containsObject: nodePath]) {
    return NSDragOperationNone;
  }

  prePath = [NSString stringWithString: nodePath];

  while (1) {
    if ([sourcePaths containsObject: prePath]) {
      return NSDragOperationNone;
    }
    if ([prePath isEqual: path_separator()]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  isDragTarget = YES;	
  dragPoint = NSZeroPoint;
  DESTROY (dragIcon);
  insertIndex = -1;
    
	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}		

  isDragTarget = NO;	
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
  dpoint = [sender draggingLocation];
  index = [self indexOfGridRectContainingPoint: dpoint];
  
  if ((index != -1) && ([self isFreeGridIndex: index])) {
    NSImage *img = [sender draggedImage];
    NSSize sz = [img size];
    NSRect irect = [self iconBoundsInGridAtIndex: index];
     
    dragPoint.x = ceil(irect.origin.x + ((irect.size.width - sz.width) / 2));
    dragPoint.y = ceil(irect.origin.y + ((irect.size.height - sz.height) / 2));
    
    if (dragIcon == nil) {
      NSImageRep *rep = [img bestRepresentationForDevice: nil];
    
      if ([rep isKindOfClass: [NSBitmapImageRep class]]) {
        NSData *data = [(NSBitmapImageRep *)rep TIFFRepresentation];
      
        dragIcon = [[NSImage alloc] initWithData: data];
      }
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

int sortDragged(id icn1, id icn2, void *context)
{
  NSArray *indexes = (NSArray *)context;
  int pos1 = [icn1 gridIndex];
  int pos2 = [icn2 gridIndex];
  int i;

  for (i = 0; i < [indexes count]; i++) {
    NSNumber *n = [indexes objectAtIndex: i];
    
    if ([n intValue] == pos1) {
      return NSOrderedAscending;
    } else if ([n intValue] == pos2) {
      return NSOrderedDescending;
    }
  }

  return NSOrderedSame;
} 

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSMutableArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
	NSString *trashPath;
  int count;
  int i;

  DESTROY (dragIcon);
  if ((insertIndex != -1) && ([self isFreeGridIndex: insertIndex])) {
    [self setNeedsDisplayInRect: grid[insertIndex]];
  }
	isDragTarget = NO;  

	sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];
    
  if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {  
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 

    [desktop concludeRemoteFilesDragOperation: pbData
                                  atLocalPath: [node path]];
    return;
  }
    
  sourcePaths = [[pb propertyListForType: NSFilenamesPboardType] mutableCopy];
  AUTORELEASE (sourcePaths);
  
  if (dragLocalIcon && (insertIndex != -1)) {
    NSMutableArray *removed = [NSMutableArray array];
    NSArray *sorted = nil;
    NSMutableArray *sortIndexes = [NSMutableArray array];
    int firstinrow = gridcount - rowcount;
    int row = 0;

    for (i = 0; i < [sourcePaths count]; i++) {
      NSString *locPath = [sourcePaths objectAtIndex: i];
      FSNIcon *icon = [self repOfSubnodePath: locPath];
      
      if (icon) {
        [removed addObject: icon];
        [icons removeObject: icon];
      }
    }

    while (firstinrow < gridcount) {
      for (i = firstinrow; i >= row; i -= rowcount) {
        [sortIndexes insertObject: [NSNumber numberWithInt: i]
                          atIndex: [sortIndexes count]];
      }
      row++;
      firstinrow++;
    }

    sorted = [removed sortedArrayUsingFunction: (int (*)(id, id, void *))sortDragged 
                                       context: (void *)sortIndexes];

    for (i = 0; i < [sorted count]; i++) {
      FSNIcon *icon = [sorted objectAtIndex: i];
      int oldindex = [icon gridIndex];
      int index;
      int shift;
    
      if (i == 0) {
        index = insertIndex;
        shift = oldindex - index;

      } else {
        index = oldindex - shift;

        if ((index < 0) || (index >= gridcount)) {
          index = [self firstFreeGridIndexAfterIndex: insertIndex];
        }

        if (index == -1) {
          index = [self firstFreeGridIndex];
        }

        if ([self isFreeGridIndex: index] == NO) {
          index = [self firstFreeGridIndexAfterIndex: index];
        }

        if (index == -1) {
          index = [self firstFreeGridIndex];
        }
      }
      
      [icons addObject: icon];

      [icon setGridIndex: index];
      [icon setFrame: grid[index]];

      [self setNeedsDisplayInRect: grid[oldindex]];
      [self setNeedsDisplayInRect: grid[index]];
    }
    
    [self updateNameEditor];
    
    return;
  }

  count = [sourcePaths count];

  for (i = 0; i < count; i++) {
    NSString *srcpath = [sourcePaths objectAtIndex: i];
    FSNIcon *icon = [self repOfSubnodePath: srcpath];
    
    if (icon && [[icon node] isMountPoint]) {
      [sourcePaths removeObject: srcpath];
      count--;
      i--;
    }
  }    
  
  if ([sourcePaths count] == 0) {
    return;
  }
  
  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  
  trashPath = [desktop trashPath];

  if ([source isEqual: trashPath]) {
    operation = @"GWorkspaceRecycleOutOperation";
	} else {	
		if (sourceDragMask == NSDragOperationCopy) {
			operation = NSWorkspaceCopyOperation;
		} else if (sourceDragMask == NSDragOperationLink) {
			operation = NSWorkspaceLinkOperation;
		} else {
			operation = NSWorkspaceMoveOperation;
		}
  }

  files = [NSMutableArray array];    
  for(i = 0; i < [sourcePaths count]; i++) {    
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  }  

	opDict = [NSMutableDictionary dictionary];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: [node path] forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [desktop performFileOperation: opDict];
}

@end


@implementation DesktopView (IconNameEditing)

- (void)updateNameEditor
{
  NSArray *selection = [self selectedNodes];
  NSRect edrect;

  if ([[self subviews] containsObject: nameEditor]) {
    edrect = [nameEditor frame];
    [nameEditor abortEditing];
    [nameEditor setNode: nil stringValue: @"" index: -1];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: edrect];
  }

  if (editIcon) {
    [editIcon setNameEdited: NO];
  }

  editIcon = nil;
  
  if ([selection count] == 1) {
    editIcon = [self repOfSubnode: [selection objectAtIndex: 0]]; 
  } 
  
  if (editIcon) {
    FSNode *iconnode = [editIcon node];
    NSString *nodeDescr = nil;
    BOOL locked = [editIcon isLocked];
    BOOL mpoint = [iconnode isMountPoint];
    NSRect icnr = [editIcon frame];
    NSRect labr = [editIcon labelRect];
    int ipos = [editIcon iconPosition];
    int margin = [FSNodeRep labelMargin];
    float bw = [self bounds].size.width - EDIT_MARGIN;
    float edwidth = 0.0; 
    
    [editIcon setNameEdited: YES];
 
    switch(infoType) {
      case FSNInfoNameType:
        nodeDescr = [iconnode name];
        break;
      case FSNInfoKindType:
        nodeDescr = [iconnode typeDescription];
        break;
      case FSNInfoDateType:
        nodeDescr = [iconnode modDateDescription];
        break;
      case FSNInfoSizeType:
        nodeDescr = [iconnode sizeDescription];
        break;
      case FSNInfoOwnerType:
        nodeDescr = [iconnode owner];
        break;
      default:
        nodeDescr = [iconnode name];
        break;
    }
 
    edwidth = [[FSNIcon labelFont] widthOfString: nodeDescr];
    edwidth += margin;
    
    if (ipos == NSImageAbove) {
      float centerx = icnr.origin.x + (icnr.size.width / 2);

      if ((centerx + (edwidth / 2)) >= bw) {
        centerx -= (centerx + (edwidth / 2) - bw);
      } else if ((centerx - (edwidth / 2)) < margin) {
        centerx += fabs(centerx - (edwidth / 2)) + margin;
      }    
 
      edrect = [self convertRect: labr fromView: editIcon];
      edrect.origin.x = centerx - (edwidth / 2);
      edrect.size.width = edwidth;
      
    } else if (ipos == NSImageLeft) {
      edrect = [self convertRect: labr fromView: editIcon];
      edrect.size.width = edwidth;
    
      if ((edrect.origin.x + edwidth) >= bw) {
        edrect.size.width = bw - edrect.origin.x;
      }    
    }
    
    edrect = NSIntegralRect(edrect);
    
    [nameEditor setFrame: edrect];
    
    if (ipos == NSImageAbove) {
		  [nameEditor setAlignment: NSCenterTextAlignment];
    } else if (ipos == NSImageLeft) {
		  [nameEditor setAlignment: NSLeftTextAlignment];
    }
        
    [nameEditor setNode: iconnode 
            stringValue: nodeDescr
                  index: 0];

    [nameEditor setBackgroundColor: [NSColor selectedControlColor]];
    
    if (locked == NO) {
      [nameEditor setTextColor: [NSColor controlTextColor]];    
    } else {
      [nameEditor setTextColor: [NSColor disabledControlTextColor]];    
    }

    [nameEditor setEditable: ((locked == NO) && (mpoint == NO) && (infoType == FSNInfoNameType))];
    [nameEditor setSelectable: ((locked == NO) && (mpoint == NO) && (infoType == FSNInfoNameType))];	
    [self addSubview: nameEditor];
  }
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSRect icnr = [editIcon frame];
  int ipos = [editIcon iconPosition];
  float edwidth = [[FSNIcon labelFont] widthOfString: [nameEditor stringValue]]; 
  int margin = [FSNodeRep labelMargin];
  float bw = [self bounds].size.width - EDIT_MARGIN;
  NSRect edrect = [nameEditor frame];
  
  edwidth += margin;

  if (ipos == NSImageAbove) {
    float centerx = icnr.origin.x + (icnr.size.width / 2);

    while ((centerx + (edwidth / 2)) > bw) {
      centerx --;  
      if (centerx < EDIT_MARGIN) {
        break;
      }
    }

    while ((centerx - (edwidth / 2)) < EDIT_MARGIN) {
      centerx ++;  
      if (centerx >= bw) {
        break;
      }
    }
        
    edrect.origin.x = centerx - (edwidth / 2);
    edrect.size.width = edwidth;
    
  } else if (ipos == NSImageLeft) {
    edrect.size.width = edwidth;

    if ((edrect.origin.x + edwidth) >= bw) {
      edrect.size.width = bw - edrect.origin.x;
    }    
  }
  
  [self setNeedsDisplayInRect: [nameEditor frame]];
  [nameEditor setFrame: NSIntegralRect(edrect)];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  FSNode *ednode = [nameEditor node];

#define CLEAREDITING \
	[self updateNameEditor]; \
  return
 
  if ([ednode isWritable] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission for ", @""), 
                    [ednode name]], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else if ([[ednode parent] isWritable] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission for ", @""), 
                  [[ednode parent] name]], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else {
    NSString *newname = [nameEditor stringValue];
    NSString *newpath = [[ednode parentPath] stringByAppendingPathComponent: newname];
    NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*$|~\'\"`^!?"];
    NSRange range = [newname rangeOfCharacterFromSet: notAllowSet];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirContents = [fm directoryContentsAtPath: [ednode parentPath]];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    
    if (range.length > 0) {
      NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
                NSLocalizedString(@"Invalid char in name", @""), 
                          NSLocalizedString(@"Continue", @""), nil, nil);   
      CLEAREDITING;
    }	

    if ([dirContents containsObject: newname]) {
      if ([newname isEqual: [ednode name]]) {
        CLEAREDITING;
      } else {
        NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\" %@ ", 
              NSLocalizedString(@"The name ", @""), 
              newname, NSLocalizedString(@" is already in use!", @"")], 
                            NSLocalizedString(@"Continue", @""), nil, nil);   
        CLEAREDITING;
      }
    }

	  [userInfo setObject: @"GWorkspaceRenameOperation" forKey: @"operation"];	
    [userInfo setObject: [ednode path] forKey: @"source"];	
    [userInfo setObject: newpath forKey: @"destination"];	
    [userInfo setObject: [NSArray arrayWithObject: @""] forKey: @"files"];	
    
    [desktop removeWatcherForPath: [node path]];
  
    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemWillChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];

    [fm movePath: [ednode path] toPath: newpath handler: self];

    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemDidChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];
    
    [desktop addWatcherForPath: [node path]];
  }
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSString *title = NSLocalizedString(@"Error", @"");
	NSString *msg1 = NSLocalizedString(@"Cannot rename ", @"");
  NSString *name = [[nameEditor node] name];
	NSString *msg2 = NSLocalizedString(@"Continue", @"");

  NSRunAlertPanel(title, [NSString stringWithFormat: @"%@'%@'!", msg1, name], msg2, nil, nil);   

	return NO;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

@end


@implementation DesktopView (BackgroundColors)

- (NSColor *)currentColor
{
  return backColor;
}

- (void)setCurrentColor:(NSColor *)color
{
  ASSIGN (backColor, color);
  [[self window] setBackgroundColor: backColor];
  [self setNeedsDisplay: YES];
  [[desktop dock] setBackColor: backColor];
}

- (void)createBackImage:(NSImage *)image
{
  NSSize imsize = [image size];
  
  if ((imsize.width >= screenFrame.size.width)
                      || (imsize.height >= screenFrame.size.height)) {
    if (backImageStyle == BackImageTileStyle) {  
      backImageStyle = BackImageCenterStyle;
    }
  }
  
  if (backImageStyle == BackImageFitStyle) {
    CREATE_AUTORELEASE_POOL (pool);
    NSImage *newImage = [[NSImage alloc] initWithSize: screenFrame.size];
  
	  [image setScalesWhenResized: YES];
	  [image setSize: screenFrame.size];
    imagePoint = NSZeroPoint;
    [newImage lockFocus];
	  [image compositeToPoint: imagePoint operation: NSCompositeCopy];    
    [newImage unlockFocus];
    ASSIGN (backImage, newImage);
    RELEASE (newImage);
    RELEASE (pool);
    
  } else if (backImageStyle == BackImageTileStyle) {
	  CREATE_AUTORELEASE_POOL (pool);
    NSImage *newImage = [[NSImage alloc] initWithSize: screenFrame.size];
    float x = 0;
    float y = screenFrame.size.width - imsize.width;

    [newImage lockFocus];

    while (y > (0 - imsize.height)) {
      [image compositeToPoint: NSMakePoint(x, y) 
                    operation: NSCompositeCopy];
      x += imsize.width;
      if (x >= screenFrame.size.width) {
        y -= imsize.height;
        x = 0;
      }
    }

    [newImage unlockFocus];
    
    imagePoint = NSZeroPoint;
    ASSIGN (backImage, newImage);
    RELEASE (newImage);
    RELEASE (pool);
    
  } else {
    imagePoint.x = ((screenFrame.size.width - imsize.width) / 2);
    imagePoint.y = ((screenFrame.size.height - imsize.height) / 2);
    ASSIGN (backImage, image);
  }
  
  [[desktop dock] setBackImage];
}

- (NSImage *)backImage
{
  return backImage;
}

- (NSString *)backImagePath
{
  return imagePath;
}

- (void)setBackImageAtPath:(NSString *)impath
{
  CREATE_AUTORELEASE_POOL (pool);
  NSImage *image = [[NSImage alloc] initWithContentsOfFile: impath];

  if (image) {
    ASSIGN (imagePath, impath);
    [self createBackImage: image];
    RELEASE (image);
    [self setNeedsDisplay: YES];
  }
  RELEASE (pool);
}

- (BOOL)useBackImage
{
  return useBackImage;
}

- (void)setUseBackImage:(BOOL)value
{
  useBackImage = value;
  [self setNeedsDisplay: YES];
  [[desktop dock] setUseBackImage: useBackImage];  
}

- (BackImageStyle)backImageStyle
{
  return backImageStyle;
}

- (void)setBackImageStyle:(BackImageStyle)style
{
  if (style != backImageStyle) {
    backImageStyle = style;
    if (backImage) {
      [self setBackImageAtPath: imagePath];
      [self setNeedsDisplay: YES];
    }
  }
}

@end

