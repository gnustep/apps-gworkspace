/* GWNotifications.h
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

 
#ifndef GWNOTIFICATIONS_H
#define GWNOTIFICATIONS_H

/* Notifications */
extern NSString *GWFileSystemWillChangeNotification;
extern NSString *GWFileSystemDidChangeNotification;
extern NSString *GWDidSetFileAttributesNotification;
extern NSString *GWSortTypeDidChangeNotification;
extern NSString *GWCurrentSelectionChangedNotification;
extern NSString *GWViewersListDidChangeNotification;
extern NSString *GWViewersUseShelfDidChangeNotification;
extern NSString *GWBrowserCellsIconsDidChangeNotification;

/* Geometry Notifications */
extern NSString *GWBrowserColumnWidthChangedNotification;
extern NSString *GWShelfCellsWidthChangedNotification;
extern NSString *GWIconsCellsWidthChangedNotification;

/* Thumbnails Notifications */
extern NSString *GWThumbnailsDidChangeNotification;

/* File Watcher Notifications */
extern NSString *GWFileWatcherFileDidChangeNotification;
extern NSString *GWFileWatcherFileDidChangeNotification;
extern NSString *GWWatchedDirectoryDeleted;
extern NSString *GWFileDeletedInWatchedDirectory;
extern NSString *GWFileCreatedInWatchedDirectory;

/* File Operations */
extern NSString *GWorkspaceCreateFileOperation;
extern NSString *GWorkspaceCreateDirOperation;
extern NSString *GWorkspaceRenameOperation;
extern NSString *GWorkspaceRecycleOutOperation;
extern NSString *GWorkspaceEmptyRecyclerOperation;


extern NSString *GSHideDotFilesDidChangeNotification;

extern NSString *GWDesktopViewColorChangedNotification;
extern NSString *GWDesktopViewImageChangedNotification;
extern NSString *GWDesktopViewUnsetImageNotification;

extern NSString *GWIconAnimationChangedNotification;

/* Pasteboard type for GWRemote */
extern NSString *GWRemoteFilenamesPboardType;

#endif
