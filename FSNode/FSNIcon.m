/* FSNIcon.m
 *  
 * Copyright (C) 2004-2022 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
#import <GNUstepBase/GNUstep.h>

#import "FSNIcon.h"
#import "FSNTextCell.h"
#import "FSNode.h"
#import "FSNFunctions.h"

#define BRANCH_SIZE 7
#define ARROW_ORIGIN_X (BRANCH_SIZE + 4)

#define DOUBLE_CLICK_LIMIT  300
#define EDIT_CLICK_LIMIT   1000

/* we redefine the dockstyle to read the preferences without including Dock.h" */
typedef enum DockStyle
{
  DockStyleClassic = 0,
  DockStyleModern = 1
} DockStyle;

static id <DesktopApplication> desktopApp = nil;

static NSImage *branchImage;

@implementation FSNIcon

- (void)dealloc
{
  if (trectTag != -1) {
    [self removeTrackingRect: trectTag];
  }
  RELEASE (node);
  RELEASE (hostname);
  RELEASE (selection);
  RELEASE (selectionTitle);
  RELEASE (extInfoType);
  RELEASE (icon);
  RELEASE (selectedicon);
  RELEASE (highlightPath);
  RELEASE (label);
  RELEASE (infolabel);
  RELEASE (labelFrameColor);
  [super dealloc];
}

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO)
    {
      if (desktopApp == nil)
        {
          NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
          NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
          NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];

          if (appName && selName)
            {
              Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
              SEL sel = NSSelectorFromString(selName);
              desktopApp = [desktopAppClass performSelector: sel];
            }
        }

      branchImage = [NSBrowserCell branchImage];
      initialized = YES;
    }
}

+ (NSImage *)branchImage
{
  return branchImage;
}

/* we try to find a good host name.
 * We try to find something different from localhost, if possibile without dots,
 * else the first part of the qualified hostname gets taken */
+ (NSString *)getBestHostName
{
  NSHost *host = [NSHost currentHost];
  NSString *hname;
  NSRange range;
  NSArray *hnames;

  hnames = [host names];
  if ([hnames count] > 0)
    {
      hname = [hnames objectAtIndex:0];

      if ([hnames count] > 1)
        {
          NSUInteger i;

          for (i = 0; i < [hnames count]; i++)
            {
              NSString *better;

              better = [hnames objectAtIndex:i];
              if (![better isEqualToString:@"localhost"])
                {
                  if ([hname isEqualToString:@"localhost"] || [hname isEqualToString:@"127.0.0.1"])
                    hname = better;
                  else if ([better rangeOfString:@"."].location == NSNotFound)
                    hname = better;
                }
            }
        }

      range = [hname rangeOfString: @"."];
      if (range.length != 0)
        hname = [hname substringToIndex: range.location];
    }
  else
    {
      hname = @"unknown";
    }
  return hname;
}

- (NSString*) description
{
  NSString *s;

  s = [super description];
  s = [s stringByAppendingString:@" {"];
  s = [s stringByAppendingString:[node path]];
  if ([node isMountPoint])
    s = [s stringByAppendingString:@" isMountPoint "];
  s = [s stringByAppendingString: [NSString stringWithFormat:@" gridIndex: %u", (unsigned)gridIndex]];
  s = [s stringByAppendingString:@" }"];
  return s;
}

