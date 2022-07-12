/* FSNIconsView.m
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
#include <unistd.h>
#include <sys/types.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSVersion.h>

#import "FSNIconsView.h"
#import "FSNIcon.h"
#import "FSNFunctions.h"

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

/* we redefine the dockstyle to read the preferences without including Dock.h" */
typedef enum DockStyle
{   
  DockStyleClassic = 0,
  DockStyleModern = 1
} DockStyle;

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


@implementation FSNIconsView

- (void)dealloc
{
  RELEASE (node);
  RELEASE (extInfoType);
  RELEASE (icons);
  RELEASE (labelFont);
  RELEASE (nameEditor);
  RELEASE (horizontalImage);
  RELEASE (verticalImage);
  RELEASE (lastSelection);
  RELEASE (charBuffer);
  RELEASE (backColor);
  RELEASE (textColor);
  RELEASE (disabledTextColor);
  
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
    
    fsnodeRep = [FSNodeRep sharedInstance];
    
    if (appName && selName) {
      Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
      SEL sel = NSSelectorFromString(selName);
      desktopApp = [desktopAppClass performSelector: sel];
    }

    /* we tie the transparent selection to the modern dock style */
    transparentSelection = NO;
    defentry = [defaults objectForKey: @"dockstyle"];
    if ([defentry intValue] == DockStyleModern)
      transparentSelection = YES;

    ASSIGN (backColor, [NSColor windowBackgroundColor]);
    ASSIGN (textColor, [NSColor controlTextColor]);
    ASSIGN (disabledTextColor, [NSColor disabledControlTextColor]);
    
    defentry = [defaults objectForKey: @"iconsize"];
    iconSize = defentry ? [defentry intValue] : DEF_ICN_SIZE;

    defentry = [defaults objectForKey: @"labeltxtsize"];
    labelTextSize = defentry ? [defentry intValue] : DEF_TEXT_SIZE;
    ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);
    
    defentry = [defaults objectForKey: @"iconposition"];
    iconPosition = defentry ? [defentry intValue] : DEF_ICN_POS;
        
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
    
    isDragTarget = NO;
		lastKeyPressed = 0.;
    charBuffer = nil;
    selectionMask = NSSingleSelectionMask;

    [self calculateGridSize];
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                                NSFilenamesPboardType, 
                                                @"GWLSFolderPboardType", 
                                                @"GWRemoteFilenamesPboardType", 
                                                nil]];    
  }
   
  return self;
}

- (void)sortIcons
{
  if (infoType == FSNInfoExtendedType) {
    [icons sortUsingFunction: compareWithExtType
                     context: (void *)NULL];
  } else {
    [icons sortUsingSelector: [fsnodeRep compareSelectorForDirectory: [node path]]];
  }
}

- (void)calculateGridSize
{
  NSSize highlightSize = NSZeroSize;
  NSSize labelSize = NSZeroSize;
  int lblmargin = [fsnodeRep labelMargin];
  
  highlightSize.width = ceil(iconSize / 3 * 4);
  highlightSize.height = ceil(highlightSize.width * [fsnodeRep highlightHeightFactor]);
  if ((highlightSize.height - iconSize) < 4) {
    highlightSize.height = iconSize + 4;
  }

  labelSize.height = floor([fsnodeRep heightOfFont: labelFont]);
  labelSize.width = [fsnodeRep labelWFactor] * labelTextSize;

  gridSize.height = highlightSize.height;

  if (infoType != FSNInfoNameType) {
    float lbsh = (labelSize.height * 2) - 2;
  
    if (iconPosition == NSImageAbove) {
      gridSize.height += lbsh;
      gridSize.width = labelSize.width;
    } else {
      if (lbsh > gridSize.height) {
        gridSize.height = lbsh;
      }
      gridSize.width = highlightSize.width + labelSize.width + lblmargin;
    }
  } else {
    if (iconPosition == NSImageAbove) {
      gridSize.height += labelSize.height;
      gridSize.width = labelSize.width;
    } else {
      gridSize.width = highlightSize.width + labelSize.width + lblmargin;
    }
  }
}

