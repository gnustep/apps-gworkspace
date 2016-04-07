/* GWDesktopView.m
 *  
 * Copyright (C) 2005-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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
#import <GNUstepGUI/GSVersion.h>
#import "FSNodeRep.h"
#import "FSNFunctions.h"
#import "GWDesktopView.h"
#import "GWDesktopIcon.h"
#import "GWDesktopManager.h"
#import "Dock.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

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


@implementation GWDesktopView

- (void)dealloc
{
	if (grid != NULL) {
		NSZoneFree (NSDefaultMallocZone(), grid);
	}
  RELEASE (mountedVolumes);
  RELEASE (desktopInfo);
  RELEASE (backImage);
  RELEASE (imagePath);
  RELEASE (dragIcon);

  [super dealloc];
}

- (id)initForManager:(id)mngr
{
  self = [super init];
    
  if (self) {
    NSSize size;
    NSCachedImageRep *rep;

    manager = mngr;

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
    
    ASSIGN (backColor, DEF_COLOR);

    backImageStyle = BackImageCenterStyle;
    mountedVolumes = [NSMutableArray new];
    [self getDesktopInfo];
    [self makeIconsGrid];
    dragIcon = nil;
  }
   
  return self;
}

- (void)newVolumeMountedAtPath:(NSString *)vpath
{
  FSNode *vnode = [FSNode nodeWithPath: vpath];

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

- (void)unlockVolumeAtPath:(NSString *)path
{
  [self checkLockedReps];
}

- (void)showMountedVolumes
{
  NSArray *rvpaths = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];

  if ([mountedVolumes isEqual: rvpaths] == NO) {
    int count = [icons count];
    int i;
        
    [mountedVolumes removeAllObjects];
    [mountedVolumes addObjectsFromArray: rvpaths];

    for (i = 0; i < count; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];

      if ([[icon node] isMountPoint]) {
        [self removeRep: icon];
        count--;
        i--;
      }
    }

    for (i = 0; i < [mountedVolumes count]; i++) {
      NSString *vpath = [mountedVolumes objectAtIndex: i];

      if ([vpath isEqual: path_separator()] == NO) {
        FSNode *vnode = [FSNode nodeWithPath: vpath];

        [vnode setMountPoint: YES];
        [self addRepForSubnode: vnode];
      }
    }

    [self tile];  
  }
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
  
    if (index < gridcount) {
      if (NSEqualRects(grid[index], [icon frame]) == NO) {
        [icon setFrame: grid[index]];
      }
    } else {
      int freeindex = [self firstFreeGridIndex];
      [icon setGridIndex: freeindex];
      [icon setFrame: grid[freeindex]];
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

- (FSNIcon *)iconWithGridIndex:(int)index
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

- (NSArray *)iconsWithGridOriginX:(float)x
{
  NSMutableArray *icns = [NSMutableArray array];
  int i;
  
	for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSPoint p = [icon frame].origin;
    
		if (p.x == x) {
      [icns addObject: icon];
		}
  }
  
  if ([icns count]) {
    return icns;
  }
  
  return nil;
}

- (NSArray *)iconsWithGridOriginY:(float)y
{
  NSMutableArray *icns = [NSMutableArray array];
  int i;
  
	for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSPoint p = [icon frame].origin;
    
		if (p.y == y) {
      [icns addObject: icon];
		}
  }

  if ([icns count]) {
    return icns;
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
  if ((hlightRect.size.height - iconSize) < 2) {
    hlightRect.size.height = iconSize + 2;
  }

  if (iconPosition == NSImageAbove) {  
    hlightRect.origin.x = ceil((gridSize.width - hlightRect.size.width) / 2);   
    if (infoType != FSNInfoNameType) {
      hlightRect.origin.y = floor([fsnodeRep heightOfFont: labelFont] * 2 - 2);
    } else { 
      hlightRect.origin.y = floor([fsnodeRep heightOfFont: labelFont]);
    }
  } else {
    hlightRect.origin.x = 0;
    hlightRect.origin.y = 0;
  }
  
  icnBounds.origin.x += hlightRect.origin.x + ((hlightRect.size.width - iconSize) / 2);
  icnBounds.origin.y += hlightRect.origin.y + ((hlightRect.size.height - iconSize) / 2);

  return NSIntegralRect(icnBounds);
}

- (void)makeIconsGrid
{
  NSRect dckr = [manager dockReservedFrame];
  NSRect tshfr = [manager tshelfReservedFrame];
  NSRect mmfr = [manager macmenuReservedFrame];
  NSRect gridrect = screenFrame;
  int ymargin;
  NSPoint gpnt;
  int i;
  
	if (grid != NULL) {
		NSZoneFree (NSDefaultMallocZone(), grid);
	}
  
  [self calculateGridSize];
  
  gridrect.origin.y += tshfr.size.height;
  gridrect.size.height -= tshfr.size.height;
  gridrect.size.width -= dckr.size.width;
  
  gridrect.size.height -= mmfr.size.height;
  
  if ([manager dockPosition] == DockPositionLeft) {
    gridrect.origin.x += dckr.size.width;
  }
  
  if (infoType != FSNInfoNameType) {
    ymargin = 2;
  } else {
    ymargin = Y_MARGIN;
  }
  
  colcount = (int)(gridrect.size.width / (gridSize.width + X_MARGIN));  
  rowcount = (int)(gridrect.size.height / (gridSize.height + ymargin));
	gridcount = colcount * rowcount;

	grid = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * gridcount);	
    
  gpnt.x = gridrect.size.width + gridrect.origin.x;
  gpnt.y = gridrect.size.height + gridrect.origin.y;
                     
  gpnt.x -= (gridSize.width + X_MARGIN);
  
  for (i = 0; i < gridcount; i++) {
    gpnt.y -= (gridSize.height + ymargin);
    
    if (gpnt.y <= gridrect.origin.y) {
      gpnt.y = gridrect.size.height + gridrect.origin.y;    
      gpnt.y -= (gridSize.height + ymargin);
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
  
  if (gpnt.y != (gridrect.origin.y + ymargin)) {
    float diffy = gpnt.y - (gridrect.origin.y + ymargin);
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

- (NSImage *)tshelfBackground
{
  CREATE_AUTORELEASE_POOL (pool);
  NSSize size = NSMakeSize([self frame].size.width, 112);
  NSImage *image = [[NSImage alloc] initWithSize: size];

  [image lockFocus];  
  NSCopyBits([[self window] gState], 
            NSMakeRect(0, 0, size.width, size.height),
			                              NSMakePoint(0.0, 0.0));
  [image unlockFocus];
  
  RETAIN (image);
  RELEASE (image);
  RELEASE (pool);
   
  return AUTORELEASE(image);
}

- (void)getDesktopInfo
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  NSDictionary *dskinfo = [defaults objectForKey: @"desktopinfo"];

  if (dskinfo) {
    id entry = [dskinfo objectForKey: @"backcolor"];
    FSNInfoType itype;

    if (entry) {
      float red = [[(NSDictionary *)entry objectForKey: @"red"] floatValue];
      float green = [[(NSDictionary *)entry objectForKey: @"green"] floatValue];
      float blue = [[(NSDictionary *)entry objectForKey: @"blue"] floatValue];
      float alpha = [[(NSDictionary *)entry objectForKey: @"alpha"] floatValue];

      ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    }

    entry = [dskinfo objectForKey: @"imagestyle"];
    backImageStyle = entry ? [entry intValue] : backImageStyle;

    entry = [dskinfo objectForKey: @"imagepath"];
    if (entry) {
      CREATE_AUTORELEASE_POOL (pool);
      NSImage *image = [[NSImage alloc] initWithContentsOfFile: entry];

      if (image) {
        ASSIGN (imagePath, entry);
        [self createBackImage: image];
        RELEASE (image);
      }
      
      RELEASE (pool);
    }

    entry = [dskinfo objectForKey: @"usebackimage"];
    useBackImage = entry ? [entry boolValue] : NO;      

    entry = [dskinfo objectForKey: @"iconsize"];
    iconSize = entry ? [entry intValue] : iconSize;

    entry = [dskinfo objectForKey: @"labeltxtsize"];
    if (entry) {
      labelTextSize = [entry intValue];
      ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);      
    }

    entry = [dskinfo objectForKey: @"iconposition"];
    iconPosition = entry ? [entry intValue] : iconPosition;

    entry = [dskinfo objectForKey: @"fsn_info_type"];
    itype = entry ? [entry intValue] : infoType;
    if (infoType != itype) {
      infoType = itype;
      [self makeIconsGrid];
    }
    infoType = itype;

    if (infoType == FSNInfoExtendedType) {
      DESTROY (extInfoType);
      entry = [dskinfo objectForKey: @"ext_info_type"];

      if (entry) {
        NSArray *availableTypes = [fsnodeRep availableExtendedInfoNames];

        if ([availableTypes containsObject: entry]) {
          ASSIGN (extInfoType, entry);
        }
      }

      if (extInfoType == nil) {
        infoType = FSNInfoNameType;
        [self makeIconsGrid];
      }
    }

    desktopInfo = [dskinfo mutableCopy];
    
  } else {
    desktopInfo = [NSMutableDictionary new];
  }
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  NSMutableDictionary *indexes = [NSMutableDictionary dictionary];
  NSColor *tempColor;
  NSMutableDictionary *backColorDict = [NSMutableDictionary dictionary];
  CGFloat red, green, blue, alpha;
  int i;

  tempColor = [backColor colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  [tempColor getRed: &red green: &green blue: &blue alpha: &alpha];
  [backColorDict setObject: [NSNumber numberWithFloat: red] forKey: @"red"];
  [backColorDict setObject: [NSNumber numberWithFloat: green] forKey: @"green"];
  [backColorDict setObject: [NSNumber numberWithFloat: blue] forKey: @"blue"];
  [backColorDict setObject: [NSNumber numberWithFloat: alpha] forKey: @"alpha"];

  [desktopInfo setObject: backColorDict forKey: @"backcolor"];

  [desktopInfo setObject: [NSNumber numberWithBool: useBackImage] 
                  forKey: @"usebackimage"];

  [desktopInfo setObject: [NSNumber numberWithInt: backImageStyle] 
                  forKey: @"imagestyle"];

  if (backImage) {
    [desktopInfo setObject: imagePath forKey: @"imagepath"];
  }

  [desktopInfo setObject: [NSNumber numberWithInt: iconSize] 
                  forKey: @"iconsize"];

  [desktopInfo setObject: [NSNumber numberWithInt: labelTextSize] 
                  forKey: @"labeltxtsize"];

  [desktopInfo setObject: [NSNumber numberWithInt: iconPosition] 
                  forKey: @"iconposition"];

  [desktopInfo setObject: [NSNumber numberWithInt: infoType] 
                  forKey: @"fsn_info_type"];

  if (infoType == FSNInfoExtendedType) {
    [desktopInfo setObject: extInfoType forKey: @"ext_info_type"];
  }

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    [indexes setObject: [NSNumber numberWithInt: [icon gridIndex]]
                forKey: [[icon node] name]];
  }

  [desktopInfo setObject: indexes forKey: @"indexes"];

  [defaults setObject: desktopInfo forKey: @"desktopinfo"];
}

- (void)selectIconInPrevLine
{
	int i;
  
	for (i = 0; i < [icons count]; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
    int index = [icon gridIndex];
    
		if ([icon isSelected]) {
      FSNIcon *prev;
      
      while (index > 0) {
        index--;
          
        prev = [self iconWithGridIndex: index];
        
        if (prev) {
          [prev select];
          break;
        }
      }
    
      break;
		}
	}
}

- (void)selectIconInNextLine
{
	int i;
  
	for (i = 0; i < [icons count]; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
    int index = [icon gridIndex];
    
		if ([icon isSelected]) {
      FSNIcon *next;
      
      while (index < gridcount) {
        index++;
          
        next = [self iconWithGridIndex: index];
        
        if (next) {
          [next select];
          break;
        }
      }
    
      break;
		}
	}
}

- (void)selectPrevIcon
{
	int i;
    
	for (i = 0; i < [icons count]; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
    int index = [icon gridIndex];
    
		if ([icon isSelected]) {
      NSArray *rowicons = [self iconsWithGridOriginY: [icon frame].origin.y];
      
      if (rowicons) {
        FSNIcon *prev;
        
        while (index < gridcount) {
          index++;
          prev = [self iconWithGridIndex: index];
      
          if (prev && [rowicons containsObject: prev]) {
            [prev select];
            break;
          }
        }
      }
      
      break;
		}
	}
}

- (void)selectNextIcon
{
	int i;
    
	for (i = 0; i < [icons count]; i++) {
		FSNIcon *icon = [icons objectAtIndex: i];
    int index = [icon gridIndex];
    
		if ([icon isSelected]) {
      NSArray *rowicons = [self iconsWithGridOriginY: [icon frame].origin.y];
      
      if (rowicons) {
        FSNIcon *next;
        
        while (index > 0) {
          index--;
          next = [self iconWithGridIndex: index];
      
          if (next && [rowicons containsObject: next]) {
            [next select];
            break;
          }
        }
      }
      
      break;
		}
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
  [self setSelectionMask: NSSingleSelectionMask];        
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSWindow *win = [self window];
  
  [win makeMainWindow];
  [win makeKeyWindow];
  
  if ([theEvent modifierFlags] != NSShiftKeyMask)
    {
      selectionMask = NSSingleSelectionMask;
      selectionMask |= FSNCreatingSelectionMask;
      [self unselectOtherReps: nil];
      selectionMask = NSSingleSelectionMask;
    
      DESTROY (lastSelection);
      [self selectionDidChange];
    }
}

#define SUPPORTS_XOR ((GNUSTEP_GUI_MAJOR_VERSION > 0)		\
		      || (GNUSTEP_GUI_MAJOR_VERSION == 0	\
			  && GNUSTEP_GUI_MINOR_VERSION > 22)	\
		      || (GNUSTEP_GUI_MAJOR_VERSION == 0	\
			  && GNUSTEP_GUI_MINOR_VERSION == 22	\
			  && GNUSTEP_GUI_SUBMINOR_VERSION > 0))

static void GWHighlightFrameRect(NSRect aRect)
{
#if SUPPORTS_XOR
  NSFrameRectWithWidthUsingOperation(aRect, 1.0, GSCompositeHighlight);
#endif
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

  transparentSelection = NO;
  if ([[manager dock] style] == DockStyleModern)
    transparentSelection = YES;

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
    
    x = min(startp.x, locp.x);
    y = min(startp.y, locp.y);
    w = max(1, max(locp.x, startp.x) - min(locp.x, startp.x));
    h = max(1, max(locp.y, startp.y) - min(locp.y, startp.y));

    r = NSMakeRect(x, y, w, h);
    
    
    // Erase the previous rect

    if (transparentSelection || !SUPPORTS_XOR)
      {
	[self setNeedsDisplayInRect: oldRect];
	[[self window] displayIfNeeded];
      }
    else
      GWHighlightFrameRect(oldRect);

    // Draw the new rect

    if (transparentSelection || !SUPPORTS_XOR)
      {
	[[NSColor darkGrayColor] set];
	NSFrameRect(r);
	if (transparentSelection)
	  {
	    [[[NSColor darkGrayColor] colorWithAlphaComponent: 0.33] set];
	    NSRectFillUsingOperation(r, NSCompositeSourceOver);
	  }
      }
    else
      GWHighlightFrameRect(r);

    oldRect = r;

    [[self window] enableFlushWindow];
    [[self window] flushWindow];
    [[self window] disableFlushWindow];

    DESTROY (arp);
  }

  [self unlockFocus];

  [[self window] postEvent: theEvent atStart: NO];
  
  // Erase the previous rect
  [self setNeedsDisplayInRect: oldRect];
  [[self window] displayIfNeeded];

  [[self window] enableFlushWindow];
  [[self window] flushWindow];

  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  x = min(startp.x, locp.x);
  y = min(startp.y, locp.y);
  w = max(1, max(locp.x, startp.x) - min(locp.x, startp.x));
  h = max(1, max(locp.y, startp.y) - min(locp.y, startp.y));

  r = NSMakeRect(x, y, w, h);

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSRect iconBounds = [self convertRect: [icon iconBounds] fromView: icon];
      
    if (NSIntersectsRect(r, iconBounds)) {
      [icon select];
    } 
  }  

  selectionMask = NSSingleSelectionMask;
  
  [self selectionDidChange];
}

- (void)keyDown:(NSEvent *)theEvent 
{
  unsigned flags = [theEvent modifierFlags];
  NSString *characters = [theEvent characters];  

  if ([characters length] > 0) {
		unichar character = [characters characterAtIndex: 0];

    if (character == NSCarriageReturnCharacter) {
      [manager openSelectionInNewViewer: NO];
      return;
    }
    
    if ((flags & NSCommandKeyMask) || (flags & NSControlKeyMask)) {
      if (character == NSBackspaceKey) {
        if (flags & NSShiftKeyMask) {
          [manager emptyTrash];
        } else {
          [manager moveToTrash];
        }
        return;
      }
    }      
	}

  [super keyDown: theEvent];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
  NSPoint p = [theEvent locationInWindow];
  
  if (NSPointInRect(p, [manager tshelfActivateFrame])) { 
    [manager mouseEnteredTShelfActivateFrame];
  } else if (NSPointInRect(p, [manager tshelfReservedFrame]) == NO) {
    [manager mouseExitedTShelfActiveFrame];
  }
  
  [super mouseMoved: theEvent];
}

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];
    
  if (backImage && useBackImage)
    {
      NSSize imsize = [backImage size];
      
      if ((imsize.width >= screenFrame.size.width) || (imsize.height >= screenFrame.size.height))
	{
	  if (backImageStyle == BackImageTileStyle)
	    backImageStyle = BackImageCenterStyle;
	}
      
      if (backImageStyle == BackImageFitStyle)
	{
	  [backImage drawInRect: NSMakeRect(0, 0, screenFrame.size.width, screenFrame.size.height)
		       fromRect: NSZeroRect
		      operation: NSCompositeSourceOver
		       fraction: 1.0
		 respectFlipped: YES
			  hints: nil];
	}
      else if (backImageStyle == BackImageTileStyle)
	{
	  CGFloat x = 0;
	  CGFloat y = screenFrame.size.width - imsize.width;

	  while (y > (0 - imsize.height))
	    {
	      [backImage compositeToPoint: NSMakePoint(x, y) 
				operation: NSCompositeSourceOver];
	      x += imsize.width;
	      if (x >= screenFrame.size.width)
		{
		  y -= imsize.height;
		  x = 0;
		}
	    }
	}
      else if (backImageStyle == BackImageScaleStyle)
	{
	  float imRatio;
	  float screenRatio;
	  float scale;
	  NSPoint imagePoint;

	  imRatio = imsize.width / imsize.height;
	  screenRatio = screenFrame.size.width / screenFrame.size.height;

	  if (imRatio > screenRatio)
	    {
	      /* image is wider in aspect than screen */
	      scale = imsize.width / screenFrame.size.width;
	      imagePoint = NSMakePoint(0, (screenFrame.size.height - imsize.height/scale) / 2);
	    }
	  else
	    {
	      /* image is taller in aspect than screen */
	      scale = imsize.height / screenFrame.size.height;
	      imagePoint = NSMakePoint((screenFrame.size.width - imsize.width/scale) / 2, 0);
	    }
	  [backImage drawInRect: NSMakeRect(imagePoint.x, imagePoint.y, imsize.width / scale, imsize.height / scale)
		       fromRect: NSZeroRect
		      operation: NSCompositeSourceOver
		       fraction: 1.0
		 respectFlipped: YES
			  hints: nil];

	}
      else
	{
	  NSPoint imagePoint;
	  imagePoint = NSMakePoint((screenFrame.size.width - imsize.width) / 2, (screenFrame.size.height - imsize.height) / 2);

	  [backImage compositeToPoint: imagePoint
			    operation: NSCompositeSourceOver];
	}
    }
  
  if (dragIcon)
    {
      [dragIcon dissolveToPoint: dragPoint fraction: 0.3];
    }
}