- (id)initForNode:(FSNode *)anode
     nodeInfoType:(FSNInfoType)type
     extendedType:(NSString *)exttype
         iconSize:(int)isize
     iconPosition:(NSUInteger)ipos
        labelFont:(NSFont *)lfont
        textColor:(NSColor *)tcolor
        gridIndex:(NSUInteger)gindex
        dndSource:(BOOL)dndsrc
        acceptDnd:(BOOL)dndaccept
        slideBack:(BOOL)slback
{
  self = [super init];

  if (self) {
    NSFontManager *fmanager = [NSFontManager sharedFontManager];
    NSFont *infoFont;
    NSRect r = NSZeroRect;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    fsnodeRep = [FSNodeRep sharedInstance];
    
    iconSize = isize;
    icnBounds = NSMakeRect(0, 0, iconSize, iconSize);
    icnPoint = NSZeroPoint;
    brImgBounds = NSMakeRect(0, 0, BRANCH_SIZE, BRANCH_SIZE);
    
    ASSIGN (node, anode);
    selection = nil;
    selectionTitle = nil;
    
    ASSIGN (icon, [fsnodeRep iconOfSize: iconSize forNode: node]);
    drawicon = icon;
    selectedicon = nil;
    
    dndSource = dndsrc;
    acceptDnd = dndaccept;
    slideBack = slback;
    
    selectable = YES;
    isLeaf = YES;
    
    hlightRect = NSZeroRect;
    hlightRect.size.width = iconSize / 3 * 4;
    hlightRect.size.height = hlightRect.size.width * [fsnodeRep highlightHeightFactor];
    if ((hlightRect.size.height - iconSize) < 4) {
      hlightRect.size.height = iconSize + 4;
    }
    hlightRect = NSIntegralRect(hlightRect);
    ASSIGN (highlightPath, [fsnodeRep highlightPathOfSize: hlightRect.size]);
        
    if ([[node path] isEqual: path_separator()] && ([node isMountPoint] == NO))
      {
	NSString *hname;

	hname = [FSNIcon getBestHostName];
        ASSIGN (hostname, hname);
      } 
    
    label = [FSNTextCell new];
    [label setFont: lfont];
    [label setTextColor: tcolor];

    infoFont = [fmanager convertFont: lfont 
                              toSize: ([lfont pointSize] - 2)];
    infoFont = [fmanager convertFont: infoFont 
                         toHaveTrait: NSItalicFontMask];

    infolabel = [FSNTextCell new];
    [infolabel setFont: infoFont];
    [infolabel setTextColor: tcolor];

    if (exttype) {
      [self setExtendedShowType: exttype];
    } else {
      [self setNodeInfoShowType: type];  
    }
    
    labelRect = NSZeroRect;
    labelRect.size.width = [label uncutTitleLenght] + [fsnodeRep labelMargin];
    labelRect.size.height = [fsnodeRep heightOfFont: [label font]];
    labelRect = NSIntegralRect(labelRect);

    infoRect = NSZeroRect;
    if ((showType != FSNInfoNameType) && [[infolabel stringValue] length]) {
      infoRect.size.width = [infolabel uncutTitleLenght] + [fsnodeRep labelMargin];
    } else {
      infoRect.size.width = labelRect.size.width;
    }
    infoRect.size.height = [fsnodeRep heightOfFont: [infolabel font]];
    infoRect = NSIntegralRect(infoRect);

    icnPosition = ipos;
    gridIndex = gindex;
    
    if (icnPosition == NSImageLeft) {
      [label setAlignment: NSLeftTextAlignment];
      [infolabel setAlignment: NSLeftTextAlignment];
      
      r.size.width = hlightRect.size.width + labelRect.size.width;    
      r.size.height = hlightRect.size.height;

      if (showType != FSNInfoNameType) {
        float lbsh = labelRect.size.height + infoRect.size.height;

        if (lbsh > hlightRect.size.height) {
          r.size.height = lbsh;
        }
      } 
    
    } else if (icnPosition == NSImageAbove) {
      [label setAlignment: NSCenterTextAlignment];
      [infolabel setAlignment: NSCenterTextAlignment];
      
      if (labelRect.size.width > hlightRect.size.width) {
        r.size.width = labelRect.size.width;
      } else {
        r.size.width = hlightRect.size.width;
      }
      
      r.size.height = labelRect.size.height + hlightRect.size.height;
      
      if (showType != FSNInfoNameType) {
        r.size.height += infoRect.size.height;
      }
      
    } else if (icnPosition == NSImageOnly) {
      r.size.width = hlightRect.size.width;
      r.size.height = hlightRect.size.height;
      
    } else {
      r.size = icnBounds.size;
    }
    
    trectTag = -1;
    [self setFrame: NSIntegralRect(r)];
    
    if (acceptDnd) {
      NSArray *pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, 
                                                    @"GWLSFolderPboardType", 
                                                    @"GWRemoteFilenamesPboardType", 
                                                    nil];
      [self registerForDraggedTypes: pbTypes];    
    }

    isLocked = [node isLocked];

    container = nil;

    isSelected = NO; 
    isOpened = NO;
    nameEdited = NO;
    editstamp = 0.0;
    
    dragdelay = 0;
    isDragTarget = NO;
    onSelf = NO;

    labelFrameColor = [NSColor controlColor];
    if ([[defaults objectForKey: @"dockstyle"] intValue] == DockStyleModern)
      {
	labelFrameColor = [labelFrameColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	labelFrameColor = [labelFrameColor colorWithAlphaComponent:0.5];
      }
    [labelFrameColor retain];

    drawLabelBackground = NO;
  }
  
  return self;
}

- (void)setSelectable:(BOOL)value
{
  if ((icnPosition == NSImageOnly) && (selectable != value)) {
    selectable = value;
    [self tile];
  }
}

- (NSRect)iconBounds
{
  return icnBounds;
}

