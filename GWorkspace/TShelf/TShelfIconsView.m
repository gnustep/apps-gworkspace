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
#include "TShelfPBIcon.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#define CELLS_WIDTH 80

@interface TShelfIcon (TShelfIconsViewSorting)

- (NSComparisonResult)iconCompare:(id)other;

@end

@implementation TShelfIcon (TShelfIconsViewSorting)

- (NSComparisonResult)iconCompare:(id)other
{
	if ([other gridindex] > [self gridindex]) {
		return NSOrderedAscending;	
	} else {
		return NSOrderedDescending;	
	}

	return NSOrderedSame;
}

@end

@interface TShelfPBIcon (TShelfIconsViewSorting)

- (NSComparisonResult)pbiconCompare:(id)other;

@end

@implementation TShelfPBIcon (TShelfIconsViewSorting)

- (NSComparisonResult)pbiconCompare:(id)other
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
    NSArray *hiddenPaths = [GWLib hiddenPaths];
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
			  int index = [[iconDict objectForKey: @"index"] intValue];
        
        if (iconsType == FILES_TAB) {
          NSArray *iconpaths = [iconDict objectForKey: @"paths"];
          BOOL canadd = YES;

          for (j = 0; j < [iconpaths count]; j++) {
            NSString *p = [iconpaths objectAtIndex: j];
            if (([fm fileExistsAtPath: p] == NO) || [hiddenPaths containsObject: p]) {
              canadd = NO;
              break;
            } 
          }

          if ((canadd == YES) && (index != -1)) {
				    [self addIconWithPaths: iconpaths withGridIndex: index];
          }
          
        } else {
          NSString *dataPath = [iconDict objectForKey: @"datapath"];
          NSString *dataType = [iconDict objectForKey: @"datatype"];
                    
          if ([fm fileExistsAtPath: dataPath]) {
            [self addPBIconForDataAtPath: dataPath
                                dataType: dataType
					                 withGridIndex: index];
          }
        }
      }
		}
        
		gpoints = NULL;
		pcount = 0;
		isDragTarget = NO;
		dragImage = nil;
		
    if (isLastView == NO) {
      if (iconsType == FILES_TAB) {
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
      } else {
        NSArray *types = [NSArray arrayWithObjects: NSStringPboardType,
                                                    NSRTFPboardType,
                                                    NSRTFDPboardType,
                                                    NSTIFFPboardType,
                                                    NSFileContentsPboardType,
                                                    NSColorPboardType,
                                                    @"IBViewPboardType",
                                                    nil];
  	    [self registerForDraggedTypes: types];
        [self setWatcherForPath: [gw tshelfPBDir]];
      }
    
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
    id icon;
    int index;

    icon = [icons objectAtIndex: i];
    index = [icon gridindex];
    [dict setObject: [NSNumber numberWithInt: index] forKey: @"index"];
		
    if (iconsType == FILES_TAB) {
		  [dict setObject: [icon paths] forKey: @"paths"];
    } else {
		  [dict setObject: [icon dataPath] forKey: @"datapath"];
		  [dict setObject: [icon dataType] forKey: @"datatype"];      
    }
    
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

- (TShelfPBIcon *)addPBIconForDataAtPath:(NSString *)dpath 
                                dataType:(NSString *)dtype
					                 withGridIndex:(int)index 
{
  TShelfPBIcon *icon = [[TShelfPBIcon alloc] initForPBDataAtPath: dpath
                            ofType: dtype gridIndex: index inIconsView: self];
              
	if (gpoints != NULL) {
		if (index < pcount) {
			gpoints[index].used = 1;
		}
	}

	[icons addObject: icon];  
	[self addSubview: icon];
	RELEASE (icon);    
	[self sortIcons];	
	[self resizeWithOldSuperviewSize: [self frame].size]; 
  
  return icon; 
}

- (void)removeIcon:(id)anIcon
{
  int index = [anIcon gridindex];	

  if (iconsType == FILES_TAB) {
	  NSString *watched = [[[anIcon paths] objectAtIndex: 0] stringByDeletingLastPathComponent];

	  if ([watchedPaths containsObject: watched]) {
		  [watchedPaths removeObject: watched];
		  [self unsetWatcherForPath: watched];
	  }
  
    [[anIcon myLabel] removeFromSuperview];
  }
  
  [anIcon removeFromSuperview];
  [icons removeObject: anIcon];
  gpoints[index].used = 0;
  [self resizeWithOldSuperviewSize: [self frame].size];  
}

- (void)removePBIconsWithData:(NSData *)data ofType:(NSString *)type
{
  int count = [icons count];
  int i;

  for (i = count - 1; i >= 0; i--) {
    TShelfPBIcon *icon = [icons objectAtIndex: i];

    if ([[icon dataType] isEqual: type]) {
      if ([[icon data] isEqual: data]) {
        NSString *dataPath = [icon dataPath];
  
        RETAIN (dataPath);
        [self removeIcon: icon];
        [fm removeFileAtPath: dataPath handler: nil];
        RELEASE (dataPath);
      }
    }
  }
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

- (BOOL)hasSelectedIcon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    TShelfIcon *icon = [icons objectAtIndex: i];
    if ([icon isSelect]) {  
      return YES;
    }
  }  

  return NO;
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
  SEL sel = (iconsType == FILES_TAB) ? @selector(iconCompare:) : @selector(pbiconCompare:);
	NSArray *sortedIcons = [icons sortedArrayUsingSelector: sel];	
  RETAIN (sortedIcons);
	[icons removeAllObjects];
	[icons addObjectsFromArray: sortedIcons];
  RELEASE (sortedIcons);
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

- (id)selectedIcon
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    id icon = [icons objectAtIndex: i];
    if ([icon isSelect]) {  
      return icon;
    }
  }  

  return nil;
}

