/* GWViewerIconsPath.m
 *  
 * Copyright (C) 2004-2022 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
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
#include <sys/types.h>
#include <unistd.h>

#import <AppKit/AppKit.h>

#import "FSNIcon.h"
#import "FSNFunctions.h"
#import "GWViewerIconsPath.h"
#import "GWViewer.h"
#import "GWorkspace.h"

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
  RELEASE (extInfoType);
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

    icons = [NSMutableArray new];

    nameEditor = [FSNIconNameEditor new];
    [nameEditor setDelegate: self];  
		[nameEditor setFont: labelFont];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSCenterTextAlignment];
	  [nameEditor setBackgroundColor: backColor];
	  [nameEditor setTextColor: textColor];
    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];
    editIcon = nil;

    [self calculateGridSize];
  }
  
  return self;
}

- (void)setOwnsScroller:(BOOL)ownscr
{
  ownScroller = ownscr;
  [self setFrame: [[self superview] bounds]];
  [self tile];
}

- (void)showPathComponents:(NSArray *)components
                 selection:(NSArray *)selection
{
  FSNode *node = [selection objectAtIndex: 0];
  int count = [components count];
  FSNIcon *icon;
  int icncount;
  int i;

  [self stopRepNameEditing]; 
    
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
        FSNode *selnode = [selection objectAtIndex: i];
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
    [self setFrame: [[self superview] bounds]];
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

  labelSize.height = myrintf([fsnodeRep heightOfFont: labelFont]);
  gridSize.height = highlightSize.height + labelSize.height;
}

- (void)tile
{
  NSClipView *clip = (NSClipView *)[self superview];
  float vwidth = [clip visibleRect].size.width;
	int count = [icons count];
  int i;    
    
  if (ownScroller) {
    NSRect fr = [self frame];
    float x = [clip bounds].origin.x;
    float y = [clip bounds].origin.y;
    float posx = 0.0;
    
    gridSize.width = myrintf(vwidth / visibleIcons);
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
    gridSize.width = myrintf(vwidth / visibleIcons);
  
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

  [self updateNameEditor]; 
       
  [self setNeedsDisplay: YES];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self tile];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  NSPoint location = [theEvent locationInWindow];
  NSPoint selfloc = [self convertPoint: location fromView: nil];

  if (editIcon && [self mouse: selfloc inRect: [editIcon frame]]) {
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
      NSAutoreleasePool *pool;

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

      pool = [NSAutoreleasePool new];

      while ((key = [app_enum nextObject])) {
        menuItem = [NSMenuItem new];    
        key = [key stringByDeletingPathExtension];
        [menuItem setTitle: key];
        [menuItem setTarget: [GWorkspace gworkspace]];      
        [menuItem setAction: @selector(openSelectionWithApp:)];      
        [menuItem setRepresentedObject: key];            
        [menu addItem: menuItem];
        RELEASE (menuItem);
      }

      RELEASE (pool);

      return [menu autorelease];
    }
  }
     
  return [super menuForEvent: theEvent]; 
}

//
// scrollview delegate
//
- (void)gwviewerPathsScroll:(GWViewerPathsScroll *)sender 
         scrollViewScrolled:(NSClipView *)clip
                    hitPart:(NSScrollerPart)hitpart
{
  if (hitpart != NSScrollerNoPart) {
    int x = (int)[clip bounds].origin.x;
    int y = (int)[clip bounds].origin.y;
    int rem = x % (int)(myrintf(gridSize.width));

    [self stopRepNameEditing]; 

    if (rem != 0) {
      if (rem <= gridSize.width / 2) {
        x -= rem;
      } else {
        x += myrintf(gridSize.width) - rem;
      }

      [clip scrollToPoint: NSMakePoint(x, y)];      
      [self setNeedsDisplay: YES];
    }

    editIcon = [self lastIcon];
    if (editIcon && NSContainsRect([editIcon visibleRect], [editIcon iconBounds])) {
      [self updateNameEditor]; 
    }
  }
}

@end


@implementation GWViewerIconsPath (NodeRepContainer)

- (FSNode *)baseNode
{
  return [viewer baseNode];  
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

- (NSArray *)selectedNodes
{
  NSMutableArray *selectedNodes = [NSMutableArray array];
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      NSArray *selection = [icon selection];
      
      if (selection) {
        [selectedNodes addObjectsFromArray: selection];
      } else {
        [selectedNodes addObject: [icon node]];
      }
    }
  }

  return [selectedNodes makeImmutableCopyOnFail: NO];
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

  return [selectedPaths makeImmutableCopyOnFail: NO];
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

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return NSDragOperationNone;
}

@end


@implementation GWViewerIconsPath (IconNameEditing)

- (void)updateNameEditor
{
  [self stopRepNameEditing];

  editIcon = [self lastIcon];

  if (editIcon && NSContainsRect([editIcon visibleRect], [editIcon iconBounds])) {
    FSNode *ednode = [editIcon node];
    NSString *nodeDescr = [editIcon shownInfo];
    NSRect icnr = [editIcon frame];
    CGFloat centerx = icnr.origin.x + (icnr.size.width / 2);    
    NSRect labr = [editIcon labelRect];
    int margin = [fsnodeRep labelMargin];
    CGFloat bw = [self bounds].size.width - EDIT_MARGIN;
    CGFloat edwidth = 0.0; 
    NSRect edrect;

    [editIcon setNameEdited: YES];

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
    [nameEditor setNode: ednode 
            stringValue: nodeDescr];

    [nameEditor setBackgroundColor: [NSColor selectedControlColor]];

    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];	
    [self addSubview: nameEditor];  
  }
}

- (void)setNameEditorForRep:(id)arep
{
  [self updateNameEditor];
}

- (void)stopRepNameEditing
{
  int i;
  
  if ([[self subviews] containsObject: nameEditor]) {
    NSRect edrect = [nameEditor frame];
    [nameEditor abortEditing];
    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];
    [nameEditor setNode: nil stringValue: @""];
    [nameEditor removeFromSuperview];
    [self setNeedsDisplayInRect: edrect];
  }

  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setNameEdited: NO];
  }
  
  editIcon = nil;
}

- (BOOL)canStartRepNameEditing
{
  return (editIcon && ([editIcon isLocked] == NO) 
                && ([editIcon isShowingSelection] == NO)
                && ([[editIcon node] isMountPoint] == NO) 
                && (infoType == FSNInfoNameType));
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
  FSNode *ednode = [nameEditor node];

  if ([ednode isParentWritable] == NO)
    {
      showAlertNoPermission([FSNode class], [ednode parentName]);
      [self updateNameEditor];
      return;
    }
  if ([ednode isSubnodeOfPath: [[GWorkspace gworkspace] trashPath]])
    {
      showAlertInRecycler([FSNode class]);
      [self updateNameEditor];
      return;
    } 
  else
    {
      NSString *newname = [nameEditor stringValue];
      NSString *newpath = [[ednode parentPath] stringByAppendingPathComponent: newname];
      NSString *extension = [newpath pathExtension];
      NSCharacterSet *notAllowSet = [NSCharacterSet characterSetWithCharactersInString: @"/\\*:?\33"];
      NSRange range = [newname rangeOfCharacterFromSet: notAllowSet];
      NSArray *dirContents = [ednode subNodeNamesOfParent];
      NSMutableDictionary *opinfo = [NSMutableDictionary dictionary];
      
      if (([newname length] == 0) || (range.length > 0))
        {
	  showAlertInvalidName([FSNode class]);
	  [self updateNameEditor];
          return;
        }	
      
      if (([extension length] 
           && ([ednode isDirectory] && ([ednode isPackage] == NO))))
        {
          if (showAlertExtensionChange([FSNode class], extension) == NSAlertDefaultReturn)
            {
	      [self updateNameEditor];
	      return;
	    }
        }
      
      if ([dirContents containsObject: newname])
        {
          if ([newname isEqual: [ednode name]])
            {
              [self updateNameEditor];
              return;
            }
          else
            {
              showAlertNameInUse([FSNode class], newname);
              [self updateNameEditor];
              return;
            }
        }
      
      [opinfo setObject: @"GWorkspaceRenameOperation" forKey: @"operation"];	
      [opinfo setObject: [ednode path] forKey: @"source"];	
      [opinfo setObject: newpath forKey: @"destination"];	
      [opinfo setObject: [NSArray arrayWithObject: @""] forKey: @"files"];	
      
      [self stopRepNameEditing];
      [[GWorkspace gworkspace] performFileOperation: opinfo];         
    }
}

@end


@implementation GWViewerPathsScroll

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

    [delegate gwviewerPathsScroll: self 
               scrollViewScrolled: aClipView 
                          hitPart: hitPart];      
  }
}

@end