- (void)tile
{
  NSRect frameRect = [self bounds];
  NSSize sz = [icon size];
  int lblmargin = [fsnodeRep labelMargin];
  BOOL hasinfo = ([[infolabel stringValue] length] > 0);
    
  if (icnPosition == NSImageAbove) {
    float hlx, hly;

    labelRect.size.width = [label uncutTitleLenght] + lblmargin;
  
    if (labelRect.size.width >= frameRect.size.width) {
      labelRect.size.width = frameRect.size.width;
      labelRect.origin.x = 0;
    } else {
      labelRect.origin.x = (frameRect.size.width - labelRect.size.width) / 2;
    }

    if (showType != FSNInfoNameType) {
      if (hasinfo) {
        infoRect.size.width = [infolabel uncutTitleLenght] + lblmargin;
      } else {
        infoRect.size.width = labelRect.size.width;
      }
      
      if (infoRect.size.width >= frameRect.size.width) {
        infoRect.size.width = frameRect.size.width;
        infoRect.origin.x = 0;
      } else {
        infoRect.origin.x = (frameRect.size.width - infoRect.size.width) / 2;
      }
    }

    if (showType == FSNInfoNameType) {
      labelRect.origin.y = 0;
      labelRect.origin.y += lblmargin / 2;
      labelRect = NSIntegralRect(labelRect);
      infoRect = labelRect;
      
    } else {
      infoRect.origin.y = 0;
      infoRect.origin.y += lblmargin / 2;
      infoRect = NSIntegralRect(infoRect);
    
      labelRect.origin.y = infoRect.origin.y + infoRect.size.height;
      labelRect = NSIntegralRect(labelRect);
    } 
        
    hlx = myrintf((frameRect.size.width - hlightRect.size.width) / 2);
    hly = myrintf(frameRect.size.height - hlightRect.size.height);

    if ((hlightRect.origin.x != hlx) || (hlightRect.origin.y != hly)) {
      NSAffineTransform *transform = [NSAffineTransform transform];

      [transform translateXBy: hlx - hlightRect.origin.x
                          yBy: hly - hlightRect.origin.y];

      [highlightPath transformUsingAffineTransform: transform];

      hlightRect.origin.x = hlx;
      hlightRect.origin.y = hly;      
    }

    icnBounds.origin.x = hlightRect.origin.x + ((hlightRect.size.width - iconSize) / 2);
    icnBounds.origin.y = hlightRect.origin.y + ((hlightRect.size.height - iconSize) / 2);
    icnBounds = NSIntegralRect(icnBounds);

    icnPoint.x = myrintf(hlightRect.origin.x + ((hlightRect.size.width - sz.width) / 2));
    icnPoint.y = myrintf(hlightRect.origin.y + ((hlightRect.size.height - sz.height) / 2));

  } else if (icnPosition == NSImageLeft) {
    float icnspacew = hlightRect.size.width;
    float hryorigin = 0;
    
    if (isLeaf == NO) {
      icnspacew += BRANCH_SIZE;
    }
    
    labelRect.size.width = myrintf([label uncutTitleLenght] + lblmargin);
    
    if (labelRect.size.width >= (frameRect.size.width - icnspacew)) {
      labelRect.size.width = (frameRect.size.width - icnspacew);
    } 
    
    if (showType != FSNInfoNameType) {
      if (hasinfo) {
        infoRect.size.width = [infolabel uncutTitleLenght] + lblmargin;
      } else {
        infoRect.size.width = labelRect.size.width;
      }
      
      if (infoRect.size.width >= (frameRect.size.width - icnspacew)) {
        infoRect.size.width = (frameRect.size.width - icnspacew);
      }
       
    } else {
      infoRect.size.width = labelRect.size.width;
    }
    
    infoRect = NSIntegralRect(infoRect);

    if (showType != FSNInfoNameType) {
      float lbsh = labelRect.size.height + infoRect.size.height;

      if (lbsh > hlightRect.size.height) {
        hryorigin = myrintf((lbsh - hlightRect.size.height) / 2);
      }
    }

    if ((hlightRect.origin.x != 0) || (hlightRect.origin.y != hryorigin)) {
      NSAffineTransform *transform = [NSAffineTransform transform];

      [transform translateXBy: 0 - hlightRect.origin.x
                          yBy: hryorigin - hlightRect.origin.y];

      [highlightPath transformUsingAffineTransform: transform];

      hlightRect.origin.x = 0;
      hlightRect.origin.y = hryorigin;      
    }

    icnBounds.origin.x = (hlightRect.size.width - iconSize) / 2;
    icnBounds.origin.y = hlightRect.origin.y + ((hlightRect.size.height - iconSize) / 2);
    icnBounds = NSIntegralRect(icnBounds);

    icnPoint.x = myrintf((hlightRect.size.width - sz.width) / 2);
    icnPoint.y = myrintf(hlightRect.origin.y + ((hlightRect.size.height - sz.height) / 2));

    labelRect.origin.x = hlightRect.size.width;
    infoRect.origin.x = hlightRect.size.width;

    if (showType != FSNInfoNameType) {
      float lbsh = labelRect.size.height + infoRect.size.height;

      infoRect.origin.y = 0;
    
      if (hasinfo) {
        if (hlightRect.size.height > lbsh) {
          infoRect.origin.y = (hlightRect.size.height - lbsh) / 2;
        }

        labelRect.origin.y = infoRect.origin.y + infoRect.size.height;
        
      } else {
        if (hlightRect.size.height > lbsh) {
          labelRect.origin.y = (hlightRect.size.height - labelRect.size.height) / 2;
        } else {
          labelRect.origin.y = (lbsh - labelRect.size.height) / 2;
        }
      }
      
    } else {
      labelRect.origin.y = (hlightRect.size.height - labelRect.size.height) / 2;
    }

    infoRect = NSIntegralRect(infoRect);
    labelRect = NSIntegralRect(labelRect);

  } else if (icnPosition == NSImageOnly) {
    if (selectable) {
      float hlx = myrintf((frameRect.size.width - hlightRect.size.width) / 2);
      float hly = myrintf((frameRect.size.height - hlightRect.size.height) / 2);
    
      if ((hlightRect.origin.x != hlx) || (hlightRect.origin.y != hly)) {
        NSAffineTransform *transform = [NSAffineTransform transform];
    
        [transform translateXBy: hlx - hlightRect.origin.x
                            yBy: hly - hlightRect.origin.y];
    
        [highlightPath transformUsingAffineTransform: transform];
      
        hlightRect.origin.x = hlx;
        hlightRect.origin.y = hly;      
      }
    }
    
    icnBounds.origin.x = (frameRect.size.width - iconSize) / 2;
    icnBounds.origin.y = (frameRect.size.height - iconSize) / 2;
    icnBounds = NSIntegralRect(icnBounds);

    icnPoint.x = myrintf((frameRect.size.width - sz.width) / 2);
    icnPoint.y = myrintf((frameRect.size.height - sz.height) / 2);
  } 
    
  brImgBounds.origin.x = frameRect.size.width - ARROW_ORIGIN_X;
  brImgBounds.origin.y = myrintf(icnBounds.origin.y + (icnBounds.size.height / 2) - (BRANCH_SIZE / 2));
  brImgBounds = NSIntegralRect(brImgBounds);

  if ([self window]) {
    if (trectTag != -1) {
      [self removeTrackingRect: trectTag];
    }
  
    trectTag = [self addTrackingRect: icnBounds 
                               owner: self 
                            userData: nil
                        assumeInside: NO]; 
  }
    
  [self setNeedsDisplay: YES]; 
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if (([theEvent type] == NSRightMouseDown) && isSelected) {
    return [container menuForEvent: theEvent];
  }
  return [super menuForEvent: theEvent]; 
}

