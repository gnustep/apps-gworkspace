 /*  -*-objc-*-
 *  Shelf.m: Implementation of the Shelf Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
#include "Shelf.h"
#include "ShelfIcon.h"
#include "GWRemote.h"
#include "GNUstep.h"

@interface ShelfIcon (ShelfSorting)
- (NSComparisonResult)iconCompare:(ShelfIcon *)other;
@end

@implementation ShelfIcon (ShelfSorting)

- (NSComparisonResult)iconCompare:(ShelfIcon *)other
{
	if ([other gridindex] > [self gridindex]) {
		return NSOrderedAscending;	
	} else {
		return NSOrderedDescending;	
	}

	return NSOrderedSame;
}

@end

@implementation Shelf

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
	[self unsetWatchers];
	if (gpoints != NULL) {
		NSZoneFree (NSDefaultMallocZone(), gpoints);
	}
	RELEASE (icons);  
  TEST_RELEASE (viewerPath);
	RELEASE (watchedPaths);
	TEST_RELEASE (dragImage);
  RELEASE (remoteHostName);
  [super dealloc];
}

- (id)initWithIconsDicts:(NSArray *)iconsDicts 
                rootPath:(NSString *)rpath
              remoteHost:(NSString *)rhost
{	
	self = [super init];
  if (self) {
    int i, j;

    gw = [GWRemote gwremote];
				
		makePosSel = @selector(makePositions);
		makePos = (IMP)[self methodForSelector: makePosSel];

		gridPointSel = @selector(gridPointNearestToPoint:);
		gridPoint = (GridPointIMP)[self methodForSelector: gridPointSel];
		
    cellsWidth = [gw shelfCellsWidth];
    
    if (rpath != nil) {
      ASSIGN (viewerPath, rpath);
    } else {
      viewerPath = nil;
    }
		
    ASSIGN (remoteHostName, rhost);
    
		watchedPaths = [[NSMutableArray alloc] initWithCapacity: 1];
		
		icons = [[NSMutableArray alloc] initWithCapacity: 1];
        
    for (i = 0; i < [iconsDicts count]; i++) { 
			NSDictionary *iconDict = [iconsDicts objectAtIndex: i];
      NSArray *iconpaths = [iconDict objectForKey: @"paths"];
			int index = [[iconDict objectForKey: @"index"] intValue];
      BOOL canadd = YES;
                
      for (j = 0; j < [iconpaths count]; j++) {
        NSString *p = [iconpaths objectAtIndex: j];
        if ([gw server: remoteHostName fileExistsAtPath: p]) {
                  
          if (viewerPath != nil) {
            if ((subPathOfPath(viewerPath, p) == NO)
                              && ([viewerPath isEqualToString: p] == NO)) {
              canadd = NO;
              break;
            }
          } 
          
        } else {
          canadd = NO;
          break;
        }
      }
    
      if ((canadd == YES) && (index != -1)) {
				[self addIconWithPaths: iconpaths withGridIndex: index];
      }
    }
		
		gpoints = NULL;
		pcount = 0;
		isDragTarget = NO;
		dragImage = nil;
    isShiftClick = NO;
		
  	[self registerForDraggedTypes: [NSArray arrayWithObjects: GWRemoteFilenamesPboardType, nil]];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(cellsWidthChanged:) 
                					    name: GWShelfCellsWidthChangedNotification
                					  object: nil];
  
//		[[NSNotificationCenter defaultCenter] addObserver: self 
//                			selector: @selector(watcherNotification:) 
//                					name: GWFileWatcherFileDidChangeNotification
//                				object: nil];
	}
  	return self;	
}

- (NSArray *)iconsDicts
{ 
  NSMutableArray *iconsdicts = [NSMutableArray arrayWithCapacity: 1]; 
  int i;
	  
	for (i = 0; i < [icons count]; i++) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];
		ShelfIcon *icon = [icons objectAtIndex: i];
		int index;
		
		[dict setObject: [icon paths] forKey: @"paths"];
		index = [icon gridindex];
		[dict setObject: [NSString stringWithFormat: @"%i", index] forKey: @"index"];

    [iconsdicts addObject: dict];
  }
  
  return iconsdicts;
}

- (void)addIconWithPaths:(NSArray *)iconpaths 
					 withGridIndex:(int)index 
{
	ShelfIcon *icon = [[ShelfIcon alloc] initForPaths: iconpaths 
                gridIndex: index inShelf: self remoteHost: remoteHostName];
	NSString *watched = [[iconpaths objectAtIndex: 0] stringByDeletingLastPathComponent];	
	
	if (gpoints != NULL) {
		if (index < pcount) {
			gpoints[index].used = 1;
		}
	}
	
	[icons addObject: icon];  
	[self addSubview: icon];
	[self addSubview: [icon myLabel]];		
	RELEASE (icon);    
	[self sortIcons];	
	[self resizeWithOldSuperviewSize: [self frame].size];  

	if ([watchedPaths containsObject: watched] == NO) {
		[watchedPaths addObject: watched];
		[self setWatcherForPath: watched];
	}
}

- (void)sortIcons
{
	NSArray *sortedIcons = [icons sortedArrayUsingSelector: @selector(iconCompare:)];	
	[icons removeAllObjects];
	[icons addObjectsFromArray: sortedIcons];
}

- (NSArray *)icons
{
  return icons;
}

- (void)cellsWidthChanged:(NSNotification *)notification
{
  int i;

  cellsWidth = [gw shelfCellsWidth];  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] setLabelWidth];
  }  
  [self resizeWithOldSuperviewSize: [self frame].size];
}

- (void)fileSystemDidChange:(NSDictionary *)info
{
  NSString *path = [info objectForKey: @"path"];
  
  if ([watchedPaths containsObject: path] == NO) {
    return;    

  } else {
    NSString *event = [info objectForKey: @"event"];
    BOOL contained = NO;
    int i;
    
	  if ([event isEqual: GWFileCreatedInWatchedDirectory]) {
		  return;
	  }
				
	  for (i = 0; i < [watchedPaths count]; i++) {
		  NSString *wpath = [watchedPaths objectAtIndex: i];
		  if (([wpath isEqual: path]) || (subPathOfPath(path, wpath))) {
			  contained = YES;
			  break;
		  }
	  }
        
    if (contained) {
		  id icon;
		  NSArray *ipaths;
		  NSString *ipath;
		  int count = [icons count];

		  if ([event isEqual: GWWatchedDirectoryDeleted]) {		
			  for (i = 0; i < count; i++) {
				  icon = [icons objectAtIndex: i];
				  ipaths = [icon paths];
				  ipath = [ipaths objectAtIndex: 0];

				  if (subPathOfPath(path, ipath)) {
					  [self removeIcon: icon];
					  count--;
					  i--;
				  }
			  }
			  return;
		  }		

		  if ([event isEqual: GWFileDeletedInWatchedDirectory]) { 
			  NSArray *files = [info objectForKey: @"files"];

			  for (i = 0; i < count; i++) {
				  int j;

				  icon = [icons objectAtIndex: i];
				  ipaths = [icon paths];				

				  if ([ipaths count] == 1) {
					  ipath = [ipaths objectAtIndex: 0];

					  for (j = 0; j < [files count]; j++) {
						  NSString *fname = [files objectAtIndex: j];
						  NSString *fullPath = [path stringByAppendingPathComponent: fname];

						  if ((subPathOfPath(fullPath, ipath))
															  || ([ipath isEqualToString: fullPath])) {
							  [self removeIcon: icon];
							  count--;
							  i--;
							  break;
						  }
					  }

				  } else {

					  for (j = 0; j < [files count]; j++) {
						  NSString *fname = [files objectAtIndex: j];
						  NSString *fullPath = [path stringByAppendingPathComponent: fname];
						  BOOL deleted = NO;
						  int m;

						  if (deleted) {
							  break;
						  }

						  ipath = [ipaths objectAtIndex: 0];
						  if (subPathOfPath(fullPath, ipath)) {
							  [self removeIcon: icon];
							  count--;
							  i--;
							  break;
						  }

						  for (m = 0; m < [ipaths count]; m++) {
							  ipath = [ipaths objectAtIndex: m];

							  if ([ipath isEqualToString: fullPath]) {
								  NSMutableArray *newpaths;

								  if ([ipaths count] == 1) {
									  [self removeIcon: icon];
									  count--;
									  i--;			
									  deleted = YES;
									  break;	
								  }

								  newpaths = [ipaths mutableCopy];
								  [newpaths removeObject: ipath];
								  [icon setPaths: newpaths];
								  ipaths = [icon paths];
								  RELEASE (newpaths);
							  }
						  }

					  }
				  }
			  }
		  }
	  }
  }
}

- (void)setWatchers
{
	int i;
	
  for (i = 0; i < [watchedPaths count]; i++) {
    [self setWatcherForPath: [watchedPaths objectAtIndex: i]];  
  }
}

- (void)setWatcherForPath:(NSString *)path
{
	[gw server: remoteHostName addWatcherForPath: path];
}

- (void)unsetWatchers
{
	int i;
	
  for (i = 0; i < [watchedPaths count]; i++) {
    [self unsetWatcherForPath: [watchedPaths objectAtIndex: i]];  
  }
}

- (void)unsetWatcherForPath:(NSString *)path
{
	[gw server: remoteHostName removeWatcherForPath: path];
}

- (void)makePositions
{
  float wdt, hgt, x, y;
	int posx, posy;
	int i;
  
  wdt = [self frame].size.width;
  hgt = [self frame].size.height;
	
	pcount = (int)((int)((wdt - 16) / cellsWidth) * (int)(MAXSHELFHEIGHT / 75));
		
 	if (gpoints != NULL) {
		NSZoneFree (NSDefaultMallocZone(), gpoints);
	} 
	gpoints = NSZoneMalloc (NSDefaultMallocZone(), sizeof(gridpoint) * pcount);		
	
  x = 16;
  y = hgt - 55;
	posx = 0;
	posy = 0;
	
	for (i = 0; i < pcount; i++) {
		if (i > 0) {
			x += cellsWidth;      
    }
    if (x >= (wdt - cellsWidth)) {
      x = 16;
      y -= 75;
			posx = 0;
			posy++;
    }  		
	
		gpoints[i].x = x;
		gpoints[i].y = y;
		gpoints[i].index = i;
		gpoints[i].used = 0;
		
		posx++;
	}
}

- (gridpoint *)gridPointNearestToPoint:(NSPoint)p
{
	float maxx = [self frame].size.width;
	float maxy = [self frame].size.height;
	float px = p.x;
	float py = p.y;	
	float minx = maxx;
	float miny = maxy;
	int pos = -1;
	int i;
		
	for (i = 0; i < pcount; i++) {
		if (gpoints[i].y > 0) {
			float dx = max(px, gpoints[i].x) - min(px, gpoints[i].x);
			float dy = max(py, gpoints[i].y) - min(py, gpoints[i].y);

			if ((dx <= minx) && (dy <= miny)) {
				minx = dx;
				miny = dy;
				pos = i;
			}
		}
	}
	
	return &gpoints[pos];
}

- (BOOL)isFreePosition:(NSPoint)pos
{
	int i;
	
	for (i = 0; i < [icons count]; i++) {
		NSPoint p = [[icons objectAtIndex: i] position];
		if (NSEqualPoints(pos, p)) {
			return NO;
		}
  }

	return YES;
}

- (void)setFrame:(NSRect)frameRect
{
	[super setFrame: frameRect];	
	makePos(self, makePosSel);
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
	int i;
				
	if (gpoints == NULL) {
		[super resizeWithOldSuperviewSize: oldFrameSize];
		return;
	}
		
	for (i = 0; i < pcount; i++) {	
		gpoints[i].used = 0;
	}
	
	for (i = 0; i < [icons count]; i++) {	
		id icon	 = [icons objectAtIndex: i];
		int index = [icon gridindex];		
		gridpoint gpoint = gpoints[index];
		NSPoint p = NSMakePoint(gpoint.x, gpoint.y);
		NSRect r = NSMakeRect(p.x, p.y, 64, 52);

		[icon setPosition: p];
		[icon setFrame: r];
		gpoints[index].used = 1;
		[self setLabelRectOfIcon: icon];		
	}
	
	[self sortIcons];
	[self setNeedsDisplay: YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [self unselectOtherIcons: nil];
}

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];

	if (dragImage != nil) {
    gridpoint *gpoint = [self gridPointNearestToPoint: dragPoint];
  
    if (gpoint->used == 0) {
      NSPoint p = NSMakePoint(dragPoint.x + 8, dragPoint.y);
		  [dragImage dissolveToPoint: p fraction: 0.3];
    }
	}
}

- (void)addIconWithPaths:(NSArray *)iconpaths
{
}

- (void)removeIcon:(id)anIcon
{
	ShelfIcon *icon = (ShelfIcon *)anIcon;
	int index = [icon gridindex];	
	NSString *watched = [[[icon paths] objectAtIndex: 0] stringByDeletingLastPathComponent];

	if ([watchedPaths containsObject: watched]) {
		[watchedPaths removeObject: watched];
		[self unsetWatcherForPath: watched];
	}
  
	gpoints[index].used = 0;
  [[icon myLabel] removeFromSuperview];
  [icon removeFromSuperview];
  [icons removeObject: icon];
	[self resizeWithOldSuperviewSize: [self frame].size];  
}

- (void)setLabelRectOfIcon:(id)anIcon
{
  ShelfIcon *icon;
	NSTextField *label;
	float iconwidth, labwidth, labxpos;
  NSRect labelRect;
  
  icon = (ShelfIcon *)anIcon;	
	label = [icon myLabel];
  
	iconwidth = [icon frame].size.width;
	labwidth = [label frame].size.width;

	if(iconwidth > labwidth) {
		labxpos = [icon frame].origin.x + ((iconwidth - labwidth) / 2);
	} else {
		labxpos = [icon frame].origin.x - ((labwidth - iconwidth) / 2);
	}
	
	labelRect = NSMakeRect(labxpos, [icon frame].origin.y - 15, labwidth, 14);
	[label setFrame: labelRect];
}

- (void)unselectOtherIcons:(id)anIcon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    ShelfIcon *icon = [icons objectAtIndex: i];
    if (icon != anIcon) {  
      [icon unselect];
    }
  }  
}

- (void)setShiftClick:(BOOL)value
{
  isShiftClick = value;
}

- (void)setCurrentSelection:(NSArray *)paths
{
  [delegate shelf: self setCurrentSelection: paths];      
}

- (void)setCurrentSelection:(NSArray *)paths 
               animateImage:(NSImage *)image
            startingAtPoint:(NSPoint)startp
{
  [delegate shelf: self setCurrentSelection: paths 
                 animateImage: image startingAtPoint: startp]; 
}

- (void)openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv
{
  [delegate shelf: self openCurrentSelection: paths newViewer: newv];
}

- (NSArray *)currentSelection
{
  return nil;
}

- (void)keyDown:(NSEvent *)theEvent 
{
  [delegate shelf: self keyDown: theEvent];
}

- (int)cellsWidth
{
  return cellsWidth;
}

- (void)setDelegate:(id)anObject
{
  delegate = anObject;
}

- (id)delegate
{
  return delegate;
}

@end

@implementation Shelf(DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	gridpoint *gpoint;
	
	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}
	  
  if ([[pb types] indexOfObject: GWRemoteFilenamesPboardType] != NSNotFound) {
    isDragTarget = YES;	
		DESTROY (dragImage);
		dragPoint = [sender draggedImageLocation];	
		dragPoint = [self convertPoint: dragPoint 
													fromView: [[self window] contentView]];													
		gpoint = [self gridPointNearestToPoint: dragPoint];						
		dragPoint = NSMakePoint(gpoint->x, gpoint->y);
    ASSIGN (dragImage, [sender draggedImage]);
		dragRect = NSMakeRect(dragPoint.x + 8, dragPoint.y, [dragImage size].width, [dragImage size].height);
		[self setNeedsDisplay: YES];
    return NSDragOperationAll;
  }
	isDragTarget = NO;	
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	NSPoint p = [sender draggedImageLocation];
	p = [self convertPoint: p fromView: [[self window] contentView]];
	
	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}

	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}	
	
	if (NSEqualPoints(dragPoint, p) == NO) {
		gridpoint *gpoint;
		
    if ([self isFreePosition: dragPoint]) {
		  [self setNeedsDisplayInRect: dragRect];
    }
		
		gpoint = gridPoint(self, gridPointSel, p);
		dragPoint = NSMakePoint(gpoint->x, gpoint->y);
				
		if (gpoint->used == 0) {
			dragRect = NSMakeRect(dragPoint.x + 8, dragPoint.y, [dragImage size].width, [dragImage size].height);
			if (dragImage == nil) {
				ASSIGN (dragImage, [sender draggedImage]);
			}
			[self setNeedsDisplayInRect: dragRect];
			
		} else {
			if (dragImage != nil) {
				DESTROY (dragImage);
			}
			return NSDragOperationNone;
		}
	}

	return NSDragOperationAll;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	if (dragImage != nil) {
		DESTROY (dragImage);
    [self setNeedsDisplay: YES];
	}

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
	NSPasteboard *pb = [sender draggingPasteboard];
	NSData *pbData = [pb dataForType: GWRemoteFilenamesPboardType];

  isDragTarget = NO;

	if (dragImage != nil) {
		DESTROY (dragImage);
		[self setNeedsDisplay: YES];
	}
		
	if (pbData) {
    NSDictionary *dndDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    NSString *remoteHost = [dndDict objectForKey: @"host"]; 
    NSArray *sourcePaths = [dndDict objectForKey: @"paths"]; 
    NSPoint p = [sender draggedImageLocation];
		gridpoint *gpoint;
		int index, i;

    if ([remoteHost isEqual: remoteHostName] == NO) {
      return;
    }
				        
    if (viewerPath != nil) {
      for (i = 0; i < [sourcePaths count]; i++) {        
        NSString *s = [sourcePaths objectAtIndex: i];

        if ((subPathOfPath(viewerPath, s) == NO)
                        && ([viewerPath isEqualToString: s] == NO)) {          
          return;       
        }
      }
    }       
    
		p = [self convertPoint: p fromView: [[self window] contentView]];
		gpoint = [self gridPointNearestToPoint: p];
		p = NSMakePoint(gpoint->x, gpoint->y);
		index = gpoint->index;
		
		if (gpoint->used == 0) {
    	for (i = 0; i < [icons count]; i++) {
      	ShelfIcon *icon = [icons objectAtIndex: i];
      	if ([[icon paths] isEqualToArray: sourcePaths]) {
					gpoints[[icon gridindex]].used = 0;
					gpoint->used = 1;					  
					[icon setGridIndex: index];
        	[self resizeWithOldSuperviewSize: [self frame].size];
        	return;
      	}
    	}
			
			[self addIconWithPaths: sourcePaths withGridIndex: index];
    }
	}
}

@end
