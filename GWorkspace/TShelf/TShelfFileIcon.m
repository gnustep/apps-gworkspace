/* TShelfFileIcon.m
 *  
 * Copyright (C) 2003-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
 * Date: November 2021
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


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "FSNFunctions.h"
#import "GWFunctions.h"
#import "FSNodeRep.h"

#import "TShelfFileIcon.h"
#import "TShelfIconsView.h"
#import "GWorkspace.h"

@implementation TShelfFileIcon

- (void)dealloc
{
  RELEASE (paths);
  RELEASE (hostname);
  RELEASE (node);
  [super dealloc];
}

- (id)initForPaths:(NSArray *)fpaths
       inIconsView:(TShelfIconsView *)aview
{
  self = [super init];
  if (self)
    {
      NSFont *font;
      NSRect hlightRect;
      NSUInteger count;

      fsnodeRep = [FSNodeRep sharedInstance];
      fm = [NSFileManager defaultManager];
      gw = [GWorkspace gworkspace];

      paths = [NSMutableArray new];
      [paths addObjectsFromArray: fpaths];
      tview = aview;
      labelWidth = [tview cellsWidth] - 4;
      font = [NSFont systemFontOfSize: 12];

      count = [paths count];
      if (count == 1)
	{
	  singlepath = YES;
	  ASSIGN (node, [FSNode nodeWithPath: [paths objectAtIndex: 0]]);

	  if ([[node path] isEqual: path_separator()])
	    {
	      ASSIGN (name, [node path]);
	      isRootIcon = YES;
	    }
	  else
	    {
	      ASSIGN (name, [node name]);
	      isRootIcon = NO;
	    }
	}
      else
	{
	  node = nil;
	  singlepath = NO;
	  isRootIcon = NO;
	  name = [[NSString alloc] initWithFormat: @"%lu items", (unsigned long)count];
	}

      if (singlepath)
	ASSIGN (icon, [fsnodeRep iconOfSize: ICON_SIZE forNode: node]);
      else
	ASSIGN (icon, [fsnodeRep multipleSelectionIconOfSize: ICON_SIZE]);

      hlightRect = NSZeroRect;
      hlightRect.size.width = (float)ICON_SIZE / 3 * 4;
      hlightRect.size.height = hlightRect.size.width * [fsnodeRep highlightHeightFactor];
      if ((hlightRect.size.height - ICON_SIZE) < 4)
	{
	  hlightRect.size.height = ICON_SIZE + 4;
	}
      hlightRect = NSIntegralRect(hlightRect);
      ASSIGN (highlightPath, [fsnodeRep highlightPathOfSize: hlightRect.size]);

      if (isRootIcon)
	{
	  NSHost *host = [NSHost currentHost];
	  NSString *hname = [host name];
	  NSRange range = [hname rangeOfString: @"."];

	  if (range.length != 0)
	    {
	      hname = [hname substringToIndex: range.location];
	    }
	  ASSIGN (hostname, hname);
	}
      else
	{
	  hostname = nil;
	}

      namelabel = [NSTextField new];
      [namelabel setFont: font];
      [namelabel setBezeled: NO];
      [namelabel setEditable: NO];
      [namelabel setSelectable: NO];
      [namelabel setAlignment: NSCenterTextAlignment];
      [namelabel setDrawsBackground: NO];
      [namelabel setTextColor: [NSColor controlTextColor]];
      [self setLabelWidth];
      [self setFrame: NSMakeRect(0, 0, 64, 52)];
      [self registerForDraggedTypes: [NSArray arrayWithObjects:
						NSFilenamesPboardType,
					      @"GWLSFolderPboardType",
					      @"GWRemoteFilenamesPboardType",
					      nil]];

      gridIndex = NSNotFound;
      isDragTarget = NO;
      onSelf = NO;
      trectTag = -1;
      minimumLaunchClicks = 2;
    }

  return self;
}

- (id)initForPaths:(NSArray *)fpaths
        atPosition:(NSPoint)pos
       inIconsView:(TShelfIconsView *)aview
{
  self = [self initForPaths: fpaths inIconsView: aview];
  if (self)
    {
      position = NSMakePoint(pos.x, pos.y);
    }
  return self;
}

- (id)initForPaths:(NSArray *)fpaths
	 gridIndex:(NSUInteger)index
       inIconsView:(TShelfIconsView *)aview
{
  self = [self initForPaths: fpaths inIconsView: aview];
  if (self)
    {
      gridIndex = index;
    }
  return self;
}

- (void)setPaths:(NSArray *)fpaths
{
  NSUInteger count;

  RELEASE (paths);
  RELEASE (node);
  paths = [[NSMutableArray alloc] initWithCapacity: 1];
  [paths addObjectsFromArray: fpaths];
  count = [paths count];

  if (count == 1)
    {
      singlepath = YES;

      ASSIGN (node, [FSNode nodeWithPath: [paths objectAtIndex: 0]]);

      if ([[node path] isEqual: path_separator()])
	{
	  ASSIGN (name, [node path]);
	  isRootIcon = YES;
	}
      else
	{
	  ASSIGN (name, [node name]);
	  isRootIcon = NO;
	}

    }
  else
    {
      node = nil;
      singlepath = NO;
      isRootIcon = NO;
      name = [[NSString alloc] initWithFormat: @"%lu items", (unsigned long)count];
    }

  if (singlepath)
    {
      ASSIGN (icon, [fsnodeRep iconOfSize: ICON_SIZE forNode: node]);
    }
  else
    {
      ASSIGN (icon, [fsnodeRep multipleSelectionIconOfSize: ICON_SIZE]);
    }

  if (isRootIcon)
    {
      NSHost *host = [NSHost currentHost];
      NSString *hname = [host name];
      NSRange range = [hname rangeOfString: @"."];

      if (range.length != 0)
	hname = [hname substringToIndex: range.location];
      ASSIGN (hostname, hname);
    }
  else
    {
      RELEASE (hostname);
      hostname = nil;
    }

  [self setLabelWidth];
  [tview setLabelRectOfIcon: self];
}

 - (NSString *)shownName
 {
  return (isRootIcon ? hostname : name);
 }


- (NSArray *)paths
{
  return paths;
}

- (BOOL)isSinglePath
{
  return singlepath;
}

 - (void)renewIcon
 {
   if (singlepath)
     ASSIGN (icon, [fsnodeRep iconOfSize: ICON_SIZE forNode: node]);
   else
     ASSIGN (icon, [fsnodeRep multipleSelectionIconOfSize: ICON_SIZE]);

   [self setNeedsDisplay: YES];
 }

// maybe this can improved with shared super-class code
- (void)setLabelWidth
{
  NSFont *font = [NSFont systemFontOfSize: 12];
  NSRect rect = [namelabel frame];
  NSString *nstr = isRootIcon ? hostname : name;

  labelWidth = [tview cellsWidth] - 8;

  if (isSelected)
    {
      [namelabel setFrame: NSMakeRect(0, 0, [font widthOfString: nstr] + 8, 14)];
      [namelabel setStringValue: nstr];
    }
  else
    {
      int width = (int)[[namelabel font] widthOfString: nstr] + 8;
      if (width > labelWidth)
	{
	  width = labelWidth;
	}
      [namelabel setFrame: NSMakeRect(0, 0, width, 14)];
      [namelabel setStringValue: cutFileLabelText(nstr, namelabel, width - 8)];
    }

  [(NSView *)tview setNeedsDisplayInRect: rect];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  if ([theEvent clickCount] >= minimumLaunchClicks)
    {
      if (locked == NO)
	[tview openCurrentSelection: paths];

      [self unselect];
    }
}

- (void)mouseDown:(NSEvent *)theEvent
{
  unsigned eventmask = NSAlternateKeyMask | NSCommandKeyMask | NSControlKeyMask;

  CHECK_LOCK;

  if ([theEvent clickCount] == 1)
    {
      NSEvent *nextEvent;
      NSPoint location;
      NSSize offset;
      BOOL startdnd = NO;

      if (isSelected == NO)
	{
	  [self select];
	}

      location = [theEvent locationInWindow];

      while (1)
	{
	  nextEvent = [[self window] nextEventMatchingMask:
				       NSLeftMouseUpMask | NSLeftMouseDraggedMask];

	  if ([nextEvent type] == NSLeftMouseUp)
	    {
	      if ([theEvent modifierFlags] & eventmask)
		{
		  [tview setCurrentSelection: paths];
		}
	      // post again, or mouse-up gets eaten
	      [[self window] postEvent: nextEvent atStart: YES];
	      [self unselect];
	      break;

	    }
	  else if ([nextEvent type] == NSLeftMouseDragged)
	    {
	      if (dragDelay < 5)
		{
		  dragDelay++;
		}
	      else
		{
		  NSPoint p = [nextEvent locationInWindow];
		  offset = NSMakeSize(p.x - location.x, p.y - location.y);
		  startdnd = YES;
		  break;
		}
	    }
	}

      if (startdnd)
	{
	  [tview setFocusedIcon: nil];
	  [self startExternalDragOnEvent: theEvent withMouseOffset: offset];
	}
    }
}

@end

@implementation TShelfFileIcon (DraggingSource)

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSArray *dndtypes = [NSArray arrayWithObject: NSFilenamesPboardType];
  [pb declareTypes: dndtypes owner: nil];
  [pb setPropertyList: paths forType: NSFilenamesPboardType];
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationEvery;
}

@end

@implementation TShelfFileIcon (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb;
  NSDragOperation sourceDragMask;
  NSArray *sourcePaths;
  NSString *fromPath;
  NSString *buff;
  unsigned i, count;

  CHECK_LOCK_RET (NSDragOperationNone);

  isDragTarget = NO;

  pb = [sender draggingPasteboard];
  sourcePaths = nil;

  if ([[pb types] containsObject: NSFilenamesPboardType])
    {
      sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
    }
  else if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"])
    {
      if ([node isApplication] == NO)
	{
	  NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"];
	  NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];

	  sourcePaths = [pbDict objectForKey: @"paths"];
	}
    }
  else if ([[pb types] containsObject: @"GWLSFolderPboardType"])
    {
      if ([node isApplication] == NO)
	{
	  NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"];
	  NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];

	  sourcePaths = [pbDict objectForKey: @"paths"];
	}
    }

  if (sourcePaths == nil)
    return NSDragOperationNone;

  if ([paths isEqualToArray: sourcePaths])
    {
      onSelf = YES;
      isDragTarget = YES;
      return NSDragOperationEvery;
    }

  if (node == nil)
    return NSDragOperationNone;

  if ((([node isDirectory] == NO) && ([node isMountPoint] == NO))
      || ([node isPackage] && ([node isApplication] == NO)))
    {
      return NSDragOperationNone;
    }

  count = [sourcePaths count];
  fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

  if (count == 0)
    return NSDragOperationNone;

  if (([node isWritable] == NO) && ([node isApplication] == NO))
    return NSDragOperationNone;

  if ([[node path] isEqual: fromPath])
    return NSDragOperationNone;

  if ([sourcePaths containsObject: [node path]])
    return NSDragOperationNone;

  buff = [NSString stringWithString: [node path]];
  while (![buff isEqual: path_separator()])
    {
      for (i = 0; i < count; i++)
        {
          if ([buff isEqual: [sourcePaths objectAtIndex: i]])
            return NSDragOperationNone;
        }
      buff = [buff stringByDeletingLastPathComponent];
    }

  if ([node isDirectory] && [node isParentOfPath: fromPath])
    {
      NSArray *subNodes = [node subNodes];

      for (i = 0; i < [subNodes count]; i++)
	{
	  FSNode *nd = [subNodes objectAtIndex: i];

	  if ([nd isDirectory])
	    {
	      int j;

	      for (j = 0; j < count; j++)
		{
		  NSString *fname = [[sourcePaths objectAtIndex: j] lastPathComponent];

		  if ([[nd name] isEqual: fname])
		    {
		      return NSDragOperationNone;
		    }
		}
	    }
	}
    }

  if ([node isApplication])
    {
      for (i = 0; i < count; i++)
	{
	  CREATE_AUTORELEASE_POOL(arp);
	  FSNode *nd = [FSNode nodeWithPath: [sourcePaths objectAtIndex: i]];

	  if (([nd isPlain] == NO) && ([nd isPackage] == NO))
	    {
	      RELEASE (arp);
	      return NSDragOperationNone;
	    }
	  RELEASE (arp);
	}
    }

  isDragTarget = YES;
  forceCopy = NO;

  ASSIGN (icon, [fsnodeRep openFolderIconOfSize: ICON_SIZE forNode: node]);
  [self setNeedsDisplay: YES];

  sourceDragMask = [sender draggingSourceOperationMask];

  if (sourceDragMask == NSDragOperationCopy)
    {
      return ([node isApplication] ? NSDragOperationMove : NSDragOperationCopy);
    }
  else if (sourceDragMask == NSDragOperationLink)
    {
      return ([node isApplication] ? NSDragOperationMove : NSDragOperationLink);
    }
  else
    {
      if ([[NSFileManager defaultManager] isWritableFileAtPath: fromPath]
	  || [node isApplication])
	{
	  return NSDragOperationEvery;
	}
      else if ([node isApplication] == NO)
	{
	  forceCopy = YES;
	  return NSDragOperationCopy;
	}
    }

  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;

  if (node == nil)
    return NSDragOperationNone;

  if ((isDragTarget == NO) || locked
      || ([node isPackage] && ([node isApplication] == NO)))
    {
      return NSDragOperationNone;
    }

  sourceDragMask = [sender draggingSourceOperationMask];

  if (sourceDragMask == NSDragOperationCopy)
    {
      return ([node isApplication] ? NSDragOperationMove : NSDragOperationCopy);
    }
  else if (sourceDragMask == NSDragOperationLink)
    {
      return ([node isApplication] ? NSDragOperationMove : NSDragOperationLink);
    }
  else
    {
      return forceCopy ? NSDragOperationCopy : NSDragOperationEvery;
    }

  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if (isDragTarget)
    {
      isDragTarget = NO;
      if (onSelf == NO)
	{
	  if (node)
	    {
	      ASSIGN (icon, [fsnodeRep iconOfSize: ICON_SIZE forNode: node]);
	      [self setNeedsDisplay: YES];
	    }
	}
      onSelf = NO;
    }
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
  NSUInteger i;

  isDragTarget = NO;

  if (onSelf)
    {
      onSelf = NO;
      return;
    }

  if (node)
    {
      ASSIGN (icon, [fsnodeRep iconOfSize: ICON_SIZE forNode: node]);
      [self setNeedsDisplay: YES];
    }

  sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];

  if ([node isApplication] == NO)
    {
      if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"])
	{
	  NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"];

	  [gw concludeRemoteFilesDragOperation: pbData
				   atLocalPath: [node path]];
	  return;

	}
      else if ([[pb types] containsObject: @"GWLSFolderPboardType"])
	{
	  NSData *pbData = [pb dataForType: @"GWLSFolderPboardType"];

	  [gw lsfolderDragOperation: pbData
		    concludedAtPath: [node path]];
	  return;
	}
    }

  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

  if ([node isApplication] == NO)
    {
      source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

      if ([source isEqual: [gw trashPath]])
	{
	  operation = @"GWorkspaceRecycleOutOperation";
	}
      else
	{
	  if (sourceDragMask == NSDragOperationCopy)
	    {
	      operation = NSWorkspaceCopyOperation;
	    }
	  else if (sourceDragMask == NSDragOperationLink)
	    {
	      operation = NSWorkspaceLinkOperation;
	    }
	  else
	    {
	      if ([fm isWritableFileAtPath: source])
		{
		  operation = NSWorkspaceMoveOperation;
		}
	      else
		{
		  operation = NSWorkspaceCopyOperation;
		}
	    }
	}

      files = [NSMutableArray arrayWithCapacity: 1];
      for (i = 0; i < [sourcePaths count]; i++)
	[files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];

      opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
      [opDict setObject: operation forKey: @"operation"];
      [opDict setObject: source forKey: @"source"];
      [opDict setObject: [node path] forKey: @"destination"];
      [opDict setObject: files forKey: @"files"];

      [gw performFileOperation: opDict];

    }
  else
    {
      for (i = 0; i < [sourcePaths count]; i++)
	{
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