@end


@implementation GWDesktopView (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *subNodes = [anode subNodes];
  NSMutableArray *unsorted = [NSMutableArray array];
  int count = [icons count];
  NSDictionary *indexes = [desktopInfo objectForKey: @"indexes"];
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
     
  ASSIGN (node, anode);
    
  for (i = 0; i < [subNodes count]; i++) {
    FSNode *subnode = [subNodes objectAtIndex: i];
    GWDesktopIcon *icon = [[GWDesktopIcon alloc] initForNode: subnode
                                          nodeInfoType: infoType
                                          extendedType: extInfoType
                                              iconSize: iconSize
                                          iconPosition: iconPosition
                                             labelFont: labelFont
                                             textColor: textColor
                                             gridIndex: -1
                                             dndSource: YES
                                             acceptDnd: YES
                                             slideBack: YES];
                                       
    [unsorted addObject: icon];
    RELEASE (icon);
  }
  
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
  [self setNeedsDisplay: YES];
  RELEASE (arp);
}

- (void)nodeContentsDidChange:(NSDictionary *)info
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
      && ([operation isEqual: NSWorkspaceMoveOperation]
	  || [operation isEqual: NSWorkspaceDestroyOperation]
	  || [operation isEqual: @"GWorkspaceRenameOperation"]
	  || [operation isEqual: NSWorkspaceRecycleOperation]
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
      && ([operation isEqual: NSWorkspaceMoveOperation]   
	  || [operation isEqual: NSWorkspaceCopyOperation]
	  || [operation isEqual: NSWorkspaceLinkOperation]
	  || [operation isEqual: NSWorkspaceDuplicateOperation]
	  || [operation isEqual: @"GWorkspaceCreateDirOperation"]
	  || [operation isEqual: @"GWorkspaceRenameOperation"]
	  || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) { 
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      FSNIcon *icon = [self repOfSubnode: subnode];
      int index = 0;

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

- (void)watchedPathChanged:(NSDictionary *)info
{
  NSString *event = [info objectForKey: @"event"];
  NSArray *files = [info objectForKey: @"files"];
  NSString *ndpath = [node path];
  BOOL needupdate = NO;
  NSString *fname;
  NSString *fpath;
  int i;

  if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      fname = [files objectAtIndex: i];
      fpath = [ndpath stringByAppendingPathComponent: fname];  
      [self removeRepOfSubnodePath: fpath];
      needupdate = YES;
    }
    
  } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      fname = [files objectAtIndex: i];
      fpath = [ndpath stringByAppendingPathComponent: fname];  
      
      if ([self repOfSubnodePath: fpath] == nil) {
        [self addRepForSubnodePath: fpath];
        needupdate = YES;
      }
    }
  }
  
  if (needupdate) {
    [self tile];
    [self setNeedsDisplay: YES];
    [self selectionDidChange];
  }
}

