/* GWDesktopWindow.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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

#ifndef GW_DESKTOP_WINDOW
#define GW_DESKTOP_WINDOW

#include <AppKit/NSWindow.h>

@interface GWDesktopWindow : NSWindow
{
  id delegate;
}

- (void)activate;
- (void)deactivate;
- (id)desktopView;

- (void)openSelection:(id)sender;
- (void)openSelectionAsFolder:(id)sender;
- (void)newFolder:(id)sender;
- (void)newFile:(id)sender;
- (void)duplicateFiles:(id)sender;
- (void)deleteFiles:(id)sender;
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


@interface NSObject (GWDesktopWindowDelegateMethods)

- (BOOL)validateItem:(id)menuItem;
- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)openSelectionAsFolder;
- (void)newFolder;
- (void)newFile;
- (void)duplicateFiles;
- (void)deleteFiles;
- (void)emptyTrash;
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

#endif // GW_DESKTOP_WINDOW
