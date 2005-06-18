/* externs.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#ifndef CACHED_MAX
  #define CACHED_MAX 20;
#endif

/* Class variables */
NSMutableDictionary *cachedContents = nil;
int cachedMax = CACHED_MAX;

NSMutableArray *lockedPaths = nil;

NSRecursiveLock *gwsdLock = nil;

/* File Operations */
NSString *NSWorkspaceMoveOperation = @"NSWorkspaceMoveOperation";
NSString *NSWorkspaceCopyOperation = @"NSWorkspaceCopyOperation";
NSString *NSWorkspaceLinkOperation = @"NSWorkspaceLinkOperation";
NSString *NSWorkspaceDestroyOperation = @"NSWorkspaceDestroyOperation";
NSString *NSWorkspaceDuplicateOperation = @"NSWorkspaceDuplicateOperation";
NSString *NSWorkspaceRecycleOperation = @"NSWorkspaceRecycleOperation";
NSString *GWorkspaceRecycleOutOperation = @"GWorkspaceRecycleOutOperation";
NSString *GWorkspaceEmptyRecyclerOperation = @"GWorkspaceEmptyRecyclerOperation";

/* Notifications */
NSString *GWFileSystemWillChangeNotification = @"GWFileSystemWillChangeNotification";
NSString *GWFileSystemDidChangeNotification = @"GWFileSystemDidChangeNotification"; 

NSString *GWFileWatcherFileDidChangeNotification = @"GWFileWatcherFileDidChangeNotification"; 
NSString *GWWatchedDirectoryDeleted = @"GWWatchedDirectoryDeleted"; 
NSString *GWFileDeletedInWatchedDirectory = @"GWFileDeletedInWatchedDirectory"; 
NSString *GWFileCreatedInWatchedDirectory = @"GWFileCreatedInWatchedDirectory"; 