- (void)tile
{
  CREATE_AUTORELEASE_POOL (pool);
  NSRect svr = [[self superview] frame];
  NSRect r = [self frame];
  NSRect maxr = [[NSScreen mainScreen] frame];
  float px = 0 - gridSize.width;
  float py = gridSize.height + Y_MARGIN;
  NSSize sz;
  NSUInteger poscount = 0;
  NSUInteger count = [icons count];
  NSRect *irects = NSZoneMalloc (NSDefaultMallocZone(), sizeof(NSRect) * count);
  NSCachedImageRep *rep = nil;
  NSArray *selection;
  NSUInteger i;

  colcount = 0;
  
  for (i = 0; i < count; i++)
    {
      px += (gridSize.width + X_MARGIN);      
    
    if (px >= (svr.size.width - gridSize.width)) {
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

	py += Y_MARGIN;  
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
    
  selection = [self selectedReps];
  if ([selection count]) {
    [self scrollIconToVisible: [selection objectAtIndex: 0]];
  } 

  if ([[self subviews] containsObject: nameEditor]) {  
    [self updateNameEditor]; 
  }
}

- (void)scrollIconToVisible:(FSNIcon *)icon
{
  NSRect irect = [icon frame];  
  float border = floor(irect.size.height * 0.2);
        
  irect.origin.y -= border;
  irect.size.height += border * 2;
  [self scrollRectToVisible: irect];	
}

- (NSString *)selectIconWithPrefix:(NSString *)prefix
{
  NSUInteger i;

  for (i = 0; i < [icons count]; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];
      NSString *name = [icon shownInfo];
    
      if ([name hasPrefix: prefix])
	{
	  [icon select];
	  [self scrollIconToVisible: icon];
	  
	  return name;
	}
    }
  
  return nil;
}

- (void)selectIconInPrevLine
{
  FSNIcon *icon;
  NSUInteger i;
  NSInteger pos = -1;
  
  for (i = 0; i < [icons count]; i++)
    {
      icon = [icons objectAtIndex: i];
      
      if ([icon isSelected])
	{
	  pos = i - colcount;
	  break;
	}
    }
  
  if (pos >= 0)
    {
      icon = [icons objectAtIndex: pos];
      [icon select];
      [self scrollIconToVisible: icon];
    }
}

- (void)selectIconInNextLine
{
  FSNIcon *icon;
  NSUInteger i;
  NSUInteger pos = [icons count];
  
  for (i = 0; i < [icons count]; i++)
    {
      icon = [icons objectAtIndex: i];
      
      if ([icon isSelected])
	{
	  pos = i + colcount;
	  break;
	}
    }
  
  if (pos <= ([icons count] -1))
    {
      icon = [icons objectAtIndex: pos];
      [icon select];
      [self scrollIconToVisible: icon];
    }
}

- (void)selectPrevIcon
{
  NSUInteger i;
    
  for (i = 0; i < [icons count]; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];
      
      if ([icon isSelected])
	{
	  if (i > 0)
	    {
	      icon = [icons objectAtIndex: i - 1];  
	      [icon select];
	      [self scrollIconToVisible: icon];
	    } 
	  break;
	}
    }
}

