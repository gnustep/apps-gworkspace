/* DesktopView.m
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
#include "DesktopView.h"
#include "IconViewsIcon.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#ifndef max
#define max(a,b) ((a) > (b) ? (a):(b))
#endif

#ifndef min
#define min(a,b) ((a) < (b) ? (a):(b))
#endif

@implementation DesktopView

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[self unsetWatchers];
	NSZoneFree (NSDefaultMallocZone(), xpositions);
	NSZoneFree (NSDefaultMallocZone(), ypositions);
  RELEASE (icons);
	RELEASE (watchedPaths);
  TEST_RELEASE (backColor);
	TEST_RELEASE (imagePath);
  TEST_RELEASE (backImage);
	TEST_RELEASE (dragImage);
  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if (self) {
    NSUserDefaults *defaults;
    NSDictionary *desktopViewPrefs, *colorDict;
    NSArray *iconsArr;
		id result;
    float red, green, blue, alpha;
    int i;
    
    fm = [NSFileManager defaultManager];
    gw = [GWorkspace gworkspace];
 
    [self setFrame: [[NSScreen mainScreen] frame]];

		gridCoordSel = @selector(gridCoordonatesX:Y:nearestToPoint:);
		gridCoord = [self methodForSelector: gridCoordSel];	
		
		xpositions = NULL;
		ypositions = NULL;
		[self makePositions];

		watchedPaths = [[NSMutableArray alloc] initWithCapacity: 1];
				
    icons = [[NSMutableArray alloc] initWithCapacity: 1];
    
    defaults = [NSUserDefaults standardUserDefaults];	

    desktopViewPrefs = [defaults dictionaryForKey: @"desktopviewprefs"];
		
    if (desktopViewPrefs != nil) { 
    	colorDict = [desktopViewPrefs objectForKey: @"backcolor"];
    	if(colorDict == nil) {
      	ASSIGN (backColor, [NSColor colorWithCalibratedRed: 0.49 green: 0.60 blue: 0.73 alpha: 1.00]);
    	} else {
      	red = [[colorDict objectForKey: @"red"] floatValue];
      	green = [[colorDict objectForKey: @"green"] floatValue];
      	blue = [[colorDict objectForKey: @"blue"] floatValue];
      	alpha = [[colorDict objectForKey: @"alpha"] floatValue];
      	ASSIGN (backColor, [NSColor colorWithCalibratedRed: red green: green blue: blue alpha: alpha]);
    	}

    	result = [desktopViewPrefs objectForKey: @"isimage"];

			if((result != nil) && ([result isEqual: @"1"])) {
				NSString *imPath = [desktopViewPrefs objectForKey: @"imagepath"];
				if (imPath != nil) {
					BOOL isdir;
					if ([fm fileExistsAtPath: imPath isDirectory: &isdir]) {
						if (isdir == NO) {
							NSImage *img = [[NSImage alloc] initWithContentsOfFile: imPath];
							if (img != nil) {
								ASSIGN (imagePath, imPath);
								ASSIGN (backImage, img);
                RELEASE (img);
							}
						} 
					}
				}
			}
			
    	iconsArr = [desktopViewPrefs objectForKey: @"icons"];      

    	if (iconsArr != nil) {
        NSArray *hiddenPaths = [GWLib hiddenPaths];
      
      	for (i = 0; i < [iconsArr count]; i++) {   
        	NSDictionary *idict = [iconsArr objectAtIndex: i];
        	NSArray *ipaths = [idict objectForKey: @"paths"];
        	int x = [[idict objectForKey: @"x"] intValue];
        	int y = [[idict objectForKey: @"y"] intValue];        
        	BOOL canadd = YES;
					int j;
					
        	for (j = 0; j < [ipaths count]; j++) {   
          	NSString *p = [ipaths objectAtIndex: j];
          	if (([fm fileExistsAtPath: p] == NO) || [hiddenPaths containsObject: p])  {
            	canadd = NO;
            	break;
          	} 
        	}

        	if (canadd == YES) {
          	[self addIconWithPaths: ipaths atPosition: NSMakePoint(x, y)];  
        	}
      	}
    	}
			 
		} else {
			ASSIGN (backColor, [NSColor colorWithCalibratedRed: 0.49 green: 0.60 blue: 0.73 alpha: 1.00]);
			backImage = nil;
			imagePath = nil;
		}  

		isDragTarget = NO;
    dragImage = nil;
		
  	[self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
    
    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(changeBackColor:) 
                					    name: GWDesktopViewColorChangedNotification
                					  object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(changeBackImage:) 
                					    name: GWDesktopViewImageChangedNotification
                					  object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(unsetBackImage:) 
                					    name: GWDesktopViewUnsetImageNotification
                					  object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(fileSystemWillChange:) 
                					    name: GWFileSystemWillChangeNotification
                					  object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(fileSystemDidChange:) 
                					    name: GWFileSystemDidChangeNotification
                					  object: nil];                     

		[[NSNotificationCenter defaultCenter] addObserver: self 
                			selector: @selector(watcherNotification:) 
                					name: GWFileWatcherFileDidChangeNotification
                				object: nil];
   
	  [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(cellsWidthChanged:) 
                					    name: GWShelfCellsWidthChangedNotification
                					  object: nil];
  }
  
  return self;
}

- (void)addIconWithPaths:(NSArray *)iconpaths atPosition:(NSPoint)pos
{
	DesktopViewIcon *icon;
	NSString *watched;
	
	pos = [self arrangePosition: pos];
	if (NSEqualPoints(pos, NSZeroPoint)) {
		return;
	}

	icon = [[DesktopViewIcon alloc] initForPaths: iconpaths 
                                	atPosition: pos inContainer: self];
	watched = [[iconpaths objectAtIndex: 0] stringByDeletingLastPathComponent];	

  [icons addObject: icon];  
	[self addSubview: icon];
	[self addSubview: [icon myLabel]];
  RELEASE (icon);
    
	[self resizeWithOldSuperviewSize: [self frame].size];
	
	if ([watchedPaths containsObject: watched] == NO) {
		[watchedPaths addObject: watched];
		[self setWatcherForPath: watched];
	}	
}

- (NSArray *)iconsPaths
{
  NSMutableArray *iconspaths = [NSMutableArray arrayWithCapacity: 1];
  int i;
	  
	for (i = 0; i < [icons count]; i++) {
		DesktopViewIcon *icon = [icons objectAtIndex: i];
    [iconspaths addObject: [icon paths]];
  }
  
  return iconspaths;
}

- (NSArray *)icons
{
  return icons;
}

- (NSColor *)backColor
{
  return backColor;
}

- (void)changeBackColor:(NSNotification *)notification
{
  NSDictionary *notifdict;
  float red, green, blue, alpha;

  notifdict = (NSDictionary *)[notification object];
  red = [[notifdict objectForKey: @"red"] floatValue];
  green = [[notifdict objectForKey: @"green"] floatValue];
  blue = [[notifdict objectForKey: @"blue"] floatValue];
  alpha = [[notifdict objectForKey: @"alpha"] floatValue];
  ASSIGN (backColor, [NSColor colorWithCalibratedRed: red green: green blue: blue alpha: alpha]);
  [self setNeedsDisplay: YES];
}

- (void)changeBackImage:(NSNotification *)notification
{
  NSString *imPath = (NSString *)[notification object];
	BOOL isdir;

  DESTROY (backImage);
	DESTROY (imagePath);

	if ([fm fileExistsAtPath: imPath isDirectory: &isdir]) {
		if (isdir == NO) {
			NSImage *img = [[NSImage alloc] initWithContentsOfFile: imPath];
			if (img) {
				ASSIGN (imagePath, imPath);
				ASSIGN (backImage, img);
        RELEASE (img);
			}
		} 
	}
    
  [self setNeedsDisplay: YES];	
}

- (NSImage *)shelfBackground
{
  NSSize size = NSMakeSize([self frame].size.width, 112);
  NSImage *image = [[NSImage alloc] initWithSize: size];
  NSCachedImageRep *rep = [[NSCachedImageRep alloc] initWithSize: size
                                    depth: [NSWindow defaultDepthLimit] 
                                                separate: YES alpha: YES];

  [image addRepresentation: rep];
  RELEASE (rep);

  [image lockFocus];  
  NSCopyBits([[self window] gState], 
            NSMakeRect(0, 0, size.width, size.height),
			                              NSMakePoint(0.0, 0.0));
  [image unlockFocus];
 
  return AUTORELEASE(image);
}

- (void)unsetBackImage:(NSNotification *)notification
{
  DESTROY (backImage);
	DESTROY (imagePath);
  [self setNeedsDisplay: YES];
}

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths
{
  int count = [icons count]; 
  int i;
    
	for (i = 0; i < count; i++) {
    BOOL deleted = NO;
		DesktopViewIcon *icon = [icons objectAtIndex: i];
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

- (void)fileSystemWillChange:(NSNotification *)notification
{
  NSDictionary *dict = (NSDictionary *)[notification object];  
  NSString *operation = [dict objectForKey: @"operation"];
	NSString *source = [dict objectForKey: @"source"];	  
	NSArray *files = [dict objectForKey: @"files"];	 

  if (operation == NSWorkspaceMoveOperation 
        || operation == NSWorkspaceDestroyOperation
				|| operation == GWorkspaceRenameOperation
				|| operation == NSWorkspaceRecycleOperation
				|| operation == GWorkspaceRecycleOutOperation
				|| operation == GWorkspaceEmptyRecyclerOperation) {
    
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity: 1];
    NSArray *iconpaths;
    int i, j, m;

    for (i = 0; i < [files count]; i++) {
      NSString *s = [source stringByAppendingPathComponent: [files objectAtIndex: i]];
      [paths addObject: s];
    }

	  for (i = 0; i < [icons count]; i++) {
		  DesktopViewIcon *icon = [icons objectAtIndex: i];
      
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
  NSDictionary *dict = (NSDictionary *)[notification object];
  NSString *operation = [dict objectForKey: @"operation"];
  NSString *source = [dict objectForKey: @"source"];
  NSString *destination = [dict objectForKey: @"destination"];
  NSArray *files = [dict objectForKey: @"files"];	
	int i;
  
  if (operation == GWorkspaceRenameOperation) {      
    for (i = 0; i < [icons count]; i++) {
      DesktopViewIcon *icon = [icons objectAtIndex: i];      
      if ([icon isSinglePath] == YES) {      
        if ([[[icon paths] objectAtIndex: 0] isEqualToString: source]) {     
          [icon setPaths: [NSArray arrayWithObject: destination]];
          [icon setLocked: NO]; 
          [icon setNeedsDisplay: YES];
          break;
        }
      }          
    }        
  }
	
  if (operation == GWorkspaceRenameOperation) {
		files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent];
  }	
	
  if (operation == NSWorkspaceMoveOperation
      || operation == NSWorkspaceDestroyOperation
			|| operation == GWorkspaceRenameOperation
		  || operation == NSWorkspaceRecycleOperation
		  || operation == GWorkspaceRecycleOutOperation
			|| operation == GWorkspaceEmptyRecyclerOperation) {
    int i, j, m, count;
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity: 1];
    
    for (i = 0; i < [files count]; i++) {
      NSString *s = [source stringByAppendingPathComponent: [files objectAtIndex: i]];
      [paths addObject: s];
    }
        
    count = [icons count];  
	  for (i = 0; i < count; i++) {
      BOOL deleted = NO;
		  DesktopViewIcon *icon = [icons objectAtIndex: i];
      NSArray *iconpaths = [icon paths];

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

          if (deleted == YES) {
            break;
          } 

        }

        if (deleted == YES) {
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

  if (contained == YES) {
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

- (void)cellsWidthChanged:(NSNotification *)notification
{
	int i;
	
	[self makePositions];
	
  for (i = 0; i < [icons count]; i++) {
    DesktopViewIcon *icon = [icons objectAtIndex: i];      
		NSPoint ipos = [icon position];
		ipos = [self arrangePosition: ipos];
		[icon setPosition: ipos];
	}
	
	[self resizeWithOldSuperviewSize: [self frame].size];
}

- (void)updateIcons
{
  int i;
  
  for (i = 0; i < [icons count]; i++) {
    [[icons objectAtIndex: i] renewIcon];  
  }
}

- (void)saveDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  NSMutableDictionary *desktopViewPrefs, *colorDict;
  NSMutableArray *iconsArr;
  float red, green, blue, alpha;
	BOOL imgok;
  int i;
	
  colorDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [backColor getRed: &red green: &green blue: &blue alpha: &alpha];
  [colorDict setObject: [NSString stringWithFormat: @"%.2f", red] forKey: @"red"];
  [colorDict setObject: [NSString stringWithFormat: @"%.2f", green] forKey: @"green"];
  [colorDict setObject: [NSString stringWithFormat: @"%.2f", blue] forKey: @"blue"];
  [colorDict setObject: [NSString stringWithFormat: @"%.2f", alpha] forKey: @"alpha"];

	imgok = NO;
	if (imagePath != nil) {
		BOOL isdir;
		if ([fm fileExistsAtPath: imagePath isDirectory: &isdir]) {
			if (isdir == NO) {
				imgok = YES;
			} 
		}
	}
	
  iconsArr = [NSMutableArray arrayWithCapacity: 1]; 
  for (i = 0; i < [icons count]; i++) { 
    DesktopViewIcon *icon = [icons objectAtIndex: i];
    NSMutableDictionary *iconDict = [NSMutableDictionary dictionaryWithCapacity: 1];
    NSString *x;
    NSString *y;
    int value;

    value = [icon position].x;
    x = [NSString stringWithFormat: @"%i", value];
    value = [icon position].y;
    y = [NSString stringWithFormat: @"%i", value];
        
    [iconDict setObject: [icon paths] forKey: @"paths"];
    [iconDict setObject: x forKey: @"x"];
    [iconDict setObject: y forKey: @"y"];

    [iconsArr addObject: iconDict];
  }

	desktopViewPrefs = [NSMutableDictionary dictionaryWithCapacity: 1];
	[desktopViewPrefs setObject: colorDict forKey: @"backcolor"];
	if (imgok == YES) {
		[desktopViewPrefs setObject: imagePath forKey: @"imagepath"];
		[desktopViewPrefs setObject: @"1" forKey: @"isimage"];
	} else {
		[desktopViewPrefs setObject: @"0" forKey: @"isimage"];
	}
  [desktopViewPrefs setObject: iconsArr forKey: @"icons"];  
	[defaults setObject: desktopViewPrefs forKey: @"desktopviewprefs"];
  [defaults synchronize];
}

- (void)makePositions
{
	NSRect r;
	int i;
	
	r = [[NSScreen mainScreen] frame];
	
	cellsWidth = [gw shelfCellsWidth];
	cellsHeight = 75;
		
	xcount = (int)(r.size.width / cellsWidth);
	ycount = (int)(r.size.height / cellsHeight);
		
	if (xpositions != NULL) {
		NSZoneFree (NSDefaultMallocZone(), xpositions);
	}
	xpositions = NSZoneMalloc (NSDefaultMallocZone(), sizeof(float) * xcount);	

	if (ypositions != NULL) {
		NSZoneFree (NSDefaultMallocZone(), ypositions);
	}
	ypositions = NSZoneMalloc (NSDefaultMallocZone(), sizeof(float) * ycount);	
		
	xpositions[0] = 30;
	for (i = 1; i < xcount; i++) {
		xpositions[i] = xpositions[i-1] + cellsWidth;
	}

	ypositions[0] = 30;
	for (i = 1; i < ycount; i++) {
		ypositions[i] = ypositions[i-1] + cellsHeight;
	}
}

- (void)gridCoordonatesX:(float *)x Y:(float *)y nearestToPoint:(NSPoint)p
{
	float maxx = [self frame].size.width;
	float maxy = [self frame].size.height;
	float px = p.x;
	float py = p.y;	
	float minx = maxx;
	float miny = maxy;
	int posx = -1;
	int posy = -1;
	int i;
		
	for (i = 0; i < xcount; i++) {
		float dx = max(px, xpositions[i]) - min(px, xpositions[i]);
		if (dx <= minx) {
			minx = dx;
			posx = i;
		}
	}

	for (i = 0; i < ycount; i++) {
		float dy = max(py, ypositions[i]) - min(py, ypositions[i]);
		if (dy <= miny) {
			miny = dy;
			posy = i;
		}
	}
		
	if ((posx == -1) || (posx == -1)) {
		*x = 0;
		*y = 0;
		return;
	}
	
	*x = xpositions[posx];
	*y = ypositions[posy];
}

- (void)getOnGridPositionX:(int *)x Y:(int *)y ofPoint:(NSPoint)p
{
	int i;
	
	*x = -1;
	for (i = 0; i <	xcount; i++) {
		if (xpositions[i] == p.x) {
			*x = i;
			break;
		}
	}

	*y = -1;
	for (i = 0; i <	ycount; i++) {
		if (ypositions[i] == p.y) {
			*y = i;
			break;
		}
	}
}

- (NSPoint)firstFreePosition
{
	int i, j;
	
	for (i = 0; i < ycount; i++) {
		for (j = 0; j < xcount; j++) {
			NSPoint p = NSMakePoint(xpositions[j], ypositions[i]);
			if ([self isFreePosition: p]) {
				return p;
			}
		}
	}

	return NSMakePoint(0, 0);
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

- (NSPoint)arrangePosition:(NSPoint)p
{
	float px, py;
	NSPoint newp;
	int posx;
	int posy;

	(*gridCoord)(self, gridCoordSel, &px, &py, p);
	newp = NSMakePoint(px, py);
	
	if (NSEqualPoints(newp, NSZeroPoint)) {
		return [self firstFreePosition];
	}

	[self getOnGridPositionX: &posx Y: &posy ofPoint: newp];

	while ([self isFreePosition: newp] == NO) {	
		posx++;
		if (posx == xcount) {
			posx = 0;
			posy++;
		}		
		if (posy == ycount) {
			return [self firstFreePosition];
		}

		newp = NSMakePoint(xpositions[posx], ypositions[posy]);
	}	
	
	return newp;
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
	int i;
  
	for (i = 0; i < [icons count]; i++) {
		DesktopViewIcon *icon = [icons objectAtIndex: i];
    NSPoint p = [icon position];
    NSRect r = NSMakeRect(p.x, p.y, 64, 52);
		[icon setFrame: r];
		[self setLabelRectOfIcon: icon];
	}

	[self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  [backColor set];
  NSRectFill(rect);
  
  if (backImage != nil) {
    NSSize imsize = [backImage size];
    NSSize scrsize = [[NSScreen mainScreen] frame].size;
    float px = ((scrsize.width - imsize.width) / 2);
    float py = ((scrsize.height - imsize.height) / 2);
       
    [backImage compositeToPoint: NSMakePoint(px, py) 
                      operation: NSCompositeSourceOver];  
  }

	if ((dragImage != nil) && ([self isFreePosition: dragPoint])) {
		NSPoint p = NSMakePoint(dragPoint.x + 8, dragPoint.y);
		[dragImage dissolveToPoint: p fraction: 0.3];
	}
}

//
// IconViewsProtocol
//
- (void)addIconWithPaths:(NSArray *)iconpaths
{
}

- (void)removeIcon:(id)anIcon
{
  DesktopViewIcon *icon = (DesktopViewIcon *)anIcon;
	NSString *watched = [[[icon paths] objectAtIndex: 0] stringByDeletingLastPathComponent];

	if ([watchedPaths containsObject: watched]) {
		[watchedPaths removeObject: watched];
		[self unsetWatcherForPath: watched];
	}

  [[icon myLabel] removeFromSuperview];
  [icon removeFromSuperview];
  [icons removeObject: icon];
	[self resizeWithOldSuperviewSize: [self frame].size];  
}

- (void)setLabelRectOfIcon:(id)anIcon
{
  DesktopViewIcon *icon = (DesktopViewIcon *)anIcon;
	NSTextField *label = [icon myLabel];
	float iconwidth = [icon frame].size.width;
	float labwidth = [label frame].size.width;
	float labxpos;
  NSRect labelRect;

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
    DesktopViewIcon *icon = [icons objectAtIndex: i];
    if ((icon != anIcon) && ([icon isSelect])) {  
    	[icon unselect];
    }
  }  
}

- (void)setShiftClick:(BOOL)value
{
}

- (void)setCurrentSelection:(NSArray *)paths
{
  [gw setSelectedPaths: paths fromDesktopView: self];
}

- (void)setCurrentSelection:(NSArray *)paths 
               animateImage:(NSImage *)image
            startingAtPoint:(NSPoint)startp
{
  [gw setSelectedPaths: paths
       fromDesktopView: self
          animateImage: image
       startingAtPoint: startp];
}

- (void)openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv
{
  [gw openSelectedPaths: paths newViewer: newv]; 
}

- (NSArray *)currentSelection
{
  return nil;
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

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{

}

@end

@implementation DesktopView (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	
	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}	
	
  if ([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
		float px, py;
		
    DESTROY (dragImage);
    isDragTarget = YES;	
		dragPoint = [sender draggedImageLocation];		
		(*gridCoord)(self, gridCoordSel, &px, &py, dragPoint);
		dragPoint = NSMakePoint(px, py);
		ASSIGN (dragImage, [sender draggedImage]);
		dragRect = NSMakeRect(dragPoint.x + 8, dragPoint.y, [dragImage size].width, [dragImage size].height);
    return NSDragOperationAll;
  }
	
	isDragTarget = NO;	
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;
	NSPoint p;
	
	sourceDragMask = [sender draggingSourceOperationMask];

	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}

	p = [sender draggedImageLocation];
	if (NSEqualPoints(dragPoint, p) == NO) {
		float px, py;
		
    if ([self isFreePosition: dragPoint]) {
		  [self setNeedsDisplayInRect: dragRect];
    }
		dragPoint = NSMakePoint(p.x, p.y);
		(*gridCoord)(self, gridCoordSel, &px, &py, dragPoint);
		dragPoint = NSMakePoint(px, py);
		
		if ([self isFreePosition: dragPoint]) {
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
  int i;

  isDragTarget = NO;

	if (dragImage != nil) {
		DESTROY (dragImage);
		[self setNeedsDisplay: YES];
	}
  	
	if (sourcePaths) {
    NSPoint p = [sender draggedImageLocation];
		float px, py;
		
		(*gridCoord)(self, gridCoordSel, &px, &py, p);
		p = NSMakePoint(px, py);
		
		if ([self isFreePosition: p]) {
    	for (i = 0; i < [icons count]; i++) {
      	DesktopViewIcon *icon = [icons objectAtIndex: i];
      	if ([[icon paths] isEqualToArray: sourcePaths]) {
        	[icon setPosition: p];
        	[self resizeWithOldSuperviewSize: [self frame].size];  
        	return;
      	}
    	}    

    	[self addIconWithPaths: sourcePaths atPosition: p]; 
		}   
	}
}

@end
