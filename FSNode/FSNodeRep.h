/* FSNodeRep.h
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef FSNODE_REP_H
#define FSNODE_REP_H

#import <Foundation/Foundation.h>
#import "FSNode.h"

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

- (void)setGridIndex:(NSUInteger)index;

- (NSUInteger)gridIndex;

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

- (NSMutableDictionary *)updateNodeInfo:(BOOL)ondisk;

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
                       wasCut:(BOOL)cut;

- (void)setNameEditorForRep:(id)arep;

- (void)stopRepNameEditing;

- (BOOL)canStartRepNameEditing;

- (void)setFocusedRep:(id)arep;

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

- (BOOL)openFile:(NSString *)fullPath;

- (void)newViewerAtPath:(NSString *)path;

- (void)performFileOperation:(NSDictionary *)opinfo;

- (BOOL)filenamesWasCutted;

- (void)setFilenamesCutted:(BOOL)value;

- (void)performFileOperation:(NSString *)operation
		                  source:(NSString *)source
		             destination:(NSString *)destination
		                   files:(NSArray *)files;

- (void)lsfolderDragOperation:(NSData *)opinfo
              concludedAtPath:(NSString *)path;

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (void)connectDDBd;

- (BOOL)ddbdactive;

- (void)ddbdInsertPath:(NSString *)path;

- (void)ddbdRemovePath:(NSString *)path;

- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path;

- (void)ddbdSetAnnotations:(NSString *)annotations
                   forPath:(NSString *)path;

- (NSString *)trashPath;

- (id)workspaceApplication;

- (oneway void)terminateApplication;

- (BOOL)terminating;

@end


@protocol FSNViewer

- (void)setSelectableNodesRange:(NSRange)range;

- (void)multipleNodeViewDidSelectSubNode:(FSNode *)node;

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
  NSMutableSet *reservedNames;
  NSMutableSet *volumes;
  NSString *rootPath;

  unsigned systype;
    
  NSMutableDictionary *iconsCache;
  NSMutableDictionary *tumbsCache;
  NSString *thumbnailDir;
  BOOL usesThumbnails;  
  
  BOOL oldresize;  

  NSImage *multipleSelIcon;
  NSImage *openFolderIcon;
  NSImage *hardDiskIcon;
  NSImage *openHardDiskIcon;
  NSImage *trashIcon;
  NSImage *trashFullIcon;
  
  float labelWFactor;
    
  NSFileManager *fm;
  id ws;    
}

+ (FSNodeRep *)sharedInstance;

- (NSArray *)directoryContentsAtPath:(NSString *)path;

- (int)labelMargin;

- (float)labelWFactor;

- (void)setLabelWFactor:(float)f;

- (float)heightOfFont:(NSFont *)font;

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

- (NSSet *)volumes;

- (void)setReservedNames:(NSArray *)names;

- (NSSet *)reservedNames;

- (BOOL)isReservedName:(NSString *)name;

- (unsigned)systemType;

- (void)setUseThumbnails:(BOOL)value;

- (BOOL)usesThumbnails;

- (void)thumbnailsDidChange:(NSDictionary *)info;

- (NSArray *)availableExtendedInfoNames;

- (NSDictionary *)extendedInfoOfType:(NSString *)type
                             forNode:(FSNode *)anode;

@end


@interface FSNodeRep (Icons)

- (NSImage *)iconOfSize:(int)size 
                forNode:(FSNode *)node;

- (NSImage *)selectedIconOfSize:(int)size 
                        forNode:(FSNode *)node;

- (NSImage *)cachedIconOfSize:(int)size 
                       forKey:(NSString *)key;

- (NSImage *)cachedIconOfSize:(int)size
                       forKey:(NSString *)key
                  addBaseIcon:(NSImage *)baseIcon;

- (void)removeCachedIconsForKey:(NSString *)key;

- (NSImage *)multipleSelectionIconOfSize:(int)size;

- (NSImage *)openFolderIconOfSize:(int)size 
                          forNode:(FSNode *)node;

- (NSImage *)trashIconOfSize:(int)size;

- (NSImage *)trashFullIconOfSize:(int)size;

- (NSBezierPath *)highlightPathOfSize:(NSSize)size;

- (float)highlightHeightFactor;

- (NSImage *)resizedIcon:(NSImage *)icon 
                  ofSize:(int)size;

- (NSImage *)lighterIcon:(NSImage *)icon;

- (NSImage *)darkerIcon:(NSImage *)icon;

- (void)prepareThumbnailsCache;

- (NSImage *)thumbnailForPath:(NSString *)apath;

@end


#endif // FSNODE_REP_H