- (void)selectNextIcon
{
  NSUInteger count = [icons count];
  NSUInteger i;
    
  for (i = 0; i < count; i++)
    {
      FSNIcon *icon = [icons objectAtIndex: i];
    
      if ([icon isSelected])
	{
	  if (i < (count - 1))
	    {
	      icon = [icons objectAtIndex: i + 1];
	      [icon select];
	      [self scrollIconToVisible: icon];
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
  if ([theEvent modifierFlags] != NSShiftKeyMask) {
    selectionMask = NSSingleSelectionMask;
    selectionMask |= FSNCreatingSelectionMask;
		[self unselectOtherReps: nil];
    selectionMask = NSSingleSelectionMask;
    
    DESTROY (lastSelection);
    [self selectionDidChange];
    [self stopRepNameEditing];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
  unsigned int eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask;
  NSDate *future = [NSDate distantFuture];
  NSPoint	sp;
  NSPoint	p, pp;
  NSRect visibleRect;
  NSRect oldRect; 
  NSRect r;
  NSRect selrect;
  float x, y, w, h;
  NSUInteger i;

  pp = NSMakePoint(0,0);

#define scrollPointToVisible(p) \
{ \
NSRect sr; \
sr.origin = p; \
sr.size.width = sr.size.height = 1.0; \
[self scrollRectToVisible: sr]; \
}

#define CONVERT_CHECK \
{ \
NSRect br = [self bounds]; \
pp = [self convertPoint: p fromView: nil]; \
if (pp.x < 1) \
pp.x = 1; \
if (pp.x >= NSMaxX(br)) \
pp.x = NSMaxX(br) - 1; \
if (pp.y < 0) \
pp.y = -1; \
if (pp.y > NSMaxY(br)) \
pp.y = NSMaxY(br) + 1; \
}

  p = [theEvent locationInWindow];
  sp = [self convertPoint: p  fromView: nil];
  
  oldRect = NSZeroRect;  

  [[self window] disableFlushWindow];

  [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.05];

  while ([theEvent type] != NSLeftMouseUp) {
    BOOL scrolled = NO;

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
    
    if ([self mouse: pp inRect: visibleRect] == NO)
      {
	scrollPointToVisible(pp);
	CONVERT_CHECK;

	scrolled = YES;
      }

    x = min(sp.x, pp.x);
    y = min(sp.y, pp.y);
    w = max(1, max(pp.x, sp.x) - min(pp.x, sp.x));
    h = max(1, max(pp.y, sp.y) - min(pp.y, sp.y));

    r = NSMakeRect(x, y, w, h);
    
    // Erase the previous rect
    if (transparentSelection
	|| !SUPPORTS_XOR
	|| (!transparentSelection && scrolled))
      {
	[self setNeedsDisplayInRect: oldRect];
	[[self window] displayIfNeeded];
      }
 
    // Draw the new rect

    [self lockFocus];

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
      {
	if (!NSEqualRects(oldRect, r) && !scrolled)
	  {
	    GWHighlightFrameRect(oldRect);
	    GWHighlightFrameRect(r);
	  }
	else if (scrolled)
	  {
	    GWHighlightFrameRect(r);
	  }
      }
     
    [self unlockFocus];

    oldRect = r;

    [[self window] enableFlushWindow];
    [[self window] flushWindow];
    [[self window] disableFlushWindow];

    DESTROY (arp);
  }
  
  [NSEvent stopPeriodicEvents];
  [[self window] postEvent: theEvent atStart: NO];

  // Erase the previous rect

  [self setNeedsDisplayInRect: oldRect];
  [[self window] displayIfNeeded];
  
  [[self window] enableFlushWindow];
  [[self window] flushWindow];

  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  x = min(sp.x, pp.x);
  y = min(sp.y, pp.y);
  w = max(1, max(pp.x, sp.x) - min(pp.x, sp.x));
  h = max(1, max(pp.y, sp.y) - min(pp.y, sp.y));

  selrect = NSMakeRect(x, y, w, h);
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    NSRect iconBounds = [self convertRect: [icon iconBounds] fromView: icon];

    if (NSIntersectsRect(selrect, iconBounds)) {
      [icon select];
    } 
  }  
  
  selectionMask = NSSingleSelectionMask;
  
  [self selectionDidChange];
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
		
  if ([characters length] > 0)
    character = [characters characterAtIndex: 0];

	
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
      
		case NSCarriageReturnCharacter:
      {
        unsigned flags = [theEvent modifierFlags];
        BOOL closesndr = ((flags == NSAlternateKeyMask) 
                                  || (flags == NSControlKeyMask));
        [self openSelectionInNewViewer: closesndr];
        return;
      }

    default:    
      break;
  }

  if (([characters length] > 0) && (character < 0xF700)) {
		SEL icnwpSel = @selector(selectIconWithPrefix:);
		IMP icnwp = [self methodForSelector: icnwpSel];
    
    if (charBuffer == nil) {
      charBuffer = [characters substringToIndex: 1];
      RETAIN (charBuffer);
      lastKeyPressed = 0.0;
    } else {
      if ([theEvent timestamp] - lastKeyPressed < 500.0) {
        ASSIGN (charBuffer, ([charBuffer stringByAppendingString:
				    															[characters substringToIndex: 1]]));
      } else {
        ASSIGN (charBuffer, ([characters substringToIndex: 1]));
        lastKeyPressed = 0.0;
      }														
    }	
    		
    lastKeyPressed = [theEvent timestamp];

    if ((*icnwp)(self, icnwpSel, charBuffer)) {
      return;
    }
  }
  
  [super keyDown: theEvent];
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
  NSUInteger i;

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
    
    menu = [[NSMenu alloc] initWithTitle: NSLocalizedStringFromTableInBundle(@"Open with", nil, [NSBundle bundleForClass:[self class]], @"")];
    apps = [[NSWorkspace sharedWorkspace] infoForExtension: firstext];
    app_enum = [[apps allKeys] objectEnumerator];

    pool = [NSAutoreleasePool new];

    while ((key = [app_enum nextObject])) {
      menuItem = [NSMenuItem new];    
      key = [key stringByDeletingPathExtension];
      [menuItem setTitle: key];
      [menuItem setTarget: desktopApp];      
      [menuItem setAction: @selector(openSelectionWithApp:)];      
      [menuItem setRepresentedObject: key];            
      [menu addItem: menuItem];
      RELEASE (menuItem);
    }

    RELEASE (pool);
    
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

  if ([self superview]) {
    [[self window] setBackgroundColor: backColor];
  }
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

- (BOOL)acceptsFirstResponder
{
  return YES;
}

@end


@implementation FSNIconsView (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *subNodes = [anode subNodes];
  NSUInteger i;

  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] removeFromSuperview];
  }
  [icons removeAllObjects];
  editIcon = nil;
    
  ASSIGN (node, anode);
  [self readNodeInfo];
  [self calculateGridSize];
    
  for (i = 0; i < [subNodes count]; i++) {
    FSNode *subnode = [subNodes objectAtIndex: i];
    FSNIcon *icon = [[FSNIcon alloc] initForNode: subnode
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
  }

  [icons sortUsingSelector: [fsnodeRep compareSelectorForDirectory: [node path]]];
  [self tile];
  
  DESTROY (lastSelection);
  [self selectionDidChange];
  RELEASE (arp);
}

- (NSDictionary *)readNodeInfo
{  
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
  NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [node path]];
  NSDictionary *nodeDict = nil;

  if ([node isWritable]
          && ([[fsnodeRep volumes] containsObject: [node path]] == NO)) {
    NSString *infoPath = [[node path] stringByAppendingPathComponent: @".gwdir"];
  
    if ([[NSFileManager defaultManager] fileExistsAtPath: infoPath]) {
      NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: infoPath];

      if (dict) {
        nodeDict = [NSDictionary dictionaryWithDictionary: dict];
      }   
    }
  }
  
  if (nodeDict == nil) {
    id defEntry = [defaults dictionaryForKey: prefsname];

    if (defEntry) {
      nodeDict = [NSDictionary dictionaryWithDictionary: defEntry];
    }
  }
  
  if (nodeDict) {
    id entry = [nodeDict objectForKey: @"iconsize"];
    iconSize = entry ? [entry intValue] : iconSize;

    entry = [nodeDict objectForKey: @"labeltxtsize"];
    if (entry) {
      labelTextSize = [entry intValue];
      ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);      
    }

    entry = [nodeDict objectForKey: @"iconposition"];
    iconPosition = entry ? [entry intValue] : iconPosition;

    entry = [nodeDict objectForKey: @"fsn_info_type"];
    infoType = entry ? [entry intValue] : infoType;

    if (infoType == FSNInfoExtendedType) {
      DESTROY (extInfoType);
      entry = [nodeDict objectForKey: @"ext_info_type"];

      if (entry) {
        NSArray *availableTypes = [fsnodeRep availableExtendedInfoNames];

        if ([availableTypes containsObject: entry]) {
          ASSIGN (extInfoType, entry);
        }
      }

      if (extInfoType == nil) {
        infoType = FSNInfoNameType;
      }
    }
  }
        
  return nodeDict;
}