- (void)setShowType:(FSNInfoType)type
{
  if (infoType != type) {
    BOOL newgrid = ((infoType == FSNInfoNameType) || (type == FSNInfoNameType));
    int i;
    
    infoType = type;
    DESTROY (extInfoType);
    
    if (newgrid) {
      [self makeIconsGrid];
    }
    
    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];
      
      [icon setNodeInfoShowType: infoType];
      [icon tile];
    }
    
    [self tile];
  }
}

- (void)setExtendedShowType:(NSString *)type
{
  if ((extInfoType == nil) || ([extInfoType isEqual: type] == NO)) {
    BOOL newgrid = (infoType == FSNInfoNameType);
    int i;
    
    infoType = FSNInfoExtendedType;
    ASSIGN (extInfoType, type);

    if (newgrid) {
      [self makeIconsGrid];
    }

    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];
      
      [icon setExtendedShowType: extInfoType];
      [icon tile];
    }
    
    [self tile];
  }
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
}

- (void)setLabelTextSize:(int)size
{
  int i;

  labelTextSize = size;
  ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);  
  [self makeIconsGrid];

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setFont: labelFont];
  }

  [nameEditor setFont: labelFont];

  [self tile];
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
}

- (id)addRepForSubnode:(FSNode *)anode
{
  CREATE_AUTORELEASE_POOL(arp);
  GWDesktopIcon *icon = [[GWDesktopIcon alloc] initForNode: anode
                                        nodeInfoType: infoType
                                        extendedType: extInfoType
                                            iconSize: iconSize
                                        iconPosition: iconPosition
                                           labelFont: labelFont
                                           textColor: textColor
                                           gridIndex: -1
                                           dndSource: YES
                                           acceptDnd: YES
                                           slideBack: YES];

  [icon setGridIndex: [self firstFreeGridIndex]];
  [icons addObject: icon];
  [self addSubview: icon];
  RELEASE (icon);
  RELEASE (arp);
    
  return icon;
}

