/* ViewersProtocol.h
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


#ifndef VIEWERSPROTOCOL_H
#define VIEWERSPROTOCOL_H

@protocol ViewersProtocol

- (void)setRootPath:(NSString *)rpath 
         viewedPath:(NSString *)vpath 
          selection:(NSArray *)selection
           delegate:(id)adelegate
           viewApps:(BOOL)canview;

- (NSString *)menuName;

- (NSString *)shortCut;

- (BOOL)usesShelf;

- (NSSize)resizeIncrements;

- (NSImage *)miniicon;

- (BOOL)hasPreferences;

- (id)prefController;

- (void)setSelectedPaths:(NSArray *)paths;

- (NSArray *)selectedPaths;

- (NSString *)rootPath;

- (NSString *)currentViewedPath;

- (void)checkRootPathAfterHidingOfPaths:(NSArray *)hpaths;

- (NSPoint)locationOfIconForPath:(NSString *)path;

- (void)setCurrentSelection:(NSArray *)paths;

- (NSPoint)positionForSlidedImage;

- (void)unsetWatchers;

- (void)setResizeIncrement:(int)increment;

- (void)setAutoSynchronize:(BOOL)value;

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths;

- (id)viewerView;

- (BOOL)viewsApps;

- (void)selectAll;

- (id)delegate;

- (void)setDelegate:(id)anObject;

@end 

#endif // VIEWERSPROTOCOL_H

