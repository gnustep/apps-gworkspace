/* GWProtocol.h
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

#ifndef GWPROTOCOL_H
#define GWPROTOCOL_H

@class GWorkspace;
@class ViewersWindow;

@protocol GWProtocol

+ (GWorkspace *)gworkspace;

- (BOOL)performFileOperation:(NSString *)operation 
                      source:(NSString *)source 
                 destination:(NSString *)destination 
                       files:(NSArray *)files 
                         tag:(int *)tag;

- (void)performFileOperationWithDictionary:(id)opdict;

- (BOOL)application:(NSApplication *)theApplication 
           openFile:(NSString *)filename;

- (BOOL)openFile:(NSString *)fullPath;

- (BOOL)openFile:(NSString *)fullPath 
			 fromImage:(NSImage *)anImage 
			  			at:(NSPoint)point 
					inView:(NSView *)aView;

- (BOOL)selectFile:(NSString *)fullPath
							inFileViewerRootedAtPath:(NSString *)rootFullpath;

- (void)rootViewerSelectFiles:(NSArray *)paths;

- (void)slideImage:(NSImage *)image 
							from:(NSPoint)fromPoint 
								to:(NSPoint)toPoint;

- (void)noteFileSystemChanged;

- (void)noteFileSystemChanged:(NSString *)path;

- (BOOL)isPakageAtPath:(NSString *)path;

- (int)sortTypeForDirectoryAtPath:(NSString *)aPath;

- (void)setSortType:(int)type forDirectoryAtPath:(NSString *)aPath;

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)newv;

- (void)openSelectedPathsWith;

- (ViewersWindow *)newViewerAtPath:(NSString *)path canViewApps:(BOOL)viewapps;

- (NSImage *)iconForFile:(NSString *)fullPath ofType:(NSString *)type;

- (NSImage *)smallIconForFile:(NSString*)aPath;

- (NSImage *)smallIconForFiles:(NSArray*)pathArray;

- (NSImage *)smallHighlightIcon;

- (NSArray *)getSelectedPaths;

- (NSString *)trashPath;

- (NSArray *)viewersSearchPaths;

- (NSArray *)imageExtensions;

- (void)lockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path;

- (void)unLockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path;

- (BOOL)isLockedPath:(NSString *)path;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (BOOL)hideSysFiles;

- (BOOL)animateChdir;

- (BOOL)animateLaunck;

- (BOOL)animateSlideBack;

- (BOOL)usesContestualMenu;

//
// methods for GWRemote
//
- (void)performFileOperationWithDictionary:(id)opdict
                            fromSourceHost:(NSString *)fromName 
                         toDestinationHost:(NSString *)toName;

- (BOOL)server:(NSString *)serverName isPakageAtPath:(NSString *)path;

- (BOOL)server:(NSString *)serverName fileExistsAtPath:(NSString *)path;  

- (BOOL)server:(NSString *)serverName isWritableFileAtPath:(NSString *)path;

- (BOOL)server:(NSString *)serverName 
            existsAndIsDirectoryFileAtPath:(NSString *)path;              

- (NSString *)server:(NSString *)serverName typeOfFileAt:(NSString *)path;  

- (int)server:(NSString *)serverName sortTypeForPath:(NSString *)aPath; 

- (void)server:(NSString *)serverName                                   
   setSortType:(int)type 
        atPath:(NSString *)aPath;

- (NSArray *)server:(NSString *)serverName 
   checkHiddenFiles:(NSArray *)files 
             atPath:(NSString *)path;

- (NSArray *)server:(NSString *)serverName 
        sortedDirectoryContentsAtPath:(NSString *)path;

- (void)server:(NSString *)serverName setSelectedPaths:(NSArray *)paths;

- (NSArray *)selectedPathsForServerWithName:(NSString *)serverName;

- (NSString *)homeDirectoryForServerWithName:(NSString *)serverName;

- (BOOL)server:(NSString *)serverName isLockedPath:(NSString *)aPath;

- (void)server:(NSString *)serverName addWatcherForPath:(NSString *)path;

- (void)server:(NSString *)serverName removeWatcherForPath:(NSString *)path;

- (void)server:(NSString *)serverName removeWatcherForPath:(NSString *)path;

- (void)server:(NSString *)serverName 
    renamePath:(NSString *)oldname 
     toNewName:(NSString *)newname;

@end 

#endif // GWPROTOCOL_H