- (void)repSelected:(id)arep
{
  NSWindow *win = [self window];

  if (win != [NSApp keyWindow]) {
    [win makeKeyWindow];
  }
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
    FSNIcon *icon = [icons objectAtIndex: i];
    FSNode *inode = [icon node];
    
    if (([inode isReserved] == NO) && ([inode isMountPoint] == NO)) {
      [icon select];
    }
	}
  
  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (void)selectionDidChange
{
  if (!(selectionMask & FSNCreatingSelectionMask))
    {
      NSArray *selection = [self selectedNodes];
		
      if ([selection count] == 0)
        selection = [NSArray arrayWithObject: node];
      
      ASSIGN (lastSelection, selection);
      [desktopApp selectionChanged: selection];
      [self updateNameEditor];
    }
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [manager openSelectionInNewViewer: newv];
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCut:(BOOL)cut
{
  NSMutableArray *sourcePaths = [names mutableCopy];
  NSString *basePath;
  NSString *nodePath = [node path];
  NSString *prePath = [NSString stringWithString: nodePath];
  NSUInteger count = [names count];
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

- (void)setBackgroundColor:(NSColor *)acolor
{
  [super setBackgroundColor: acolor];
}
          
- (void)setTextColor:(NSColor *)acolor
{
  [super setTextColor: acolor];
  [self setNeedsDisplay: YES];
}

@end


@implementation GWDesktopView (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb;
  NSDragOperation sourceDragMask;
  NSArray *sourcePaths;
  NSString *basePath;
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

  } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {
    NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 
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

  basePath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  if ([basePath isEqual: nodePath]) {
    return NSDragOperationNone;
  }

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

  if ([node isDirectory] && [node isParentOfPath: basePath]) {
    NSArray *subNodes = [node subNodes];
    int i;
    
    for (i = 0; i < [subNodes count]; i++) {
      FSNode *nd = [subNodes objectAtIndex: i];
      
      if ([nd isDirectory]) {
        int j;
        
        for (j = 0; j < count; j++) {
          NSString *fname = [[sourcePaths objectAtIndex: j] lastPathComponent];
          
          if ([[nd name] isEqual: fname]) {
            return NSDragOperationNone;
          }
        }
      }
    }
  }	

  isDragTarget = YES;	
  forceCopy = NO;
  dragPoint = NSZeroPoint;
  DESTROY (dragIcon);
  insertIndex = -1;
    
	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
    if ([[NSFileManager defaultManager] isWritableFileAtPath: basePath]) {
      return NSDragOperationAll;			
    } else {
      forceCopy = YES;
			return NSDragOperationCopy;			
    }
	}		

  isDragTarget = NO;	
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  NSPoint dpoint = [sender draggingLocation];
  int index;
  
  if (NSPointInRect(dpoint, [manager tshelfActivateFrame])) { 
    [manager mouseEnteredTShelfActivateFrame];
    return NSDragOperationNone;
  } else if (NSPointInRect(dpoint, [manager tshelfReservedFrame]) == NO) {
    [manager mouseExitedTShelfActiveFrame];
  }

	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}
  
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
  
  if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return forceCopy ? NSDragOperationCopy : NSDragOperationAll;
	}

	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  NSPoint dpoint = [sender draggingLocation];

  DESTROY (dragIcon);
  if (insertIndex != -1) {
    [self setNeedsDisplayInRect: grid[insertIndex]];
  }
	isDragTarget = NO;

  if (NSPointInRect(dpoint, [manager tshelfReservedFrame]) == NO) {
    [manager mouseExitedTShelfActiveFrame];
  }
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

    [desktopApp concludeRemoteFilesDragOperation: pbData
                                     atLocalPath: [node path]];
    return;
  
  } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {  
    NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 

    [desktopApp lsfolderDragOperation: pbData
                      concludedAtPath: [node path]];
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
      int index = 0;
      int shift = 0;
    
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
  
  trashPath = [desktopApp trashPath];

  if ([source isEqual: trashPath]) {
    operation = @"GWorkspaceRecycleOutOperation";
	} else {	
		if (sourceDragMask == NSDragOperationCopy) {
			operation = NSWorkspaceCopyOperation;
		} else if (sourceDragMask == NSDragOperationLink) {
			operation = NSWorkspaceLinkOperation;
		} else {
      if ([[NSFileManager defaultManager] isWritableFileAtPath: source]) {
			  operation = NSWorkspaceMoveOperation;
      } else {
			  operation = NSWorkspaceCopyOperation;
      }
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

  [desktopApp performFileOperation: opDict];
}

@end


@implementation GWDesktopView (BackgroundColors)

- (NSColor *)currentColor
{
  return backColor;
}

- (void)setCurrentColor:(NSColor *)color
{
  ASSIGN (backColor, color);
  [[self window] setBackgroundColor: backColor];
  [self setNeedsDisplay: YES];
}

- (void)createBackImage:(NSImage *)image
{
  ASSIGN(backImage, image);
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
