/* FSNBrowserCell.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "FSNBrowserCell.h"
#import "FSNode.h"

#define DEFAULT_ISIZE (16)
#define HLIGHT_H_FACT (0.8125)

static id <DesktopApplication> desktopApp = nil;

static NSString *dots = @"...";

@implementation FSNBrowserCell

- (void)dealloc
{
  RELEASE (selection);
  RELEASE (selectionTitle);
  RELEASE (uncutTitle);
  RELEASE (extInfoType);
  RELEASE (infoCell); 
  RELEASE (icon); 
  RELEASE (selectedicon); 
  
  [super dealloc];
}

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO) {
    if (desktopApp == nil) {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
      NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];

      if (appName && selName) {
        Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
        SEL sel = NSSelectorFromString(selName);
        desktopApp = [desktopAppClass performSelector: sel];
      }
    }
   
    initialized = YES;
  }
}

- (id)init
{
  self = [super init];
  
  if (self)
    {
      node = nil;
      selection = nil;
      selectionTitle = nil;
      showType = FSNInfoNameType;
      extInfoType = nil;
      icon = nil;
      selectedicon = nil;
      icnsize = DEFAULT_ISIZE;
      
      isLocked = NO;
      iconSelected = NO;
      isOpened = NO;
      nameEdited = NO;
      
      [self setAllowsMixedState: NO];
      
      fsnodeRep = [FSNodeRep sharedInstance];
    }
  
  return self;
}

- (void)setIcon
{
  if (node) {
    ASSIGN (icon, [fsnodeRep iconOfSize: icnsize forNode: node]);
    icnh = [icon size].height;
    DESTROY (selectedicon);
  }
}

- (NSString *)path
{
  if (node) {
    return [node path];
  }
  return nil;
}

- (BOOL)selectIcon
{
  if (iconSelected) {
    return NO;
  }
  
  if (selectedicon == nil) {
    NSImage *opicn = [fsnodeRep openFolderIconOfSize: icnsize forNode: node];

    if (opicn) {
      ASSIGN (selectedicon, opicn);
      icnh = [selectedicon size].height;
    }
  }
  
  iconSelected = YES;
  return YES;
}

- (BOOL)unselectIcon
{
  if (iconSelected == NO) {
    return NO;
  }
  iconSelected = NO;
  return YES;
}

- (NSString *)cutTitle:(NSString *)title 
            toFitWidth:(float)width
{
  NSDictionary *fontAttr;

  fontAttr = [NSDictionary dictionaryWithObject: [NSFont systemFontOfSize: 12]
			   forKey: NSFontAttributeName];

  if ([title sizeWithAttributes: fontAttr].width > width) {
    int tl = [title length];
  
    if (tl <= 5) {
      return dots;
    } else {
      int fpto = (tl / 2) - 2;
      int spfr = fpto + 3;
      NSString *fp = [title substringToIndex: fpto];
      NSString *sp = [title substringFromIndex: spfr];
      NSString *dotted = [NSString stringWithFormat: @"%@%@%@", fp, dots, sp];
      int dl = [dotted length];
      float dotl = [dotted sizeWithAttributes: fontAttr].width;
      int p = 0;

      while (dotl > width) {
        if (dl <= 5) {
          return dots;
        }        

        if (p) {
          fpto--;
        } else {
          spfr++;
        }
        p = !p;

        fp = [title substringToIndex: fpto];
        sp = [title substringFromIndex: spfr];
        dotted = [NSString stringWithFormat: @"%@%@%@", fp, dots, sp];
        dotl = [dotted sizeWithAttributes: fontAttr].width;
        dl = [dotted length];
      }      
      
      return dotted;
    }
  }
  
  return title;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame 
		                   inView:(NSView *)controlView
{
#define MARGIN (2.0)
#define LEAF_MARGIN (5.0)

  NSWindow *cvwin = [controlView window];

  if (cvwin) {
    NSColor *backcolor = [cvwin backgroundColor];
    float textlenght = cellFrame.size.width;
    BOOL showsFirstResponder = [self showsFirstResponder];
    int infoheight = 0;

    titleRect = cellFrame;

    if (icon) {
      textlenght -= ([icon size].width + (MARGIN * 2));
    }
    if ([self isLeaf]) {
      textlenght -= LEAF_MARGIN; 
    } else {
      textlenght -= (LEAF_MARGIN + 16); 
    }

    textlenght -= MARGIN;
    ASSIGN (uncutTitle, [self stringValue]);
    [self setStringValue: [self cutTitle:uncutTitle toFitWidth:textlenght]];        

    [self setShowsFirstResponder: NO];

    if (icon == nil) {
      if (nameEdited == NO) {
        if (infoCell) {
          infoheight = floor([[FSNodeRep sharedInstance] heightOfFont: [infoCell font]]);

          if (([self isHighlighted] || [self state]) && (nameEdited == NO)) {
	          [[self highlightColorInView: controlView] set];
            NSRectFill(cellFrame);
          }

          titleRect.size.height -= infoheight;

          if ([controlView isFlipped]) {
            titleRect.origin.y += cellFrame.size.height;
            titleRect.origin.y -= (titleRect.size.height + infoheight);
          } else {
            titleRect.origin.y += infoheight;
          }

          [super drawInteriorWithFrame: titleRect inView: controlView];

        } else {
          [super drawInteriorWithFrame: titleRect inView: controlView];
        }

      } else {
        [backcolor set];
        NSRectFill(cellFrame);
      }

      if (infoCell) {
        infoRect = NSMakeRect(cellFrame.origin.x + 2, cellFrame.origin.y + 3,
                                        cellFrame.size.width - 2, infoheight);

        if ([controlView isFlipped]) {
	        infoRect.origin.y += (cellFrame.size.height - infoRect.size.height);
          infoRect.origin.y -= 6;
        }

        [infoCell drawInteriorWithFrame: infoRect inView: controlView];
      } 

    } else {
      NSRect icon_rect;    

      if (([self isHighlighted] || [self state]) && (nameEdited == NO)) {
	      [[self highlightColorInView: controlView] set];
        NSRectFill(cellFrame);
      } 
	    
      if (infoCell) {
        titleRect.size.height -= infoheight;

        if ([controlView isFlipped]) {
          titleRect.origin.y += cellFrame.size.height;
          titleRect.origin.y -= (titleRect.size.height + infoheight);
        } else {
          titleRect.origin.y += infoheight;
        }
      }

      icon_rect.origin = titleRect.origin;
      icon_rect.size = NSMakeSize(icnsize, icnh);
      icon_rect.origin.x += MARGIN;
      icon_rect.origin.y += ((titleRect.size.height - icon_rect.size.height) / 2.0);

      if ([controlView isFlipped]) {
        if (infoCell) {
          icon_rect.origin.y += cellFrame.size.height;
          icon_rect.origin.y -= (titleRect.size.height + infoheight);
        }

	      icon_rect.origin.y += icon_rect.size.height;
      }

      titleRect.origin.x += (icon_rect.size.width + (MARGIN * 2));	
      titleRect.size.width -= (icon_rect.size.width + (MARGIN * 2));	

      if (nameEdited == NO) {        
        [super drawInteriorWithFrame: titleRect inView: controlView];
      }

      if (infoCell) {
        infoRect = NSMakeRect(cellFrame.origin.x + 2, cellFrame.origin.y + 3,
                                        cellFrame.size.width - 2, infoheight);

        if ([controlView isFlipped]) {
	        infoRect.origin.y += (cellFrame.size.height - infoRect.size.height);
          infoRect.origin.y -= 6;
        }

        [infoCell drawInteriorWithFrame: infoRect inView: controlView];
      }

      [controlView lockFocus];

      if ([self isEnabled]) {
        if (iconSelected) {
          if (isOpened == NO) {	
            [selectedicon compositeToPoint: icon_rect.origin 
	                           operation: NSCompositeSourceOver];
          } else {
            [selectedicon dissolveToPoint: icon_rect.origin fraction: 0.5];
          }
        } else {
          if (isOpened == NO) {	
            [icon compositeToPoint: icon_rect.origin 
	                       operation: NSCompositeSourceOver];
          } else {              
            [icon dissolveToPoint: icon_rect.origin fraction: 0.5];
          }
        }
      } else {
			  [icon dissolveToPoint: icon_rect.origin fraction: 0.3];
      }

      [controlView unlockFocus];
    }

    if (showsFirstResponder) {
      [self setShowsFirstResponder: showsFirstResponder];
      NSDottedFrameRect(cellFrame);
    }

    [self setStringValue: uncutTitle]; 
  }         
}


//
// FSNodeRep protocol
//
- (void)setNode:(FSNode *)anode
{
  DESTROY (selection);
  DESTROY (selectionTitle);
  ASSIGN (node, anode);

  [self setIcon];
  
  if (extInfoType) {
    [self setExtendedShowType: extInfoType];
  } else {
    [self setNodeInfoShowType: showType];  
  }
  
  [self setLocked: [node isLocked]];
}

- (void)setNode:(FSNode *)anode
   nodeInfoType:(FSNInfoType)type
   extendedType:(NSString *)exttype
{
  [self setNode: anode];

  if (exttype) {
    [self setExtendedShowType: exttype];
  } else {
    [self setNodeInfoShowType: type];  
  }
}

- (FSNode *)node
{
  return node;
}

- (void)showSelection:(NSArray *)selnodes
{
  NSUInteger i;

  ASSIGN (node, [selnodes objectAtIndex: 0]);
  ASSIGN (selection, selnodes);
  if (icon) {
    ASSIGN (icon, [fsnodeRep multipleSelectionIconOfSize: icnsize]);
    icnh = [icon size].height;
  }  
  ASSIGN (selectionTitle, ([NSString stringWithFormat: @"%lu %@", 
                                     (unsigned long)[selection count], NSLocalizedString(@"elements", @"")]));
  [self setStringValue: selectionTitle];

  [self setLocked: NO];
  for (i = 0; i < [selnodes count]; i++) {
    if ([fsnodeRep isNodeLocked: [selnodes objectAtIndex: i]]) {
      [self setLocked: YES];
      break;
    }
  }
}

- (BOOL)isShowingSelection
{
  return (selection != nil);
}

- (NSArray *)selection
{
  return selection;
}

- (NSArray *)pathsSelection
{
  if (selection) {
    NSMutableArray *selpaths = [NSMutableArray array];
    NSUInteger i;

    for (i = 0; i < [selection count]; i++) {
      [selpaths addObject: [[selection objectAtIndex: i] path]];
    }

    return [NSArray arrayWithArray: selpaths];
  }

  return nil;
}

- (void)setFont:(NSFont *)fontObj
{
  [super setFont: fontObj];
}


- (NSFont *)labelFont
{
  return [super font];
}

- (void)setLabelTextColor:(NSColor *)acolor
{
}

- (NSColor *)labelTextColor
{
  return [NSColor controlTextColor];
}

- (void)setIconSize:(int)isize
{
  icnsize = isize;
  [self setIcon];
}

- (int)iconSize
{
  return icnsize;
}

- (void)setIconPosition:(unsigned int)ipos
{
}

- (int)iconPosition
{
  return NSImageLeft;
}

- (NSRect)labelRect
{
  return titleRect;
}

- (void)setNodeInfoShowType:(FSNInfoType)type
{
  showType = type;
  DESTROY (extInfoType);
  
  if (selection) {
    [self setStringValue: selectionTitle];
    if (infoCell) {
      [infoCell setStringValue: @""];
    }
    return;
  }
  
  [self setStringValue: [node name]];
  
  if (showType == FSNInfoNameType) {
    DESTROY (infoCell);
  }
  else if (infoCell == nil)
    {
      NSFont *infoFont;
      
      infoFont = [[NSFontManager sharedFontManager] convertFont: [self font] 	 
                                                    toHaveTrait: NSItalicFontMask];
      infoCell = [NSCell new];
      [infoCell setFont: infoFont];
    }
  
  switch(showType) {
    case FSNInfoKindType:
      [infoCell setStringValue: [node typeDescription]];
      break;
    case FSNInfoDateType:
      [infoCell setStringValue: [node modDateDescription]];
      break;
    case FSNInfoSizeType:
      [infoCell setStringValue: [node sizeDescription]];
      break;
    case FSNInfoOwnerType:
      [infoCell setStringValue: [node owner]];
      break;
    default:
      break;
  }
}

- (BOOL)setExtendedShowType:(NSString *)type
{
  ASSIGN (extInfoType, type);
  showType = FSNInfoExtendedType;   

  [self setNodeInfoShowType: showType];

  if (selection == nil) {
    NSDictionary *info = [fsnodeRep extendedInfoOfType: type forNode: node];

    if (info) {
      [infoCell setStringValue: [info objectForKey: @"labelstr"]]; 
      return YES;
    }
  } 
  
  return NO;
}

- (FSNInfoType)nodeInfoShowType
{
  return showType;
}

- (NSString *)shownInfo
{
  return [self stringValue];
}

- (void)setNameEdited:(BOOL)value
{
  nameEdited = value;
}

- (void)setLeaf:(BOOL)flag
{
  [super setLeaf: flag];
}

- (BOOL)isLeaf
{
  return [super isLeaf];
}

- (void)select
{
}

- (void)unselect
{
}

- (BOOL)isSelected
{
  return NO;
}

- (void)setOpened:(BOOL)value
{
  /* This was commented. (To know if something goes wrong) */
  if (isOpened == value) {
    return;
  }
  isOpened = value;
}

