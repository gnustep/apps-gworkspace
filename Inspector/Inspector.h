/* Inspector.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
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

#ifndef INSPECTOR_H
#define INSPECTOR_H

#include <Foundation/Foundation.h>
#include "FSNodeRep.h"

@class Attributes;
@class Contents;
@class Tools;

@interface Inspector : NSObject 
{
  IBOutlet id win;
  IBOutlet id popUp;
  IBOutlet id inspBox;

  NSMutableArray *inspectors;
	id currentInspector;

	NSArray *currentPaths;
  NSString *watchedPath;
    
  NSNotificationCenter *nc; 

  id <DesktopApplication> desktopApp;
}

- (void)activate;

- (void)setCurrentSelection:(NSArray *)selection;

- (BOOL)canDisplayDataOfType:(NSString *)type;

- (void)showData:(NSData *)data 
          ofType:(NSString *)type;

- (IBAction)activateInspector:(id)sender;

- (void)showAttributes;

- (id)attributes;

- (void)showContents;

- (id)contents;

- (void)showTools;

- (id)tools;

- (NSWindow *)win;

- (void)updateDefaults;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (void)watcherNotification:(NSNotification *)notif;

@end

#endif // INSPECTOR_H
