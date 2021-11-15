/* TShelfIconsView.m
 *  
 * Copyright (C) 2003-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */


#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "FSNodeRep.h"
#import "FSNFunctions.h"
#import "TShelfIcon.h"
#import "TShelfFileIcon.h"
#import "TShelfPBIcon.h"
#import "TShelfIconsView.h"
#import "GWorkspace.h"
#import "TShelfWin.h"


#define CELLS_WIDTH (80)
#define EDIT_MARGIN (4)


@implementation TShelfIconsView

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [self unsetWatchers];
  if (gpoints != NULL)
    {
      NSZoneFree (NSDefaultMallocZone(), gpoints);
    }
  RELEASE (icons);  
  RELEASE (watchedPaths);
  RELEASE (dragImage);
  RELEASE (focusedIconLabel);
  [super dealloc];
}

- (id)initWithIconsDescription:(NSArray *)idescr 
                     iconsType:(int)itype
                      lastView:(BOOL)last
{	
  self = [super init];
  
  if (self)
    {
      NSArray *hiddenPaths = [[FSNodeRep sharedInstance] hiddenPaths];
      NSUInteger i, j;

      fm = [NSFileManager defaultManager];
      gw = [GWorkspace gworkspace];
				        
      makePosSel = @selector(makePositions);
      makePos = (IMP)[self methodForSelector: makePosSel];

      gridPointSel = @selector(gridPointNearestToPoint:);
      gridPoint = (GridPointIMP)[self methodForSelector: gridPointSel];
		
      cellsWidth = CELLS_WIDTH;
    		
      watchedPaths = [[NSCountedSet alloc] initWithCapacity: 1];
		    
      focusedIconLabel = [NSTextField new];
      [focusedIconLabel setFont: [NSFont systemFontOfSize: 12]];
      [focusedIconLabel setBezeled: NO];
      [focusedIconLabel setAlignment: NSCenterTextAlignment];
      [focusedIconLabel setEditable: NO];
      [focusedIconLabel setSelectable: NO];
      [focusedIconLabel setBackgroundColor: [NSColor windowBackgroundColor]];
      [focusedIconLabel setTextColor: [NSColor controlTextColor]];
      [focusedIconLabel setFrame: NSMakeRect(0, 0, 0, 14)];
    
      focusedIcon = nil;
    
      icons = [[NSMutableArray alloc] initWithCapacity: 1];
        
      iconsType = itype;
      isLastView = last;
        
      if (idescr && [idescr count])
	{
	  for (i = 0; i < [idescr count]; i++)
	    { 
	      NSDictionary *iconDict = [idescr objectAtIndex: i];
	      NSUInteger index = [[iconDict objectForKey: @"index"] unsignedIntValue];
	      
	      if (iconsType == FILES_TAB)
		{
		  NSArray *iconpaths = [iconDict objectForKey: @"paths"];
		  BOOL canadd = YES;

		  for (j = 0; j < [iconpaths count]; j++)
		    {
		      NSString *p = [iconpaths objectAtIndex: j];
		      if (([fm fileExistsAtPath: p] == NO) || [hiddenPaths containsObject: p])
			{
			  canadd = NO;
			  break;
			} 
		    }
		  
		  if (canadd == YES)
		    {
		      [self addIconWithPaths: iconpaths withGridIndex: index];
		    }
		  
		}
	      else
		{
		  NSString *dataPath = [iconDict objectForKey: @"datapath"];
		  NSString *dataType = [iconDict objectForKey: @"datatype"];
		  
		  if ([fm fileExistsAtPath: dataPath])
		    {
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
	
      if (isLastView == NO)
	{
	  if (iconsType == FILES_TAB)
	    {
	      [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
	      
	      [[NSNotificationCenter defaultCenter] 
                   addObserver: self 
		      selector: @selector(fileSystemWillChange:) 
			  name: @"GWFileSystemWillChangeNotification"
			object: nil];

	      [[NSNotificationCenter defaultCenter] 
                   addObserver: self 
		      selector: @selector(fileSystemDidChange:) 
			  name: @"GWFileSystemDidChangeNotification"
			object: nil];                     
	    } 
	  else 
	    {
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
			name: @"GWFileWatcherFileDidChangeNotification"
		      object: nil];
	}
    }
  
  return self;	
}

- (NSArray *)iconsDescription
{ 
  NSMutableArray *arr = [NSMutableArray arrayWithCapacity: 1]; 
  NSUInteger i;
	  
  for (i = 0; i < [icons count]; i++)
    {
      NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];
      id icon;
      NSUInteger index;

      icon = [icons objectAtIndex: i];
      index = [icon gridIndex];
      [dict setObject: [NSNumber numberWithInt: index] forKey: @"index"];
		
      if (iconsType == FILES_TAB)
	{
	  [dict setObject: [(TShelfFileIcon *)icon paths] forKey: @"paths"];
	}
      else
	{
	  [dict setObject: [icon dataPath] forKey: @"datapath"];
	  [dict setObject: [icon dataType] forKey: @"datatype"];      
	}
    
      [arr addObject: dict];
    }
  
  return arr;
}

- (void)addIconWithPaths:(NSArray *)iconpaths 
	   withGridIndex:(NSUInteger)index 
{
  TShelfFileIcon *icon = [[TShelfFileIcon alloc] initForPaths: iconpaths
                                                    gridIndex: index inIconsView: self];
  NSString *watched = [[iconpaths objectAtIndex: 0] stringByDeletingLastPathComponent];

  [icon setSingleClickLaunch:[(TShelfWin *)[gw tabbedShelf] singleClickLaunch]];

  if (gpoints != NULL)
    {
      if (index < pcount)
	{
	  gpoints[index].used = 1;
	}
    }

  [icons addObject: icon];  
  [self addSubview: icon];
  [self addSubview: [icon myLabel]];		
  RELEASE (icon);
  [self sortIcons];
  [self resizeWithOldSuperviewSize: [self frame].size];

  if ([watchedPaths containsObject: watched] == NO)
    [self setWatcherForPath: watched];

  [watchedPaths addObject: watched];
}

- (TShelfPBIcon *)addPBIconForDataAtPath:(NSString *)dpath 
                                dataType:(NSString *)dtype
			   withGridIndex:(NSUInteger)index 
{
  TShelfPBIcon *icon = [[TShelfPBIcon alloc] initForPBDataAtPath: dpath
							  ofType: dtype
						       gridIndex: index
						     inIconsView: self];

  if (gpoints != NULL)
    {
      if (index < pcount)
	{
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
  if (anIcon)
    {
      id label = [anIcon myLabel];
      NSUInteger index = [anIcon gridIndex];

      if (iconsType == FILES_TAB)
	{
	  NSString *watched = [[[anIcon paths] objectAtIndex: 0] stringByDeletingLastPathComponent];

	  if ([watchedPaths containsObject: watched])
	    {
	      [watchedPaths removeObject: watched];

	      if ([watchedPaths containsObject: watched] == NO)
		{
		  [self unsetWatcherForPath: watched];
		}
	    }

	  if (label && [[self subviews] containsObject: label])
	    {
	      [label removeFromSuperview];
	    }
	}

    if (focusedIcon == anIcon)
      {
	focusedIcon = nil;
	[self updateFocusedIconLabel];
      }

    if ([[self subviews] containsObject: anIcon])
      {
	[anIcon removeFromSuperview];
      }

    [icons removeObject: anIcon];
    gpoints[index].used = 0;
    [self resizeWithOldSuperviewSize: [self frame].size];  
  }
}

- (void)removePBIconsWithData:(NSData *)data ofType:(NSString *)type
{
  NSUInteger count = [icons count];
  NSUInteger i;

  for (i = 0; i < count; i++)
    {
      TShelfPBIcon *icon = [icons objectAtIndex: count-i-1];
      
      if ([[icon dataType] isEqual: type])
	{
	  if ([[icon data] isEqual: data])
	    {
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

  if (iconwidth > labwidth)
    {
      labxpos = [icon frame].origin.x + ((iconwidth - labwidth) / 2);
    }
  else
    {
      labxpos = [icon frame].origin.x - ((labwidth - iconwidth) / 2);
    }

  labelRect = NSMakeRect(labxpos, [icon frame].origin.y - 14, labwidth, 14);
  [label setFrame: labelRect];
}

- (BOOL)hasSelectedIcon
{
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++)
    {
      TShelfIcon *icon = [icons objectAtIndex: i];
      if ([icon isSelected])
	{
	  return YES;
	}
    }

  return NO;
}

- (void)unselectOtherIcons:(id)anIcon
{
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++) {
    TShelfIcon *icon = [icons objectAtIndex: i];
    if (icon != anIcon) {  
      [icon unselect];
    }
  }  
}

- (void)setFocusedIcon:(id)anIcon
{
  if (anIcon == nil) {
    if (focusedIcon) {
      [self addSubview: [focusedIcon myLabel]];
      [self setLabelRectOfIcon: focusedIcon];
    }
  } 

  focusedIcon = anIcon;  
  [self updateFocusedIconLabel];
}

- (void)updateFocusedIconLabel
{
  if ([[self subviews] containsObject: focusedIconLabel]) {
    NSRect rect = [focusedIconLabel frame];

    [focusedIconLabel removeFromSuperview];
    [self setNeedsDisplayInRect: rect];
  }
  
  if (focusedIcon) {
    NSRect iconrect = [focusedIcon frame];
    float centerx = iconrect.origin.x + (iconrect.size.width / 2);  
    NSTextField *label = [focusedIcon myLabel];
    NSRect labelrect = [label frame];
    NSString *name = [focusedIcon shownName];  
    float fwidth = [[label font] widthOfString: name];
    float boundswidth = [self bounds].size.width - EDIT_MARGIN;
    int margin = 8;
      
    fwidth += margin;  

    if ((centerx + (fwidth / 2)) >= boundswidth) {
      centerx -= (centerx + (fwidth / 2) - boundswidth);
    } else if ((centerx - (fwidth / 2)) < margin) {
      centerx += fabs(centerx - (fwidth / 2)) + margin;
    }    

    labelrect.origin.x = centerx - (fwidth / 2);
    labelrect.size.width = fwidth;
    labelrect = NSIntegralRect(labelrect);

    [label removeFromSuperview];

    [focusedIconLabel setFrame: labelrect];
    [focusedIconLabel setStringValue: name];
    [self addSubview: focusedIconLabel];  
    [self setNeedsDisplayInRect: labelrect];
  }  
}

- (void)sortIcons
{
  SEL sel = @selector(iconCompare:);
  [icons sortUsingSelector: sel];
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
  NSUInteger i;

  for (i = 0; i < [icons count]; i++)
    {
      id icon = [icons objectAtIndex: i];

      if ([icon respondsToSelector: @selector(renewIcon)])
	{
	  [icon renewIcon];
	}
    }
}

- (id)selectedIcon
{
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++) {
    id icon = [icons objectAtIndex: i];
    if ([icon isSelected]) {  
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
  [gw openSelectedPaths: paths newViewer: YES];
}

- (void)checkIconsAfterDotsFilesChange
{
  if (iconsType == FILES_TAB)
    {
      NSUInteger count = [icons count]; 
      NSUInteger i;

      for (i = 0; i < count; i++)
	{
	  TShelfFileIcon *icon = [icons objectAtIndex: i];
	  NSArray *iconpaths = [icon paths];
	  NSUInteger j;

	  for (j = 0; j < [iconpaths count]; j++)
	    {
	      NSString *op = [iconpaths objectAtIndex: j];
	      
	      if ([op rangeOfString: @"."].location != NSNotFound)
		{
		  [self removeIcon: icon];
		  count--;
		  i--;
		  break;
		}
	    }
	}
    }
}

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths
{
  if (iconsType == FILES_TAB)
    {
      NSUInteger count = [icons count]; 
      NSUInteger i;

      for (i = 0; i < count; i++)
	{
	  BOOL deleted = NO;
	  TShelfFileIcon *icon = [icons objectAtIndex: i];
	  NSArray *iconpaths = [icon paths];
	  NSUInteger j;
	  
	  for (j = 0; j < [iconpaths count]; j++)
	    {
	      NSString *op = [iconpaths objectAtIndex: j];
	      NSUInteger m;

	      for (m = 0; m < [hpaths count]; m++)
		{
		  NSString *fp = [hpaths objectAtIndex: m]; 
		  
		  if (isSubpathOfPath(fp, op) || [fp isEqual: op])
		    {
		      [self removeIcon: icon];
		      count--;
		      i--;
		      deleted = YES;
		      break;
		    }

		  if (deleted)
		    {
		      break;
		    } 
		}
	      
	      if (deleted)
		{
		  break;
		}       
	    }
	}
    }
}

- (void)fileSystemWillChange:(NSNotification *)notification
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *dict = [notification object];
  NSString *operation = [dict objectForKey: @"operation"];
  NSString *source = [dict objectForKey: @"source"];	  
  NSArray *files = [dict objectForKey: @"files"];	 

  if ([operation isEqual: NSWorkspaceMoveOperation] 
      || [operation isEqual: NSWorkspaceDestroyOperation]
      || [operation isEqual: @"GWorkspaceRenameOperation"]
      || [operation isEqual: NSWorkspaceRecycleOperation]
      || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
      || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"])
    {
      NSMutableArray *paths = [NSMutableArray array];
      NSArray *iconpaths;
      NSUInteger i, j, m;

      for (i = 0; i < [files count]; i++)
	{
	  NSString *s = [source stringByAppendingPathComponent: [files objectAtIndex: i]];
	  [paths addObject: s];
	}

      for (i = 0; i < [icons count]; i++)
	{
	  TShelfIcon *icon = [icons objectAtIndex: i];

	  if ([icon isKindOfClass:[TShelfFileIcon class]])
	    {
	      iconpaths = [(TShelfFileIcon *)icon paths];

	      for (j = 0; j < [iconpaths count]; j++)
		{
		  NSString *op = [iconpaths objectAtIndex: j];

		  for (m = 0; m < [paths count]; m++)
		    {
		      NSString *fp = [paths objectAtIndex: m];

		      if ([op hasPrefix: fp])
			{
			  [icon setLocked: YES];
			  break;
			}
		    }
		}
	    } // if TShelfFileIcon
	}
    }

  RELEASE (arp);
}

- (void)fileSystemDidChange:(NSNotification *)notification
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *dict = [notification object];
  NSString *operation = [dict objectForKey: @"operation"];
  NSString *source = [dict objectForKey: @"source"];
  NSArray *files = [dict objectForKey: @"files"];
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"])
    {
      files = [NSArray arrayWithObject: [source lastPathComponent]];
      source = [source stringByDeletingLastPathComponent];
    }
		                    
  if ([operation isEqual: NSWorkspaceMoveOperation] 
      || [operation isEqual: NSWorkspaceDestroyOperation]
      || [operation isEqual: @"GWorkspaceRenameOperation"]
      || [operation isEqual: NSWorkspaceRecycleOperation]
      || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
      || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"])
    {
      NSMutableArray *paths = [NSMutableArray arrayWithCapacity: 1];
      TShelfIcon *icon;
      NSArray *iconpaths;
      NSUInteger count;
      NSUInteger i, j, m;

      for (i = 0; i < [files count]; i++)
	{
	  NSString *s = [source stringByAppendingPathComponent: [files objectAtIndex: i]];
	  [paths addObject: s];
	}
        
      count = [icons count];  
      for (i = 0; i < count; i++)
	{
	  BOOL deleted = NO;
	  icon = [icons objectAtIndex: i];
	  if ([icon isKindOfClass:[TShelfFileIcon class]])
	    {
	      iconpaths = [(TShelfFileIcon *)icon paths];

	      for (j = 0; j < [iconpaths count]; j++)
		{
		  NSString *op = [iconpaths objectAtIndex: j];

		  for (m = 0; m < [paths count]; m++)
		    {
		      NSString *fp = [paths objectAtIndex: m]; 

		      if ([op hasPrefix: fp])
			{
			  [self removeIcon: icon];
			  count--;
			  i--;
			  deleted = YES;
			  break;
			}

		      if (deleted)
			break;
		    }

		  if (deleted)
		    break;
		}
	    } // if TShelfFileIcon
	}
    }
  
  RELEASE (arp);
}

- (void)watcherNotification:(NSNotification *)notification
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *notifdict = (NSDictionary *)[notification object];
  NSString *path = [notifdict objectForKey: @"path"];
  NSString *event = [notifdict objectForKey: @"event"];
  NSEnumerator *enumerator;
  NSString *wpath;
  BOOL contained = NO;
  NSUInteger i;

  if (iconsType == DATA_TAB)
    {
      NSUInteger count = [icons count];

      if ([event isEqual: @"GWFileDeletedInWatchedDirectory"])
	{
	  NSArray *files = [notifdict objectForKey: @"files"];

	  for (i = 0; i < count; i++)
	    {
	      TShelfPBIcon *icon = [icons objectAtIndex: i];
	      NSString *dataPath = [icon dataPath];
	      NSUInteger j;
				  
	      for (j = 0; j < [files count]; j++)
		{
		  NSString *fname = [files objectAtIndex: j];
		  NSString *fullPath = [path stringByAppendingPathComponent: fname];

		  if ([fullPath isEqual: dataPath])
		    {
		      [self removeIcon: icon];
		      count--;
		      i--;
		    }
		}
	    }
	}
    }
  else
    {
      if ([event isEqual: @"GWFileCreatedInWatchedDirectory"])
	{
	  RELEASE (arp);
	  return;
	}

      enumerator = [watchedPaths objectEnumerator];

      while ((wpath = [enumerator nextObject]))
	{
	  if (([wpath isEqual: path]) || (isSubpathOfPath(path, wpath)))
	    {
	      contained = YES;
	      break;
	    }
	}

    if (contained)
      {
	id icon;
	NSArray *ipaths;
	NSString *ipath;
	NSUInteger count = [icons count];

	if ([event isEqual: @"GWWatchedPathDeleted"])
	  {
	    for (i = 0; i < count; i++)
	      {
		icon = [icons objectAtIndex: i];
		ipaths = [icon paths];
		ipath = [ipaths objectAtIndex: 0];

		if (isSubpathOfPath(path, ipath))
		  {
		    [self removeIcon: icon];
		    count--;
		    i--;
		  }
	      }

	    RELEASE (arp);
	    return;
	  }

	if ([event isEqual: @"GWFileDeletedInWatchedDirectory"])
	  {
	    NSArray *files = [notifdict objectForKey: @"files"];

	    for (i = 0; i < count; i++)
	      {
		NSUInteger j;

		icon = [icons objectAtIndex: i];
		ipaths = [icon paths];

		if ([ipaths count] == 1)
		  {
		    ipath = [ipaths objectAtIndex: 0];

		    for (j = 0; j < [files count]; j++)
		      {
			NSString *fname = [files objectAtIndex: j];
			NSString *fullPath = [path stringByAppendingPathComponent: fname];

			if ((isSubpathOfPath(fullPath, ipath))
			    || ([ipath isEqual: fullPath]))
			  {
			    [self removeIcon: icon];
			    count--;
			    i--;
			    break;
			  }
		      }

		  }
		else
		  {
		    for (j = 0; j < [files count]; j++)
		      {
			NSString *fname = [files objectAtIndex: j];
			NSString *fullPath = [path stringByAppendingPathComponent: fname];
			BOOL deleted = NO;
			NSUInteger m;

			if (deleted)
			  {
			    break;
			  }

			ipath = [ipaths objectAtIndex: 0];
			if (isSubpathOfPath(fullPath, ipath))
			  {
			    [self removeIcon: icon];
			    count--;
			    i--;
			    break;
			  }

			for (m = 0; m < [ipaths count]; m++)
			  {
			    ipath = [ipaths objectAtIndex: m];

			    if ([ipath isEqual: fullPath])
			      {
				NSMutableArray *newpaths;

				if ([ipaths count] == 1)
				  {
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

  RELEASE (arp);
}

- (void)setWatchers
{
  NSEnumerator *enumerator = [watchedPaths objectEnumerator]; 
  NSString *wpath;

  while ((wpath = [enumerator nextObject]))
    {
      [self setWatcherForPath: wpath];
    }
}

- (void)setWatcherForPath:(NSString *)path
{
  [gw addWatcherForPath: path];
}

- (void)unsetWatchers
{
  NSEnumerator *enumerator = [watchedPaths objectEnumerator]; 
  NSString *wpath;

  while ((wpath = [enumerator nextObject]))
    {
      [self unsetWatcherForPath: wpath];
    }
}

- (void)unsetWatcherForPath:(NSString *)path
{
  [gw removeWatcherForPath: path];
}

- (void)makePositions
{
  CGFloat wdt, hgt, x, y;
  NSUInteger i;
  
  wdt = [self bounds].size.width;
  hgt = [self bounds].size.height;

  pcount = (NSUInteger)((wdt - 16) / cellsWidth);

  if (gpoints != NULL)
    {
      NSZoneFree (NSDefaultMallocZone(), gpoints);
    }
  gpoints = NSZoneMalloc (NSDefaultMallocZone(), sizeof(gridpoint) * pcount);

  x = 16;
  y = hgt - 59;

  for (i = 0; i < pcount; i++)
    {
      if (i > 0)
	{
	  x += cellsWidth;
	}
      gpoints[i].x = x;
      gpoints[i].y = y;
      gpoints[i].index = i;

      if (x < (wdt - cellsWidth))
	{
	  gpoints[i].used = 0;
	}
      else
	{
	  gpoints[i].used = 1;
	}
    }
}

- (gridpoint *)gridPointNearestToPoint:(NSPoint)p
{
  NSRect r = [self bounds];
  CGFloat maxx = r.size.width;
  CGFloat maxy = r.size.height;
  float px = p.x;
  float py = p.y;
  float minx = maxx;
  float miny = maxy;
  int pos = -1;
  NSUInteger i;
		
  for (i = 0; i < pcount; i++)
    {
      if (gpoints[i].y > 0)
	{
	  float dx = max(px, gpoints[i].x) - min(px, gpoints[i].x);
	  float dy = max(py, gpoints[i].y) - min(py, gpoints[i].y);

	  if ((dx <= minx) && (dy <= miny))
	    {
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
  NSUInteger i;
  
  for (i = 0; i < [icons count]; i++)
    {
      NSPoint p = [[icons objectAtIndex: i] position];
      if (NSEqualPoints(pos, p))
	{
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
  NSUInteger i;
				
  if (gpoints == NULL)
    {
      [super resizeWithOldSuperviewSize: oldFrameSize];
      return;
    }
		
  for (i = 0; i < pcount; i++)
    {	
      gpoints[i].used = 0;
    }
	
  for (i = 0; i < [icons count]; i++)
    {
      id icon	 = [icons objectAtIndex: i];
      NSUInteger index = [icon gridIndex];
      gridpoint gpoint = gpoints[index];
      NSPoint p = NSMakePoint(gpoint.x, gpoint.y);
      NSRect r = NSMakeRect(p.x, p.y, 64, 52);
      
      [icon setPosition: p];
      [icon setFrame: NSIntegralRect(r)];
      gpoints[index].used = 1;
      
      if (iconsType == FILES_TAB)
        {
          [self setLabelRectOfIcon: icon];
        }
    }
	
  [self sortIcons];
  [self setNeedsDisplay: YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
  [self unselectOtherIcons: nil];
  
  if (iconsType == DATA_TAB)
    {
      [self setCurrentPBIcon: nil];
    }
}

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];

  if (dragImage != nil)
    {
      gridpoint *gpoint = [self gridPointNearestToPoint: dragPoint];
  
      if (gpoint->used == 0)
	{
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

- (void)setSingleClickLaunch:(BOOL)value
{
  NSUInteger i;

  for (i = 0; i < [icons count]; i++)
    {
      TShelfIcon *icon;

      icon = [icons objectAtIndex: i];
      [icon setSingleClickLaunch: value];
    }
}

@end

@implementation TShelfIconsView(PBoardOperations)

- (void)setCurrentPBIcon:(id)anIcon
{
  if (anIcon)
    {
      NSString *dataPath = [anIcon dataPath];
      NSString *dataType = [anIcon dataType];
      NSImage *icn = [anIcon icon];
      NSData *data = [NSData dataWithContentsOfFile: dataPath];
    
      if (data)
	{
	  [gw showPasteboardData: data ofType: dataType typeIcon: icn];
	}
    }
  else
    {
      [gw resetSelectedPaths];
    }
}

- (void)doCut
{
  TShelfPBIcon *icon = [self selectedIcon];

  if (icon)
    {
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

  if (icon)
    {
      NSString *dataPath = [icon dataPath];
      NSString *dataType = [icon dataType];
      NSData *data = [NSData dataWithContentsOfFile: dataPath];

      if (data)
	{
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

  if (data && [[TShelfPBIcon dataTypes] containsObject: type]) {         
    NSString *dpath = [gw tshelfPBFilePath];
    NSUInteger index = NSNotFound; 
    NSUInteger i;

    for (i = 0; i < pcount; i++)
      {
	if (gpoints[i].used == 0)
	  {
	    index = i;
	    break;
	  }
      }

    if (index == NSNotFound)
      {
	NSRunAlertPanel(NSLocalizedString(@"Error!", @""),
                        NSLocalizedString(@"No space left on this tab", @""),
                        NSLocalizedString(@"Ok", @""),
                        nil,
                        nil);
	return;
      }

    if ([data writeToFile: dpath atomically: YES])
      {
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
  NSUInteger i;
  
  if ((types == nil) || ([types count] == 0))
    {
      return nil;
    }

  for (i = 0; i < [types count]; i++)
    {
      type = [types objectAtIndex: 0];
      data = [pboard dataForType: type];
      if (data)
	{
	  *pbtype = type;
	  return data;
	}
    }
  
  return nil;
}

@end

@implementation TShelfIconsView(DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  BOOL found = YES;
  gridpoint *gpoint;
  
  DESTROY (dragImage);

  if (iconsType == FILES_TAB)
    {
      if ((sourceDragMask == NSDragOperationCopy) || (sourceDragMask == NSDragOperationLink))
        {
          return NSDragOperationNone;
        }
    }
  
  if (iconsType == FILES_TAB)
    {
      if ([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound)
	{
	  NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

	  if ([sourcePaths count])
	    {
	      NSString *basePath = [sourcePaths objectAtIndex: 0];

	      basePath = [basePath stringByDeletingLastPathComponent];
	      if ([basePath isEqual: [gw trashPath]])
		{
		  found = NO;
		}
	    }
	  else
	    {
	      found = NO;
	    }
	}
      else
	{
	  found = NO;
	}
    }
  else
    {
      NSArray *types = [pb types];
    
      if (([types indexOfObject: NSStringPboardType] == NSNotFound)
          && ([types indexOfObject: NSRTFPboardType] == NSNotFound)
          && ([types indexOfObject: NSRTFDPboardType] == NSNotFound)
          && ([types indexOfObject: NSTIFFPboardType] == NSNotFound)
          && ([types indexOfObject: NSFileContentsPboardType] == NSNotFound)
          && ([types indexOfObject: NSColorPboardType] == NSNotFound)
          && ([types indexOfObject: @"IBViewPboardType"] == NSNotFound))
	{
	  found = NO;
	}
    }
    
  if (found)
    {
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

      return NSDragOperationEvery;
    }

  isDragTarget = NO;
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  NSPoint p = [sender draggedImageLocation];
  p = [self convertPoint: p fromView: [[self window] contentView]];

  if (isDragTarget == NO)
    {
      return NSDragOperationNone;
    }

  if (iconsType == FILES_TAB)
    {
      if ((sourceDragMask == NSDragOperationCopy)
	  || (sourceDragMask == NSDragOperationLink))
	{
	  if (dragImage)
	    {
	      DESTROY (dragImage);
	      [self setNeedsDisplayInRect: dragRect]; 
	    }
	  return NSDragOperationNone;
	}
    }

  if (NSEqualPoints(dragPoint, p) == NO)
    {
      gridpoint *gpoint;

      if ([self isFreePosition: dragPoint])
	{
	  [self setNeedsDisplayInRect: dragRect];
	}

      gpoint = gridPoint(self, gridPointSel, p);
      dragPoint = NSMakePoint(gpoint->x, gpoint->y);

      if (gpoint->used == 0)
	{
	  dragRect = NSMakeRect(dragPoint.x + 8, dragPoint.y, [dragImage size].width, [dragImage size].height);
	  if (dragImage == nil)
	    {
	      ASSIGN (dragImage, [sender draggedImage]);
	    }
	  [self setNeedsDisplayInRect: dragRect];

	}
      else
	{
	  DESTROY (dragImage);
	  return NSDragOperationNone;
	}
    }

  return NSDragOperationEvery;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if (dragImage != nil)
    {
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
  NSUInteger index;
  NSUInteger i;

  isDragTarget = NO;

  if (dragImage != nil)
    {
      DESTROY (dragImage);
      [self setNeedsDisplay: YES];
    }
  
  p = [self convertPoint: p fromView: [[self window] contentView]];
  gpoint = [self gridPointNearestToPoint: p];
  index = gpoint->index;

  if (gpoint->used == 0)
    {
      if (iconsType == FILES_TAB)
        {
          NSArray *sourcePaths; 
          sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
            
          if (sourcePaths)
            {
              for (i = 0; i < [icons count]; i++)
                {
                  TShelfFileIcon *icon = [icons objectAtIndex: i];
                  if ([[icon paths] isEqualToArray: sourcePaths])
                    {
                      gpoints[[icon gridIndex]].used = 0;
                      gpoint->used = 1;					  
                      [icon setGridIndex: index];
                      [self resizeWithOldSuperviewSize: [self frame].size];        	  
                      return;
                    }
                }
                
              [self addIconWithPaths: sourcePaths withGridIndex: index];
            }
        }
      else
        {
          NSData *data;
          NSString *type;
      
          data = [self readSelectionFromPasteboard: pb ofType: &type];

          if (data)
            {   
              NSString *dpath = [gw tshelfPBFilePath];
        
              if ([data writeToFile: dpath atomically: YES])
                {
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
