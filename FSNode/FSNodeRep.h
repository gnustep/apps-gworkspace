/* FSNodeRep.h
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

#ifndef FSNODE_REP_H
#define FSNODE_REP_H

#include <Foundation/Foundation.h>
#include "FSNode.h"

typedef enum FSNInfoType {   
  FSNInfoNameType = 0,
  FSNInfoParentType = 1,
  FSNInfoKindType = 2,
  FSNInfoDateType = 3,
  FSNInfoSizeType = 4,
  FSNInfoOwnerType = 5
} FSNInfoType;

@class NSImage;
@class NSBezierPath;

@protocol FSNodeRep

- (void)setNode:(FSNode *)anode;

- (FSNode *)node;

- (void)showSelection:(NSArray *)selnodes;

- (void)setFont:(NSFont *)fontObj;

- (void)setIconSize:(float)isize;

- (void)setIconPosition:(unsigned int)ipos;

- (void)setNodeInfoShowType:(FSNInfoType)type;

- (void)setLocked:(BOOL)value;

- (BOOL)isLocked;

- (void)setGridIndex:(int)index;

- (int)gridIndex;

- (int)compareAccordingToName:(id)aObject;

- (int)compareAccordingToKind:(id)aObject;

- (int)compareAccordingToDate:(id)aObject;

- (int)compareAccordingToSize:(id)aObject;

- (int)compareAccordingToOwner:(id)aObject;

- (int)compareAccordingToGroup:(id)aObject;

- (int)compareAccordingToIndex:(id)aObject;

@end


@interface FSNodeRep : NSObject 
{
  FSNInfoType defSortOrder;
  BOOL hideSysFiles;

	NSMutableArray *lockedPaths;
  
  NSMutableDictionary *tumbsCache;
  NSString *thumbnailDir;
  BOOL usesThumbnails;  

  NSImage *multipleSelIcon;
  NSImage *openFolderIcon;
  
  NSNotificationCenter *nc;
  NSFileManager *fm;
  id ws;    
}

+ (NSArray *)directoryContentsAtPath:(NSString *)path;

+ (NSImage *)iconOfSize:(float)size 
                forNode:(FSNode *)node;

+ (NSImage *)multipleSelectionIconOfSize:(float)size;

+ (NSImage *)openFolderIconOfSize:(float)size 
                          forNode:(FSNode *)node;

+ (NSBezierPath *)highlightPathOfSize:(NSSize)size;

+ (float)highlightHeightFactor;

+ (float)labelMargin;

+ (float)defaultIconBaseShift;

+ (void)setDefaultSortOrder:(int)order;

+ (unsigned int)defaultSortOrder;

+ (SEL)defaultCompareSelector;

+ (unsigned int)sortOrderForDirectory:(NSString *)dirpath;

+ (SEL)compareSelectorForDirectory:(NSString *)dirpath;

+ (void)setSortOrder:(int)order 
        forDirectory:(NSString *)dirpath;

+ (void)lockNodes:(NSArray *)nodes;

+ (void)unlockNodes:(NSArray *)nodes;

+ (BOOL)isNodeLocked:(FSNode *)node;

+ (void)setUseThumbnails:(BOOL)value;

@end

#endif // FSNODE_REP_H

