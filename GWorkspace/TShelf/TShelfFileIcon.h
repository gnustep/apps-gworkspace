/* TShelfIcon.h
 *  
 * Copyright (C) 2003-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
 * Date: November 2021
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

#ifndef TSHELF_FILEICON_H
#define TSHELF_FILEICON_H

#import "TShelfIcon.h"

@class FSNode;
@class FSNodeRep;
@class GWorkspace;

@interface TShelfFileIcon : TShelfIcon
{
  NSMutableArray *paths;
  NSString *hostname;
  FSNode *node;
  BOOL singlepath;
  BOOL isRootIcon;
  FSNodeRep *fsnodeRep;
  NSFileManager *fm;
  GWorkspace *gw;

  BOOL forceCopy;
}

- (id)initForPaths:(NSArray *)fpaths
       inIconsView:(TShelfIconsView *)aview;

- (id)initForPaths:(NSArray *)fpaths
        atPosition:(NSPoint)pos
       inIconsView:(TShelfIconsView *)aview;

- (id)initForPaths:(NSArray *)fpaths
	 gridIndex:(NSUInteger)index
       inIconsView:(TShelfIconsView *)aview;

- (void)setPaths:(NSArray *)fpaths;

- (NSArray *)paths;

- (BOOL)isSinglePath;

@end

#endif // TSHELF_FILEICON_H