- (NSMutableDictionary *)updateNodeInfo:(BOOL)ondisk
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *updatedInfo = nil;

  if ([node isValid]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    NSString *prefsname = [NSString stringWithFormat: @"viewer_at_%@", [node path]];
    NSString *infoPath = [[node path] stringByAppendingPathComponent: @".gwdir"];
    BOOL writable = ([node isWritable] && ([[fsnodeRep volumes] containsObject: [node path]] == NO));
    
    if (writable) {
      if ([[NSFileManager defaultManager] fileExistsAtPath: infoPath]) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: infoPath];

        if (dict) {
          updatedInfo = [dict mutableCopy];
        }   
      }
  
    } else { 
      NSDictionary *prefs = [defaults dictionaryForKey: prefsname];
  
      if (prefs) {
        updatedInfo = [prefs mutableCopy];
      }
    }

    if (updatedInfo == nil) {
      updatedInfo = [NSMutableDictionary new];
    }
	    
    [updatedInfo setObject: [NSNumber numberWithInt: iconSize] 
                    forKey: @"iconsize"];

    [updatedInfo setObject: [NSNumber numberWithInt: labelTextSize] 
                    forKey: @"labeltxtsize"];

    [updatedInfo setObject: [NSNumber numberWithInt: iconPosition] 
                    forKey: @"iconposition"];

    [updatedInfo setObject: [NSNumber numberWithInt: infoType] 
                    forKey: @"fsn_info_type"];

    if (infoType == FSNInfoExtendedType) {
      [updatedInfo setObject: extInfoType forKey: @"ext_info_type"];
    }

    if (ondisk) {
      if (writable) {
        [updatedInfo writeToFile: infoPath atomically: YES];
      } else {
        [defaults setObject: updatedInfo forKey: prefsname];
      }
    }
  }

  RELEASE (arp);
  
  return (AUTORELEASE (updatedInfo));
}

