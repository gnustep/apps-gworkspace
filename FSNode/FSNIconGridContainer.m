/* FSNIconGridContainer.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "FSNIconGridContainer.h"
#include "GNUstep.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

#define LABEL_W_FACT (8)

#define X_MARGIN (10)
#define Y_MARGIN (12)

#define EDIT_MARGIN (4)

#ifndef max
  #define max(a,b) ((a) >= (b) ? (a):(b))
#endif

#ifndef min
  #define min(a,b) ((a) <= (b) ? (a):(b))
#endif


@implementation FSNIconGridContainer

- (void)dealloc
{
	NSZoneFree (NSDefaultMallocZone(), grid);
  TEST_RELEASE (dragIcon);

  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if (self) {
 //   [self makeIconsGrid];
    dragIcon = nil;
  }
   
  return self;
}


//
// FSNodeRepContainer protocol
//
- (void)showContentsOfNode:(FSNode *)anode
{
}

- (FSNode *)shownNode
{
  return nil;
}

- (void)setShowType:(FSNInfoType)type
{
}

- (FSNInfoType)showType
{
  return 0;
}

- (id)repOfSubnode:(FSNode *)anode
{
  return nil;
}

- (id)repOfSubnodePath:(NSString *)apath
{
  return nil;
}

- (id)addRepForSubnode:(FSNode *)anode
{
  return nil;
}

- (id)addRepForSubnodePath:(NSString *)apath
{
  return nil;
}

- (void)removeRepOfSubnode:(FSNode *)anode
{
}

- (void)removeRepOfSubnodePath:(NSString *)apath
{
}

- (void)removeRep:(id)arep
{
}

- (void)unselectOtherReps:(id)arep
{
}

- (void)selectRepsOfSubnodes:(NSArray *)nodes
{
}

- (void)selectRepsOfPaths:(NSArray *)paths
{
}

- (void)selectAll
{
}

- (NSArray *)selectedReps
{
  return nil;
}

- (NSArray *)selectedNodes
{
  return nil;
}

- (NSArray *)selectedPaths
{
  return nil;
}

- (void)selectionDidChange
{
}

- (void)checkLockedReps
{
}

- (void)setSelectionMask:(FSNSelectionMask)mask
{
}

- (FSNSelectionMask)selectionMask
{
  return 0;
}

- (void)openSelectionInNewViewer:(BOOL)newv
{
}

- (void)restoreLastSelection
{
}

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted
{
  return NO;
}
                       
- (NSColor *)backgroundColor
{
  return nil;
}

@end
