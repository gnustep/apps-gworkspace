/* IconsPath.m
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
#include "GWProtocol.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "BNameEditor.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/BNameEditor.h>
  #endif
#include "IconsPath.h"
#include "PathIcon.h"
#include "GNUstep.h" 

#define LABEL_MARGIN 8
#define EDIT_MARGIN 4
#define LABEL_HEIGHT 14
#define LABEL_V_SHIFT 14
#define ICON_VOFFSET 14
#define ICON_FRAME_HEIGHT 52
#define ICON_V_SHIFT 18
#define LABEL_VOFFSET 4
#define LABEL_HEIGHT 14
#define LAST_ICON_COMP 4

@implementation IconsPath

- (void)dealloc
{
  RELEASE (root);
  TEST_RELEASE (currentPath);
  RELEASE (icons);
	RELEASE (nameEditor);
  RELEASE (editorFont);  
  [super dealloc];
}

- (id)initWithRootAtPath:(NSString *)rpath 
        		columnsWidth:(float)cwidth
						    delegate:(id)adelegate
{
  self = [super init];
  
  if (self) {
    ASSIGN (root, rpath);
    columnsWidth = cwidth;
		[self setDelegate: adelegate];
    [self setAutoresizingMask: (NSViewWidthSizable)];
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
  }
   
  return self; 
}

- (void)setIconsForSelection:(NSArray *)selection
{
  NSString *fullPath;
  NSArray *components;
  NSMutableArray *subpaths;
  NSString *path;
  PathIcon *icon;
  int i, count;

  fullPath = [NSString stringWithString: [selection objectAtIndex: 0]]; 
  subpaths = [NSMutableArray arrayWithCapacity: 1];  
  path = [NSString string];     
  components = [fullPath pathComponents];  
  
  for (i = 0; i < [components count]; i++) {
    path = [path stringByAppendingPathComponent: [components objectAtIndex: i]];
    if (subPathOfPath(path, root) == NO) {
      [subpaths addObject: path];     
    }
  }

  count = [subpaths count];
  [self renewIcons: count];  
  
  for (i = 0; i < count; i++) {
    icon = [icons objectAtIndex: i];  
    [icon setBranch: YES];
    [icon setPaths: [NSArray arrayWithObject: [subpaths objectAtIndex: i]]];
  }
	
	if (count > 0) {
  	icon = [icons objectAtIndex: count - 1];
  	[icon setBranch: NO];
  	[icon setPaths: selection];
  	[icon select];
  }
	
  [self setIconsPositions];
}

- (void)setColumnWidth:(float)width
{
  columnsWidth = width;
  [self setIconsPositions];
}

- (void)renewIcons:(int)n
{
  while ([icons count] > n) {
    PathIcon *icon = [self lastIcon];
    
    if (icon) {
      [self removeIcon: icon];
    }
  }
  while ([icons count] < n) {  
    [self addIcon];
  } 
}

- (void)addIcon
{
  PathIcon *icon = [[PathIcon alloc] initWithDelegate: self];
  [self addSubview: icon];
  [self addSubview: [icon label]];  
  [icons addObject: icon];
  RELEASE (icon);
  [self setIconsPositions];  
}

- (void)removeIcon:(PathIcon *)icon
{
	NSTextField *label = [icon label];
	[label setDelegate: nil];
	[label setEditable: NO];
  [label removeFromSuperview];
  [icon removeFromSuperview];
  [icons removeObject: icon];
	[self setIconsPositions];  
}

- (void)removeIconAtIndex:(int)index
{
  [self removeIcon: [self iconAtIndex: index]];
}

- (void)lockIconsFromPath:(NSString *)path
{
  int index = [self indexOfIconWithPath: path];
  
  if (index != -1) {
    int i;
  
    for (i = index + 1; i < [icons count]; i++) {
      [[icons objectAtIndex: i] setLocked: YES];
    }
  }
}

- (void)unlockIconsFromPath:(NSString *)path
{
  int index = [self indexOfIconWithPath: path];
  
  if (index != -1) {
    int i;
  
    for (i = index; i < [icons count]; i++) {
      [[icons objectAtIndex: i] setLocked: NO];
    }
  }
}

- (void)setIconsPositions
{
  float posx = 0.0;
	int count = [icons count];
  int i;
  
	for (i = 0; i < count; i++) {
		PathIcon *icon = [icons objectAtIndex: i];
    NSRect r = NSMakeRect(posx, ICON_V_SHIFT, columnsWidth, ICON_FRAME_HEIGHT);
        
    if (i == (count - 1)) {
      r.size.width -= LAST_ICON_COMP;
    }
    
    [icon setFrame: r];
    [icon setNeedsDisplay: YES];
    posx += columnsWidth;
  }
  
  posx -= LAST_ICON_COMP;
    
  if (posx != [self frame].size.width) {
    [self setFrame: NSMakeRect(0, 0, posx, 70)];
  }

  [self updateNameEditor];
    
	[self setNeedsDisplay: YES];
}

- (void)setLabelRectOfIcon:(PathIcon *)icon
{
	NSTextField *label;
	float labwidth, labxpos;
  NSRect labelRect;
  
	label = [icon label];
 	labwidth = [label frame].size.width;

	if(columnsWidth > labwidth) {
		labxpos = [icon frame].origin.x + ((columnsWidth - labwidth) / 2);
	} else {
		labxpos = [icon frame].origin.x - ((labwidth - columnsWidth) / 2);
  }
  
	labelRect = NSMakeRect(labxpos, LABEL_VOFFSET, labwidth, LABEL_HEIGHT);
	[label setFrame: labelRect];
  [label setNeedsDisplay: YES];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self setIconsPositions];
}

- (void)unselectOtherIcons:(PathIcon *)icon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    PathIcon *icn = [icons objectAtIndex: i];
    if (icn != icon) {    
      [icn unselect];
    }
  }
}

- (void)selectIconAtIndex:(int)index
{
  if (index < [icons count]) {
    [[icons objectAtIndex: index] select];
  }
}

- (void)startEditing
{
  [nameEditor selectText: nil];
}

- (NSArray *)icons
{
  return icons;
}

- (PathIcon *)iconAtIndex:(int)index
{
  if (index < [icons count]) {
    return [icons objectAtIndex: index];
  }
  return nil;
}

- (int)indexOfIcon:(PathIcon *)icon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    PathIcon *icn = [icons objectAtIndex: i];  
    if (icn == icon) {    
      return i;
    }
  }
  
  return i;
}

- (int)indexOfIconWithPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    PathIcon *icon = [icons objectAtIndex: i];
    NSArray *ipaths = [icon paths];
    if (ipaths && [ipaths containsObject: path]) {
      return i;
    }
  }
  
  return -1;
}

- (PathIcon *)iconWithPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    PathIcon *icon = [icons objectAtIndex: i];
    NSArray *ipaths = [icon paths];
    if (ipaths && [ipaths containsObject: path]) {
      return icon;
    }
  }
  
  return nil;
}

- (PathIcon *)lastIcon
{
  int count = [icons count];
  
  if(count) {
    return [icons objectAtIndex: count - 1];
  }
  
  return nil;
}

- (NSPoint)positionOfLastIcon
{
  PathIcon *icon = [self lastIcon];
  
  if (icon) {
    NSRect r = [icon frame];
    NSSize s = [icon iconShift];
    float xshift = fabs([self visibleRect].origin.x);

    return NSMakePoint(r.origin.x + s.width - xshift, 
                              r.origin.y + s.height + ICON_VOFFSET);
  }
  
  return NSZeroPoint;
}

- (NSPoint)positionForSlidedImage
{
  return [self positionOfLastIcon];
}

- (int)numberOfIcons
{
  return [icons count];
}

- (void)updateNameEditor
{
  PathIcon *icon = [self lastIcon];
  
  if (icon == nil) {
    return;
  }
  
  if ([[self subviews] containsObject: nameEditor]) {
    NSRect edrect = [nameEditor frame];
    
    [nameEditor abortEditing];
    [nameEditor setName: nil paths: nil index: -1];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: edrect];
    edIcon = nil;
  } 
  
  if (icon) {
    NSArray *paths = [icon paths];
    NSString *name = [icon isRootIcon] ? [icon hostname] : [icon name];
    BOOL locked = [icon isLocked];
    BOOL canedit = ((!locked) && (paths && [paths count] == 1) && (![icon isRootIcon]));
    NSRect r = [icon frame];
    float bw = [self bounds].size.width - EDIT_MARGIN;
    float centerx = r.origin.x + (r.size.width / 2);
    float labwidth = [editorFont widthOfString: name] + LABEL_MARGIN;
    int index = [icons count] - 1;

    [[icon label] setFrame: NSMakeRect(centerx, r.origin.y, 1, 1)];
    
    if ((centerx + (labwidth / 2)) >= bw) {
      centerx -= (centerx + (labwidth / 2) - bw);
    } else if ((centerx - (labwidth / 2)) < LABEL_MARGIN) {
      centerx += fabs(centerx - (labwidth / 2)) + LABEL_MARGIN;
    }    

    r = NSMakeRect(centerx - (labwidth / 2), r.origin.y - LABEL_V_SHIFT, labwidth, LABEL_HEIGHT);
    [nameEditor setFrame: r];
    [nameEditor setName: name paths: paths index: index];
    [nameEditor setBackgroundColor: [NSColor whiteColor]];
    [nameEditor setTextColor: (locked ? [NSColor disabledControlTextColor] 
																			          : [NSColor controlTextColor])];
    [nameEditor setEditable: canedit];
    [nameEditor setSelectable: canedit];	
    [self addSubview: nameEditor];
  }
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
  
  if (edIcon == nil) {
    edIcon = [self lastIcon]; 
    edr = [edIcon frame];
    crx = edr.origin.x + (edr.size.width / 2);
    ory = [nameEditor frame].origin.y;
    bw = [self bounds].size.width - EDIT_MARGIN;
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
  NSFileManager *fm = [NSFileManager defaultManager];

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

    [self updateNameEditor];
  }
}

- (void)editorAction:(id)sender
{
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

- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)anObject
{
	delegate = anObject;
}

@end

//
// PathIcon Delegate Methods
//

@implementation IconsPath (PathIconDelegateMethods)

- (void)setLabelFrameOfIcon:(id)anicon
{
	[self setLabelRectOfIcon: anicon];
}

- (void)unselectIconsDifferentFrom:(id)anicon
{
	[self unselectOtherIcons: anicon];
}

- (void)clickedIcon:(id)anicon
{
	[delegate clickedIcon: anicon];
}

- (void)doubleClickedIcon:(id)anicon newViewer:(BOOL)isnew
{
	[delegate doubleClickedIcon: anicon newViewer: isnew];
}

- (void)unselectNameEditor
{
  [nameEditor setBackgroundColor: [NSColor windowBackgroundColor]];
  [self setNeedsDisplayInRect: [nameEditor frame]];
}

- (void)restoreSelectionAfterDndOfIcon:(id)dndicon
{
  PathIcon *icon = [self lastIcon];

  if (icon) {
    [icon select];
  }
  
  [nameEditor setBackgroundColor: [NSColor whiteColor]];
  [self updateNameEditor];
}

@end
