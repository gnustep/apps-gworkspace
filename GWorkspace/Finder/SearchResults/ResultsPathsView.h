/* ResultsPathsView.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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

#ifndef RESULTS_PATHS_VIEW_H
#define RESULTS_PATHS_VIEW_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "FSNodeRep.h"

@interface ResultsPathsView : NSView
{
	NSMutableArray *icons; 
}

- (id)initWithFrame:(NSRect)frameRect;

- (void)showComponentsOfSelection:(NSArray *)selection;

- (void)tile;

@end


@interface ResultsPathsView (NodeRepContainer)

- (void)nodeContentsWillChange:(NSDictionary *)info;

- (void)nodeContentsDidChange:(NSDictionary *)info;

- (void)watchedPathChanged:(NSDictionary *)info;

- (void)selectionDidChange;

- (void)unselectOtherReps:(id)arep;

- (NSArray *)selectedReps;

- (NSArray *)selectedNodes;

- (NSArray *)selectedPaths;

- (FSNSelectionMask)selectionMask;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (NSColor *)backgroundColor;

- (NSColor *)textColor;

- (NSColor *)disabledTextColor;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

@end

#endif // RESULTS_PATHS_VIEW_H
