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
  FSNInfoKindType = 1,
  FSNInfoDateType = 2,
  FSNInfoSizeType = 3,
  FSNInfoOwnerType = 4,
  FSNInfoParentType = 5,
  FSNInfoExtendedType = 6
} FSNInfoType;

typedef enum FSNSelectionMask {
  NSSingleSelectionMask = 0,
  FSNMultipleSelectionMask = 1,
  FSNCreatingSelectionMask = 2
} FSNSelectionMask;

@class NSImage;
@class NSColor;
@class NSBezierPath;
@class NSFont;

@protocol FSNodeRep

- (void)setNode:(FSNode *)anode;

- (void)setNode:(FSNode *)anode
   nodeInfoType:(FSNInfoType)type
   extendedType:(NSString *)exttype;

- (FSNode *)node;

- (void)showSelection:(NSArray *)selnodes;

- (BOOL)isShowingSelection;

- (NSArray *)selection;

- (NSArray *)pathsSelection;

- (void)setFont:(NSFont *)fontObj;

- (NSFont *)labelFont;

- (void)setLabelTextColor:(NSColor *)acolor;

- (NSColor *)labelTextColor;

- (void)setIconSize:(int)isize;

- (int)iconSize;

- (void)setIconPosition:(unsigned int)ipos;

- (int)iconPosition;

- (NSRect)labelRect;

- (void)setNodeInfoShowType:(FSNInfoType)type;

- (BOOL)setExtendedShowType:(NSString *)type;

- (FSNInfoType)nodeInfoShowType;

- (NSString *)shownInfo;

- (void)setNameEdited:(BOOL)value;

- (void)setLeaf:(BOOL)flag;

- (BOOL)isLeaf;

- (void)select;

- (void)unselect;

- (BOOL)isSelected;

- (void)setOpened:(BOOL)value;

- (BOOL)isOpened;

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

- (NSDictionary *)readNodeInfo;

- (void)updateNodeInfo;

- (void)reloadContents;

- (void)reloadFromNode:(FSNode *)anode;

- (FSNode *)baseNode;

- (FSNode *)shownNode;

- (BOOL)isSingleNode;

- (BOOL)isShowingNode:(FSNode *)anode;

- (BOOL)isShowingPath:(NSString *)path;

- (void)sortTypeChangedAtPath:(NSString *)path;

- (void)nodeContentsWillChange:(NSDictionary *)info;

- (void)nodeContentsDidChange:(NSDictionary *)info;

- (void)watchedPathChanged:(NSDictionary *)info;

- (void)setShowType:(FSNInfoType)type;

- (void)setExtendedShowType:(NSString *)type;

- (FSNInfoType)showType;

- (void)setIconSize:(int)size;

- (int)iconSize;

- (void)setLabelTextSize:(int)size;

- (int)labelTextSize;

- (void)setIconPosition:(int)pos;

- (int)iconPosition;

- (void)updateIcons;

- (id)repOfSubnode:(FSNode *)anode;

- (id)repOfSubnodePath:(NSString *)apath;

- (id)addRepForSubnode:(FSNode *)anode;

- (id)addRepForSubnodePath:(NSString *)apath;

- (void)removeRepOfSubnode:(FSNode *)anode;

- (void)removeRepOfSubnodePath:(NSString *)apath;

- (void)removeRep:(id)arep;

- (void)removeUndepositedRep:(id)arep;

- (void)unloadFromNode:(FSNode *)anode;

- (void)repSelected:(id)arep;

- (void)unselectOtherReps:(id)arep;

- (void)selectReps:(NSArray *)reps;

- (void)selectRepsOfSubnodes:(NSArray *)nodes;

- (void)selectRepsOfPaths:(NSArray *)paths;

- (void)selectAll;

- (void)scrollSelectionToVisible;

- (NSArray *)reps;

- (NSArray *)selectedReps;

- (NSArray *)selectedNodes;

- (NSArray *)selectedPaths;

- (void)selectionDidChange;

- (void)checkLockedReps;

- (void)setSelectionMask:(FSNSelectionMask)mask;

