/* TShelfIconsView.m
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
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "TShelfIconsView.h"
#include "TShelfIcon.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#define CELLS_WIDTH 80

@interface TShelfIcon (TShelfIconsViewSorting)

- (NSComparisonResult)iconCompare:(TShelfIcon *)other;

@end

@implementation TShelfIcon (TShelfIconsViewSorting)

- (NSComparisonResult)iconCompare:(TShelfIcon *)other
{
	if ([other gridindex] > [self gridindex]) {
		return NSOrderedAscending;	
	} else {
		return NSOrderedDescending;	
	}

	return NSOrderedSame;
}

@end

@implementation TShelfIconsView

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
	[self unsetWatchers];
	if (gpoints != NULL) {
		NSZoneFree (NSDefaultMallocZone(), gpoints);
	}
	RELEASE (icons);  
	RELEASE (watchedPaths);
	TEST_RELEASE (dragImage);
  [super dealloc];
}

- (id)initWithIconsDescription:(NSArray *)idescr 
                     iconsType:(int)itype
                      lastView:(BOOL)last
{	
	self = [super init];
  
  if (self) {
    int i, j;

    fm = [NSFileManager defaultManager];
    gw = [GWorkspace gworkspace];
				
		makePosSel = @selector(makePositions);
		makePos = (IMP)[self methodForSelector: makePosSel];

		gridPointSel = @selector(gridPointNearestToPoint:);
		gridPoint = (GridPointIMP)[self methodForSelector: gridPointSel];
		
    cellsWidth = CELLS_WIDTH;
    		
		watchedPaths = [[NSMutableArray alloc] initWithCapacity: 1];
		
		icons = [[NSMutableArray alloc] initWithCapacity: 1];
        
    iconsType = itype;
    isLastView = last;
        
    if (idescr && [idescr count]) {    
      for (i = 0; i < [idescr count]; i++) { 
			  NSDictionary *iconDict = [idescr objectAtIndex: i];
        NSArray *iconpaths = [iconDict objectForKey: @"paths"];
			  int index = [[iconDict objectForKey: @"index"] intValue];
        BOOL canadd = YES;

        for (j = 0; j < [iconpaths count]; j++) {
          NSString *p = [iconpaths objectAtIndex: j];
          if ([fm fileExistsAtPath: p] == NO) {
            canadd = NO;
            break;
          } 
        }

        if ((canadd == YES) && (index != -1)) {
				  [self addIconWithPaths: iconpaths withGridIndex: index];
        }
      }
		}
        
		gpoints = NULL;
		pcount = 0;
		isDragTarget = NO;
		dragImage = nil;
		
    if (isLastView == NO) {
  	  [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
    
		  [[NSNotificationCenter defaultCenter] 
                 addObserver: self 
                	  selector: @selector(fileSystemWillChange:) 
                			  name: GWFileSystemWillChangeNotification
                		  object: nil];

		  [[NSNotificationCenter defaultCenter] 
                 addObserver: self 
                	  selector: @selector(fileSystemDidChange:) 
                			  name: GWFileSystemDidChangeNotification
                		  object: nil];                     

		  [[NSNotificationCenter defaultCenter] 
                 addObserver: self 
                    selector: @selector(watcherNotification:) 
                		    name: GWFileWatcherFileDidChangeNotification
                	    object: nil];
    }
	}
  
  return self;	
}

- (NSArray *)iconsDescription
{ 
  NSMutableArray *arr = [NSMutableArray arrayWithCapacity: 1]; 
  int i;
	  
	for (i = 0; i < [icons count]; i++) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];
		TShelfIcon *icon = [icons objectAtIndex: i];
		int index;
		
		[dict setObject: [icon paths] forKey: @"paths"];
		index = [icon gridindex];
		[dict setObject: [NSNumber numberWithInt: index] forKey: @"index"];

    [arr addObject: dict];
  }
  
  return arr;
}

- (void)addIconWithPaths:(NSArray *)iconpaths 
					 withGridIndex:(int)index 
{
	TShelfIcon *icon = [[TShelfIcon alloc] initForPaths: iconpaths 
															 gridIndex: index inIconsView: self];
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

- (void)removeIcon:(id)anIcon
{
	TShelfIcon *icon = (TShelfIcon *)anIcon;
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
  TShelfIcon *icon;
	NSTextField *label;
	float iconwidth, labwidth, labxpos;
  NSRect labelRect;
  
  icon = (TShelfIcon *)anIcon;	
	label = [icon myLabel];
  
	iconwidth = [icon frame].size.width;
	labwidth = [label frame].size.width;

	if(iconwidth > labwidth) {
		labxpos = [icon frame].origin.x + ((iconwidth - labwidth) / 2);
	} else {
		labxpos = [icon frame].origin.x - ((labwidth - iconwidth) / 2);
	}
	
	labelRect = NSMakeRect(labxpos, [icon frame].origin.y - 14, labwidth, 14);
	[label setFrame: labelRect];
}

- (void)unselectOtherIcons:(id)anIcon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    TShelfIcon *icon = [icons objectAtIndex: i];
    if (icon != anIcon) {  
      [icon unselect];
    }
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

- (int)iconsType
{
  return iconsType;
}

- (void)updateIcons
{
  int i;

  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] renewIcon];
  }  
}

- (void)setCurrentSelection:(NSArray *)paths
{
  [gw rootViewerSelectFiles: paths];
}

- (void)openCurrentSelection:(NSArray *)paths
{
  [gw openSelectedPaths: paths newViewer: NO];
}

- (void)fileSystemWillChange:(NSNotification *)notification
{
  NSDictionary *dict = [notification userInfo];
  NSString *operation = [dict objectForKey: @"operation"];
	NSString *source = [dict objectForKey: @"source"];	  
	NSArray *files = [dict objectForKey: @"files"];	 

  if ([operation isEqual: NSWorkspaceMoveOperation] 
        || [operation isEqual: NSWorkspaceDestroyOperation]
				|| [operation isEqual: GWorkspaceRenameOperation]
				|| [operation isEqual: NSWorkspaceRecycleOperation]
				|| [operation isEqual: GWorkspaceRecycleOutOperation]
				|| [operation isEqual: GWorkspaceEmptyRecyclerOperation]) {
    
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity: 1];
    NSArray *iconpaths;
    int i, j, m;

    for (i = 0; i < [files count]; i++) {
      NSString *s = [source stringByAppendingPathComponent: [files objectAtIndex: i]];
      [paths addObject: s];
    }

	  for (i = 0; i < [icons count]; i++) {
		  TShelfIcon *icon = [icons objectAtIndex: i];
      
      iconpaths = [icon paths];

	    for (j = 0; j < [iconpaths count]; j++) {
        NSString *op = [iconpaths objectAtIndex: j];

	      for (m = 0; m < [paths count]; m++) {
          NSString *fp = [paths objectAtIndex: m]; 

          if ([op hasPrefix: fp]) {
            [icon setLocked: YES]; 
            break;
          }
        }
      }
	  }
  }
}

- (void)fileSystemDidChange:(NSNotification *)notification
{
  NSDictionary *dict;
  NSString *operation, *source, *destination;
  NSArray *files;
  NSMutableArray *paths;
  TShelfIcon *icon;
  NSArray *iconpaths;
  int count;
	int i, j, m;
  
  dict = [notification userInfo];
  operation = [dict objectForKey: @"operation"];
  source = [dict objectForKey: @"source"];
  destination = [dict objectForKey: @"destination"];
  files = [dict objectForKey: @"files"];
		                    
  if ([operation isEqual: GWorkspaceRenameOperation]) {      
    for (i = 0; i < [icons count]; i++) {
      icon = [icons objectAtIndex: i];      
      if ([icon isSinglePath] == YES) {      
        if ([[[icon paths] objectAtIndex: 0] isEqualToString: source]) {     
          [icon setPaths: [NSArray arrayWithObject: destination]];
          [icon setNeedsDisplay: YES];
					[self resizeWithOldSuperviewSize: [self frame].size];  
          break;
        }
      }          
    }        
  }  

  if ([operation isEqual: GWorkspaceRenameOperation]) {
		files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent];
  }	
		                    
  if ([operation isEqual: NSWorkspaceMoveOperation] 
        || [operation isEqual: NSWorkspaceDestroyOperation]
				|| [operation isEqual: GWorkspaceRenameOperation]
				|| [operation isEqual: NSWorkspaceRecycleOperation]
				|| [operation isEqual: GWorkspaceRecycleOutOperation]
				|| [operation isEqual: GWorkspaceEmptyRecyclerOperation]) {

    paths = [NSMutableArray arrayWithCapacity: 1];
    for (i = 0; i < [files count]; i++) {
      NSString *s = [source stringByAppendingPathComponent: [files objectAtIndex: i]];
      [paths addObject: s];
    }
        
    count = [icons count];  
	  for (i = 0; i < count; i++) {
      BOOL deleted = NO;
		  icon = [icons objectAtIndex: i];
      iconpaths = [icon paths];

	    for (j = 0; j < [iconpaths count]; j++) {
        NSString *op = [iconpaths objectAtIndex: j];

	      for (m = 0; m < [paths count]; m++) {
          NSString *fp = [paths objectAtIndex: m]; 

          if ([op hasPrefix: fp]) {
            [self removeIcon: icon];
            count--;
            i--;
            deleted = YES;
            break;
          }

          if (deleted) {
            break;
          } 

        }

        if (deleted) {
          break;
        }       
      }
	  }
  }
}

- (void)watcherNotification:(NSNotification *)notification
{
	NSDictionary *notifdict = (NSDictionary *)[notification object];
  NSString *path = [notifdict objectForKey: @"path"];
	NSString *event = [notifdict objectForKey: @"event"];
	BOOL contained = NO;
	int i;

	if (event == GWFileCreatedInWatchedDirectory) {
		return;
	}
	
	for (i = 0; i < [watchedPaths count]; i++) {
		NSString *wpath = [watchedPaths objectAtIndex: i];
		if (([wpath isEqualToString: path]) || (subPathOfPath(path, wpath))) {
			contained = YES;
			break;
		}
	}

  if (contained) {
		id icon;
		NSArray *ipaths;
		NSString *ipath;
		int count = [icons count];

		if (event == GWWatchedDirectoryDeleted) {		
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
		
		if (event == GWFileDeletedInWatchedDirectory) { 
			NSArray *files = [notifdict objectForKey: @"files"];
						
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

- (void)setWatchers
{
	int i;
	
  for (i = 0; i < [watchedPaths count]; i++) {
    [self setWatcherForPath: [watchedPaths objectAtIndex: i]];  
  }
}

- (void)setWatcherForPath:(NSString *)path
{
	[GWLib addWatcherForPath: path];
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
	[GWLib removeWatcherForPath: path];
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
  y = hgt - 62;
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

- (int)cellsWidth
{
  return cellsWidth;
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

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

@end

@implementation TShelfIconsView(DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	gridpoint *gpoint;
	
	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}
	  
  if ([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
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
  NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 

  isDragTarget = NO;

	if (dragImage != nil) {
		DESTROY (dragImage);
		[self setNeedsDisplay: YES];
	}
		
	if (sourcePaths) {
    NSPoint p = [sender draggedImageLocation];
		gridpoint *gpoint;
		int index, i;
				            
		p = [self convertPoint: p fromView: [[self window] contentView]];
		gpoint = [self gridPointNearestToPoint: p];
		p = NSMakePoint(gpoint->x, gpoint->y);
		index = gpoint->index;
		
		if (gpoint->used == 0) {
    	for (i = 0; i < [icons count]; i++) {
      	TShelfIcon *icon = [icons objectAtIndex: i];
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
