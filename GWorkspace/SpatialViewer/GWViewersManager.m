/* GWViewersManager.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
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

#include <AppKit/AppKit.h>
#include "GWViewersManager.h"
#include "GWSpatialViewer.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"

static GWViewersManager *vwrsmanager = nil;

@implementation GWViewersManager

+ (GWViewersManager *)viewersManager
{
	if (vwrsmanager == nil) {
		vwrsmanager = [[GWViewersManager alloc] init];
	}	
  return vwrsmanager;
}

- (void)dealloc
{
  RELEASE (viewers);
  
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    viewers = [NSMutableArray new];
    [FSNodeRep setLabelWFactor: 9.0];
  }
  
  return self;
}

- (id)newViewerForPath:(NSString *)path 
         viewsPackages:(BOOL)viewspkg
{
  GWSpatialViewer *viewer = [self viewerForPath: path];

  if (viewer == nil) {
    FSNode *node = [FSNode nodeWithRelativePath: path parent: nil];
  
    viewer = [[GWSpatialViewer alloc] initForNode: node];    
    [viewers addObject: viewer];
    RELEASE (viewer);
  } 
  
  [viewer activate];
    
  return viewer;
}

- (id)viewerForPath:(NSString *)path
{
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    GWSpatialViewer *viewer = [viewers objectAtIndex: i];
    FSNode *node = [viewer shownNode];
    
    if ([[node path] isEqual: path]) {
      return viewer;
    }
  }
  
  return nil;
}

@end