- (void)viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];
  container = (NSView <FSNodeRepContainer> *)[self superview];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  NSPoint location = [theEvent locationInWindow];
  BOOL onself = NO;

  location = [self convertPoint: location fromView: nil];

  if (icnPosition == NSImageOnly) {
    onself = [self mouse: location inRect: icnBounds];
  } else {
    onself = ([self mouse: location inRect: icnBounds]
                        || [self mouse: location inRect: labelRect]);
  }
     
  if ([container respondsToSelector: @selector(setSelectionMask:)]) {
    [container setSelectionMask: NSSingleSelectionMask];
  }

  if (onself) {
	  if (([node isLocked] == NO) && ([theEvent clickCount] > 1)) {
      if ([container respondsToSelector: @selector(openSelectionInNewViewer:)]) {
        BOOL newv = (([theEvent modifierFlags] & NSControlKeyMask)
                        || ([theEvent modifierFlags] & NSAlternateKeyMask));

        [container openSelectionInNewViewer: newv];
      }
    }  
  } else {
    [container mouseUp: theEvent];
  }
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSPoint location = [theEvent locationInWindow];
  NSPoint selfloc = [self convertPoint: location fromView: nil];
  BOOL onself = NO;
  NSEvent *nextEvent = nil;
  BOOL startdnd = NO;
  NSSize offset;

  if (icnPosition == NSImageOnly) {
    onself = [self mouse: selfloc inRect: icnBounds];
  } else {
    onself = ([self mouse: selfloc inRect: icnBounds]
	      || [self mouse: selfloc inRect: labelRect]);
  }

  if (onself) {
    if (selectable == NO) {
      return;
    }
    
    if ([theEvent clickCount] == 1) {
      if (isSelected == NO) {
        if ([container respondsToSelector: @selector(stopRepNameEditing)]) {
          [container stopRepNameEditing];
        }
      }
      
      if ([theEvent modifierFlags] & NSShiftKeyMask) {
        if ([container respondsToSelector: @selector(setSelectionMask:)]) {
          [container setSelectionMask: FSNMultipleSelectionMask];
        }
         
	if (isSelected) {
          if ([container selectionMask] == FSNMultipleSelectionMask) {
	    [self unselect];
            if ([container respondsToSelector: @selector(selectionDidChange)]) {
              [container selectionDidChange];	
            }
	    return;
          }
        } else {
	  [self select];
	}
        
      } else {
        if ([container respondsToSelector: @selector(setSelectionMask:)]) {
          [container setSelectionMask: NSSingleSelectionMask];
        }
        
        if (isSelected == NO) {
	  [self select];
          
	} else {
          NSTimeInterval interval = ([theEvent timestamp] - editstamp);
        
          if ((interval > DOUBLE_CLICK_LIMIT) 
	      && [self mouse: location inRect: labelRect]) {
            if ([container respondsToSelector: @selector(setNameEditorForRep:)]) {
              [container setNameEditorForRep: self];
            }
          } 
        }
      }
    
      if (dndSource) {
        while (1) {
	  nextEvent = [[self window] nextEventMatchingMask:
				       NSLeftMouseUpMask | NSLeftMouseDraggedMask];

          if ([nextEvent type] == NSLeftMouseUp) {
            [[self window] postEvent: nextEvent atStart: NO];
            
            if ([container respondsToSelector: @selector(repSelected:)]) {
              [container repSelected: self];
            }
            
            break;

          } else if (([nextEvent type] == NSLeftMouseDragged)
		     && ([self mouse: selfloc inRect: icnBounds])) {
	    if (dragdelay < 5) {
              dragdelay++;
            } else {    
              NSPoint p = [nextEvent locationInWindow];
              offset = NSMakeSize(p.x - location.x, p.y - location.y); 
              startdnd = YES;        
              break;
            }
          } 
        }
      } 
      
      if (startdnd) {  
        if ([container respondsToSelector: @selector(stopRepNameEditing)]) {
          [container stopRepNameEditing];
        }
        
        if ([container respondsToSelector: @selector(setFocusedRep:)]) {
          [container setFocusedRep: nil];
        }
        
        [self startExternalDragOnEvent: theEvent withMouseOffset: offset];
      }
      
      editstamp = [theEvent timestamp];       
    }
    
  } else {
    [container mouseDown: theEvent];
  }
}

