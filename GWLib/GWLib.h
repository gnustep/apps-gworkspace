/* GWLib.h
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

#ifndef GWLIB_H
#define GWLIB_H

#include <Foundation/Foundation.h>

@interface GWLib : NSObject
{
  NSMutableDictionary *cachedContents;
  int cachedMax;
  int defSortType;
  BOOL hideSysFiles;
  
  NSMutableArray *watchers;
	NSMutableArray *watchTimers;
  NSMutableArray *watchedPaths;  

	NSMutableArray *lockedPaths;
  
  NSMutableDictionary *tumbsCache;
  NSString *thumbnailDir;
  BOOL usesThumbnails;    

  NSFileManager *fm;
  NSWorkspace *ws;
  NSNotificationCenter *nc;
  
  id workspaceApp;
}

+ (NSArray *)sortedDirectoryContentsAtPath:(NSString *)path;

+ (NSArray *)checkHiddenFiles:(NSArray *)files atPath:(NSString *)path;

+ (void)setCachedMax:(int)cmax;

+ (void)addWatcherForPath:(NSString *)path;

+ (void)removeWatcherForPath:(NSString *)path;

+ (void)lockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path;

+ (void)unLockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path;

+ (BOOL)isLockedPath:(NSString *)path;

+ (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path;

+ (NSString *)typeOfFileAt:(NSString *)path;  

+ (BOOL)isPakageAtPath:(NSString *)path;

+ (int)sortTypeForDirectoryAtPath:(NSString *)path;

+ (void)setSortType:(int)type forDirectoryAtPath:(NSString *)path;

+ (void)setDefSortType:(int)type;

+ (int)defSortType;

+ (void)setHideSysFiles:(BOOL)value;

+ (BOOL)hideSysFiles;

+ (NSImage *)iconForFile:(NSString *)fullPath ofType:(NSString *)type;

+ (NSImage *)smallIconForFile:(NSString*)aPath;

+ (NSImage *)smallIconForFiles:(NSArray*)pathArray;

+ (NSImage *)smallHighlightIcon;

+ (void)setUseThumbnails:(BOOL)value;

+ (NSArray *)imageExtensions;

+ (id)workspaceApp;

@end

#endif // GWLIB_H

