/* GWViewerIconsPath.h
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AppKit/AppKit.h>
#include <math.h>
#include "FSNIcon.h"
#include "FSNFunctions.h"
#include "GWViewerIconsPath.h"
#include "GWViewer.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

#define X_MARGIN (10)
#define Y_MARGIN (12)

#define EDIT_MARGIN (4)


@implementation GWViewerIconsPath

- (void)dealloc
{
  RELEASE (icons);
  TEST_RELEASE (extInfoType);
  RELEASE (labelFont);
  RELEASE (backColor);
  RELEASE (textColor);
  RELEASE (disabledTextColor);
  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
       visibleIcons:(int)vicns
          forViewer:(id)vwr
       ownsScroller:(BOOL)ownscr
{
  self = [super initWithFrame: frameRect]; 
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    id defentry;
    
    fsnodeRep = [FSNodeRep sharedInstance];
    
    visibleIcons = vicns;
    viewer = vwr;
    ownScroller = ownscr;
    
    firstVisibleIcon = 0;
    lastVisibleIcon = visibleIcons - 1;
    shift = 0;
   
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
      ASSIGN (backColor, [[NSColor windowBackgroundColor] colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    }

    defentry = [defaults dictionaryForKey: @"textcolor"];
    if (defentry) {
      float red = [[defentry objectForKey: @"red"] floatValue];
      float green = [[defentry objectForKey: @"green"] floatValue];
      float blue = [[defentry objectForKey: @"blue"] floatValue];
      float alpha = [[defentry objectForKey: @"alpha"] floatValue];
    
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

    icons = [NSMutableArray new];

    nameEditor = [FSNIconNameEditor new];
    [nameEditor setDelegate: self];  
		[nameEditor setFont: labelFont];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSCenterTextAlignment];
	  [nameEditor setBackgroundColor: backColor];
	  [nameEditor setTextColor: textColor];
    editIcon = nil;

    [self calculateGridSize];
  }
  
  return self;
}

- (void)setOwnsScroller:(BOOL)ownscr
{
  ownScroller = ownscr;
  [self setFrame: [[self superview] frame]];
  [self tile];
}

- (void)showPathComponents:(NSArray *)components
                 selection:(NSArray *)selection
{
  NSString *firstsel = [selection objectAtIndex: 0];
  FSNode *node = [FSNode nodeWithPath: firstsel];
  int count = [components count];
  FSNIcon *icon;
  int icncount;
  int i;
    
  while ([icons count] > count) {
    icon = [self lastIcon];
    if (icon) {
      [self removeRep: icon];
    }
  }

  icncount = [icons count];

  for (i = 0; i < [components count]; i++) {
    FSNode *component = [components objectAtIndex: i];
  
    if (i < icncount) {
      icon = [icons objectAtIndex: i];
      [icon setNode: component];
    } else {
      icon = [self addRepForSubnode: component];
    }
    
    [icon setLeaf: NO];
    [icon setNameEdited: NO];
    [icon setGridIndex: i];
  }

  if ([node isEqual: [components objectAtIndex: (count -1)]] == NO) {
    icon = [self addRepForSubnode: node];
  
    if ([selection count] > 1) {
      NSMutableArray *selnodes = [NSMutableArray array];
    
      for (i = 0; i < [selection count]; i++) {
        NSString *selpath = [selection objectAtIndex: i];
        FSNode *selnode = [FSNode nodeWithPath: selpath];
        [selnodes addObject: selnode];
      }
      
      [icon showSelection: selnodes];
    } 
  }
  
  icon = [self lastIcon];
  [icon setLeaf: YES];
  [icon select];
  
  editIcon = nil;
  
  [self tile];
}

- (void)setSelectableIconsRange:(NSRange)range
{
  int cols = range.length;

  if (cols != visibleIcons) {
    [self setFrame: [[self superview] frame]];
    visibleIcons = cols;  
  }

  firstVisibleIcon = range.location;
  lastVisibleIcon = firstVisibleIcon + visibleIcons - 1;
  shift = 0;

  if (([icons count] - 1) < lastVisibleIcon) {
    shift = lastVisibleIcon - [icons count] + 1;
  }
  
  [self tile];
}

- (int)firstVisibleIcon
{
  return firstVisibleIcon;
}

- (int)lastVisibleIcon
{
  return lastVisibleIcon;
}
                         
- (id)lastIcon
{
  int count = [icons count];
  return (count ? [icons objectAtIndex: (count - 1)] : nil);
}

- (void)updateLastIcon
{
  FSNIcon *icon = [self lastIcon];
  
  if (icon) {
    NSArray *selection = [icon selection];

    if (selection) {
      [icon showSelection: selection];
    } else {
      [icon setNode: [icon node]];
    }
  }
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

  labelSize.height = rintf([labelFont defaultLineHeightForFont]);
  gridSize.height = highlightSize.height + labelSize.height;
}

- (void)tile
{
  NSClipView *clip = [self superview];
  float vwidth = [clip visibleRect].size.width;
	int count = [icons count];
  int i;
    
  if (ownScroller) {
    NSRect fr = [self frame];
    float x = [clip bounds].origin.x;
    float y = [clip bounds].origin.y;
    float posx = 0.0;
    
    gridSize.width = rintf(vwidth / visibleIcons);
    [(NSScrollView *)[clip superview] setLineScroll: gridSize.width];
  
    for (i = 0; i < count; i++) {
      NSRect r = NSZeroRect;

      r.size = gridSize;
      r.origin.y = 0;
      r.origin.x = posx;
      
      [[icons objectAtIndex: i] setFrame: r];

      posx += gridSize.width;
    }
    
    if (posx != fr.size.width) {
      [self setFrame: NSMakeRect(0, fr.origin.y, posx, fr.size.height)];
    }

    if (count > visibleIcons) {    
      x += gridSize.width * count;
      [clip scrollToPoint: NSMakePoint(x, y)];
    }

  } else {
    vwidth -= visibleIcons;
    gridSize.width = rintf(vwidth / visibleIcons);
  
    for (i = 0; i < count; i++) {
      int n = i - firstVisibleIcon;
      NSRect r = NSZeroRect;

      r.size = gridSize;
      r.origin.y = 0;

      if (i < firstVisibleIcon) {
        r.origin.x = (n * gridSize.width) - 8;
      } else {
        if (i == firstVisibleIcon) {
          r.origin.x = (n * gridSize.width);
        } else if (i <= lastVisibleIcon) {
          r.origin.x = (n * gridSize.width) + n;
        } else {
          r.origin.x = (n * gridSize.width) + n + 8;
        }
	    }

      if (i == lastVisibleIcon) {
        r.size.width = [[self superview] visibleRect].size.width - r.origin.x;
	    }

      [[icons objectAtIndex: i] setFrame: r];
    }
  }

  [self stopRepNameEditing]; 
    
  [self setNeedsDisplay: YES];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self tile];
}

//
// scrollview delegate
//
- (void)gwviewerScroll:(GWViewerScroll *)sender 
    scrollViewScrolled:(NSClipView *)clip
               hitPart:(NSScrollerPart)hitpart
{
  int x = (int)[clip bounds].origin.x;
  int y = (int)[clip bounds].origin.y;
  int rem = x % (int)(rintf(gridSize.width));

  if (rem != 0) {
    if (rem <= gridSize.width / 2) {
      x -= rem;
    } else {
      x += rintf(gridSize.width) - rem;
    }

    [clip scrollToPoint: NSMakePoint(x, y)];    
    [self setNeedsDisplay: YES];
  }
}

@end


@implementation GWViewerIconsPath (NodeRepContainer)

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
  [icons addObject: icon];
  [self addSubview: icon];
  RELEASE (icon);
  
  return icon;
}

- (id)addRepForSubnodePath:(NSString *)apath
{
  FSNode *subnode = [FSNode nodeWithPath: apath];
  return [self addRepForSubnode: subnode];
}

- (void)removeRep:(id)arep
{
  if (arep == editIcon) {
    editIcon = nil;
  }
  [arep removeFromSuperviewWithoutNeedingDisplay];
  [icons removeObject: arep];
}

- (void)repSelected:(id)arep
{
  if (([arep isShowingSelection] == NO) && ((arep == [self lastIcon]) == NO)) {
    [viewer pathsViewDidSelectIcon: arep];
  } 
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

- (void)openSelectionInNewViewer:(BOOL)newv
{
  [viewer openSelectionInNewViewer: newv];
}

- (void)restoreLastSelection
{
  [[self lastIcon] select];
  [nameEditor setBackgroundColor: [NSColor selectedControlColor]];
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

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return NSDragOperationNone;
}

@end


@implementation GWViewerIconsPath (IconNameEditing)

- (void)setNameEditorForRep:(id)arep
{
  FSNode *node = [arep node];
  BOOL canedit = (([arep isLocked] == NO) 
                      && ([arep isShowingSelection] == NO)
                      && ([node isMountPoint] == NO) 
                      && (infoType == FSNInfoNameType));

  [self stopRepNameEditing];

  if (canedit) {   
    NSString *nodeDescr = [arep shownInfo];
    NSRect icnr = [arep frame];
    float centerx = icnr.origin.x + (icnr.size.width / 2);    
    NSRect labr = [arep labelRect];
    int margin = [fsnodeRep labelMargin];
    float bw = [self bounds].size.width - EDIT_MARGIN;
    float edwidth = 0.0; 
    NSFontManager *fmanager = [NSFontManager sharedFontManager];
    NSFont *edfont = [nameEditor font];
    NSRect edrect;
    
    editIcon = arep;    
    [editIcon setNameEdited: YES];
    
    if ([editIcon nodeInfoShowType] == FSNInfoExtendedType) {
      edfont = [fmanager convertFont: edfont 
                         toHaveTrait: NSItalicFontMask];
    } else {
      edfont = [fmanager convertFont: edfont 
                      toNotHaveTrait: NSItalicFontMask];
    }
    
    [nameEditor setFont: edfont];

    edwidth = [[nameEditor font] widthOfString: nodeDescr];
    edwidth += margin;

    if ((centerx + (edwidth / 2)) >= bw) {
      centerx -= (centerx + (edwidth / 2) - bw);
    } else if ((centerx - (edwidth / 2)) < margin) {
      centerx += fabs(centerx - (edwidth / 2)) + margin;
    }    

    edrect = [self convertRect: labr fromView: editIcon];
    edrect.origin.x = centerx - (edwidth / 2);
    edrect.size.width = edwidth;
    edrect = NSIntegralRect(edrect);
    
    [nameEditor setFrame: edrect];
    [nameEditor setAlignment: NSCenterTextAlignment];

    [nameEditor setNode: node 
            stringValue: nodeDescr
                  index: 0];

    [nameEditor setBackgroundColor: [NSColor selectedControlColor]];
    
    [nameEditor setEditable: YES];
    [nameEditor setSelectable: YES];	
    [self addSubview: nameEditor];  
  }
}

- (void)stopRepNameEditing
{
  int i;
  
  if ([[self subviews] containsObject: nameEditor]) {
    NSRect edrect = [nameEditor frame];
    [nameEditor abortEditing];
    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];
    [nameEditor setNode: nil stringValue: @"" index: -1];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: edrect];
    [[NSCursor arrowCursor] set];
  }

  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setNameEdited: NO];
  }
  
  editIcon = nil;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSRect icnr = [editIcon frame];
  float centerx = icnr.origin.x + (icnr.size.width / 2);
  float edwidth = [[nameEditor font] widthOfString: [nameEditor stringValue]]; 
  int margin = [fsnodeRep labelMargin];
  float bw = [self bounds].size.width - EDIT_MARGIN;
  NSRect edrect = [nameEditor frame];
  
  edwidth += margin;

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

  [self setNeedsDisplayInRect: [nameEditor frame]];
  [nameEditor setFrame: NSIntegralRect(edrect)];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSFileManager *fm = [NSFileManager defaultManager];
  FSNode *ednode = [nameEditor node];

#define CLEAREDITING \
  [self stopRepNameEditing]; \
  return 
  
  if ([ednode isWritable] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission for ", @""), 
                    [ednode name]], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else if ([fm isWritableFileAtPath: [ednode parentPath]] == NO) {
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), 
          [NSString stringWithFormat: @"%@\"%@\"!\n", 
              NSLocalizedString(@"You have not write permission for ", @""), 
                  [ednode parentName]], NSLocalizedString(@"Continue", @""), nil, nil);   
    CLEAREDITING;
    
  } else {
    NSString *newname = [nameEditor stringValue];
    NSString *newpath = [[ednode parentPath] stringByAppendingPathComponent: newname];
    NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*$|~\'\"`^!?"];
    NSRange range = [newname rangeOfCharacterFromSet: notAllowSet];
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

    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemWillChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];

    [fm movePath: [ednode path] toPath: newpath handler: self];

    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemDidChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];
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


@implementation GWViewerScroll

- (void)setDelegate:(id)anObject
{
  delegate = anObject;
}

- (id)delegate
{
  return delegate;
}

- (void)reflectScrolledClipView:(NSClipView *)aClipView
{
  [super reflectScrolledClipView: aClipView];  

  if (delegate) {
    NSScroller *scroller = [self horizontalScroller];
    NSScrollerPart hitPart = [scroller hitPart];

    [delegate gwviewerScroll: self 
          scrollViewScrolled: aClipView 
                     hitPart: hitPart];      
  }
}

@end