- (void)mouseEntered:(NSEvent *)theEvent
{
  if ([container respondsToSelector: @selector(setFocusedRep:)]) {
    [container setFocusedRep: self];
  }
}

- (void)mouseExited:(NSEvent *)theEvent
{
  if ([container respondsToSelector: @selector(setFocusedRep:)]) {
    [container setFocusedRep: nil];
  }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}

- (void)setFrame:(NSRect)frameRect
{
  [super setFrame: frameRect];
  [self tile];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
  [self tile];
}

- (void)drawRect:(NSRect)rect
{	 
  if (isSelected)
    {
      [[NSColor selectedControlColor] set];
      [highlightPath fill];
      if (nameEdited == NO)
        {
          NSFrameRect(labelRect);
          NSRectFill(labelRect);  
        }
    }
  else
    {
      if (nameEdited == NO)
        {
          [[container backgroundColor] set];
        }
    }  
  if (icnPosition != NSImageOnly)
    {
      if (nameEdited == NO)
        {
          [label setBackgroundColor:labelFrameColor];
          [label setDrawsBackground: drawLabelBackground];
          [label drawWithFrame: labelRect inView: self];
        }
      
      if ((showType != FSNInfoNameType) && [[infolabel stringValue] length])
        {
          [infolabel drawWithFrame: infoRect inView: self];
        }
    }

  if (isLocked == NO)
    {	
      if (isOpened == NO)
        {
          [drawicon compositeToPoint: icnPoint operation: NSCompositeSourceOver];
        }
      else
        {
          [drawicon dissolveToPoint: icnPoint fraction: 0.5];
        }
    }
  else
    {	
      [drawicon dissolveToPoint: icnPoint fraction: 0.3];
    }
  
  if (isLeaf == NO)
    [[object_getClass(self) branchImage] compositeToPoint: brImgBounds.origin operation: NSCompositeSourceOver];
}


//
// FSNodeRep protocol
//
- (void)setNode:(FSNode *)anode
{
  DESTROY (selection);
  DESTROY (selectionTitle);
  DESTROY (hostname);
  
  ASSIGN (node, anode);
  ASSIGN (icon, [fsnodeRep iconOfSize: iconSize forNode: node]);
  drawicon = icon;
  DESTROY (selectedicon);
  
  if ([[node path] isEqual: path_separator()] && ([node isMountPoint] == NO))
    { 
      NSString *hname;

      hname = [FSNIcon getBestHostName];
      ASSIGN (hostname, hname);
    } 
  
  if (extInfoType) {
    [self setExtendedShowType: extInfoType];
  } else {
    [self setNodeInfoShowType: showType];  
  }
  
  [self setLocked: [node isLocked]];
  [self tile];
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
  ASSIGN (selectionTitle, ([NSString stringWithFormat: @"%lu %@", 
                                     (unsigned long)[selection count], NSLocalizedString(@"elements", @"")]));
  ASSIGN (icon, [fsnodeRep multipleSelectionIconOfSize: iconSize]);
  drawicon = icon;
  DESTROY (selectedicon);
  
  [label setStringValue: selectionTitle];
  [infolabel setStringValue: @""];
  
  [self setLocked: NO];
  for (i = 0; i < [selnodes count]; i++) {
    if ([fsnodeRep isNodeLocked: [selnodes objectAtIndex: i]]) {
      [self setLocked: YES];
      break;
    }
  }

  [self tile];
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
  NSFontManager *fmanager = [NSFontManager sharedFontManager];
  int lblmargin = [fsnodeRep labelMargin];
  NSFont *infoFont;

  [label setFont: fontObj];

  infoFont = [fmanager convertFont: fontObj 
                            toSize: ([fontObj pointSize] - 2)];
  infoFont = [fmanager convertFont: infoFont 
                       toHaveTrait: NSItalicFontMask];

  [infolabel setFont: infoFont];

  labelRect.size.width = myrintf([label uncutTitleLenght] + lblmargin);
  labelRect.size.height = myrintf([fsnodeRep heightOfFont: [label font]]);
  labelRect = NSIntegralRect(labelRect);

  infoRect = NSZeroRect;
  if ((showType != FSNInfoNameType) && [[infolabel stringValue] length]) {
    infoRect.size.width = [infolabel uncutTitleLenght] + lblmargin;
  } else {
    infoRect.size.width = labelRect.size.width;
  }
  infoRect.size.height = [fsnodeRep heightOfFont: infoFont];
  infoRect = NSIntegralRect(infoRect);

  [self tile];
}

