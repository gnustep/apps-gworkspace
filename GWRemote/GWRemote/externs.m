/* externs.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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

/* Notifications */
NSString *GWFileSystemWillChangeNotification = @"GWFileSystemWillChangeNotification";
NSString *GWFileSystemDidChangeNotification = @"GWFileSystemDidChangeNotification";
NSString *GWSortTypeDidChangeNotification = @"GWSortTypeDidChangeNotification";

/* Geometry Notifications */
NSString *GWBrowserColumnWidthChangedNotification = @"GWBrowserColumnWidthChangedNotification";
NSString *GWShelfCellsWidthChangedNotification = @"GWShelfCellsWidthChangedNotification";

/* File Watcher Notifications */
NSString *GWFileWatcherFileDidChangeNotification = @"GWFileWatcherFileDidChangeNotification";
NSString *GWWatchedDirectoryDeleted = @"GWWatchedDirectoryDeleted";
NSString *GWFileDeletedInWatchedDirectory = @"GWFileDeletedInWatchedDirectory";
NSString *GWFileCreatedInWatchedDirectory = @"GWFileCreatedInWatchedDirectory";

/* File Operations */
NSString *GWorkspaceCreateFileOperation = @"GWorkspaceCreateFileOperation";
NSString *GWorkspaceCreateDirOperation = @"GWorkspaceCreateDirOperation";
NSString *GWorkspaceRenameOperation = @"GWorkspaceRenameOperation";
NSString *GWorkspaceRecycleOutOperation = @"GWorkspaceRecycleOutOperation";
NSString *GWorkspaceEmptyRecyclerOperation = @"GWorkspaceEmptyRecyclerOperation";

NSString *GWRemoteFilenamesPboardType = @"GWRemoteFilenamesPboardType";
