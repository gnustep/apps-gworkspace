/* IconsPanel.m
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
#include <math.h>
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "GWProtocol.h"
#include "BNameEditor.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/BNameEditor.h>
  #endif
#include "IconsPanel.h"
#include "IconsViewerIcon.h"
#include "GNUstep.h"

#ifndef max
#define max(a,b) ((a) >= (b) ? (a):(b))
#endif

#ifndef min
#define min(a,b) ((a) <= (b) ? (a):(b))
#endif

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: rct]; \
}

#define LEFTMARGIN 32
#define RIGHTMARGIN 64
#define ROWSHEIGHT 75
#define FIRSTPOSY 65
#define ICNWIDTH 64 
#define ICNHEIGHT 52
#define ICON_FRAME_MARGIN 10

#define LABEL_MARGIN 8
#define EDIT_MARGIN 4
#define LABEL_HEIGHT 14
#define LABEL_V_SHIFT 14

@implementation IconsPanel

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE (icons);
  RELEASE (currentPath);
	RELEASE (nameEditor);
  TEST_RELEASE (horizontalImage);
  TEST_RELEASE (verticalImage);
  TEST_RELEASE (charBuffer);
  [super dealloc];
}

- (id)initAtPath:(NSString *)path
        delegate:(id)adelegate
{
  self = [super initWithFrame: NSZeroRect];
  
  if (self) {
    NSArray *pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, 
                                          GWRemoteFilenamesPboardType, nil];
  
    fm = [NSFileManager defaultManager];

    ASSIGN (currentPath, path);
		[self setDelegate: adelegate];
		
		cellsWidth = [delegate iconCellsWidth];
    [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];            
    icons = [[NSMutableArray alloc] initWithCapacity: 1]; 
    
    nameEditor = [[BNameEditor alloc] init];
    [nameEditor setDelegate: self];  
    [nameEditor setTarget: self]; 
    [nameEditor setAction: @selector(editorAction:)];  
    ASSIGN (editorFont, [NSFont systemFontOfSize: 12]); 
		[nameEditor setFont: editorFont];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSCenterTextAlignment];
	  [nameEditor setBackgroundColor: [NSColor whiteColor]];
    edIcon = nil;
    editingIcnName = NO;
    
		isDragTarget = NO;
    isShiftClick = NO;
    horizontalImage = nil;
    verticalImage = nil;
		lastKeyPressed = 0.;
    charBuffer = nil;
    selectInProgress = NO;
    
    contestualMenu = [[GWLib workspaceApp] usesContestualMenu];
    
  	[self registerForDraggedTypes: pbTypes];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(cellsWidthChanged:) 
                					    name: GWIconsCellsWidthChangedNotification
                					  object: nil];
  }
  
  return self;
}

- (void)setPath:(NSString *)path
{
  ASSIGN (currentPath, path);
  [self makeFileIcons];
}

- (void)setCurrentSelection:(NSArray *)paths
{
	if (selectInProgress) {
		return;
	}
	[delegate setTheSelectedPaths: [self currentSelection]];
  [self updateNameEditor];
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
      [delegate setTheSelectedPaths: selection];
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
    IconsViewerIcon *icon = [icons objectAtIndex: i];
    [[icon myLabel] removeFromSuperviewWithoutNeedingDisplay];
    [icon removeFromSuperviewWithoutNeedingDisplay];
  }
    
  [icons removeAllObjects];
  edIcon = nil;
  
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
    IconsViewerIcon *icon = [[IconsViewerIcon alloc] initForPath: ipath 
                                                        delegate: self];
    [icon setLocked: [GWLib isLockedPath: ipath]]; 
    [icons addObject: icon];  
    RELEASE (icon);
  }  
  
  for (i = 0; i < [icons count]; ++i) {
    IconsViewerIcon *icon = [icons objectAtIndex: i];
	  [self addSubview: icon];
	  [self addSubview: [icon myLabel]];  
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
  float py = FIRSTPOSY;
  NSSize sz;
  int poscount = 0;
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
		if (i > 0) {
			px += cellsWidth;      
    }
    if (px >= sfw - RIGHTMARGIN) {
      px = LEFTMARGIN; 
      py += ROWSHEIGHT;  

      if (iconsperrow < poscount) {
        iconsperrow = poscount;
      }
      poscount = 0;    
    }
		poscount++;

		irects[i] = NSMakeRect(px, py, ICNWIDTH, ICNHEIGHT);		
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
		IconsViewerIcon *icon = [icons objectAtIndex: i];
		irects[i].origin.y = py - irects[i].origin.y;
		[icon setFrame: irects[i]];
		[self setLabelRectOfIcon: icon];
	}

	NSZoneFree (NSDefaultMallocZone(), irects);

  [self updateNameEditor];
}

- (void)scrollFirstIconToVisible
{
  [self scrollRectToVisible: NSMakeRect(0, [self frame].size.height - 10, 10, 10)];
}

- (void)scrollToVisibleIconsWithPaths:(NSArray *)paths
{
  IconsViewerIcon *icon = [self iconWithPath: [paths objectAtIndex: 0]];

  if (icon) {
    NSRect vrect = [self visibleRect];
    NSRect r = NSUnionRect([icon frame], [[icon myLabel] frame]);  
    
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
    IconsViewerIcon *icon = [icons objectAtIndex: i];    
    if ([icon isSelect]) {
      [allpaths addObject: [icon path]];
    }
  } 
  
  if ([allpaths count] == 0) {
    return nil;
  }
    
  return allpaths;
}

- (IconsViewerIcon *)iconWithPath:(NSString *)path
{
  int i;

  for (i = 0; i < [icons count]; i++) {
    IconsViewerIcon *icon = [icons objectAtIndex: i];
  
    if ([[icon path] isEqual: path]) {
      return icon;
    }
  }
  
  return nil;
}

- (NSArray *)iconsWithPaths:(NSArray *)paths
{
  NSMutableArray *icnsarr = [NSMutableArray arrayWithCapacity: 1];
  int i;

  for (i = 0; i < [icons count]; i++) {
    IconsViewerIcon *icon = [icons objectAtIndex: i];
  
    if ([paths containsObject: [icon path]]) {
      [icnsarr addObject: icon];
    }
  }
    
  return ([icnsarr count]) ? icnsarr : nil;
}

- (void)selectIconWithPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    IconsViewerIcon *icon = [icons objectAtIndex: i];    
    
    if ([[icon path] isEqual: path]) {
      NSRect irect = NSUnionRect([icon frame], [[icon myLabel] frame]);  
      irect.origin.y -= ICON_FRAME_MARGIN;
      irect.size.height += ICON_FRAME_MARGIN * 2;
      [icon select];
			[self scrollRectToVisible: irect];	
      return;
    }
  }
}

- (void)selectIconsWithPaths:(NSArray *)paths
{
  int i;
  
  isShiftClick = YES;

  for (i = 0; i < [icons count]; i++) {
    IconsViewerIcon *icon = [icons objectAtIndex: i];    
    NSString *ipath = [icon path];

    if ([paths containsObject: ipath]) {
      [icon select];
    }
  }

  isShiftClick = NO;
}

- (NSString *)selectIconWithPrefix:(NSString *)prefix
{
	int i;

	for (i = 0; i < [icons count]; i++) {
		IconsViewerIcon *icon = [icons objectAtIndex: i];
    NSString *name = [icon myName];
		if ([name hasPrefix: prefix]) {
      NSRect irect = NSUnionRect([icon frame], [[icon myLabel] frame]);  
      irect.origin.y -= ICON_FRAME_MARGIN;
      irect.size.height += ICON_FRAME_MARGIN * 2;
			[icon select];
			[self scrollRectToVisible: irect];	
			return name;
		}
	}
  return nil;
}

- (void)selectIconInPrevLine
{
	IconsViewerIcon *icon;
  NSRect r[2];
  NSRect irect;
	int i, pos = -1;
  
	for (i = 0; i < [icons count]; i++) {
		icon = [icons objectAtIndex: i];
    
		if ([icon isSelect]) {
      r[0] = [icon frame];
      r[1] = [[icon myLabel] frame];
			pos = i - iconsperrow;
			break;
		}
	}
  
	if (pos >= 0) {
		icon = [icons objectAtIndex: pos];
		[icon select];
    [self setNeedsDisplayInRect: r[0]];
    [self setNeedsDisplayInRect: r[1]];
    
    irect = NSUnionRect([icon frame], [[icon myLabel] frame]);  
    irect.origin.y -= ICON_FRAME_MARGIN;
    irect.size.height += ICON_FRAME_MARGIN * 2;
    [self scrollRectToVisible: irect];
	}
}

- (void)selectIconInNextLine
{
	IconsViewerIcon *icon;
  NSRect r[2];
  NSRect irect;
	int i, pos = [icons count];
    
	for (i = 0; i < [icons count]; i++) {
		icon = [icons objectAtIndex: i];
		if ([icon isSelect]) {
      r[0] = [icon frame];
      r[1] = [[icon myLabel] frame];
			pos = i + iconsperrow;
			break;
		}
	}
  
	if (pos <= ([icons count] -1)) {
		icon = [icons objectAtIndex: pos];
		[icon select];
    [self setNeedsDisplayInRect: r[0]];
    [self setNeedsDisplayInRect: r[1]];
    
    irect = NSUnionRect([icon frame], [[icon myLabel] frame]);  
    irect.origin.y -= ICON_FRAME_MARGIN * 2;
    irect.size.height += ICON_FRAME_MARGIN * 4;
    [self scrollRectToVisible: irect];
	}
}

- (void)selectPrevIcon
{
	int i;
    
	for(i = 0; i < [icons count]; i++) {
		IconsViewerIcon *icon = [icons objectAtIndex: i];
    
		if([icon isSelect]) {
			if (i > 0) {
        NSRect irect = NSUnionRect([icon frame], [[icon myLabel] frame]); 
      
        icon = [icons objectAtIndex: i - 1];  
        [icon select];
        [self setNeedsDisplayInRect: irect];
        
        irect = NSUnionRect([icon frame], [[icon myLabel] frame]); 
        irect.origin.y -= ICON_FRAME_MARGIN;
        irect.size.height += ICON_FRAME_MARGIN * 2;
				[self scrollRectToVisible: irect];		
				break;
			} else {
				break;
			}
		}
	}
}

- (void)selectNextIcon
{
	int i, count = [icons count];
    
	for(i = 0; i < [icons count]; i++) {
		IconsViewerIcon *icon = [icons objectAtIndex: i];
    
		if([icon isSelect]) {
			if (i < (count - 1)) {
        NSRect irect = NSUnionRect([icon frame], [[icon myLabel] frame]); 
      
				icon = [icons objectAtIndex: i + 1];
        [icon select];
        [self setNeedsDisplayInRect: irect];
      
        irect = NSUnionRect([icon frame], [[icon myLabel] frame]); 
        irect.origin.y -= ICON_FRAME_MARGIN;
        irect.size.height += ICON_FRAME_MARGIN * 2;
				[self scrollRectToVisible: irect];		
				break;
			} else {
				break;
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
		IconsViewerIcon *icon = [icons objectAtIndex: i];
    
		if([icon isSelect] == NO) {
			[icon select];
    }
	}
  selectInProgress = NO;
  [self setCurrentSelection: [self currentSelection]];
	isShiftClick = NO;
}

- (void)unselectOtherIcons:(id)anIcon
{
  int i;
  
  if(isShiftClick == YES) {
    return;
  }
  
  for (i = 0; i < [icons count]; i++) {
    IconsViewerIcon *icon = [icons objectAtIndex: i];
    if (icon != anIcon) {  
      if ([icon isSelect]) {  
        [icon unselect];
      }
    }
  }  
}

- (void)extendSelectionWithDimmedFiles:(NSArray *)files 
                        startingAtPath:(NSString *)bpath
{
  if ([currentPath isEqual: bpath]) {
    [self addIconsWithNames: files dimmed: YES];

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

- (void)addIconWithPath:(NSString *)iconpath dimmed:(BOOL)isdimmed
{
  IconsViewerIcon *icon = [self iconWithPath: iconpath];
  
  if (icon) {
    [icon setLocked: isdimmed];  
  } else {
    icon = [[IconsViewerIcon alloc] initForPath: iconpath delegate: self];
    [icon setLocked: isdimmed]; 
    [icons addObject: icon];  
	  [self addSubview: icon];
	  [self addSubview: [icon myLabel]];
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
  IconsViewerIcon *icon = (IconsViewerIcon *)anIcon;
  [[icon myLabel] removeFromSuperview];
  [icon removeFromSuperview];
  [icons removeObject: icon];
	[self tile]; 
}

- (void)removeIconsWithNames:(NSArray *)names
{
  int i, count = [icons count];
  
  for (i = 0; i < count; i++) {
    IconsViewerIcon *icon = [icons objectAtIndex: i];
    NSString *name = [icon myName];

    if ([names containsObject: name] == YES) {
      [[icon myLabel] removeFromSuperview];
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
		IconsViewerIcon *icon = [icons objectAtIndex: i];
    if ([names containsObject: [icon myName]]) {
			[icon setLocked: YES];
    }
  }
  
  [self updateNameEditor];
}

- (void)unLockIconsWithNames:(NSArray *)names
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
		IconsViewerIcon *icon = [icons objectAtIndex: i];
    if ([names containsObject: [icon myName]]) {
			[icon setLocked: NO];
    }
  }
  
  [self updateNameEditor];
}

- (void)lockAllIcons
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
		IconsViewerIcon *icon = [icons objectAtIndex: i];
    if ([icon isLocked] == NO) {
			[icon setLocked: YES];
    }
  }
  
  [self updateNameEditor];
}

- (void)unLockAllIcons
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
		IconsViewerIcon *icon = [icons objectAtIndex: i];
    if ([icon isLocked]) {
			[icon setLocked: NO];
    }
  }
  
  [self updateNameEditor];
}

- (void)setLabelRectOfIcon:(id)anIcon
{
  IconsViewerIcon *icon = (IconsViewerIcon *)anIcon;	
	NSTextField *label = [icon myLabel];
	float icnwidth = [icon frame].size.width;
  float labwidth = [label frame].size.width;
  float labxpos = [icon frame].origin.x;

	if(icnwidth > labwidth) {
		labxpos += ((icnwidth - labwidth) / 2);
	} else {
		labxpos -= ((labwidth - icnwidth) / 2);
	}
	
	[label setFrame: NSMakeRect(labxpos, [icon frame].origin.y - LABEL_HEIGHT, 
                                                      labwidth, LABEL_HEIGHT)];
	[label setNeedsDisplay: YES];
}

- (int)cellsWidth
{
  return cellsWidth;
}

- (void)cellsWidthChanged:(NSNotification *)notification
{
  int i;
  
  cellsWidth = [(NSNumber *)[notification object] intValue];
	  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setLabelWidth];
  }
  
  [self tile];
}

- (void)setShiftClick:(BOOL)value
{
  isShiftClick = value;
}

- (void)openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv
{
	[delegate openTheCurrentSelection: [self currentSelection] newViewer: newv];
}

- (void)updateNameEditor
{
  NSArray *selection = [self currentSelection];
    
  if ([[self subviews] containsObject: nameEditor]) {
    NSRect edrect = [nameEditor frame];

    [nameEditor abortEditing];
    [nameEditor setName: nil paths: nil index: -1];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: edrect];
    editingIcnName = NO;
  }

  if (edIcon) {
    [edIcon setLabelWidth];
    [self setLabelRectOfIcon: edIcon];
  }

  if (selection && ([selection count] == 1)) {
    edIcon = [self iconWithPath: [selection objectAtIndex: 0]]; 
  } else {
    edIcon = nil;
  }
  
  if (edIcon) {
    NSString *path = [edIcon path];
    NSString *name = [edIcon myName];
    BOOL locked = [edIcon isLocked];
    NSRect r = [edIcon frame];
    float bw = [self bounds].size.width - EDIT_MARGIN;
    float centerx = r.origin.x + (r.size.width / 2);
    float labwidth = [editorFont widthOfString: name] + LABEL_MARGIN;

    [[edIcon myLabel] setFrame: NSMakeRect(centerx, r.origin.y, 1, 1)];

    if ((centerx + (labwidth / 2)) >= bw) {
      centerx -= (centerx + (labwidth / 2) - bw);
    } else if ((centerx - (labwidth / 2)) < LABEL_MARGIN) {
      centerx += fabs(centerx - (labwidth / 2)) + LABEL_MARGIN;
    }    
    
    r = NSMakeRect(centerx - (labwidth / 2), r.origin.y - LABEL_V_SHIFT, labwidth, LABEL_HEIGHT);
    [nameEditor setFrame: r];
    [nameEditor setName: name paths: [NSArray arrayWithObject: path] index: 0];
    [nameEditor setTextColor: (locked ? [NSColor disabledControlTextColor] 
																			          : [NSColor controlTextColor])];
    [nameEditor setEditable: !locked];
    [nameEditor setSelectable: !locked];	
    [self addSubview: nameEditor];
  }
}

- (void)editorAction:(id)sender
{
}

- (void)setDelegate:(id)anObject
{
  delegate = anObject;
}

- (id)delegate
{
  return delegate;
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
		[delegate setTheSelectedPaths: [NSArray arrayWithObject: currentPath]];
    [self updateNameEditor];
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
    IconsViewerIcon *icon = [icons objectAtIndex: i];
      
    if (NSIntersectsRect(selrect, [icon frame])) {
      [icon select];
    } 
  }  
  
  selectInProgress = NO;
  [self setCurrentSelection: [self currentSelection]];
  [self setShiftClick: NO];  
}

- (void)keyDown:(NSEvent *)theEvent 
{
  NSString *characters = [theEvent characters];  
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
	    [self selectIconInPrevLine];
      return;

    case NSDownArrowFunctionKey:
	    [self selectIconInNextLine];
      return;

    case NSLeftArrowFunctionKey:
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
	    		[self selectPrevIcon];
				}
			}
      return;

    case NSRightArrowFunctionKey:
			{
				if ([theEvent modifierFlags] & NSControlKeyMask) {
	      	[super keyDown: theEvent];
	    	} else {
	    		[self selectNextIcon];
				}
			}
	  	return;
      
    case 13:
      [self openCurrentSelection: [self currentSelection] newViewer: NO];      
      return;

    default:    
      break;
  }

  if ((character < 0xF700) && ([characters length] > 0)) {
		SEL icnwpSel = @selector(selectIconWithPrefix:);
		IMP icnwp = [self methodForSelector: icnwpSel];
    
    if (charBuffer == nil) {
      charBuffer = [characters substringToIndex: 1];
      RETAIN (charBuffer);
      lastKeyPressed = 0.;
    } else {
      if ([theEvent timestamp] - lastKeyPressed < 2000.0) {
        ASSIGN (charBuffer, ([charBuffer stringByAppendingString:
				    															[characters substringToIndex: 1]]));
      } else {
        ASSIGN (charBuffer, ([characters substringToIndex: 1]));
        lastKeyPressed = 0.;
      }														
    }	
    		
    lastKeyPressed = [theEvent timestamp];

    if ((*icnwp)(self, icnwpSel, charBuffer)) {
      return;
    }
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

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  static NSRect edr = {{0, 0}, {0, 0}};
  static float crx = 0;
  static float ory = 0;
  static float bw = 0;
  NSString *s;
  float labwidth;
  float labcenter;

  if (editingIcnName == NO) {
    edr = [edIcon frame];
    crx = edr.origin.x + (edr.size.width / 2);
    ory = [nameEditor frame].origin.y;
    bw = [self bounds].size.width - EDIT_MARGIN;
    editingIcnName = YES;
  }

  s = [nameEditor stringValue];
  labwidth = [editorFont widthOfString: s] + LABEL_MARGIN;
  
  labcenter = crx;


  while ((labcenter + (labwidth / 2)) > bw) {
    labcenter -= EDIT_MARGIN;  
    if (labcenter < EDIT_MARGIN) {
      break;
    }
  }
  
  while ((labcenter - (labwidth / 2)) < EDIT_MARGIN) {
    labcenter += EDIT_MARGIN;  
    if (labcenter >= bw) {
      break;
    }
  }
  
  [self setNeedsDisplayInRect: [nameEditor frame]];
  [nameEditor setFrame: NSMakeRect((labcenter - (labwidth / 2)), ory, labwidth, LABEL_HEIGHT)];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSString *oldpath = [[nameEditor paths] objectAtIndex: 0];
  NSString *basepath = [oldpath stringByDeletingLastPathComponent];
  NSString *oldname = [nameEditor name];
  NSString *newname = [nameEditor stringValue];
  NSString *newpath = [basepath stringByAppendingPathComponent: newname];

#define CLEAREDITING \
	[self updateNameEditor]; \
  return

  [nameEditor setAlignment: NSCenterTextAlignment];
    
  if ([fm isWritableFileAtPath: oldpath] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission\nfor ", @""), 
                      oldpath], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else if ([fm isWritableFileAtPath: basepath] == NO) {	
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission\nfor ", @""), 
                      basepath], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else {  
    NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*$|~\'\"`^!?"];
    NSRange range = [newname rangeOfCharacterFromSet: notAllowSet];
    NSArray *dirContents = [fm directoryContentsAtPath: basepath];
    NSMutableDictionary *notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];
    
    if (range.length > 0) {
      NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
                NSLocalizedString(@"Invalid char in name", @""), 
                          NSLocalizedString(@"Continue", @""), nil, nil);   
      CLEAREDITING;
    }	
        
    if ([dirContents containsObject: newname]) {
      if ([newname isEqualToString: oldname]) {
        CLEAREDITING;
      } else {
        NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\" %@\n", 
              NSLocalizedString(@"The name ", @""), 
              newname, NSLocalizedString(@" is already in use!", @"")], 
                            NSLocalizedString(@"Continue", @""), nil, nil);   
        CLEAREDITING;
      }
    }
    
	  [notifObj setObject: GWorkspaceRenameOperation forKey: @"operation"];	
    [notifObj setObject: oldpath forKey: @"source"];	
    [notifObj setObject: newpath forKey: @"destination"];	
    [notifObj setObject: [NSArray arrayWithObject: @""] forKey: @"files"];	

	  [[NSNotificationCenter defaultCenter]
 				   postNotificationName: GWFileSystemWillChangeNotification
	 								  object: notifObj];

    [fm movePath: oldpath toPath: newpath handler: self];

	  [[NSNotificationCenter defaultCenter]
 				   postNotificationName: GWFileSystemDidChangeNotification
	 								object: notifObj];
  }
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{
	NSString *title = NSLocalizedString(@"Error", @"");
	NSString *msg1 = NSLocalizedString(@"Cannot rename ", @"");
  NSString *name = [nameEditor name];
	NSString *msg2 = NSLocalizedString(@"Continue", @"");

  NSRunAlertPanel(title, [NSString stringWithFormat: @"%@'%@'!", msg1, name], msg2, nil, nil);   

	return NO;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

@end

@implementation IconsPanel (DraggingDestination)

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
// IconsViewerIcon Delegate Methods
//

@implementation IconsPanel (IconsViewerIconDelegateMethods)

- (int)getCellsWidth
{
	return cellsWidth;
}

- (void)setLabelFrameOfIcon:(id)aicon
{
	[self setLabelRectOfIcon: aicon];
}

- (void)unselectIconsDifferentFrom:(id)aicon
{
	[self unselectOtherIcons: aicon];
}

- (void)setShiftClickValue:(BOOL)value
{
	[self setShiftClick: value];
}

- (void)setTheCurrentSelection:(id)paths
{
	[self setCurrentSelection: paths];
}

- (NSArray *)getTheCurrentSelection
{
	return [self currentSelection];
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
