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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
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
extern NSString *GWCustomDirectoryIconDidChangeNotification;

/* File Watcher Notifications */
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

extern NSString *GWOpenFolderIconName;
extern NSString *GWSmallOpenFolderIconName;
extern NSString *GWCellHighlightIconName;

/* The name of the pasteboard for the Live Search Folders */
extern NSString *GWLSFolderPboardType;

/* The name of the pasteboard for GWNet */
extern NSString *GWRemoteFilenamesPboardType;

/* The protocol of the remote dnd source */
@protocol GWRemoteFilesDraggingInfo
- (oneway void)remoteDraggingDestinationReply:(NSData *)reply;
@end 

#endif
