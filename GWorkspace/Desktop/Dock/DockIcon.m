/* DockIcon.m
 *  
 * Copyright (C) 2005-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
#include <unistd.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "DockIcon.h"
#import "Dock.h"
#import "GWDesktopManager.h"
#import "GWorkspace.h"

@implementation DockIcon

- (void)dealloc
{
  RELEASE (appName);
  RELEASE (highlightColor);
  RELEASE (darkerColor);
  RELEASE (highlightImage);
  RELEASE (trashFullIcon);
  RELEASE (dragIcon);
  
  [super dealloc];
}

- (id)initForNode:(FSNode *)anode
          appName:(NSString *)aname
         iconSize:(int)isize
{
  self = [super initForNode: anode
               nodeInfoType: FSNInfoNameType
               extendedType: nil
                   iconSize: isize
               iconPosition: NSImageOnly
                  labelFont: [NSFont systemFontOfSize: 12]
                  textColor: [NSColor controlTextColor]
                  gridIndex: 0
                  dndSource: NO
                  acceptDnd: NO
                  slideBack: NO];

  if (self) {
    if (aname != nil) {
      ASSIGN (appName, aname);
    } else {
      ASSIGN (appName, [[node name] stringByDeletingPathExtension]);
    }
        
    dragIcon = [icon copy];
    
    docked = NO;
    launched = NO;
    apphidden = NO;

    minimumLaunchClicks = 2;
    
    nc = [NSNotificationCenter defaultCenter];
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];

    [self setToolTip: appName];  
  }

  return self;
}

- (NSString *)appName
{
  return appName;
}

- (void)setWsIcon:(BOOL)value
{
  isWsIcon = value;
  if (isWsIcon) {
    [self removeAllToolTips];
  }
}

- (BOOL)isWsIcon
{
  return isWsIcon;
}

- (void)setTrashIcon:(BOOL)value
{
  if (value != isTrashIcon) {
    isTrashIcon = value;

    if (isTrashIcon) {
      NSArray *subNodes;
      NSUInteger i, count;

      ASSIGN (icon, [fsnodeRep trashIconOfSize: ceil(icnBounds.size.width)]);
      ASSIGN (trashFullIcon, [fsnodeRep trashFullIconOfSize: ceil(icnBounds.size.width)]);
      
      subNodes = [node subNodes];
      count = [subNodes count];
      
      for (i = 0; i < [subNodes count]; i++) {
        if ([[subNodes objectAtIndex: i] isReserved]) {
          count --;
        }
      }
      
      [self setTrashFull: !(count == 0)];
    
    } else {
      ASSIGN (icon, [fsnodeRep iconOfSize: ceil(icnBounds.size.width) 
                                  forNode: node]);
    }
  }
  
  if (isTrashIcon) {
    [self removeAllToolTips];
  }  
}

- (void)setTrashFull:(BOOL)value
{
  trashFull = value;
  [self setNeedsDisplay: YES];
}

- (BOOL)isTrashIcon
{
  return isTrashIcon;
}

- (BOOL)isSpecialIcon
{
  return (isWsIcon || isTrashIcon);
}

- (void)setDocked:(BOOL)value
{
  docked = value;
}

- (BOOL)isDocked
{
  return docked;
}

- (void)setSingleClickLaunch:(BOOL)value
{
  minimumLaunchClicks = (value == YES) ? 1 : 2;
}

- (void)setLaunched:(BOOL)value
{
  launched = value;
  [self setNeedsDisplay: YES];
}

- (BOOL)isLaunched
{
  return launched;
}

- (void)setAppHidden:(BOOL)value
{
  apphidden = value;
  [self setNeedsDisplay: YES];
  [container setNeedsDisplayInRect: [self frame]];
}

- (BOOL)isAppHidden
{
  return apphidden;
}

- (void)animateLaunch
{
  launching = YES;
  dissFract = 0.2;
    
  while (1)
    {
      NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.02];
      [[NSRunLoop currentRunLoop] runUntilDate: date];
      [self display];

      dissFract += 0.05;
      if (dissFract >= 1)
	{
	  launching = NO;
	  break;
	}
    }
  
  [self setNeedsDisplay: YES];
}

- (void)setHighlightColor:(NSColor *)color
{
  ASSIGN (highlightColor, [color highlightWithLevel: 0.2]);
  ASSIGN (darkerColor, [color shadowWithLevel: 0.4]);
}

- (void)setHighlightImage:(NSImage *)image
{
  DESTROY (highlightImage);
  
  if (image) {
    NSSize size = [self frame].size;
    
    highlightImage = [[NSImage alloc] initWithSize: size];
    [highlightImage lockFocus]; 
    [image compositeToPoint: NSZeroPoint 
                   fromRect: [self frame]
                  operation: NSCompositeCopy];
    [highlightImage unlockFocus];
  }
}

- (void)setUseHlightImage:(BOOL)value
{
  useHligtImage = value;
}

- (void)setIsDndSourceIcon:(BOOL)value
{
  if (isDndSourceIcon != value) {
    isDndSourceIcon = value;
    [self setNeedsDisplay: YES];
  }
}

- (void)setIconSize:(int)isize
{
  icnBounds = NSMakeRect(0, 0, isize, isize);
  if (isTrashIcon) {
    ASSIGN (icon, [fsnodeRep trashIconOfSize: ceil(icnBounds.size.width)]);
    ASSIGN (trashFullIcon, [fsnodeRep trashFullIconOfSize: ceil(icnBounds.size.width)]);
  } else {
    ASSIGN (icon, [fsnodeRep iconOfSize: ceil(icnBounds.size.width) 
                                forNode: node]);
  }
  hlightRect.size.width = ceil(isize / 3 * 4);
  hlightRect.size.height = ceil(hlightRect.size.width * [fsnodeRep highlightHeightFactor]);
  if ((hlightRect.size.height - isize) < 4) {
    hlightRect.size.height = isize + 4;
  }
  hlightRect.origin.x = 0;
  hlightRect.origin.y = 0;
  ASSIGN (highlightPath, [fsnodeRep highlightPathOfSize: hlightRect.size]); 
  [self tile];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  if ([theEvent clickCount] >= minimumLaunchClicks) {
    if ([self isSpecialIcon] == NO) {
      if (launched == NO) {
        [ws launchApplication: appName];
      } else if (apphidden) {
        [[GWorkspace gworkspace] unhideAppWithPath: [node path] andName: appName];
      } else {
        [[GWorkspace gworkspace] activateAppWithPath: [node path] andName: appName];
      }
    } else if (isWsIcon) {
      [[GWDesktopManager desktopManager] showRootViewer];
    
    } else if (isTrashIcon) {
      NSString *path = [node path];
      [[GWDesktopManager desktopManager] selectFile: path inFileViewerRootedAtPath: path];
    }
  }
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSEvent *nextEvent = nil;
  BOOL startdnd = NO;
    
  if ([theEvent clickCount] == 1)
    {
      [self select];

      dragdelay = 0;
      [(Dock *)container setDndSourceIcon: nil];

    while (1)
      {
	nextEvent = [[self window] nextEventMatchingMask:
				     NSLeftMouseUpMask | NSLeftMouseDraggedMask];

	if ([nextEvent type] == NSLeftMouseUp) {
	  [[self window] postEvent: nextEvent atStart: YES];
	  [self unselect];
	  break;

	} else if (([nextEvent type] == NSLeftMouseDragged)
		   && ([self isSpecialIcon] == NO)) {
	  if (dragdelay < 5) {
	    dragdelay++;
	  } else {
	    startdnd = YES;
	    break;
	  }
	}
      }

    if (startdnd == YES)
      {
	[self startExternalDragOnEvent: theEvent withMouseOffset: NSZeroSize];
      }
    }
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if ([self isSpecialIcon] == NO) {
    NSString *appPath = [ws fullPathForApplication: appName];
    
    if (appPath) {
      CREATE_AUTORELEASE_POOL(arp);
      NSMenu *menu = [[NSMenu alloc] initWithTitle: appName];
      NSMenuItem *item;
      GWLaunchedApp *app;
      
      item = [NSMenuItem new];  
      [item setTitle: NSLocalizedString(@"Show In File Viewer", @"")];
      [item setTarget: (Dock *)container];  
      [item setAction: @selector(iconMenuAction:)]; 
      [item setRepresentedObject: appPath];            
      [menu addItem: item];
      RELEASE (item);

      app = [[GWorkspace gworkspace] launchedAppWithPath: appPath
                                                 andName: appName];      
      if (app && [app isRunning]) {
        item = [NSMenuItem new];  
        [item setTarget: (Dock *)container];  
        [item setAction: @selector(iconMenuAction:)]; 
        [item setRepresentedObject: app];            
      
        if ([app isHidden]) {
          [item setTitle: NSLocalizedString(@"Unhide", @"")];
        } else {
          [item setTitle: NSLocalizedString(@"Hide", @"")];
        }
        
        [menu addItem: item];
        RELEASE (item);      

        item = [NSMenuItem new];  
        [item setTitle: NSLocalizedString(@"Quit", @"")];
        [item setTarget: (Dock *)container];  
        [item setAction: @selector(iconMenuAction:)]; 
        [item setRepresentedObject: app];            
        [menu addItem: item];
        RELEASE (item);
      } 
      
      RELEASE (arp);

      return AUTORELEASE (menu);
    }
  }
  
  return [super menuForEvent: theEvent];
}

- (void)startExternalDragOnEvent:(NSEvent *)event
                 withMouseOffset:(NSSize)offset
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [dict setObject: appName forKey: @"name"];
  [dict setObject: [node path] forKey: @"path"];
  [dict setObject: [NSNumber numberWithBool: docked] 
           forKey: @"docked"];
  [dict setObject: [NSNumber numberWithBool: launched] 
           forKey: @"launched"];
  [dict setObject: [NSNumber numberWithBool: apphidden] 
           forKey: @"hidden"];
  
  [pb declareTypes: [NSArray arrayWithObject: @"DockIconPboardType"] 
             owner: nil];
    
  if ([pb setData: [NSArchiver archivedDataWithRootObject: dict] 
          forType: @"DockIconPboardType"]) {
    NSPoint dragPoint = [event locationInWindow]; 
    NSSize fs = [self frame].size; 
 
    dragPoint.x -= ((fs.width - icnPoint.x) / 2);
    dragPoint.y -= ((fs.height - icnPoint.y) / 2);
      
    [self unselect];  
    [self setIsDndSourceIcon: YES];
    [(Dock *)container setDndSourceIcon: self];
    [(Dock *)container tile];
    
    [[self window] dragImage: dragIcon
                          at: dragPoint 
                      offset: NSZeroSize
                       event: event
                  pasteboard: pb
                      source: self
                   slideBack: NO];
  }
}

- (void)draggedImage:(NSImage *)anImage
	     endedAt:(NSPoint)aPoint
	   deposited:(BOOL)flag
{
	dragdelay = 0;
  [self setIsDndSourceIcon: NO];
  [(Dock *)container setDndSourceIcon: nil];
}

- (void)drawRect:(NSRect)rect
{   
#define DRAWDOT(c1, c2, p) \
{ \
[c1 set]; \
NSRectFill(NSMakeRect(p.x, p.y, 3, 2)); \
[c2 set]; \
NSRectFill(NSMakeRect(p.x + 1, p.y, 2, 1)); \
NSRectFill(NSMakeRect(p.x + 2, p.y + 1, 1, 1)); \
}

#define DRAWDOTS(c1, c2, p) \
{ \
int i, x = p.x, y = p.y; \
for (i = 0; i < 3; i++) { \
[c1 set]; \
NSRectFill(NSMakeRect(x, y, 3, 2)); \
[c2 set]; \
NSRectFill(NSMakeRect(x + 1, y, 2, 1)); \
NSRectFill(NSMakeRect(x + 2, y + 1, 1, 1)); \
x += 6; \
} \
}
 	
  if (isSelected || launching) {
    [highlightColor set];
    NSRectFill(rect);

    if (highlightImage && useHligtImage) {
      [highlightImage dissolveToPoint: NSZeroPoint fraction: 0.2];
    }
  }
  
  if (launching) {		
	  [icon dissolveToPoint: icnPoint fraction: dissFract];
	  return;
  }
  
  if (isDndSourceIcon == NO) {
    if (isTrashIcon == NO) {
      [icon compositeToPoint: icnPoint operation: NSCompositeSourceOver];
    } else {
      if (trashFull) {
        [trashFullIcon compositeToPoint: icnPoint operation: NSCompositeSourceOver];
      } else {
        [icon compositeToPoint: icnPoint operation: NSCompositeSourceOver];
      }
    }
    
    if ((isWsIcon == NO) && (isTrashIcon == NO)) { 
      if (apphidden) {
        DRAWDOT (darkerColor, [NSColor whiteColor], NSMakePoint(4, 2));
      } else if (launched == NO) {
        DRAWDOTS (darkerColor, [NSColor whiteColor], NSMakePoint(4, 2));
      }
    }
  }
}

- (BOOL)acceptsDraggedPaths:(NSArray *)paths
{
  unsigned i;

  if ([self isSpecialIcon] == NO) {
    for (i = 0; i < [paths count]; i++) {
      NSString *path = [paths objectAtIndex: i];
      FSNode *nod = [FSNode nodeWithPath: path];

      if (([nod isPlain] || ([nod isPackage] && ([nod isApplication] == NO))) == NO) {
        return NO;
      }
    }

    [self select]; 
    return YES;
    
  } else if (isTrashIcon) {
    NSString *fromPath = [[paths objectAtIndex: 0] stringByDeletingLastPathComponent];
    BOOL accept = YES;
    
    if ([fromPath isEqual: [[GWDesktopManager desktopManager] trashPath]] == NO) {
      NSArray *vpaths = [ws mountedLocalVolumePaths];
    
      for (i = 0; i < [paths count]; i++) {
        NSString *path = [paths objectAtIndex: i];

        if (([vpaths containsObject: path] == NO)
                          && ([fm isWritableFileAtPath: path] == NO)) {
          accept = NO;
          break;
        }
      }
    } else {
      accept = NO;
    }
      
    if (accept) {
      [self select];
    }
  
    return accept;
  }

  return NO;
}

- (void)setDraggedPaths:(NSArray *)paths
{
  NSUInteger i;
  
  [self unselect];
        
  if ([self isSpecialIcon] == NO)
    {
      for (i = 0; i < [paths count]; i++)
        {
          NSString *path = [paths objectAtIndex: i];
          FSNode *nod = [FSNode nodeWithPath: path];
          
          if ([nod isPlain] || ([nod isPackage] && ([nod isApplication] == NO)))
            {
              NS_DURING
                {
                  [ws openFile: path withApplication: appName];
                }
              NS_HANDLER
                {
                  NSRunAlertPanel(NSLocalizedString(@"error", @""), 
                                  [NSString stringWithFormat: @"%@ %@!", 
                                            NSLocalizedString(@"Can't open ", @""), [path lastPathComponent]],
                                  NSLocalizedString(@"OK", @""), 
                                  nil, 
                                  nil);                                     
                }
              NS_ENDHANDLER  
             }
        } 
    }
  else if (isTrashIcon) // FIXME this is largely similar to RecyclerIcon ####
    {
      NSArray *vpaths = [ws mountedLocalVolumePaths];
      NSMutableArray *files = [NSMutableArray array];
      NSMutableArray *umountPaths = [NSMutableArray array];
      NSMutableDictionary *opinfo = [NSMutableDictionary dictionary];
      
      for (i = 0; i < [paths count]; i++)
        {
          NSString *srcpath = [paths objectAtIndex: i];
          
          if ([vpaths containsObject: srcpath])
            {
              [umountPaths addObject: srcpath];
            }
          else
            {
              [files addObject: [srcpath lastPathComponent]];
            }
        }
      
    for (i = 0; i < [umountPaths count]; i++)
      {
        NSString *umpath = [umountPaths objectAtIndex: i];
        
        if (![ws unmountAndEjectDeviceAtPath: umpath])
          {
	    NSString *err = NSLocalizedString(@"Error", @"");
	    NSString *msg = NSLocalizedString(@"You are not allowed to umount\n", @"");
	    NSString *buttstr = NSLocalizedString(@"Continue", @"");
            NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, umpath], buttstr, nil, nil);
	    [[GWDesktopManager desktopManager] unlockVolumeAtPath:umpath];
          }
      }
    
    if ([files count])
      {
        NSString *fromPath = [[paths objectAtIndex: 0] stringByDeletingLastPathComponent];
        
        if ([fm isWritableFileAtPath: fromPath] == NO) {
          NSString *err = NSLocalizedString(@"Error", @"");
          NSString *msg = NSLocalizedString(@"You do not have write permission\nfor", @"");
          NSString *buttstr = NSLocalizedString(@"Continue", @"");
          NSRunAlertPanel(err, [NSString stringWithFormat: @"%@ \"%@\"!\n", msg, fromPath], buttstr, nil, nil);   
          return;
        }
        
        [opinfo setObject: NSWorkspaceRecycleOperation forKey: @"operation"];
        [opinfo setObject: fromPath forKey: @"source"];
        [opinfo setObject: [node path] forKey: @"destination"];
        [opinfo setObject: files forKey: @"files"];
        
        [[GWDesktopManager desktopManager] performFileOperation: opinfo];
      }
    }
}

@end
