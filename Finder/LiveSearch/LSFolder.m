/* LSFolder.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
 *
 * This file is part of the GNUstep Finder application
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
#include <math.h>
#include "LSFolder.h"
#include "Finder.h"
#include "FinderModulesProtocol.h"
#include "Functions.h"
#include "config.h"

static NSString *nibName = @"LSFolderWindow";

@implementation LSFolder

- (void)dealloc
{
  if (watcherSuspended == NO) {
    [finder removeWatcherForPath: [node path]];
  }
  RELEASE (node);
  RELEASE (searchPaths);
  RELEASE (searchCriteria);
  RELEASE (foundPaths);
  RELEASE (lastUpdate);
        
  [super dealloc];
}

- (id)initForNode:(FSNode *)anode
     contentsInfo:(NSDictionary *)info
{
	self = [super init];

  if (self) {
    ASSIGN (node, anode);

    foundPaths = [NSMutableArray new];
    [foundPaths addObjectsFromArray: [info objectForKey: @"foundpaths"]];
    ASSIGN (searchPaths, [info objectForKey: @"searchpaths"]);
    ASSIGN (searchCriteria, [info objectForKey: @"criteria"]);
    ASSIGN (lastUpdate, [NSDate dateWithString: [info objectForKey: @"lastupdate"]]);

    finder = [Finder finder];
    [finder addWatcherForPath: [node path]];
    watcherSuspended = NO;
  }
  
	return self;
}

- (void)setNode:(FSNode *)anode
{
  if (watcherSuspended == NO) {
    [finder removeWatcherForPath: [node path]];
  }
  ASSIGN (node, anode);
  [finder addWatcherForPath: [node path]];
}

- (FSNode *)node
{
  return node;
}

- (BOOL)watcherSuspended
{
  return watcherSuspended;
}

- (void)setWatcherSuspended:(BOOL)value
{
  watcherSuspended = value;
}

@end