- (BOOL)isOpened
{
  return isOpened;
}

- (void)setLocked:(BOOL)value
{
	if (isLocked == value) {
		return;
	}
	isLocked = value;
	[self setEnabled: isLocked];
}

- (void)checkLocked
{
  [self setLocked: [node isLocked]];
}

- (BOOL)isLocked
{
	return isLocked;
}

- (void)setGridIndex:(NSUInteger)index
{
}

- (NSUInteger)gridIndex
{
  return 0;
}

- (int)compareAccordingToName:(id)aCell
{
  return [node compareAccordingToName: [aCell node]];
}

- (int)compareAccordingToKind:(id)aCell
{
  return [node compareAccordingToKind: [aCell node]];
}

- (int)compareAccordingToDate:(id)aCell
{
  return [node compareAccordingToDate: [aCell node]];
}

- (int)compareAccordingToSize:(id)aCell
{
  return [node compareAccordingToSize: [aCell node]];
}

- (int)compareAccordingToOwner:(id)aCell
{
  return [node compareAccordingToOwner: [aCell node]];
}

- (int)compareAccordingToGroup:(id)aCell
{
  return [node compareAccordingToGroup: [aCell node]];
}

- (int)compareAccordingToIndex:(id)aCell
{
  return NSOrderedSame;
}

@end


@implementation FSNCellNameEditor

- (void)dealloc
{
  RELEASE (node);
  [super dealloc];
}

- (void)setNode:(FSNode *)anode 
    stringValue:(NSString *)str
          index:(int)idx
{
  DESTROY (node);
  if (anode) {
    ASSIGN (node, anode);
  } 
  [self setStringValue: str];
  index = idx;
}

- (FSNode *)node
{
  return node;
}

- (int)index
{
  return index;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  if ([self isEditable]) {
	  [self setAlignment: NSLeftTextAlignment];
    [[self window] makeFirstResponder: self];
  }
  [super mouseDown: theEvent];
}

@end