- (NSFont *)labelFont
{
  return [label font];
}

- (void)setLabelTextColor:(NSColor *)acolor
{
  [label setTextColor: acolor];
  [infolabel setTextColor: acolor];
}

- (NSColor *)labelTextColor
{
  return [label textColor];
}

- (void)setIconSize:(int)isize
{
  iconSize = isize;
  icnBounds = NSMakeRect(0, 0, iconSize, iconSize);
  if (selection == nil) {
    ASSIGN (icon, [fsnodeRep iconOfSize: iconSize forNode: node]);
  } else {
    ASSIGN (icon, [fsnodeRep multipleSelectionIconOfSize: iconSize]);
  }
  drawicon = icon;
  DESTROY (selectedicon);
  hlightRect.size.width = myrintf(iconSize / 3 * 4);
  hlightRect.size.height = myrintf(hlightRect.size.width * [fsnodeRep highlightHeightFactor]);
  if ((hlightRect.size.height - iconSize) < 4) {
    hlightRect.size.height = iconSize + 4;
  }
  hlightRect.origin.x = 0;
  hlightRect.origin.y = 0;
  ASSIGN (highlightPath, [fsnodeRep highlightPathOfSize: hlightRect.size]); 

  labelRect.size.width = [label uncutTitleLenght] + [fsnodeRep labelMargin];
  labelRect.size.height = [fsnodeRep heightOfFont: [label font]];

  [self tile];
}

- (int)iconSize
{
  return iconSize;
}

- (void)setIconPosition:(unsigned int)ipos
{
  icnPosition = ipos;

  if (icnPosition == NSImageLeft) {
    [label setAlignment: NSLeftTextAlignment];
    [infolabel setAlignment: NSLeftTextAlignment];
  } else if (icnPosition == NSImageAbove) {
    [label setAlignment: NSCenterTextAlignment];
    [infolabel setAlignment: NSCenterTextAlignment];
  } 
  
  [self tile];
}

- (int)iconPosition
{
  return icnPosition;
}

- (NSRect)labelRect
{
  return labelRect;
}

- (void)setNodeInfoShowType:(FSNInfoType)type
{
  showType = type;
  DESTROY (extInfoType);

  if (selection) {
    [label setStringValue: selectionTitle];
    [infolabel setStringValue: @""];
    return;
  }
   
  [label setStringValue: (hostname ? hostname : [node name])];
   
  switch(showType) {
    case FSNInfoNameType:
      [infolabel setStringValue: @""];
      break;
    case FSNInfoKindType:
      [infolabel setStringValue: [node typeDescription]];
      break;
    case FSNInfoDateType:
      [infolabel setStringValue: [node modDateDescription]];
      break;
    case FSNInfoSizeType:
      [infolabel setStringValue: [node sizeDescription]];
      break;
    case FSNInfoOwnerType:
      [infolabel setStringValue: [node owner]];
      break;
    default:
      [infolabel setStringValue: @""];
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
      [infolabel setStringValue: [info objectForKey: @"labelstr"]]; 
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
  return [label stringValue];
}

- (void)setNameEdited:(BOOL)value
{
  if (nameEdited != value) {
    nameEdited = value;
    [self setNeedsDisplay: YES];
  }
}

- (void)setLeaf:(BOOL)flag
{
  if (isLeaf != flag) {
    isLeaf = flag;
    [self tile]; 
  }
}

- (BOOL)isLeaf
{
  return isLeaf;
}

- (void)select
{
  if (isSelected) {
    return;
  }
  isSelected = YES;
  
  if ([container respondsToSelector: @selector(unselectOtherReps:)]) {
    [container unselectOtherReps: self];
  }
  if ([container respondsToSelector: @selector(selectionDidChange)]) {
    [container selectionDidChange];	
  }
  
  [self setNeedsDisplay: YES]; 
}

- (void)unselect
{
  if (isSelected == NO) {
    return;
  }
	isSelected = NO;
  [self setNeedsDisplay: YES];
}

- (BOOL)isSelected
{
  return isSelected;
}

- (void)setOpened:(BOOL)value
{
  if (isOpened == value) {
    return;
  }
  isOpened = value;
  [self setNeedsDisplay: YES]; 
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
	[label setTextColor: (isLocked ? [container disabledTextColor] 
                                            : [container textColor])];
	[infolabel setTextColor: (isLocked ? [container disabledTextColor] 
                                            : [container textColor])];
                                                
	[self setNeedsDisplay: YES];		
}

- (void)checkLocked
{
  if (selection == nil)
    {
      [self setLocked: [node isLocked]];
    }
  else
    {
      NSUInteger i;
    
      [self setLocked: NO];
    
      for (i = 0; i < [selection count]; i++)
	{
	  if ([[selection objectAtIndex: i] isLocked])
	    {
	      [self setLocked: YES];
	      break;
	    }
	}
    }
}

- (BOOL)isLocked
{
  return isLocked;
}

- (void)setGridIndex:(NSUInteger)index
{
  gridIndex = index;
}

- (NSUInteger)gridIndex
{
  return gridIndex;
}

- (int)compareAccordingToName:(id)aIcon
{
  return [node compareAccordingToName: [aIcon node]];
}

- (int)compareAccordingToKind:(id)aIcon
{
  return [node compareAccordingToKind: [aIcon node]];
}

- (int)compareAccordingToDate:(id)aIcon
{
  return [node compareAccordingToDate: [aIcon node]];
}

- (int)compareAccordingToSize:(id)aIcon
{
  return [node compareAccordingToSize: [aIcon node]];
}

- (int)compareAccordingToOwner:(id)aIcon
{
  return [node compareAccordingToOwner: [aIcon node]];
}

- (int)compareAccordingToGroup:(id)aIcon
{
  return [node compareAccordingToGroup: [aIcon node]];
}

- (int)compareAccordingToIndex:(id)aIcon
{
  return (gridIndex <= [aIcon gridIndex]) ? NSOrderedAscending : NSOrderedDescending;
}

@end


@implementation FSNIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset
{
  if ([container respondsToSelector: @selector(selectedPaths)]) {
    NSArray *selectedPaths = [container selectedPaths];
    NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	

    [pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] 
               owner: nil];

    if ([pb setPropertyList: selectedPaths forType: NSFilenamesPboardType]) {
      NSImage *dragIcon;

      if ([selectedPaths count] == 1) {
        dragIcon = icon;
      } else {
        dragIcon = [fsnodeRep multipleSelectionIconOfSize: iconSize];
      }     

      [self dragImage: dragIcon
                   at: icnPoint
               offset: offset
                event: event
           pasteboard: pb
               source: self
            slideBack: slideBack];
    }
  }
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationEvery;
}