- (void)setCurrentSelection:(NSArray *)paths
{
  [gw rootViewerSelectFiles: paths];
}

- (void)openCurrentSelection:(NSArray *)paths
{
  [gw openSelectedPaths: paths newViewer: NO];
}

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths
{
  if (iconsType == FILES_TAB) {
    int count = [icons count]; 
    int i;

	  for (i = 0; i < count; i++) {
      BOOL deleted = NO;
		  TShelfIcon *icon = [icons objectAtIndex: i];
      NSArray *iconpaths = [icon paths];
      int j;

	    for (j = 0; j < [iconpaths count]; j++) {
        NSString *op = [iconpaths objectAtIndex: j];
        int m;

	      for (m = 0; m < [hpaths count]; m++) {
          NSString *fp = [hpaths objectAtIndex: m]; 

          if (subPathOfPath(fp, op) || [fp isEqualToString: op]) {  
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
  
  if (iconsType == DATA_TAB) {
    int count = [icons count];
    
    if (event == GWFileDeletedInWatchedDirectory) { 
      NSArray *files = [notifdict objectForKey: @"files"];
    
      for (i = 0; i < count; i++) {
        TShelfPBIcon *icon = [icons objectAtIndex: i];
        NSString *dataPath = [icon dataPath];
        int j;
				  
        for (j = 0; j < [files count]; j++) {
          NSString *fname = [files objectAtIndex: j];
          NSString *fullPath = [path stringByAppendingPathComponent: fname];

          if ([fullPath isEqualToString: dataPath]) {
            [self removeIcon: icon];
            count--;
            i--;
          }
        }
      }
    }
  } else {
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
	int i;
  
  wdt = [self frame].size.width;
  hgt = [self frame].size.height;
	
	pcount = (int)((wdt - 16) / cellsWidth);
		
 	if (gpoints != NULL) {
		NSZoneFree (NSDefaultMallocZone(), gpoints);
	} 
	gpoints = NSZoneMalloc (NSDefaultMallocZone(), sizeof(gridpoint) * pcount);		
	
  x = 16;
  y = hgt - 59;
	
	for (i = 0; i < pcount; i++) {
		if (i > 0) {
			x += cellsWidth;      
    }
    gpoints[i].x = x;
    gpoints[i].y = y;
    gpoints[i].index = i;
    
    if (x < (wdt - cellsWidth)) {
      gpoints[i].used = 0;
    } else {
		  gpoints[i].used = 1;
    }
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
    
    if (iconsType == FILES_TAB) {
		  [self setLabelRectOfIcon: icon];		
    }
	}
	
	[self sortIcons];
	[self setNeedsDisplay: YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [self unselectOtherIcons: nil];
  
  if (iconsType == DATA_TAB) {
    [self setCurrentPBIcon: nil];
  }
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

@implementation TShelfIconsView(PBoardOperations)

- (void)setCurrentPBIcon:(id)anIcon
{
  if (anIcon) {
    NSString *dataPath = [anIcon dataPath];
    NSString *dataType = [anIcon dataType];
    NSImage *icn = [anIcon icon];
    NSData *data = [NSData dataWithContentsOfFile: dataPath];
    
    if (data) {
      [gw showPasteboardData: data ofType: dataType typeIcon: icn];
    }
  } else {
    [gw resetSelectedPaths];
  }
}

- (void)doCut
{
  TShelfPBIcon *icon = [self selectedIcon];

  if (icon) {
    NSString *dataPath = [icon dataPath];
  
    RETAIN (dataPath);
    [self doCopy];
    [self removeIcon: icon];
    [fm removeFileAtPath: dataPath handler: nil];
    RELEASE (dataPath);
    [gw resetSelectedPaths];
  }
}

- (void)doCopy
{
  TShelfPBIcon *icon = [self selectedIcon];

  if (icon) {
    NSString *dataPath = [icon dataPath];
    NSString *dataType = [icon dataType];
    NSData *data = [NSData dataWithContentsOfFile: dataPath];

    if (data) {
      NSPasteboard *pb = [NSPasteboard generalPasteboard];
      
      [pb declareTypes: [NSArray arrayWithObject: dataType] owner: self];
      [pb setData: data forType: dataType];
    }
  }
}

- (void)doPaste
{
  NSData *data;
  NSString *type;
  
  data = [self readSelectionFromPasteboard: [NSPasteboard generalPasteboard]
                                    ofType: &type];
     
  if (data) {         
    NSString *dpath = [gw tshelfPBFilePath];
		int index = -1; 
    int i;
    
	  for (i = 0; i < pcount; i++) {
		  if (gpoints[i].used == 0) {
        index = i;
		    break;
      }
    }
    
    if (index == -1) {
      NSRunAlertPanel(NSLocalizedString(@"Error!", @""),
                        NSLocalizedString(@"No space left on this tab", @""),
                        NSLocalizedString(@"Ok", @""),
                        nil,
                        nil);
      return;
    }
  
    if ([data writeToFile: dpath atomically: YES]) {
      [self addPBIconForDataAtPath: dpath
                          dataType: type
					           withGridIndex: index];
    }
  }
}

- (NSData *)readSelectionFromPasteboard:(NSPasteboard *)pboard 
                                 ofType:(NSString **)pbtype
{
  NSArray *types = [pboard types];
  NSData *data;
  NSString *type;
  int i;
  
  if ((types == nil) || ([types count] == 0)) {
    return nil;
  }

  for (i = 0; i < [types count]; i++) {
    type = [types objectAtIndex: 0];
    data = [pboard dataForType: type];
    if (data) {
      *pbtype = type;
      return data;
    }
  }
  
  return nil;
}

@end

@implementation TShelfIconsView(DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  BOOL found = YES;
  gridpoint *gpoint;
  
  if (iconsType == FILES_TAB) {
	  if ((sourceDragMask == NSDragOperationCopy) 
												  || (sourceDragMask == NSDragOperationLink)) {
		  return NSDragOperationNone;
	  }
  }
  
  if (iconsType == FILES_TAB) {  
    if ([[pb types] indexOfObject: NSFilenamesPboardType] == NSNotFound) {
      found = NO;
    }
  } else {
    NSArray *types = [pb types];
    
    if (([types indexOfObject: NSStringPboardType] == NSNotFound)
          && ([types indexOfObject: NSRTFPboardType] == NSNotFound)
          && ([types indexOfObject: NSRTFDPboardType] == NSNotFound)
          && ([types indexOfObject: NSTIFFPboardType] == NSNotFound)
          && ([types indexOfObject: NSFileContentsPboardType] == NSNotFound)
          && ([types indexOfObject: NSColorPboardType] == NSNotFound)
          && ([types indexOfObject: @"IBViewPboardType"] == NSNotFound)) {
      found = NO;
    }
  }   
    
  if (found) {
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
    
    if (iconsType == FILES_TAB) { 
      return NSDragOperationAll;
    } else {
      return NSDragOperationCopy;
    }
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

  if (iconsType == FILES_TAB) {
	  if ((sourceDragMask == NSDragOperationCopy) 
												  || (sourceDragMask == NSDragOperationLink)) {
		  return NSDragOperationNone;
	  }	
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
  
  if (iconsType == FILES_TAB) { 
    return NSDragOperationAll;
  } else {
    return NSDragOperationCopy;
  }
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
  NSPoint p = [sender draggedImageLocation];
  gridpoint *gpoint;
  int index;
  int i;

  isDragTarget = NO;

  if (dragImage != nil) {
    DESTROY (dragImage);
    [self setNeedsDisplay: YES];
  }

  p = [self convertPoint: p fromView: [[self window] contentView]];
  gpoint = [self gridPointNearestToPoint: p];
  p = NSMakePoint(gpoint->x, gpoint->y);
  index = gpoint->index;

  if (gpoint->used == 0) {
    if (iconsType == FILES_TAB) {
      NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
      sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

	    if (sourcePaths) {
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
    } else {
      NSData *data;
      NSString *type;
      
      data = [self readSelectionFromPasteboard: pb ofType: &type];

      if (data) {   
        NSString *dpath = [gw tshelfPBFilePath];
        
        if ([data writeToFile: dpath atomically: YES]) {
          TShelfPBIcon *icon;
          
          [self removePBIconsWithData: data ofType: type];
        
          icon = [self addPBIconForDataAtPath: dpath
                                     dataType: type
					                      withGridIndex: index];
          [icon select];                      
        }
      }
    }  
  }
}

@end
