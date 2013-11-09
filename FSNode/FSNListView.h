/* FSNListView.h
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2004
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

#ifndef FSN_LIST_VIEW_H
#define FSN_LIST_VIEW_H

#import <Foundation/Foundation.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSTextField.h>
#import "FSNodeRep.h"

@class NSTableColumn;
@class FSNListView;
@class FSNListViewNodeRep;
@class FSNListViewNameEditor;

@interface FSNListViewDataSource : NSObject <NSTextFieldDelegate>
{
  FSNListView *listView;
    
  FSNode *node;
  NSMutableArray *nodeReps;
  FSNInfoType hlighColId;
  NSString *extInfoType;

  NSArray *lastSelection;

  NSUInteger mouseFlags;    
  BOOL isDragTarget;
  BOOL forceCopy;
  FSNListViewNodeRep *dndTarget;
  unsigned int dragOperation;
  NSRect dndValidRect;

  FSNListViewNameEditor *nameEditor;
      
  FSNodeRep *fsnodeRep;

  id <DesktopApplication> desktopApp;
}

- (id)initForListView:(FSNListView *)aview;

- (FSNode *)infoNode;

- (BOOL)keepsColumnsInfo;

- (void)createColumns:(NSDictionary *)info;

- (void)addColumn:(NSDictionary *)info;

- (void)removeColumnWithIdentifier:(NSNumber *)identifier;

- (NSDictionary *)columnsDescription;

- (void)sortNodeReps;

- (void)setMouseFlags:(NSUInteger)flags;

- (void)doubleClickOnListView:(id)sender;

- (void)selectRep:(id)aRep;

- (void)unselectRep:(id)aRep;

- (void)selectIconOfRep:(id)aRep;

- (void)unSelectIconsOfRepsDifferentFrom:(id)aRep;

- (void)selectRepInPrevRow;

- (void)selectRepInNextRow;

- (NSString *)selectRepWithPrefix:(NSString *)prefix;

- (void)redisplayRep:(id)aRep;

- (id)desktopApp;

@end


@interface FSNListViewDataSource (NSTableViewDataSource)

- (int)numberOfRowsInTableView:(NSTableView *)aTableView;

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(NSInteger)rowIndex;

- (void)tableView:(NSTableView *)aTableView 
            setObjectValue:(id)anObject 
            forTableColumn:(NSTableColumn *)aTableColumn 
                       row:(NSInteger)rowIndex;

- (BOOL)tableView:(NSTableView *)aTableView
	      writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard;

- (NSDragOperation)tableView:(NSTableView *)tableView 
                validateDrop:(id <NSDraggingInfo>)info 
                 proposedRow:(NSInteger)row 
       proposedDropOperation:(NSTableViewDropOperation)operation;

- (BOOL)tableView:(NSTableView *)tableView 
       acceptDrop:(id <NSDraggingInfo>)info 
              row:(NSInteger)row 
    dropOperation:(NSTableViewDropOperation)operation;
    
//
// NSTableView delegate methods
//
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

- (BOOL)tableView:(NSTableView *)aTableView 
  shouldSelectRow:(NSInteger)rowIndex;

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(NSInteger)rowIndex;
              
- (void)tableView:(NSTableView *)tableView 
            mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn;

- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows;

- (BOOL)tableView:(NSTableView *)aTableView 
            shouldEditTableColumn:(NSTableColumn *)aTableColumn 
                              row:(NSInteger)rowIndex;   

@end


@interface FSNListViewDataSource (NodeRepContainer)

- (void)showContentsOfNode:(FSNode *)anode;
- (NSDictionary *)readNodeInfo;
- (NSMutableDictionary *)updateNodeInfo:(BOOL)ondisk;
- (void)reloadContents;
- (void)reloadFromNode:(FSNode *)anode;
- (FSNode *)baseNode;
- (FSNode *)shownNode;
- (BOOL)isShowingNode:(FSNode *)anode;
- (BOOL)isShowingPath:(NSString *)path;
- (void)sortTypeChangedAtPath:(NSString *)path;
- (void)nodeContentsWillChange:(NSDictionary *)info;
- (void)nodeContentsDidChange:(NSDictionary *)info;
- (void)watchedPathChanged:(NSDictionary *)info;
- (void)setShowType:(FSNInfoType)type;
- (void)setExtendedShowType:(NSString *)type;
- (FSNInfoType)showType;
- (id)repOfSubnode:(FSNode *)anode;
- (id)repOfSubnodePath:(NSString *)apath;
- (id)addRepForSubnode:(FSNode *)anode;
- (void)removeRepOfSubnode:(FSNode *)anode;
- (void)removeRepOfSubnodePath:(NSString *)apath;
- (void)unloadFromNode:(FSNode *)anode;
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
- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)setLastShownNode:(FSNode *)anode;
- (BOOL)needsDndProxy;
- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo;
- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCut:(BOOL)cut;
- (void)stopRepNameEditing;

@end


@interface FSNListViewDataSource (RepNameEditing)

- (void)setEditorAtRow:(int)row withMouseDownEvent: (NSEvent *)anEvent;

- (void)controlTextDidChange:(NSNotification *)aNotification;

- (void)controlTextDidEndEditing:(NSNotification *)aNotification;

@end


@interface FSNListViewDataSource (DraggingDestination)

- (BOOL)checkDraggingLocation:(NSPoint)loc;

- (NSDragOperation)checkReturnValueForRep:(FSNListViewNodeRep *)arep
                         withDraggingInfo:(id <NSDraggingInfo>)sender;

- (NSDragOperation)listViewDraggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)listViewDraggingUpdated:(id <NSDraggingInfo>)sender;

- (void)listViewDraggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)listViewPrepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)listViewPerformDragOperation:(id <NSDraggingInfo>)sender;

- (void)listViewConcludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface FSNListViewNodeRep : NSObject <FSNodeRep>
{
  FSNode *node;
  NSImage *icon;
  NSImage *openicon;
  NSImage *lockedicon;
  NSImage *spopenicon;
  NSString *extInfoStr;
  
  BOOL isLocked;
  BOOL iconSelected;
  BOOL isOpened;
  BOOL wasOpened;
  BOOL nameEdited;
  BOOL isDragTarget;
  BOOL forceCopy;
  
  FSNListViewDataSource *dataSource;
  FSNodeRep *fsnodeRep;  
}

- (id)initForNode:(FSNode *)anode
       dataSource:(FSNListViewDataSource *)fsnds;

- (NSImage *)icon;

- (NSImage *)openIcon;

- (NSImage *)lockedIcon;

- (NSImage *)spatialOpenIcon;

- (BOOL)selectIcon:(BOOL)value;

- (BOOL)iconSelected;

@end


@interface FSNListViewNodeRep (DraggingDestination)

- (NSDragOperation)repDraggingEntered:(id <NSDraggingInfo>)sender;

- (void)repConcludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface FSNListViewNameEditor : NSTextField
{
  FSNode *node;
  int index;
}  

- (void)setNode:(FSNode *)anode 
    stringValue:(NSString *)str
          index:(int)idx;

- (FSNode *)node;

- (int)index;

@end


@interface FSNListView : NSTableView
{
  id dsource;
  NSString *charBuffer;	
  NSTimeInterval lastKeyPressed;

  NSTimer *clickTimer;
}

- (id)initWithFrame:(NSRect)frameRect
    dataSourceClass:(Class)dsclass;

- (void)checkSize;
    
@end


@interface NSObject (FSNListViewDelegateMethods)

- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows;

@end


@interface FSNListView (NodeRepContainer)

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
- (id)repOfSubnode:(FSNode *)anode;
- (id)repOfSubnodePath:(NSString *)apath;
- (id)addRepForSubnode:(FSNode *)anode;
- (void)removeRepOfSubnode:(FSNode *)anode;
- (void)removeRepOfSubnodePath:(NSString *)apath;
- (void)unloadFromNode:(FSNode *)anode;
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
- (void)openSelectionInNewViewer:(BOOL)newv;
- (void)setLastShownNode:(FSNode *)anode;
- (BOOL)needsDndProxy;
- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo;
- (BOOL)validatePasteOfFilenames:(NSArray *)names
                       wasCut:(BOOL)cut;
- (void)stopRepNameEditing;

@end


@interface FSNListView (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end


@interface NSDictionary (TableColumnSort)

- (int)compareTableColumnInfo:(NSDictionary *)info;

@end

#endif // FSN_LIST_VIEW_H
