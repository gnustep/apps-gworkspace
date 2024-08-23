/* TShelfWin.h
 *  
 * Copyright (C) 2003-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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

#ifndef TSHELF_WIN_H
#define TSHELF_WIN_H

#include <Foundation/Foundation.h>
#include <AppKit/NSWindow.h>

#ifndef FILES_TAB
  #define FILES_TAB 0
  #define DATA_TAB 1
#endif

@class TShelfView;

@interface TShelfWin : NSWindow
{
  TShelfView *tView;
  BOOL autohide;
  BOOL autohidden;
  BOOL singleClickLaunch;
}

- (TShelfView *)shelfView;

- (void)activate;

- (void)deactivate;

- (void)animateShowing;

- (void)animateHiding;

- (void)setAutohide:(BOOL)value;

- (BOOL)autohide;

- (BOOL)singleClickLaunch;

- (void)setSingleClickLaunch:(BOOL)value;

- (void)addTab;

- (void)removeTab;

- (void)renameTab;

- (void)updateIcons;

- (void)checkIconsAfterDotsFilesChange;

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths;

- (void)saveDefaults;

@end

#endif // TABBED_SHELF_WIN_H
