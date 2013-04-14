/* GWViewer.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2004
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


#import <Foundation/Foundation.h>
#import <AppKit/NSWindow.h>

@class GWorkspace;

@interface GWViewerWindow : NSWindow
{

}

- (void)openSelection:(id)sender;
- (void)openSelectionAsFolder:(id)sender;
- (void)openWith:(id)sender;
- (void)newFolder:(id)sender;
- (void)newFile:(id)sender;
- (void)duplicateFiles:(id)sender;
- (void)recycleFiles:(id)sender;
- (void)deleteFiles:(id)sender;
- (void)goBackwardInHistory:(id)sender;
- (void)goForwardInHistory:(id)sender;
- (void)setViewerType:(id)sender;
- (void)setShownType:(id)sender;
- (void)setExtendedShownType:(id)sender;
- (void)setIconsSize:(id)sender;
- (void)setIconsPosition:(id)sender;
- (void)setLabelSize:(id)sender;
- (void)chooseLabelColor:(id)sender;
- (void)chooseBackColor:(id)sender;
- (void)selectAllInViewer:(id)sender;
- (void)showTerminal:(id)sender;

@end


@interface NSObject (GWViewerWindowDelegateMethods)

- (BOOL)validateItem:(id)menuItem;
- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)openSelectionAsFolder;
- (void)openSelectionWith;
- (void)newFolder;
- (void)newFile;
- (void)duplicateFiles;
- (void)recycleFiles;
- (void)emptyTrash;
- (void)deleteFiles;
- (void)goBackwardInHistory;
- (void)goForwardInHistory;
- (void)setViewerBehaviour:(id)sender;
- (void)setViewerType:(id)sender;
- (void)setShownType:(id)sender;
- (void)setExtendedShownType:(id)sender;
- (void)setIconsSize:(id)sender;
- (void)setIconsPosition:(id)sender;
- (void)setLabelSize:(id)sender;
- (void)chooseLabelColor:(id)sender;
- (void)chooseBackColor:(id)sender;
- (void)selectAllInViewer;
- (void)showTerminal;

@end