- (void)reloadContents
{
  NSArray *selection = [self selectedNodes];
  NSMutableArray *opennodes = [NSMutableArray array];
  NSUInteger i;
            
  RETAIN (selection);
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isOpened]) {
      [opennodes addObject: [icon node]];
    }
  }
  
  RETAIN (opennodes);

  [self showContentsOfNode: node];

  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  for (i = 0; i < [selection count]; i++) {
    FSNode *nd = [selection objectAtIndex: i]; 
    
    if ([nd isValid]) { 
      FSNIcon *icon = [self repOfSubnode: nd];
      
      if (icon) {
        [icon select];
      }
    }
  }

  selectionMask = NSSingleSelectionMask;

  RELEASE (selection);

  for (i = 0; i < [opennodes count]; i++) {
    FSNode *nd = [opennodes objectAtIndex: i]; 
    
    if ([nd isValid]) { 
      FSNIcon *icon = [self repOfSubnode: nd];
      
      if (icon) {
        [icon setOpened: YES];
      }
    }
  }
  
  RELEASE (opennodes);
    
  [self checkLockedReps];
  [self tile];

  selection = [self selectedReps];
  
  if ([selection count]) {
    [self scrollIconToVisible: [selection objectAtIndex: 0]];
  }

  [self selectionDidChange];
}

- (void)reloadFromNode:(FSNode *)anode
{
  if ([node isEqual: anode]) {
    [self reloadContents];
    
  } else if ([node isSubnodeOfNode: anode]) {
    NSArray *components = [FSNode nodeComponentsFromNode: anode toNode: node];
    int i;
  
    for (i = 0; i < [components count]; i++) {
      FSNode *component = [components objectAtIndex: i];
    
      if ([component isValid] == NO) {
        component = [FSNode nodeWithPath: [component parentPath]];
        [self showContentsOfNode: component];
        break;
      }
    }
  }
}

- (FSNode *)baseNode
{
  return node;
}

- (FSNode *)shownNode
{
  return node;
}

- (BOOL)isSingleNode
{
  return YES;
}

- (BOOL)isShowingNode:(FSNode *)anode
{
  return [node isEqual: anode];
}

- (BOOL)isShowingPath:(NSString *)path
{
  return [[node path] isEqual: path];
}

- (void)sortTypeChangedAtPath:(NSString *)path
{
  if ((path == nil) || [[node path] isEqual: path]) {
    [self reloadContents];
  }
}

- (void)nodeContentsWillChange:(NSDictionary *)info
{
  [self checkLockedReps];
}

