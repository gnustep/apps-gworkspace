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

typedef enum FSNSelectionMask {   
  NSSingleSelectionMask = 0,
  FSNMultipleSelectionMask = 1,
  FSNCreatingSelectionMask = 2
} FSNSelectionMask;

@class NSImage;
@class NSBezierPath;
@class NSFont;

@protocol FSNodeRep

- (void)setNode:(FSNode *)anode;

- (FSNode *)node;

- (void)showSelection:(NSArray *)selnodes;

- (BOOL)isShowingSelection;

- (NSArray *)selection;

- (void)setFont:(NSFont *)fontObj;

- (void)setIconSize:(int)isize;

- (void)setIconPosition:(unsigned int)ipos;

- (int)iconPosition;

- (NSRect)labelRect;

- (void)setNodeInfoShowType:(FSNInfoType)type;

- (FSNInfoType)nodeInfoShowType;

- (void)setNameEdited:(BOOL)value;

- (void)setLocked:(BOOL)value;

- (BOOL)isLocked;

- (void)checkLocked;

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


@protocol FSNodeRepContainer

- (void)showContentsOfNode:(FSNode *)anode;

- (FSNode *)shownNode;

- (void)setShowType:(FSNInfoType)type;

- (FSNInfoType)showType;

- (void)setIconSize:(int)size;

- (int)iconSize;

- (void)setLabelTextSize:(int)size;

- (int)labelTextSize;

- (void)setIconPosition:(int)pos;

- (int)iconPosition;

- (id)repOfSubnode:(FSNode *)anode;

- (id)repOfSubnodePath:(NSString *)apath;

- (id)addRepForSubnode:(FSNode *)anode;

- (id)addRepForSubnodePath:(NSString *)apath;

- (void)removeRepOfSubnode:(FSNode *)anode;

- (void)removeRepOfSubnodePath:(NSString *)apath;

- (void)removeRep:(id)arep;

- (void)unselectOtherReps:(id)arep;

- (void)selectRepsOfSubnodes:(NSArray *)nodes;

- (void)selectRepsOfPaths:(NSArray *)paths;

- (void)selectAll;

- (NSArray *)selectedReps;

- (NSArray *)selectedNodes;

- (NSArray *)selectedPaths;

- (void)selectionDidChange;

- (void)checkLockedReps;

- (void)setSelectionMask:(FSNSelectionMask)mask;

- (FSNSelectionMask)selectionMask;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)restoreLastSelection;

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted;

- (void)setBackgroundColor:(NSColor *)acolor;

- (NSColor *)backgroundColor;

@end


@protocol DesktopApplication

- (void)selectionChanged:(NSArray *)newsel;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)performFileOperation:(NSDictionary *)opinfo;

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (NSString *)trashPath;

- (id)workspaceApplication;

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
  NSImage *hardDiskIcon;
  NSImage *openHardDiskIcon;
  NSImage *workspaceIcon;
  NSImage *trashIcon;
  NSImage *trashFullIcon;
  
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

+ (NSImage *)workspaceIconOfSize:(float)size;

+ (NSImage *)trashIconOfSize:(float)size;

+ (NSImage *)trashFullIconOfSize:(float)size;

+ (NSBezierPath *)highlightPathOfSize:(NSSize)size;

+ (float)highlightHeightFactor;

+ (int)labelMargin;

+ (int)defaultIconBaseShift;

+ (void)setDefaultSortOrder:(int)order;

+ (unsigned int)defaultSortOrder;

+ (SEL)defaultCompareSelector;

+ (unsigned int)sortOrderForDirectory:(NSString *)dirpath;

+ (SEL)compareSelectorForDirectory:(NSString *)dirpath;

+ (void)setSortOrder:(int)order 
        forDirectory:(NSString *)dirpath;

+ (void)lockNode:(FSNode *)node;

+ (void)lockPath:(NSString *)path;

+ (void)lockNodes:(NSArray *)nodes;

+ (void)lockPaths:(NSArray *)paths;

+ (void)unlockNode:(FSNode *)node;

+ (void)unlockPath:(NSString *)path;

+ (void)unlockNodes:(NSArray *)nodes;

+ (void)unlockPaths:(NSArray *)paths;

+ (BOOL)isNodeLocked:(FSNode *)node;

+ (BOOL)isPathLocked:(NSString *)path;

+ (void)setUseThumbnails:(BOOL)value;

@end

#endif // FSNODE_REP_H

