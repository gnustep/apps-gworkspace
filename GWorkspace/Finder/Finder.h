/* Finder.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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

#ifndef FINDER_H
#define FINDER_H

#include <Foundation/Foundation.h>

@class FSNode;
@class NSScrollView;
@class NSMatrix;
@class FindModuleView;
@class LSFolder;

@interface Finder : NSObject 
{
  IBOutlet id win;
  IBOutlet id searchLabel;
  IBOutlet id wherePopUp;
  IBOutlet id placesBox;
  NSScrollView *placesScroll;
  NSMatrix *placesMatrix;
  IBOutlet id addPlaceButt;
  IBOutlet id removePlaceButt;
  IBOutlet id itemsLabel;
  IBOutlet id modulesBox;
  IBOutlet id findButt;

  NSMutableArray *modules;
  NSMutableArray *fmviews;

  NSArray *currentSelection;
  BOOL usesSearchPlaces;
  BOOL splacesDndTarget;

  NSMutableArray *searchResults;
  int searchResh;

  NSMutableArray *lsFolders;

  NSFileManager *fm;
  NSNotificationCenter *nc; 
  id ws;
  id gworkspace;
}

+ (Finder *)finder;

- (void)activate;

- (void)loadModules;

- (NSArray *)bundlesWithExtension:(NSString *)extension 
													 inPath:(NSString *)path;
                           
- (NSArray *)modules;

- (NSArray *)usedModules;

- (id)firstUnusedModule;

- (id)moduleWithName:(NSString *)mname;

- (void)addModule:(FindModuleView *)aview;

- (void)removeModule:(FindModuleView *)aview;

- (void)findModuleView:(FindModuleView *)aview 
        changeModuleTo:(NSString *)mname;
                           
- (IBAction)chooseSearchPlacesType:(id)sender;

- (unsigned int)draggingEnteredInSearchPlaces:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdatedInSearchPlaces:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperationInSearchPlaces:(id <NSDraggingInfo>)sender;

- (IBAction)addSearchPlaceFromDialog:(id)sender;

- (void)addSearchPlaceWithPath:(NSString *)spath;

- (void)placesMatrixAction:(id)sender;

- (IBAction)removeSearchPlaceButtAction:(id)sender;

- (void)removeSearchPlaceWithPath:(NSString *)spath;

- (NSArray *)searchPlacesPaths;

- (NSArray *)selectedSearchPlacesPaths;

- (void)setCurrentSelection:(NSArray *)paths;

- (IBAction)startFind:(id)sender;

- (void)stopAllSearchs;

- (id)resultWithAddress:(unsigned long)address;

- (void)resultsWindowWillClose:(id)results;

- (void)setSearchResultsHeight:(int)srh;

- (int)searchResultsHeight;

- (void)foundSelectionChanged:(NSArray *)selected;

- (void)openFoundSelection:(NSArray *)selection;

- (void)fileSystemWillChange:(NSNotification *)notif;

- (void)fileSystemDidChange:(NSNotification *)notif;

- (void)watcherNotification:(NSNotification *)notif;

- (void)tile;

- (void)adjustMatrix;

- (void)updateDefaults;

@end


@interface Finder (LSFolders)

- (void)lsfolderDragOperation:(NSData *)opinfo
              concludedAtPath:(NSString *)path;

- (BOOL)openLiveSearchFolderAtPath:(NSString *)path;

- (LSFolder *)addLiveSearchFolderWithPath:(NSString *)path
                              createIndex:(BOOL)index;

- (void)removeLiveSearchFolder:(LSFolder *)folder;

- (LSFolder *)lsfolderWithNode:(FSNode *)node;

- (LSFolder *)lsfolderWithPath:(NSString *)path;

@end


@interface NSDictionary (ColumnsSort)

- (int)compareColInfo:(NSDictionary *)dict;

@end

#endif // FINDER_H