- (void)nodeContentsDidChange:(NSDictionary *)info
{
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSString *ndpath = [node path];
  NSUInteger i; 
 
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent]; 
  }

  if (([ndpath isEqual: source] == NO) && ([ndpath isEqual: destination] == NO)) {
    [self reloadContents];
    return;
  }

  if ([ndpath isEqual: source]) {
    if ([operation isEqual: NSWorkspaceMoveOperation]
              || [operation isEqual: NSWorkspaceDestroyOperation]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
              || [operation isEqual: NSWorkspaceRecycleOperation]
			        || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
      
      if ([operation isEqual: NSWorkspaceRecycleOperation]) {
		    files = [info objectForKey: @"origfiles"];
      }	
              
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
        [self removeRepOfSubnode: subnode];
      }
    } 
  }
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [destination lastPathComponent]];
    destination = [destination stringByDeletingLastPathComponent]; 
  }

  if ([ndpath isEqual: destination]
          && ([operation isEqual: NSWorkspaceMoveOperation]   
              || [operation isEqual: NSWorkspaceCopyOperation]
              || [operation isEqual: NSWorkspaceLinkOperation]
              || [operation isEqual: NSWorkspaceDuplicateOperation]
              || [operation isEqual: @"GWorkspaceCreateDirOperation"]
              || [operation isEqual: @"GWorkspaceCreateFileOperation"]
              || [operation isEqual: NSWorkspaceRecycleOperation]
              || [operation isEqual: @"GWorkspaceRenameOperation"]
				      || [operation isEqual: @"GWorkspaceRecycleOutOperation"])) { 
    
    if ([operation isEqual: NSWorkspaceRecycleOperation]) {
		  files = [info objectForKey: @"files"];
    }	

    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      FSNIcon *icon = [self repOfSubnode: subnode];
      
      if (icon) {
        [icon setNode: subnode];
      } else {
        [self addRepForSubnode: subnode];
      }
    }
    
    [self sortIcons];
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
  NSUInteger i;

  if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      NSString *fname = [files objectAtIndex: i];
      NSString *fpath = [ndpath stringByAppendingPathComponent: fname];  
      [self removeRepOfSubnodePath: fpath];
    }
    
  } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    for (i = 0; i < [files count]; i++) {  
      NSString *fname = [files objectAtIndex: i];
      FSNode *subnode = [FSNode nodeWithRelativePath: fname parent: node];
      
      if (subnode && [subnode isValid]) {
        FSNIcon *icon = [self repOfSubnode: subnode];

        if (icon) {
          [icon setNode: subnode];
        } else {
          [self addRepForSubnode: subnode];
        }
      }   
    }
  }

  [self sortIcons];
  [self tile];
  [self setNeedsDisplay: YES];  
  [self selectionDidChange];
}

- (void)setShowType:(FSNInfoType)type
{
  if (infoType != type) {
    NSUInteger i;
    
    infoType = type;
    DESTROY (extInfoType);
    
    [self calculateGridSize];
    
    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];
      
      [icon setNodeInfoShowType: infoType];
      [icon tile];
    }
    
    [self sortIcons];
    [self tile];
  }
}

- (void)setExtendedShowType:(NSString *)type
{
  if ((extInfoType == nil) || ([extInfoType isEqual: type] == NO)) {
    int i;
    
    infoType = FSNInfoExtendedType;
    ASSIGN (extInfoType, type);

    [self calculateGridSize];

    for (i = 0; i < [icons count]; i++) {
      FSNIcon *icon = [icons objectAtIndex: i];
      
      [icon setExtendedShowType: extInfoType];
      [icon tile];
    }
    
    [self sortIcons];
    [self tile];
  }
}

- (FSNInfoType)showType
{
  return infoType;
}

- (void)setIconSize:(int)size
{
  NSUInteger i;
  
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
  NSUInteger i;

  labelTextSize = size;
  ASSIGN (labelFont, [NSFont systemFontOfSize: labelTextSize]);  
  [self calculateGridSize];

  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    [icon setFont: labelFont];
  }

  [nameEditor setFont: labelFont];

  [self tile];
}

- (int)labelTextSize
{
  return labelTextSize;
}

- (void)setIconPosition:(int)pos
{
  NSUInteger i;
  
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

- (void)updateIcons
{
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    FSNode *inode = [icon node];
    [icon setNode: inode];
  }  
}

