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

- (BOOL)selectFile:(NSString *)fullPath
							inFileViewerRootedAtPath:(NSString *)rootFullpath;

- (void)showRootViewer;

- (void)rootViewerSelectFiles:(NSArray *)paths;

- (void)slideImage:(NSImage *)image 
							from:(NSPoint)fromPoint 
								to:(NSPoint)toPoint;

- (void)openSelectedPaths:(NSArray *)paths 
                newViewer:(BOOL)newv;

- (void)openSelectedPathsWith;

- (NSArray *)getSelectedPaths;

- (NSString *)trashPath;

- (BOOL)animateChdir;

- (BOOL)animateSlideBack;

- (BOOL)usesContestualMenu;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

@end 

#endif // GWPROTOCOL_H

