/* FileAnnotationsManager.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
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

#ifndef FILE_ANNOTATIONS_MANAGER_H
#define FILE_ANNOTATIONS_MANAGER_H

#include <Foundation/Foundation.h>

@class FileAnnotation;
@class FSNode;

@interface FileAnnotationsManager: NSObject
{
  NSMutableArray *annotations;
  NSMutableArray *watchedpaths;
  NSFileManager *fm;
  NSNotificationCenter *nc;
  id gw;
}

+ (FileAnnotationsManager *)fannmanager;

- (void)showAnnotationsForNodes:(NSArray *)nodes;

- (FileAnnotation *)annotationsOfNode:(FSNode *)anode;

- (FileAnnotation *)annotationsOfPath:(NSString *)apath;

- (void)annotationsWillClose:(id)ann;

- (NSArray *)annotationsWins;

- (void)closeAll;

- (void)fileSystemWillChange:(NSNotification *)notif;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)watcherNotification:(NSNotification *)notif;

@end

#endif // FILE_ANNOTATIONS_MANAGER_H