- (void)draggedImage:(NSImage *)anImage 
             endedAt:(NSPoint)aPoint 
           deposited:(BOOL)flag
{
  dragdelay = 0;
  onSelf = NO;
  
  if ([container respondsToSelector: @selector(restoreLastSelection)]) {
    [container restoreLastSelection];
  }
  
  if (flag == NO) {
    if ([container respondsToSelector: @selector(removeUndepositedRep:)]) {
      [container removeUndepositedRep: self];
    }
  }
}

@end


@implementation FSNIcon (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb;
  NSDragOperation sourceDragMask;
  NSArray *sourcePaths;
  NSString *fromPath;
  NSString *nodePath;
  NSString *prePath;
  NSUInteger i, count;
  
  isDragTarget = NO;
  onSelf = NO;
	
  if (selection || isLocked || ([node isDirectory] == NO) 
            || (([node isWritable] == NO) && ([node isApplication] == NO))) {
    return NSDragOperationNone;
  }
  
  if ([node isDirectory]) {
    if ([node isSubnodeOfPath: [desktopApp trashPath]]) { 
      return NSDragOperationNone;
    }
  }	
  
  if ([node isPackage] && ([node isApplication] == NO)) {
    if ([container respondsToSelector: @selector(baseNode)]) { 
      if ([node isEqual: [container baseNode]] == NO) {
        return NSDragOperationNone;
      }
    } else {
      return NSDragOperationNone;
    }
  }
  
  pb = [sender draggingPasteboard];
  sourcePaths = nil;
  
  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {
    if ([node isPackage] == NO) {
      NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 
      NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];

      sourcePaths = [pbDict objectForKey: @"paths"];
    }
  } else if ([[pb types] containsObject: @"GWLSFolderPboardType"]) {
    if ([node isPackage] == NO) {
      NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"]; 
      NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
      sourcePaths = [pbDict objectForKey: @"paths"];
    }
  }
  
  if (sourcePaths == nil) {
    return NSDragOperationNone;
  }
  
  count = [sourcePaths count];
  if (count == 0)
    {
      return NSDragOperationNone;
    } 
  
  nodePath = [node path];
  
  if (selection) {
    if ([selection isEqual: sourcePaths]) {
      onSelf = YES;
    }  
  } else if (count == 1) {
    if ([nodePath isEqual: [sourcePaths objectAtIndex: 0]]) {
      onSelf = YES;
    }  
  }

  if (onSelf) {
    isDragTarget = YES;
    return NSDragOperationAll;  
  }

  fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

  if ([nodePath isEqual: fromPath])
    {
      return NSDragOperationNone;
    }  

  if ([sourcePaths containsObject: nodePath]) {
    return NSDragOperationNone;
  }

  prePath = [NSString stringWithString: nodePath];

  while (![prePath isEqual: path_separator()])
    {
      if ([sourcePaths containsObject: prePath])
        return NSDragOperationNone;
      prePath = [prePath stringByDeletingLastPathComponent];
    }


  if ([node isDirectory] && [node isParentOfPath: fromPath]) {
    NSArray *subNodes = [node subNodes];
    
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

  if ([node isApplication]) {
    if (([container respondsToSelector: @selector(baseNode)] == NO)
                        || ([node isEqual: [container baseNode]] == NO)) { 
      for (i = 0; i < count; i++) {
        CREATE_AUTORELEASE_POOL(arp);
        FSNode *nd = [FSNode nodeWithPath: [sourcePaths objectAtIndex: i]];

        if (([nd isPlain] == NO) && ([nd isPackage] == NO)) {
          RELEASE (arp);
          return NSDragOperationNone;
        }
        RELEASE (arp);
      }
      
    } else if ([node isEqual: [container baseNode]] == NO) {
      return NSDragOperationNone;
    }
  }

  isDragTarget = YES;
  forceCopy = NO;
  
  onApplication = ([node isApplication]
                      && [container respondsToSelector: @selector(baseNode)]
                                      && [node isEqual: [container baseNode]]);   
  
	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
    if ([node isApplication]) {
      return (onApplication ? NSDragOperationCopy : NSDragOperationMove);
    } else {
      return NSDragOperationCopy;
    }
    
	} else if (sourceDragMask == NSDragOperationLink) {
    if ([node isApplication]) {
      return (onApplication ? NSDragOperationLink : NSDragOperationMove);
    } else {
      return NSDragOperationLink;
    }
  
	} else {  
    if ([[NSFileManager defaultManager] isWritableFileAtPath: fromPath]
                          || ([node isApplication] && (onApplication == NO))) {
      return NSDragOperationAll;			
    } else if (([node isApplication] == NO) || onApplication) {
      forceCopy = YES;
			return NSDragOperationCopy;			
    }
	}
    
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  NSPoint p = [self convertPoint: [sender draggingLocation] fromView: nil];

  if ([self mouse: p inRect: icnBounds] == NO) {
    if (drawicon == selectedicon) {
      drawicon = icon;
      [self setNeedsDisplay: YES];
    }
    return [container draggingUpdated: sender];
    
  } else {
    if ((selectedicon == nil) && isDragTarget && (onSelf == NO)) {
      ASSIGN (selectedicon, [fsnodeRep openFolderIconOfSize: iconSize forNode: node]);
    }
  
    if (selectedicon && (drawicon == icon) && isDragTarget && (onSelf == NO)) {
      drawicon = selectedicon;
      [self setNeedsDisplay: YES];
    }
  }

  if (isDragTarget == NO) {
    return NSDragOperationNone;
  } else if (sourceDragMask == NSDragOperationCopy) {
    if ([node isApplication]) {
      return (onApplication ? NSDragOperationCopy : NSDragOperationMove);
    } else {
      return NSDragOperationCopy;
    }
    
	} else if (sourceDragMask == NSDragOperationLink) {
    if ([node isApplication]) {
      return (onApplication ? NSDragOperationLink : NSDragOperationMove);
    } else {
      return NSDragOperationLink;
    }

	} else {
		return forceCopy ? NSDragOperationCopy : NSDragOperationAll;
	}

	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  isDragTarget = NO;  
  
  if (onSelf == NO) { 
    drawicon = icon;
    [container setNeedsDisplayInRect: [self frame]];   
    [self setNeedsDisplay: YES];   
  }
  
  onSelf = NO;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return isLocked ? NO : isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  return isLocked ? NO : isDragTarget;
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
  NSUInteger i;

  isDragTarget = NO;  

  if (isLocked) {
    return;
  }

  if (onSelf) {
		[container resizeWithOldSuperviewSize: [container frame].size]; 
    onSelf = NO;		
    return;
  }	

  drawicon = icon;
  [self setNeedsDisplay: YES];

	sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];

  if ([node isPackage] == NO) {    
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
  }
    
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

  if (([node isApplication] == NO) || onApplication) {
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

    files = [NSMutableArray arrayWithCapacity: 1];    
    for(i = 0; i < [sourcePaths count]; i++) {    
      [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
    }  

	  opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
	  [opDict setObject: operation forKey: @"operation"];
	  [opDict setObject: source forKey: @"source"];
	  [opDict setObject: [node path] forKey: @"destination"];
	  [opDict setObject: files forKey: @"files"];

    [desktopApp performFileOperation: opDict];

  } else {
    for (i = 0; i < [sourcePaths count]; i++) {  
      NSString *path = [sourcePaths objectAtIndex: i];
    
      NS_DURING
        {
      [[NSWorkspace sharedWorkspace] openFile: path 
                              withApplication: [node name]];
        }
      NS_HANDLER
        {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
          [NSString stringWithFormat: @"%@ %@!", 
                    NSLocalizedString(@"Can't open ", @""), [node name]],
                                        NSLocalizedString(@"OK", @""), 
                                        nil, 
                                        nil);                                     
        }
      NS_ENDHANDLER  
    }
  }
}

@end


@implementation FSNIconNameEditor

- (void)dealloc
{
  RELEASE (node);
  [super dealloc];
}

- (void)setNode:(FSNode *)anode 
    stringValue:(NSString *)str
{
  DESTROY (node);
  if (anode) {
    ASSIGN (node, anode);
  } 
  [self setStringValue: str];
}

- (FSNode *)node
{
  return node;
}

- (void)viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];
  container = (NSView <FSNodeRepContainer> *)[self superview];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  if ([self isEditable] == NO) {
    if ([container respondsToSelector: @selector(canStartRepNameEditing)]
                                      && [container canStartRepNameEditing]) {  
      [self setAlignment: NSLeftTextAlignment];  
      [self setSelectable: YES];  
      [self setEditable: YES];  
      [[self window] makeFirstResponder: self]; 
    }
    
  } else {
    [super mouseDown: theEvent];
  }
}

@end

