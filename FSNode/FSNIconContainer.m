/* FSNIconContainer.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
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
#include "FSNIconContainer.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"
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

#define CHECK_SIZE(s) \
if (s.width < 1) s.width = 1; \
if (s.height < 1) s.height = 1; \
if (s.width > maxr.size.width) s.width = maxr.size.width; \
if (s.height > maxr.size.height) s.height = maxr.size.height

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: NSIntegralRect(rct)]; \
}

@implementation FSNIconContainer

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
  RELEASE (backColor);

  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
    NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];
    id defentry;

    if (appName && selName) {
      #ifdef GNUSTEP 
		  Class desktopAppClass = [[NSBundle mainBundle] principalClass];
      #else
		  Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
      #endif
      SEL sel = NSSelectorFromString(selName);

      desktopApp = [desktopAppClass performSelector: sel];
    }
  
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
      ASSIGN (backColor, [NSColor windowBackgroundColor]);
    }

    defentry = [defaults objectForKey: @"iconsize"];
    iconSize = defentry ? [defentry intValue] : DEF_ICN_SIZE;
    [FSNIcon setLabelFont: [NSFont systemFontOfSize: iconSize]];

    defentry = [defaults objectForKey: @"labeltxtsize"];
    labelTextSize = defentry ? [defentry intValue] : DEF_TEXT_SIZE;
    
    defentry = [defaults objectForKey: @"iconposition"];
    iconPosition = defentry ? [defentry intValue] : DEF_ICN_POS;
        
    defentry = [defaults objectForKey: @"fsn_info_type"];
    infoType = defentry ? [defentry intValue] : FSNInfoNameType;

    [FSNodeRep setUseThumbnails: [defaults boolForKey: @"use_thumbnails"]];
    
    icons = [NSMutableArray new];
        
    nameEditor = [FSNIconNameEditor new];
    [nameEditor setDelegate: self];  
		[nameEditor setFont: [FSNIcon labelFont]];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSCenterTextAlignment];
	  [nameEditor setBackgroundColor: backColor];
    editIcon = nil;
    
    isDragTarget = NO;
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                                NSFilenamesPboardType, 
                                                @"GWRemoteFilenamesPboardType", 
                                                nil]];    

    selectionMask = NSSingleSelectionMask;
    
    [self calculateGridSize];
  }
   
  return self;
}











- (void)sortIcons
{
  SEL compSel = [FSNodeRep compareSelectorForDirectory: [node path]];
  NSArray *sorted = [icons sortedArrayUsingSelector: compSel];

  [icons removeAllObjects];
  [icons addObjectsFromArray: sorted];
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

- (void)tile
{
  CREATE_AUTORELEASE_POOL (pool);
  NSRect svr = [[self superview] frame];
  NSRect r = [self frame];
  NSRect maxr = [[NSScreen mainScreen] frame];
	float px = X_MARGIN - gridSize.width;
  float py = gridSize.height + Y_MARGIN;
  NSSize sz;
  int poscount = 0;
	int count = [icons count];
	NSRect *irects = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * count);
  NSCachedImageRep *rep = nil;
  int i;

  colcount = 0;
  
	for (i = 0; i < count; i++) {
    px += gridSize.width;      
    
    if (px >= (svr.size.width - X_MARGIN)) {
      px = X_MARGIN; 
      py += (gridSize.height + Y_MARGIN);  

      if (colcount < poscount) { 
        colcount = poscount; 
      } 
      poscount = 0;    
    }
    
		poscount++;

		irects[i] = NSMakeRect(px, py, gridSize.width, gridSize.height);		
	}

	py += (gridSize.height / 2);  
  py = (py < svr.size.height) ? svr.size.height : py;

  SETRECT (self, r.origin.x, r.origin.y, svr.size.width, py);

	for (i = 0; i < count; i++) {   
		FSNIcon *icon = [icons objectAtIndex: i];
    
		irects[i].origin.y = py - irects[i].origin.y;
    irects[i] = NSIntegralRect(irects[i]);
    
    if (NSEqualRects(irects[i], [icon frame]) == NO) {
      [icon setFrame: irects[i]];
    }
    
    [icon setGridIndex: i];
	}

  DESTROY (horizontalImage);
  sz = NSMakeSize(svr.size.width, 2);
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
 
	NSZoneFree (NSDefaultMallocZone(), irects);
  
  RELEASE (pool);
  
  [self updateNameEditor];
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

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];
  [backColor set];
  NSRectFill(rect);
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}


//
// FSNodeRepContainer protocol
//
- (void)showContentsOfNode:(FSNode *)anode
{
  NSArray *subNodes = [anode subNodes];
  NSMutableArray *unsorted = [NSMutableArray array];
  SEL compSel;
  NSArray *sorted;
  int i;

  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] removeFromSuperview];
  }
  [icons removeAllObjects];
  
  if (node) {
    [desktopApp removeWatcherForPath: [node path]];
  }
  
  ASSIGN (node, anode);
  [desktopApp addWatcherForPath: [node path]];
    
  for (i = 0; i < [subNodes count]; i++) {
    FSNode *subnode = [subNodes objectAtIndex: i];
    FSNIcon *icon = [[FSNIcon alloc] initForNode: subnode
                                        iconSize: iconSize
                                    iconPosition: iconPosition
                                       gridIndex: -1
                                       dndSource: YES
                                       acceptDnd: YES];
    [unsorted addObject: icon];
    [self addSubview: icon];
    RELEASE (icon);
  }

  compSel = [FSNodeRep compareSelectorForDirectory: [node path]];
  sorted = [unsorted sortedArrayUsingSelector: compSel];
  [icons addObjectsFromArray: sorted];
  
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

- (void)setIconSize:(int)size
{
  int i;
  
  iconSize = size;
  [self calculateGridSize];
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setIconSize: iconSize];
  }
  
  [self tile];
}

- (int)iconSize
{
  return iconSize;
}

- (void)setLabelTextSize:(int)size
{
  int i;

  labelTextSize = size;
  [self calculateGridSize];

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setFont: [FSNIcon labelFont]];
  }

  [nameEditor setFont: [FSNIcon labelFont]];

  [self tile];
}

- (int)labelTextSize
{
  return labelTextSize;
}

- (void)setIconPosition:(int)pos
{
  int i;
  
  iconPosition = pos;
  [self calculateGridSize];
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setIconPosition: iconPosition];
  }
    
  [self tile];
}

- (int)iconPosition
{
  return iconPosition;
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
                                     gridIndex: -1
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
      [desktopApp selectionChanged: selection];
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
  [desktopApp openSelectionInNewViewer: newv];
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
  NSString *nodePath = [node path];
  NSString *prePath = [NSString stringWithString: nodePath];
  NSString *basePath;
  
	if ([names count] == 0) {
		return NO;
  } 

  if ([node isWritable] == NO) {
    return NO;
  }
    
  basePath = [[names objectAtIndex: 0] stringByDeletingLastPathComponent];
  if ([basePath isEqual: nodePath]) {
    return NO;
  }  
    
  if ([names containsObject: nodePath]) {
    return NO;
  }

  while (1) {
    if ([names containsObject: prePath]) {
      return NO;
    }
    if ([prePath isEqual: path_separator()]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  return YES;
}

- (void)setBackgroundColor:(NSColor *)acolor
{
  ASSIGN (backColor, acolor);
  [[self window] setBackgroundColor: backColor];
  [self setNeedsDisplay: YES];
}
                       
- (NSColor *)backgroundColor
{
  return backColor;
}

@end


@implementation FSNIconContainer (IconNameEditing)

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

    [nameEditor setEditable: ((locked == NO) && (infoType == FSNInfoNameType))];
    [nameEditor setSelectable: ((locked == NO) && (infoType == FSNInfoNameType))];	
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
    
    [desktopApp removeWatcherForPath: [node path]];
  
    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemWillChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];

    [fm movePath: [ednode path] toPath: newpath handler: self];

    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemDidChangeNotification"
	 								    object: nil 
                    userInfo: userInfo];
    
    [desktopApp addWatcherForPath: [node path]];
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






















