/* GWViewersManager.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2004
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

#ifndef GWVIEWERS_MANAGER_H
#define GWVIEWERS_MANAGER_H

#include <Foundation/Foundation.h>

@class GWSpatialViewer;
@class GWorkspace;

@interface GWViewersManager : NSObject
{
  NSMutableArray *viewers;
  GWorkspace *gworkspace;
}

+ (GWViewersManager *)viewersManager;

- (id)newViewerForPath:(NSString *)path
        closeOldViewer:(GWSpatialViewer *)oldvwr;

- (id)viewerForPath:(NSString *)path;

- (void)viewerSelected:(GWSpatialViewer *)aviewer;

- (void)unselectOtherViewers:(GWSpatialViewer *)aviewer;

- (void)viewerWillClose:(GWSpatialViewer *)aviewer;

- (void)openSelectionInViewer:(GWSpatialViewer *)viewer
                  closeSender:(BOOL)close;



/*
//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)openSelectionWithApp:(id)sender;

- (void)performFileOperation:(NSDictionary *)opinfo;

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;
*/

@end

#endif // GWVIEWERS_MANAGER_H
