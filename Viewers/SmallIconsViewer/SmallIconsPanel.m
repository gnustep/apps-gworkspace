/* SmallIconsPanel.m
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
#include "SmallIconsPanel.h"
#include "SmallIcon.h"
#include "GNUstep.h"

#ifndef max
#define max(a,b) ((a) >= (b) ? (a):(b))
#endif

#ifndef min
#define min(a,b) ((a) <= (b) ? (a):(b))
#endif

#define ICNWIDTH 32
#define ICNHEIGHT 26
#define LABHEIGHT 14
#define ROWSHEIGHT 32
#define LEFTMARGIN 16
#define ICON_FRAME_MARGIN 6

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: rct]; \
}

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

@implementation SmallIconsPanel

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE (icons);
  RELEASE (currentPath);
  TEST_RELEASE (horizontalImage);
  TEST_RELEASE (verticalImage);
  TEST_RELEASE(charBuffer);
  [super dealloc];
}

- (id)initAtPath:(NSString *)path
        delegate:(id)adelegate
{
  self = [super initWithFrame: NSZeroRect];
  if (self) {
    NSArray *pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, 
                                          GWRemoteFilenamesPboardType, nil];
  
    ASSIGN (currentPath, path);
		[self setDelegate: adelegate];
		
		cellsWidth = [delegate iconCellsWidth];
    [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];            
    icons = [[NSMutableArray alloc] initWithCapacity: 1]; 		
		currSelectionSel = @selector(currentSelection);
		currSelection = [self methodForSelector: currSelectionSel];	
		isDragTarget = NO;
    isShiftClick = NO;
    horizontalImage = nil;
    verticalImage = nil;
		selectInProgress = NO;
		
		lastKeyPressed = 0.;
  	charBuffer = nil;

    contestualMenu = [[GWLib workspaceApp] usesContestualMenu];
		
  	[self registerForDraggedTypes: pbTypes];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(cellsWidthChanged:) 
                					    name: GWIconsCellsWidthChangedNotification
                					  object: nil];

		fm = [NSFileManager defaultManager];
    [self makeFileIcons];
  }
	
  return self;
}

- (void)setPath:(NSString *)path
{
  ASSIGN (currentPath, path);
  [self makeFileIcons];
}

- (void)setCurrentSelection
{
	if (selectInProgress) {
		return;
	}
	[delegate setSelectedPathsFromIcons: (*currSelection)(self, currSelectionSel)];
}

- (void)reloadFromPath:(NSString *)path
{
  NSArray *csel = nil;
  NSMutableArray *selection = nil;
  int i, count;

  csel = [self currentSelection];

  if (csel && [csel count]) {
    selection = [csel mutableCopy];
    count = [selection count];

    for (i = 0; i < count; i++) {
      NSString *spath = [selection objectAtIndex: i];

      if ([fm fileExistsAtPath: spath] == NO) {
        [selection removeObject: spath];
        count--;
        i--;
      }
    }
  }
    
  if ([currentPath isEqual: path]) {
    [self makeFileIcons];
    
    if (selection && [selection count]) {
      [self selectIconsWithPaths: selection];
      [delegate setSelectedPathsFromIcons: selection];
    } else {
      [delegate setTheSelectedPaths: [NSArray arrayWithObject: currentPath]];
    }
    
  } else if (subPathOfPath(path, currentPath)) {
    NSRange range = [currentPath rangeOfString: path];
    NSString *s = [currentPath substringFromIndex: (range.length + 1)];
    NSArray *components = [s pathComponents];
    NSString *bpath = [NSString stringWithString: path];
  
    for (i = 0; i < [components count]; i++) {
      NSString *component = [components objectAtIndex: i];
      BOOL isdir = NO;
  
      bpath = [bpath stringByAppendingPathComponent: component];
    
      if (([fm fileExistsAtPath: bpath isDirectory: &isdir] && isdir) == NO) {
        bpath = [bpath stringByDeletingLastPathComponent];  
        [self setPath: bpath];
        [self scrollFirstIconToVisible];
        [delegate setTheSelectedPaths: [NSArray arrayWithObject: currentPath]];        
        break;
      }
    }
    
    [self unLockAllIcons];
  }
  
  TEST_RELEASE (selection);
}

- (NSArray *)checkHiddenFiles:(NSArray *)files atPath:(NSString *)path
{
  NSArray *checkedFiles;
  NSArray *hiddenFiles;
	BOOL hideSysFiles;
  NSString *h; 
			
	h = [path stringByAppendingPathComponent: @".hidden"];
  if ([fm fileExistsAtPath: h]) {
	  h = [NSString stringWithContentsOfFile: h];
	  hiddenFiles = [h componentsSeparatedByString: @"\n"];
	} else {
    hiddenFiles = nil;
  }
	hideSysFiles = [GWLib hideSysFiles];
	
	if (hiddenFiles != nil  ||  hideSysFiles) {	
		NSMutableArray *mutableFiles = AUTORELEASE ([files mutableCopy]);
	
		if (hiddenFiles != nil) {
	    [mutableFiles removeObjectsInArray: hiddenFiles];
	  }
	
		if (hideSysFiles) {
	    int j = [mutableFiles count] - 1;
	    
	    while (j >= 0) {
				NSString *file = (NSString *)[mutableFiles objectAtIndex: j];

				if ([file hasPrefix: @"."]) {
		    	[mutableFiles removeObjectAtIndex: j];
		  	}
				j--;
			}
	  }		
    
		checkedFiles = mutableFiles;
    
	} else {
    checkedFiles = files;
  }

  return checkedFiles;
}

- (void)makeFileIcons
{
  NSArray *files;
  NSMutableArray *paths;
  int i, count;

  for (i = 0; i < [icons count]; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];
		NSTextField *label = [icon label];
		[label setDelegate: nil];
		[label setEditable: NO];
    [label removeFromSuperviewWithoutNeedingDisplay]; 							
    [icon removeFromSuperviewWithoutNeedingDisplay];
  }
  
  [icons removeAllObjects];

  files = [GWLib sortedDirectoryContentsAtPath: currentPath];
  files = [GWLib checkHiddenFiles: files atPath: currentPath];  
   	
  count = [files count];
  if (count == 0) {
  	[self tile]; 
		return;
	}

  paths = [NSMutableArray arrayWithCapacity: 1];

  for (i = 0; i < count; ++i) {
    NSString *s = [currentPath stringByAppendingPathComponent: [files objectAtIndex: i]];
    [paths addObject: s];
  }

  for (i = 0; i < count; ++i) {
    NSString *ipath = [paths objectAtIndex: i];
    SmallIcon *icon = [[SmallIcon alloc] initForPath: ipath delegate: self];
  
    [icon setLocked: [GWLib isLockedPath: ipath]]; 
    [icons addObject: icon];  
    RELEASE (icon);
  }  
    
  for (i = 0; i < [icons count]; ++i) {
    SmallIcon *icon = [icons objectAtIndex: i];
	  [self addSubview: icon];
	  [self addSubview: [icon label]];
    [icon setLabelFrame];
  }
  
  [self tile];  
  [self setNeedsDisplay: YES];
}

- (void)sortIcons
{
  NSMutableDictionary *sortDict = [NSMutableDictionary dictionaryWithCapacity: 1];
	int stype = [GWLib sortTypeForDirectoryAtPath: currentPath];

	[sortDict setObject: currentPath forKey: @"path"];
	[sortDict setObject: [NSString stringWithFormat: @"%i", stype] forKey: @"type"];

  [icons sortUsingFunction: (int (*)(id, id, void*))compIcons 
                   context: (void *)sortDict];
}

- (void)tile
{
  float sfw = [[self superview] frame].size.width;
  float sfh = [[self superview] frame].size.height;
	float ox = [self frame].origin.x;
	float oy = [self frame].origin.y;
  NSRect maxr = [[NSScreen mainScreen] frame];
	float px = LEFTMARGIN;
	float py = ROWSHEIGHT;
  NSSize sz;
	float shiftx = 0;
	int count = [icons count];
	NSRect *irects = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * count);
  NSCachedImageRep *rep = nil;
	int i;

#define CHECK_SIZE(s) \
if (s.width < 1) s.width = 1; \
if (s.height < 1) s.height = 1; \
if (s.width > maxr.size.width) s.width = maxr.size.width; \
if (s.height > maxr.size.height) s.height = maxr.size.height
	  
	for (i = 0; i < count; i++) {
		SmallIcon *icon = [icons objectAtIndex: i];
		float labwidth = [icon labelWidth];
		float iconwidth = [icon frame].size.width + labwidth;
		
		px += shiftx;

    if (px >= (sfw - iconwidth)) {
      px = LEFTMARGIN;  
			shiftx = 0;    
      py += ROWSHEIGHT;  			
    }
		
		irects[i] = NSMakeRect(px, py, ICNWIDTH, ICNHEIGHT);
		
		while (iconwidth > shiftx) {
			shiftx += cellsWidth;
		}
	}

	py += (ROWSHEIGHT / 2);  
  py = (py < sfh) ? sfh : py;

  SETRECT (self, ox, oy, sfw, py);

  DESTROY (horizontalImage);
  sz = NSMakeSize(sfw, 2);
  CHECK_SIZE (sz);
  horizontalImage = [[NSImage allocWithZone: (NSZone *)[(NSObject *)self zone]] 
                               initWithSize: sz];

  rep = [[NSCachedImageRep allocWithZone: (NSZone *)[(NSObject *)self zone]]
                            initWithSize: sz
                                   depth: [NSWindow defaultDepthLimit] 
                                separate: YES 
                                   alpha: YES];

  [horizontalImage addRepresentation: rep];
  RELEASE (rep);

  DESTROY (verticalImage);
  sz = NSMakeSize(2, py);
  CHECK_SIZE (sz);
  verticalImage = [[NSImage allocWithZone: (NSZone *)[(NSObject *)self zone]] 
                             initWithSize: sz];

  rep = [[NSCachedImageRep allocWithZone: (NSZone *)[(NSObject *)self zone]]
                            initWithSize: sz
                                   depth: [NSWindow defaultDepthLimit] 
                                separate: YES 
                                   alpha: YES];

  [verticalImage addRepresentation: rep];
  RELEASE (rep);

	for (i = 0; i < count; i++) {   
		SmallIcon *icon = [icons objectAtIndex: i];
		irects[i].origin.y = py - irects[i].origin.y;
		[icon setFrame: irects[i]];
		[icon setPosition: irects[i].origin gridIndex: i];
    [icon setNeedsDisplay: YES];
		[self setLabelRectOfIcon: icon];
	}
	
	NSZoneFree (NSDefaultMallocZone(), irects);
}

- (void)scrollFirstIconToVisible
{
  [self scrollRectToVisible: NSMakeRect(0, [self frame].size.height - 10, 10, 10)];
}

- (void)scrollToVisibleIconsWithPaths:(NSArray *)paths
{
  SmallIcon *icon = [self iconWithPath: [paths objectAtIndex: 0]];

  if (icon) {
    NSRect vrect = [self visibleRect];
    NSRect r = NSUnionRect([icon frame], [[icon label] frame]);  
    
    if (NSContainsRect(vrect, r) == NO) {    
      r.origin.y -= ICON_FRAME_MARGIN;
      r.size.height += ICON_FRAME_MARGIN * 2;
      [self scrollRectToVisible: r];
    }
  }
}

- (NSString *)currentPath
{
  return currentPath;
}

- (BOOL)isOnBasePath:(NSString *)bpath withFiles:(NSArray *)files
{
  if ([currentPath isEqual: bpath]) {
    return YES;
  
  } else if (subPathOfPath(bpath, currentPath)) {
    int i;
    
    if (files == nil) {
      return YES;
      
    } else {
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        NSString *fpath = [bpath stringByAppendingPathComponent: fname];				
				
        if (([fpath isEqual: currentPath]) || (subPathOfPath(fpath, currentPath))) {
          return YES;
        }
      }
    }
  }

  return NO;
}

- (NSArray *)currentSelection
{
  NSMutableArray *allpaths = [NSMutableArray arrayWithCapacity: 1]; 
  int i;

  for (i = 0; i < [icons count]; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];    
    if ([icon isSelect] == YES) {
      NSString *ipath = [icon path];
      
      if ([fm fileExistsAtPath: ipath]) {
        [allpaths addObject: ipath];
      }
    }
  } 
  
  if ([allpaths count] == 0) {
    return nil;
  }
    
  return allpaths;
}

- (SmallIcon *)iconWithPath:(NSString *)path
{
  int i;

  for (i = 0; i < [icons count]; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];
  
    if ([[icon path] isEqual: path]) {
      return icon;
    }
  }
  
  return nil;
}

- (NSArray *)iconsWithPaths:(NSArray *)paths
{
  return [NSArray array];
}

- (void)selectIconWithPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];    
    
    if ([[icon path] isEqual: path]) {
      NSRect irect = [icon frame];  
      irect.origin.y -= ICON_FRAME_MARGIN;
      irect.size.height += ICON_FRAME_MARGIN * 2;
      [icon select];
			[self scrollRectToVisible: irect];	      
      return;
    }
  }
}

- (SmallIcon *)iconWithNamePrefix:(NSString *)prefix 
													inRange:(NSRange)range
{
	int i;

	if (range.length == 0) {
		return nil;
	}
	
	for (i = range.location; i < range.location + range.length; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];
    if ([[icon myName] hasPrefix: charBuffer]) {
			return icon;	
    }
	}
	
	return nil;
}

- (NSPoint)locationOfIconWithName:(NSString *)name
{
	int i;

  for (i = 0; i < [icons count]; i++) {
    SmallIcon *icon = [icons objectAtIndex: i]; 
		
    if ([[icon myName] isEqualToString: name]) {	
			NSPoint p = [icon frame].origin;
			NSSize s = [icon iconShift];
			return NSMakePoint(p.x + s.width, p.y + s.height);
    }
  } 

	return NSMakePoint(0, 0);
}

- (void)selectIconsWithPaths:(NSArray *)paths
{
  int i;
  
  isShiftClick = YES;

  for (i = 0; i < [icons count]; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];    
    NSString *ipath = [icon path];

    if ([paths containsObject: ipath] == YES) {
      [icon select];
    }
  }

  isShiftClick = NO;
}

- (void)selectIconInPrevLine
{
	NSPoint sp;
  NSRect r[2];
  NSRect irect;
	int i, startpos = -1;
	
	for (i = [icons count] -1; i >= 0; i--) {
		SmallIcon *icon = [icons objectAtIndex: i];
		
		if ([icon isSelect]) {
      r[0] = [icon frame];
      r[1] = [[icon label] frame];    
			startpos = i;
			sp = [icon position];
			break;
		}
	}

	if (startpos != -1) {
		for (i = startpos; i >= 0; i--) {
			SmallIcon *icon = [icons objectAtIndex: i];
			NSPoint p = [icon position];

			if ((p.x == sp.x) && (p.y > sp.y)) {
				[icon select];
        [self setNeedsDisplayInRect: r[0]];
        [self setNeedsDisplayInRect: r[1]];
        
        irect = NSUnionRect([icon frame], [[icon label] frame]);  
        irect.origin.y -= ICON_FRAME_MARGIN;
        irect.size.height += ICON_FRAME_MARGIN * 2;
        [self scrollRectToVisible: irect];
				break;
			}
		}
	}	
}

- (void)selectIconInNextLine
{
	NSPoint sp;
  NSRect r[2];
  NSRect irect;
	int i, startpos = -1;
	
	for (i = 0; i < [icons count]; i++) {
		SmallIcon *icon = [icons objectAtIndex: i];
		
		if ([icon isSelect]) {
      r[0] = [icon frame];
      r[1] = [[icon label] frame];    
			startpos = i;
			sp = [icon position];
			break;
		}
	}

	if (startpos != -1) {
		for (i = startpos; i < [icons count]; i++) {
			SmallIcon *icon = [icons objectAtIndex: i];
			NSPoint p = [icon position];

			if ((p.x == sp.x) && (p.y < sp.y)) {
				[icon select];
        [self setNeedsDisplayInRect: r[0]];
        [self setNeedsDisplayInRect: r[1]];
        
        irect = NSUnionRect([icon frame], [[icon label] frame]);  
        irect.origin.y -= ICON_FRAME_MARGIN;
        irect.size.height += ICON_FRAME_MARGIN * 2;
        [self scrollRectToVisible: irect];
				break;
			}
		}
	}	
}

- (void)selectPrevIcon
{
	int i;
    
	for(i = 0; i < [icons count]; i++) {
		SmallIcon *icon = [icons objectAtIndex: i];
    
		if([icon isSelect]) {
			if (i > 0) {
        NSRect irect = NSUnionRect([icon frame], [[icon label] frame]); 
      
				[self unselectOtherIcons: icon];
				icon = [icons objectAtIndex: i - 1];
				[icon select];
        [self setNeedsDisplayInRect: irect];
        
        irect = NSUnionRect([icon frame], [[icon label] frame]); 
        irect.origin.y -= ICON_FRAME_MARGIN;
        irect.size.height += ICON_FRAME_MARGIN * 2;
				[self scrollRectToVisible: irect];		
				return;
			} else {
				return;
			}
		}
	}
}

- (void)selectNextIcon
{
	int i, count = [icons count];
    
	for(i = 0; i < [icons count]; i++) {
		SmallIcon *icon = [icons objectAtIndex: i];
    
		if([icon isSelect]) {
			if (i < (count - 1)) {
        NSRect irect = NSUnionRect([icon frame], [[icon label] frame]); 
      
				[self unselectOtherIcons: icon];
				icon = [icons objectAtIndex: i + 1];
				[icon select];
        [self setNeedsDisplayInRect: irect];
        
        irect = NSUnionRect([icon frame], [[icon label] frame]); 
        irect.origin.y -= ICON_FRAME_MARGIN;
        irect.size.height += ICON_FRAME_MARGIN * 2;
				[self scrollRectToVisible: irect];		
				return;
			} else {
				return;
			}
		}
	} 
}

- (void)selectAllIcons
{
	int i;

	isShiftClick = YES;  
	selectInProgress = YES;
	for(i = 0; i < [icons count]; i++) {
		[[icons objectAtIndex: i] select];
	}
	selectInProgress = NO;
	[self setCurrentSelection];
	isShiftClick = NO;
}

- (void)unselectOtherIcons:(id)anIcon
{
  int i;
  
  if(isShiftClick == YES) {
    return;
  }
  
  for (i = 0; i < [icons count]; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];
    if (icon != anIcon) {  
      [icon unselect];
    }
  }  
}

- (void)extendSelectionWithDimmedFiles:(NSArray *)files 
                        startingAtPath:(NSString *)bpath
{
  if ([currentPath isEqual: bpath]) {
    [self addIconsWithNames: files dimmed: YES];
    [self tile];
  } else if (subPathOfPath(bpath, currentPath)) {
    int i;

    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fpath = [bpath stringByAppendingPathComponent: fname];				
				
      if (([fpath isEqual: currentPath]) || (subPathOfPath(fpath, currentPath))) {
        [self lockAllIcons];                 
				break;
			}
    } 
  }
}

- (void)openSelectionWithApp:(id)sender
{
  NSString *appName = (NSString *)[sender representedObject];
  NSArray *selection = [self currentSelection];
  
  if (selection && [selection count]) {
    int i;
    
    for (i = 0; i < [selection count]; i++) {
      [[NSWorkspace sharedWorkspace] openFile: [selection objectAtIndex: i] 
                              withApplication: appName];
    }
  }
}

- (void)openSelectionWith:(id)sender
{
  [[GWLib workspaceApp] openSelectedPathsWith];
}

- (void)addIconWithPath:(NSString *)iconpath dimmed:(BOOL)isdimmed;
{
  SmallIcon *icon = [self iconWithPath: iconpath];
  
  if (icon) {
    [icon setLocked: isdimmed];  
  } else {
    icon = [[SmallIcon alloc] initForPath: iconpath delegate: self];
    [icon setLocked: isdimmed]; 
    [icons addObject: icon];  
	  [self addSubview: icon];
	  [self addSubview: [icon label]];
    RELEASE (icon);
  }
}

- (void)addIconsWithPaths:(NSArray *)iconpaths
{
  int i;
  
  for (i = 0; i < [iconpaths count]; i++) {
		NSString *s = [iconpaths objectAtIndex: i];
    SmallIcon *icon = [[SmallIcon alloc] initForPath: s delegate: self];
    
    [icon setLocked: [GWLib isLockedPath: s]];	
    
    [icons addObject: icon];  
	  [self addSubview: icon];
	  [self addSubview: [icon label]];
    [icon setLabelFrame];
    RELEASE (icon);
  }
}

- (void)addIconsWithNames:(NSArray *)names dimmed:(BOOL)isdimmed
{
  NSArray *files = [self checkHiddenFiles: names atPath: currentPath];

  if ([files count]) {
    int i;

    for (i = 0; i < [files count]; i++) {
      NSString *s = [currentPath stringByAppendingPathComponent: [files objectAtIndex: i]];
      [self addIconWithPath: s dimmed: isdimmed];
    }    
    [self sortIcons];    
    [self tile];
  }  
}

- (void)removeIcon:(id)anIcon
{
  SmallIcon *icon = (SmallIcon *)anIcon;
  [[icon label] removeFromSuperview];
  [icon removeFromSuperview];
  [icons removeObject: icon];
	[self tile];
}

- (void)removeIconsWithNames:(NSArray *)names
{
  int i, count = [icons count];
  
  for (i = 0; i < count; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];
    NSString *name = [icon myName];

    if ([names containsObject: name] == YES) {
      [[icon label] removeFromSuperview];
      [icon removeFromSuperview];
      [icons removeObject: icon];
      count--;
      i--;
    }
  }

  [self tile]; 
}

- (void)lockIconsWithNames:(NSArray *)names
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
		SmallIcon *icon = [icons objectAtIndex: i];
    if ([names containsObject: [icon myName]]) {
			[icon setLocked: YES];
    }
  }
}

- (void)unLockIconsWithNames:(NSArray *)names
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
		SmallIcon *icon = [icons objectAtIndex: i];
    if ([names containsObject: [icon myName]]) {
			[icon setLocked: NO];
    }
  }
}

- (void)lockAllIcons
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
		SmallIcon *icon = [icons objectAtIndex: i];
    if ([icon isLocked] == NO) {
			[icon setLocked: YES];
    }
  }
}

- (void)unLockAllIcons
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
		SmallIcon *icon = [icons objectAtIndex: i];
    if ([icon isLocked]) {
			[icon setLocked: NO];
    }
  }
}

- (void)setLabelRectOfIcon:(id)anIcon
{
  SmallIcon *icon = (SmallIcon *)anIcon;
	NSTextField *label = [icon label];

	[label setFrame: NSMakeRect([icon frame].origin.x + ICNWIDTH, 
							[icon frame].origin.y + ((ICNHEIGHT - LABHEIGHT) / 2), 
																						[icon labelWidth], LABHEIGHT)];					
	[label setNeedsDisplay: YES];
}

- (int)cellsWidth
{
  return cellsWidth;
}

- (void)cellsWidthChanged:(NSNotification *)notification
{
  cellsWidth = [(NSNumber *)[notification object] intValue];
  [self tile];
}

- (void)setShiftClick:(BOOL)value
{
  isShiftClick = value;
}

- (void)openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv
{
	[delegate openTheCurrentSelection: (*currSelection)(self, currSelectionSel) 
													newViewer: newv];
}

- (id)delegate
{
  return delegate;
}

- (void)setDelegate:(id)anObject
{	
  delegate = anObject;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self tile];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if ([theEvent type] == NSRightMouseDown) {
    NSArray *selection = [self currentSelection];

    if (contestualMenu == NO) {
      return [super menuForEvent: theEvent];
    }

    if (selection && [selection count]) {
      if ([theEvent modifierFlags] == NSControlKeyMask) {
        return [super menuForEvent: theEvent];
      } else {
        NSMenu *menu;
        NSMenuItem *menuItem;
        NSString *firstext; 
        NSDictionary *apps;
        NSEnumerator *app_enum;
        id key; 
        int i;

        firstext = [[selection objectAtIndex: 0] pathExtension];

        for (i = 0; i < [selection count]; i++) {
          NSString *selpath = [selection objectAtIndex: i];
          NSString *ext = [selpath pathExtension];   
		      NSString *defApp = nil;
		      NSString *fType = nil;

          if ([ext isEqual: firstext] == NO) {
            return [super menuForEvent: theEvent];  
          }

		      [[NSWorkspace sharedWorkspace] getInfoForFile: selpath 
                                            application: &defApp 
                                                   type: &fType];	

		      if (([fType isEqual: NSPlainFileType] == NO)
                         && ([fType isEqual: NSShellCommandFileType] == NO)) {
            return [super menuForEvent: theEvent];  
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

          [menuItem setTarget: self];      
          [menuItem setAction: @selector(openSelectionWithApp:)];      
          [menuItem setRepresentedObject: key];            
          [menu addItem: menuItem];
          RELEASE (menuItem);
        }

        menuItem = [NSMenuItem new]; 
        [menuItem setTitle:  NSLocalizedString(@"Open with...", @"")];
        [menuItem setTarget: self];      
        [menuItem setAction: @selector(openSelectionWith:)];          
        [menu addItem: menuItem];
        RELEASE (menuItem);

        return [menu autorelease];
      }
      
    } else {
      return [super menuForEvent: theEvent];
    }
  }

  return [super menuForEvent: theEvent];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [[self window] makeFirstResponder: self];
  
	if([theEvent modifierFlags] != 2) {
		isShiftClick = NO;
    selectInProgress = YES;
		[self unselectOtherIcons: nil];
    selectInProgress = NO;
		[delegate setSelectedPathsFromIcons: [NSArray arrayWithObject: currentPath]];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
  unsigned int eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask;
  NSDate *future = [NSDate distantFuture];
  NSPoint	startp, sp;
  NSPoint	p, pp;
  NSRect visibleRect;
  NSRect oldRect; 
  NSRect r, wr;
  NSRect selrect;
  float x, y, w, h;
  int i;
  
#define scrollPointToVisible(p) \
{ \
NSRect sr; \
sr.origin = p; \
sr.size.width = sr.size.height = 0.1; \
[self scrollRectToVisible: sr]; \
}

#define CONVERT_CHECK \
pp = [self convertPoint: p fromView: nil]; \
if (pp.x < 1) \
pp.x = 1; \
if (pp.x >= NSMaxX([self bounds])) \
pp.x = NSMaxX([self bounds]) - 1

  p = [theEvent locationInWindow];
  sp = [self convertPoint: p  fromView: nil];
  startp = [self convertPoint: p fromView: nil];
  
  oldRect = NSZeroRect;  

	[[self window] disableFlushWindow];
  [self lockFocus];

  [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.05];

  while ([theEvent type] != NSLeftMouseUp) {
    CREATE_AUTORELEASE_POOL (arp);

    theEvent = [NSApp nextEventMatchingMask: eventMask
                                  untilDate: future
                                     inMode: NSEventTrackingRunLoopMode
                                    dequeue: YES];

    if ([theEvent type] != NSPeriodic) {
      p = [theEvent locationInWindow];
    }
    
    CONVERT_CHECK;
    
    visibleRect = [self visibleRect];
    
    if (NSPointInRect(pp, [self visibleRect]) == NO) {
      scrollPointToVisible(pp);      
      CONVERT_CHECK;
      visibleRect = [self visibleRect];      
    }

    if ((sp.y < visibleRect.origin.y)
          || (sp.y > (visibleRect.origin.y + visibleRect.size.height))) {
      if (sp.y < visibleRect.origin.y) {
        sp.y = visibleRect.origin.y - 1;
      }
      if (sp.y > (visibleRect.origin.y + visibleRect.size.height)) {
        sp.y = (visibleRect.origin.y + visibleRect.size.height + 1);
      }
    } 

    x = (pp.x >= sp.x) ? sp.x : pp.x;
    y = (pp.y >= sp.y) ? sp.y : pp.y;
    w = max(pp.x, sp.x) - min(pp.x, sp.x);
    w = (w == 0) ? 1 : w;
    h = max(pp.y, sp.y) - min(pp.y, sp.y);
    h = (h == 0) ? 1 : h;

    r = NSMakeRect(x, y, w, h);
    
    wr = [self convertRect: r toView: nil];
  
    sp = startp;

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
            NSMakeRect(NSMinX(wr), NSMinY(wr), 
                          1.0, r.size.height),
			                          NSMakePoint(0.0, 0.0));
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMaxX(wr) -1, NSMinY(wr),
				                  1.0, r.size.height),
			                          NSMakePoint(1.0, 0.0));
    [verticalImage unlockFocus];

    [horizontalImage lockFocus];
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMinX(wr), NSMinY(wr),
				                  r.size.width, 1.0),
			                          NSMakePoint(0.0, 0.0));
    NSCopyBits([[self window] gState],
			      NSMakeRect(NSMinX(wr), NSMaxY(wr) -1,
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
  
  [NSEvent stopPeriodicEvents];
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

  [self setShiftClick: YES];
  selectInProgress = YES;

  x = (pp.x >= startp.x) ? startp.x : pp.x;
  y = (pp.y >= startp.y) ? startp.y : pp.y;
  w = max(pp.x, startp.x) - min(pp.x, startp.x);
  w = (w == 0) ? 1 : w;
  h = max(pp.y, startp.y) - min(pp.y, startp.y);
  h = (h == 0) ? 1 : h;

  selrect = NSMakeRect(x, y, w, h);
  
  for (i = 0; i < [icons count]; i++) {
    SmallIcon *icon = [icons objectAtIndex: i];
      
    if (NSIntersectsRect(selrect, [icon frame])) {
      [icon select];
    } 
  }  
  
  selectInProgress = NO;
	[self setCurrentSelection];
  [self setShiftClick: NO];  
}

- (void)keyDown:(NSEvent *)theEvent 
{
	NSString *characters;
	unichar character;
	NSRect vRect, hiddRect;
	NSPoint p;
	float x, y, w, h;
		
	characters = [theEvent characters];
	character = 0;
		
  if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];
	}
		
	switch (character) {
    case NSPageUpFunctionKey:
		  vRect = [self visibleRect];
		  p = vRect.origin;    
		  x = p.x;
		  y = p.y + vRect.size.height;
		  w = vRect.size.width;
		  h = vRect.size.height;
		  hiddRect = NSMakeRect(x, y, w, h);
		  [self scrollRectToVisible: hiddRect];
	    return;

    case NSPageDownFunctionKey:
		  vRect = [self visibleRect];
		  p = vRect.origin;
		  x = p.x;
		  y = p.y - vRect.size.height;
		  w = vRect.size.width;
		  h = vRect.size.height;
		  hiddRect = NSMakeRect(x, y, w, h);
		  [self scrollRectToVisible: hiddRect];
	    return;

    case NSUpArrowFunctionKey:
			isShiftClick = NO;
	    [self selectIconInPrevLine];
      return;

    case NSDownArrowFunctionKey:
			isShiftClick = NO;
	    [self selectIconInNextLine];
      return;

    case NSLeftArrowFunctionKey:
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
					isShiftClick = NO;
	    		[self selectPrevIcon];
				}
			}
      return;

    case NSRightArrowFunctionKey:			
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
					isShiftClick = NO;
	    		[self selectNextIcon];
				}
			}
      return;

    case 13:
      [self openCurrentSelection: (*currSelection)(self, currSelectionSel)
											 newViewer: NO];      
      return;

		case NSTabCharacter:
	  	{
	    	if ([theEvent modifierFlags] & NSShiftKeyMask) {
	      	[[self window] selectKeyViewPrecedingView: self];
	    	} else {
	      	[[self window] selectKeyViewFollowingView: self];
				}
	  	}
			return;

      break;
	} 

  if ((character < 0xF700) && ([characters length] > 0)) {
		SEL iwnpSel = @selector(iconWithNamePrefix:inRange:);
		IMP iwnp = [self methodForSelector: iwnpSel];
		SmallIcon *icon;
    NSRect r;
		int i, s, count;
		
		s = -1;
		count = [icons count];
	  
		if (charBuffer == nil) {
	    charBuffer = [characters substringToIndex: 1];
	    RETAIN (charBuffer);
	  } else {
	    if ([theEvent timestamp] - lastKeyPressed < 2000.0) {
		  	ASSIGN (charBuffer, ([charBuffer stringByAppendingString:
				    															[characters substringToIndex: 1]]));
			} else {
		  	ASSIGN (charBuffer, ([characters substringToIndex: 1]));
			}														
		}

		lastKeyPressed = [theEvent timestamp];

		[self setShiftClick: NO];
		
		for (i = 0; i < count; i++) {
      icon = [icons objectAtIndex: i];
			
			if ([icon isSelect]) {												
      	if ([[icon myName] hasPrefix: charBuffer]) {
          r = [icon frame];
          r.origin.y -= ICON_FRAME_MARGIN;
          r.size.height += ICON_FRAME_MARGIN * 2;
					[self scrollRectToVisible: r];	
					return;
      	} else {
					s = i;
					break;
				}
			}
		}
		
  	icon = (*iwnp)(self, iwnpSel, charBuffer, NSMakeRange(s + 1, count -s -1));
		if (icon) {
  		[icon select];
      r = [icon frame];
      r.origin.y -= ICON_FRAME_MARGIN;
      r.size.height += ICON_FRAME_MARGIN * 2;
			[self scrollRectToVisible: r];	
			return;	
		}
		
		s = (s == -1) ? count - 1 : s;
		
  	icon = (*iwnp)(self, iwnpSel, charBuffer, NSMakeRange(0, s)); 
		if (icon) {
  		[icon select];
      r = [icon frame];
      r.origin.y -= ICON_FRAME_MARGIN;
      r.size.height += ICON_FRAME_MARGIN * 2;
			[self scrollRectToVisible: r];	
			return;	
		}
				
		lastKeyPressed = 0.;			
	}
	
	[super keyDown: theEvent];
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

@end

@implementation SmallIconsPanel (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *buff;
	int i, count;

	isDragTarget = NO;	
    
 	pb = [sender draggingPasteboard];
  
  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: GWRemoteFilenamesPboardType]) {
    NSData *pbData = [pb dataForType: GWRemoteFilenamesPboardType]; 
    NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
    sourcePaths = [pbDict objectForKey: @"paths"];
  } else {
    return NSDragOperationNone;
  }

	count = [sourcePaths count];
	fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	if (count == 0) {
		return NSDragOperationNone;
  } 

	if ([fm isWritableFileAtPath: currentPath] == NO) {
		return NSDragOperationNone;
	}

	if ([currentPath isEqualToString: fromPath]) {
		return NSDragOperationNone;
  }  

	for (i = 0; i < count; i++) {
		if ([currentPath isEqualToString: [sourcePaths objectAtIndex: i]]) {
		  return NSDragOperationNone;
		}
	}

	buff = [NSString stringWithString: currentPath];
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

	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}		
  return NSDragOperationAll;
  
  
	isDragTarget = NO;	
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;
	
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
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
	NSString *trashPath;
  int i;

  isDragTarget = NO;
	
	sourceDragMask = [sender draggingSourceOperationMask];  	
  pb = [sender draggingPasteboard];
  
  if ([[pb types] containsObject: GWRemoteFilenamesPboardType]) {  
    NSData *pbData = [pb dataForType: GWRemoteFilenamesPboardType]; 

    [GWLib concludeRemoteFilesDragOperation: pbData
                                atLocalPath: currentPath];
    return;
  }
  
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
	[opDict setObject: currentPath forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];
	
	[[GWLib workspaceApp] performFileOperationWithDictionary: opDict];	
}

@end

//
// SmallIcon Delegate Methods
//
@implementation SmallIconsPanel (SmallIconDelegateMethods)

- (void)unselectIconsDifferentFrom:(id)aicon
{
	[self unselectOtherIcons: aicon];
}

- (void)setShiftClickValue:(BOOL)value
{
	[self setShiftClick: value];
}

- (void)setTheCurrentSelection
{
	[self setCurrentSelection];
}

- (NSArray *)getTheCurrentSelection
{
	return (*currSelection)(self, currSelectionSel);
}

- (void)openTheCurrentSelection:(id)paths newViewer:(BOOL)newv
{
	[self openCurrentSelection: paths newViewer: newv];
}

- (id)menuForRightMouseEvent:(NSEvent *)theEvent
{ 
  return [self menuForEvent: theEvent];
}

@end