- (id)repOfSubnode:(FSNode *)anode
{
  NSUInteger i;
  
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
  NSUInteger i;
  
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
  CREATE_AUTORELEASE_POOL(arp);
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
  RELEASE (arp);
    
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

- (void)unloadFromNode:(FSNode *)anode
{
  FSNode *parent = [FSNode nodeWithPath: [anode parentPath]];
  [self showContentsOfNode: parent];
}

- (void)repSelected:(id)arep
{
}

- (void)unselectOtherReps:(id)arep
{
  NSUInteger i;

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

- (void)selectReps:(NSArray *)reps
{
  NSUInteger i;
  
  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
  [self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;

  for (i = 0; i < [reps count]; i++) {
    [[reps objectAtIndex: i] select];
  }  

  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (void)selectRepsOfSubnodes:(NSArray *)nodes
{
  NSUInteger i;
  
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
  NSUInteger i;
  
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
  NSUInteger i;

  selectionMask = NSSingleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
  [self unselectOtherReps: nil];
  
  selectionMask = FSNMultipleSelectionMask;
  selectionMask |= FSNCreatingSelectionMask;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];
    FSNode *inode = [icon node];
    
    if ([inode isReserved] == NO) {
      [icon select];
    }
	}
  
  selectionMask = NSSingleSelectionMask;

  [self selectionDidChange];
}

- (void)scrollSelectionToVisible
{
  NSArray *selection = [self selectedReps];
  
  if ([selection count]) {
    [self scrollIconToVisible: [selection objectAtIndex: 0]];
  } else {
    NSRect r = [self frame];
    [self scrollRectToVisible: NSMakeRect(0, r.size.height - 1, 1, 1)];	
  }
}

- (NSArray *)reps
{
  return icons;
}

- (NSArray *)selectedReps
{
  NSMutableArray *selectedReps = [NSMutableArray array];
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++) {
    FSNIcon *icon = [icons objectAtIndex: i];

    if ([icon isSelected]) {
      [selectedReps addObject: icon];
    }
  }

  return [selectedReps makeImmutableCopyOnFail: NO];
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

- (void)selectionDidChange
{
  if (!(selectionMask & FSNCreatingSelectionMask)) {
    NSArray *selection = [self selectedNodes];
		
    if ([selection count] == 0) {
      selection = [NSArray arrayWithObject: node];
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
  NSUInteger i;
  
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
    [self selectRepsOfSubnodes: lastSelection];
  }
}

- (void)setLastShownNode:(FSNode *)anode
{
}

- (BOOL)needsDndProxy
{
  return NO;
}

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  return [node involvedByFileOperation: opinfo];
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCut:(BOOL)cut
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

- (void)setTextColor:(NSColor *)acolor
{
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setLabelTextColor: acolor];  
  }
  
  [nameEditor setTextColor: acolor];
  
  ASSIGN (textColor, acolor);
}

- (NSColor *)textColor
{
  return textColor;
}

- (NSColor *)disabledTextColor
{
  return disabledTextColor;
}

@end


@implementation FSNIconsView (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb;
  NSDragOperation sourceDragMask;
  NSArray *sourcePaths;
  NSString *basePath;
  NSString *nodePath;
  NSString *prePath;
  NSUInteger count;
  
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
    NSUInteger i;
    
    for (i = 0; i < [subNodes count]; i++) {
      FSNode *nd = [subNodes objectAtIndex: i];
      
      if ([nd isDirectory]) {
        NSUInteger j;
        
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
  NSRect vr = [self visibleRect];
  NSRect scr = vr;
  int xsc = 0.0;
  int ysc = 0.0;
  int sc = 0;
  float margin = 4.0;
  NSRect ir = NSInsetRect(vr, margin, margin);
  NSPoint p = [sender draggingLocation];
  int i;
  
  p = [self convertPoint: p fromView: nil];

  if ([self mouse: p inRect: ir] == NO) {
    if (p.x < (NSMinX(vr) + margin)) {
      xsc = -gridSize.width;
    } else if (p.x > (NSMaxX(vr) - margin)) {
      xsc = gridSize.width;
    }

    if (p.y < (NSMinY(vr) + margin)) {
      ysc = -gridSize.height;
    } else if (p.y > (NSMaxY(vr) - margin)) {
      ysc = gridSize.height;
    }

    sc = (abs(xsc) >= abs(ysc)) ? xsc : ysc;
          
    for (i = 0; i < (int)fabsf(sc / margin); i++) {
      CREATE_AUTORELEASE_POOL (pool);
      NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 0.01];
      int x = (abs(xsc) >= i) ? (xsc > 0 ? margin : -margin) : 0;
      int y = (abs(ysc) >= i) ? (ysc > 0 ? margin : -margin) : 0;
      
      scr = NSOffsetRect(scr, x, y);
      [self scrollRectToVisible: scr];

      vr = [self visibleRect];
      ir = NSInsetRect(vr, margin, margin);

      p = [[self window] mouseLocationOutsideOfEventStream];
      p = [self convertPoint: p fromView: nil];

      if ([self mouse: p inRect: ir]) {
        RELEASE (pool);
        break;
      }
      
      [[NSRunLoop currentRunLoop] runUntilDate: limit];
      RELEASE (pool);
    }
  }
  
	if (isDragTarget == NO) {
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
  NSUInteger i;
  
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
    
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
  
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


@implementation FSNIconsView (IconNameEditing)

- (void)updateNameEditor
{
  [self stopRepNameEditing];
  
  if (lastSelection && ([lastSelection count] == 1)) {
    editIcon = [self repOfSubnode: [lastSelection objectAtIndex: 0]]; 
  } 
  
  if (editIcon) {
    FSNode *ednode = [editIcon node];
    NSString *nodeDescr = [editIcon shownInfo];    
    NSRect icnr = [editIcon frame];
    NSRect labr = [editIcon labelRect];
    int ipos = [editIcon iconPosition];
    int margin = [fsnodeRep labelMargin];
    float bw = [self bounds].size.width - EDIT_MARGIN;
    float edwidth = 0.0; 
    NSRect edrect;

    [editIcon setNameEdited: YES];

    edwidth = [[nameEditor font] widthOfString: nodeDescr];
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
    else
      {
	NSLog(@"Unexpected icon position in [FSNIconsView updateNameEditor]");
	return;
      }

    edrect = NSIntegralRect(edrect);

    [nameEditor setFrame: edrect];

    if (ipos == NSImageAbove) {
  	  [nameEditor setAlignment: NSCenterTextAlignment];
    } else if (ipos == NSImageLeft) {
		  [nameEditor setAlignment: NSLeftTextAlignment];
    }

    [nameEditor setNode: ednode 
            stringValue: nodeDescr];

    [nameEditor setBackgroundColor: [NSColor selectedControlColor]];

    if ([editIcon isLocked] == NO) {
      [nameEditor setTextColor: [NSColor controlTextColor]];    
    } else {
      [nameEditor setTextColor: [NSColor disabledControlTextColor]];    
    }

    [nameEditor setEditable: NO];
    [nameEditor setSelectable: NO];	
    [self addSubview: nameEditor];  
  }  
}

- (void)setNameEditorForRep:(id)arep
{
}

- (void)stopRepNameEditing
{
  NSUInteger i;

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
                  && ([[editIcon node] isMountPoint] == NO));
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSRect icnr = [editIcon frame];
  int ipos = [editIcon iconPosition];
  float edwidth = [[nameEditor font] widthOfString: [nameEditor stringValue]]; 
  int margin = [fsnodeRep labelMargin];
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
  [self stopRepNameEditing]; \
  return 
 
  
    if ([ednode isParentWritable] == NO)
      {
	showAlertNoPermission([FSNode class], [ednode parentName]);
	CLEAREDITING;
      }
    else if ([ednode isSubnodeOfPath: [desktopApp trashPath]])
      {
	showAlertInRecycler([FSNode class]);
	CLEAREDITING;
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
	  CLEAREDITING;
	}

      if (([extension length] 
              && ([ednode isDirectory] && ([ednode isPackage] == NO))))
	{
          if (showAlertExtensionChange([FSNode class], extension) == NSAlertDefaultReturn)
            {
              CLEAREDITING;
            }
	}

      if ([dirContents containsObject: newname])
	{
	  if ([newname isEqual: [ednode name]])
	    {
	      CLEAREDITING;
	    }
	  else
	    {
	      showAlertNameInUse([FSNode class], newname);
	      CLEAREDITING;
	    }
	}

      [opinfo setObject: @"GWorkspaceRenameOperation" forKey: @"operation"];	
      [opinfo setObject: [ednode path] forKey: @"source"];	
      [opinfo setObject: newpath forKey: @"destination"];	
      [opinfo setObject: [NSArray arrayWithObject: @""] forKey: @"files"];	

      [self stopRepNameEditing];
      [desktopApp performFileOperation: opinfo];
    }
}

@end






















