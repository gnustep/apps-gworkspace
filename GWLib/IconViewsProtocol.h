/* IconViewsProtocol.h
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


#ifndef ICONVIEWSPROTOCOL_H
#define ICONVIEWSPROTOCOL_H

@protocol IconViewsProtocol

- (void)addIconWithPaths:(NSArray *)iconpaths;

- (void)removeIcon:(id)anIcon;

- (void)setLabelRectOfIcon:(id)anIcon;

- (void)unselectOtherIcons:(id)anIcon;

- (void)setShiftClick:(BOOL)value;

- (void)setCurrentSelection:(NSArray *)paths;

- (void)setCurrentSelection:(NSArray *)paths 
               animateImage:(NSImage *)image
            startingAtPoint:(NSPoint)startp;

- (void)openCurrentSelection:(NSArray *)paths newViewer:(BOOL)newv;

- (NSArray *)currentSelection;

- (int)cellsWidth;

- (void)setDelegate:(id)anObject;

- (id)delegate;

@end 

#endif // ICONVIEWSPROTOCOL_H