- (FSNSelectionMask)selectionMask;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)restoreLastSelection;

- (void)setLastShownNode:(FSNode *)anode;

- (BOOL)needsDndProxy;

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo;

- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCutted:(BOOL)cutted;

- (void)setNameEditorForRep:(id)arep;

- (void)stopRepNameEditing;

- (BOOL)canStartRepNameEditing;

- (void)setBackgroundColor:(NSColor *)acolor;

- (NSColor *)backgroundColor;

- (void)setTextColor:(NSColor *)acolor;

- (NSColor *)textColor;

- (NSColor *)disabledTextColor;

@end


@protocol DesktopApplication

- (void)selectionChanged:(NSArray *)newsel;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)openSelectionWithApp:(id)sender;

- (void)performFileOperation:(NSDictionary *)opinfo;

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (NSString *)trashPath;

- (id)workspaceApplication;

@end


@protocol FSNViewer

- (void)setSelectableNodesRange:(NSRange)range;

@end


@protocol FSNViewerManager

- (void)viewer:(id)aviewer didShowNode:(FSNode *)node;

- (void)openSelectionInViewer:(id)viewer
                  closeSender:(BOOL)close;
                  
@end


@interface FSNodeRep : NSObject 
{
  NSArray *extInfoModules;
  
  FSNInfoType defSortOrder;
  BOOL hideSysFiles;

	NSMutableArray *lockedPaths;
  NSArray *hiddenPaths;
  NSMutableSet *volumes;
  
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
  
  float labelWFactor;
  
  NSNotificationCenter *nc;
  NSFileManager *fm;
  id ws;    
}

+ (FSNodeRep *)sharedInstance;

- (NSArray *)directoryContentsAtPath:(NSString *)path;

- (NSImage *)iconOfSize:(int)size 
                forNode:(FSNode *)node;

- (NSImage *)multipleSelectionIconOfSize:(int)size;

- (NSImage *)openFolderIconOfSize:(int)size 
                          forNode:(FSNode *)node;

- (NSImage *)workspaceIconOfSize:(int)size;

- (NSImage *)trashIconOfSize:(int)size;

- (NSImage *)trashFullIconOfSize:(int)size;

- (NSBezierPath *)highlightPathOfSize:(NSSize)size;

- (float)highlightHeightFactor;

- (int)labelMargin;

- (float)labelWFactor;

- (void)setLabelWFactor:(float)f;

- (int)defaultIconBaseShift;

- (void)setDefaultSortOrder:(int)order;

- (unsigned int)defaultSortOrder;

- (SEL)defaultCompareSelector;

- (unsigned int)sortOrderForDirectory:(NSString *)dirpath;

- (SEL)compareSelectorForDirectory:(NSString *)dirpath;

- (void)setHideSysFiles:(BOOL)value;

- (BOOL)hideSysFiles;

- (void)setHiddenPaths:(NSArray *)paths;

- (NSArray *)hiddenPaths;

- (void)lockNode:(FSNode *)node;

- (void)lockPath:(NSString *)path;

- (void)lockNodes:(NSArray *)nodes;

- (void)lockPaths:(NSArray *)paths;

- (void)unlockNode:(FSNode *)node;

- (void)unlockPath:(NSString *)path;

- (void)unlockNodes:(NSArray *)nodes;

- (void)unlockPaths:(NSArray *)paths;

- (BOOL)isNodeLocked:(FSNode *)node;

- (BOOL)isPathLocked:(NSString *)path;

- (void)setVolumes:(NSArray *)vls;

- (void)addVolumeAt:(NSString *)path;

- (void)removeVolumeAt:(NSString *)path;

- (void)setUseThumbnails:(BOOL)value;

- (BOOL)usesThumbnails;

- (void)thumbnailsDidChange:(NSDictionary *)info;

- (NSArray *)availableExtendedInfoNames;

- (NSDictionary *)extendedInfoOfType:(NSString *)type
                             forNode:(FSNode *)anode;

@end

#endif // FSNODE_REP_H

